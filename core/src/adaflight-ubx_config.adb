package body Adaflight.UBX_Config with SPARK_Mode is

   subtype Value_Fill is Natural range 0 .. Max_Values;
   subtype Value_Index is Natural range 0 .. Max_Values - 1;
   type Value_Data is array (Value_Index) of Byte;

   --  The values of a keyed message, each key little-endian ahead of its
   --  value.
   type Value_Set is record
      Data : Value_Data := (others => 0);
      Fill : Value_Fill := 0;
   end record;

   procedure Add (V : in out Value_Set; K : Key; Value : Unsigned_64)
     with Pre  => Value_Size (K) > 0 and then V.Fill + 4 + Value_Size (K) <= Max_Values,
          Post => V.Fill = V.Fill'Old + 4 + Value_Size (K)
   is
      Size : constant Natural := Value_Size (K);
   begin
      for I in 0 .. 3 loop
         V.Data (V.Fill + I) := Byte (Interfaces.Shift_Right (K, 8 * I) and 16#FF#);
      end loop;
      for I in 0 .. Size - 1 loop
         V.Data (V.Fill + 4 + I) := Byte (Interfaces.Shift_Right (Value, 8 * I) and 16#FF#);
      end loop;
      V.Fill := V.Fill + 4 + Size;
   end Add;

   function Build (Class, Id : Unsigned_8; Payload : Byte_Array; Skip_Ack : Boolean) return Frame
     with Pre  => Payload'Length <= Max_Payload,
          Post => Build'Result.Length = 8 + Payload'Length and then Build'Result.Id = Id
                  and then Build'Result.Skip_Ack = Skip_Ack
   is
      F    : Frame;
      Len  : constant Payload_Length := Payload'Length;
      Ck_A : Unsigned_8 := 0;
      Ck_B : Unsigned_8 := 0;
   begin
      F.Data (0) := Preamble_1;
      F.Data (1) := Preamble_2;
      F.Data (2) := Class;
      F.Data (3) := Id;
      F.Data (4) := Byte (Len mod 256);
      F.Data (5) := Byte (Len / 256);
      for I in 0 .. Len - 1 loop
         F.Data (6 + I) := Payload (Payload'First + I);
      end loop;
      for I in 2 .. 5 + Len loop
         Ck_A := Ck_A + F.Data (I);
         Ck_B := Ck_B + Ck_A;
      end loop;
      F.Data (6 + Len) := Ck_A;
      F.Data (7 + Len) := Ck_B;
      F.Length := 8 + Len;
      F.Id := Id;
      F.Skip_Ack := Skip_Ack;
      return F;
   end Build;

   --  A keyed message: the version, the RAM layer, two reserved bytes and
   --  the values.
   function Keyed_Message (V : Value_Set; Skip_Ack : Boolean) return Frame
     with Post => Keyed_Message'Result.Length = 12 + V.Fill
   is
      Payload : Byte_Array (0 .. 3 + V.Fill) := (others => 0);
   begin
      Payload (1) := 1;
      for I in 0 .. V.Fill - 1 loop
         Payload (4 + I) := V.Data (I);
      end loop;
      return Build (Class_Cfg, Msg_Cfg_Valset, Payload, Skip_Ack);
   end Keyed_Message;

   procedure Put_U16 (A : in out Byte_Array; Pos : Buffer_Index; V : Unsigned_16)
     with Pre => Pos in A'Range and then Pos + 1 in A'Range
   is
   begin
      A (Pos) := Byte (V and 16#FF#);
      A (Pos + 1) := Byte (Interfaces.Shift_Right (V, 8));
   end Put_U16;

   procedure Put_U32 (A : in out Byte_Array; Pos : Buffer_Index; V : Unsigned_32)
     with Pre => Pos in A'Range and then Pos + 3 in A'Range
   is
   begin
      for I in 0 .. 3 loop
         A (Pos + I) := Byte (Interfaces.Shift_Right (V, 8 * I) and 16#FF#);
      end loop;
   end Put_U32;

   ----------
   -- Poll --
   ----------

   function Poll (Class, Id : Unsigned_8) return Frame is
      Empty : constant Byte_Array (1 .. 0) := (others => 0);
   begin
      return Build (Class, Id, Empty, False);
   end Poll;

   ------------------
   -- Message_Rate --
   ------------------

   function Message_Rate (Class, Id, Rate : Unsigned_8) return Frame is
      Payload : constant Byte_Array (0 .. 2) := (Class, Id, Rate);
   begin
      return Build (Class_Cfg, Msg_Cfg_Msg, Payload, False);
   end Message_Rate;

   ----------------------
   -- Message_Rate_Key --
   ----------------------

   function Message_Rate_Key (K : Key; Rate : Unsigned_8) return Frame is
      V : Value_Set;
   begin
      Add (V, K, Unsigned_64 (Rate));
      return Keyed_Message (V, True);
   end Message_Rate_Key;

   --------------
   -- Nav_Rate --
   --------------

   function Nav_Rate (Rate : Measurement_Rate_Hz; Solutions : Unsigned_16; Time_Ref : Unsigned_8;
                      Keyed : Boolean) return Frame is
      Period_Ms : constant Unsigned_16 := 1000 / Rate;
   begin
      if Keyed then
         declare
            V : Value_Set;
         begin
            Add (V, Key_Rate_Meas, Unsigned_64 (Period_Ms));
            Add (V, Key_Rate_Nav, Unsigned_64 (Solutions));
            Add (V, Key_Rate_Timeref, Unsigned_64 (Time_Ref));
            return Keyed_Message (V, False);
         end;
      else
         declare
            Payload : Byte_Array (0 .. 5) := (others => 0);
         begin
            Put_U16 (Payload, 0, Period_Ms);
            Put_U16 (Payload, 2, Solutions);
            Put_U16 (Payload, 4, Unsigned_16 (Time_Ref));
            return Build (Class_Cfg, Msg_Cfg_Rate, Payload, True);
         end;
      end if;
   end Nav_Rate;

   function Model_Code (Model : Dynamic_Model) return Unsigned_8 is
     (if Model = Portable then 0 else Dynamic_Model'Pos (Model) + 1);

   function UTC_Code (UTC : UTC_Standard) return Unsigned_8 is
     (case UTC is
         when Auto => 0,
         when USNO => 3,
         when EU   => 5,
         when SU   => 6,
         when NTSC => 7);

   -------------------
   -- Model_Message --
   -------------------

   function Model_Message (Model : Dynamic_Model; UTC : UTC_Standard; Keyed : Boolean) return Frame is
   begin
      if Keyed then
         declare
            V : Value_Set;
         begin
            Add (V, Key_Dynamic_Model, Unsigned_64 (Model_Code (Model)));
            Add (V, Key_UTC_Standard, Unsigned_64 (UTC_Code (UTC)));
            return Keyed_Message (V, True);
         end;
      else
         declare
            Payload : Byte_Array (0 .. 35) := (others => 0);
         begin
            Put_U16 (Payload, 0, 16#FFFF#);
            Payload (2) := Model_Code (Model);
            Payload (3) := 3;
            Put_U32 (Payload, 8, 10_000);
            Payload (12) := 5;
            Put_U16 (Payload, 14, 250);
            Put_U16 (Payload, 16, 250);
            Put_U16 (Payload, 18, 100);
            Put_U16 (Payload, 20, 300);
            Payload (23) := 60;
            Put_U16 (Payload, 28, 200);
            Payload (30) := UTC_Code (UTC);
            return Build (Class_Cfg, Msg_Cfg_Nav5, Payload, False);
         end;
      end if;
   end Model_Message;

   ------------------------
   -- Assistance_Message --
   ------------------------

   function Assistance_Message (Keyed : Boolean) return Frame is
   begin
      if Keyed then
         declare
            V : Value_Set;
         begin
            Add (V, Key_Use_Assistance, 1);
            return Keyed_Message (V, True);
         end;
      else
         declare
            Payload : Byte_Array (0 .. 39) := (others => 0);
         begin
            Put_U16 (Payload, 0, 2);
            Put_U16 (Payload, 2, 16#4000#);
            Payload (27) := 1;
            return Build (Class_Cfg, Msg_Cfg_Navx5, Payload, False);
         end;
      end if;
   end Assistance_Message;

   ------------------------
   -- Power_Mode_Message --
   ------------------------

   function Power_Mode_Message (Keyed : Boolean) return Frame is
   begin
      if Keyed then
         declare
            V : Value_Set;
         begin
            Add (V, Key_Power_Operate_Mode, 0);
            return Keyed_Message (V, True);
         end;
      else
         declare
            Payload : constant Byte_Array (0 .. 7) := (others => 0);
         begin
            return Build (Class_Cfg, Msg_Cfg_Pms, Payload, False);
         end;
      end if;
   end Power_Mode_Message;

   --  The scan mask bits of the system's satellites, numbered from 120.
   function Scan_Mask (Mode : Sbas_Mode) return Unsigned_32 is
     (case Mode is
         when EGNOS        => 16#0001_0048#,
         when WAAS         => 16#0004_A800#,
         when MSAS         => 16#0002_0200#,
         when GAGAN        => 16#0000_1180#,
         when Auto | None  => 0);

   ------------------
   -- Sbas_Message --
   ------------------

   function Sbas_Message (Mode : Sbas_Mode; Integrity : Boolean; Keyed : Boolean) return Frame is
   begin
      if Keyed then
         declare
            V : Value_Set;
         begin
            Add (V, Key_Sbas_Test_Mode, (if Mode /= None then 1 else 0));
            Add (V, Key_Sbas_Ranging, 1);
            Add (V, Key_Sbas_Corrections, 1);
            if Integrity then
               Add (V, Key_Sbas_Integrity, 1);
            end if;
            Add (V, Key_Sbas_Scan_Mask, Unsigned_64 (Scan_Mask (Mode)));
            return Keyed_Message (V, True);
         end;
      else
         declare
            Payload : Byte_Array (0 .. 7) := (others => 0);
         begin
            Payload (0) := (if Mode /= None then 3 else 2);
            Payload (1) := (if Integrity then 7 else 3);
            Payload (2) := 3;
            Put_U32 (Payload, 4, Scan_Mask (Mode));
            return Build (Class_Cfg, Msg_Cfg_Sbas, Payload, False);
         end;
      end if;
   end Sbas_Message;

   --------------------------
   -- Disable_NMEA_Message --
   --------------------------

   function Disable_NMEA_Message return Frame is
      V : Value_Set;
   begin
      Add (V, Key_NMEA_GGA_UART1, 0);
      Add (V, Key_NMEA_VTG_UART1, 0);
      Add (V, Key_NMEA_GSV_UART1, 0);
      Add (V, Key_NMEA_GLL_UART1, 0);
      Add (V, Key_NMEA_GSA_UART1, 0);
      Add (V, Key_NMEA_RMC_UART1, 0);
      return Keyed_Message (V, True);
   end Disable_NMEA_Message;

   -------------------------
   -- Satellite_Info_Rate --
   -------------------------

   function Satellite_Info_Rate (Divisor : Unsigned_8; M8, M9 : Boolean) return Frame is
   begin
      if M9 then
         return Message_Rate_Key (Key_Nav_Sat_UART1, Divisor);
      elsif M8 then
         return Message_Rate (Class_Nav, Msg_Nav_Sat, Divisor);
      else
         return Message_Rate (Class_Nav, Msg_Nav_Svinfo, Divisor);
      end if;
   end Satellite_Info_Rate;

   ------------------
   -- Gnss_Message --
   ------------------

   function Gnss_Message (Reply : Gnss_Reply; Disable_Sbas, Enable_Galileo : Boolean) return Frame is
      Blocks  : constant Natural := Natural'Min (Natural (Reply (3)), Max_Gnss_Blocks);
      Payload : Byte_Array (0 .. 3 + 8 * Blocks) := Reply (0 .. 3 + 8 * Blocks);
   begin
      for B in 0 .. Blocks - 1 loop
         declare
            Id    : constant Byte := Reply (4 + 8 * B);
            Flags : constant Buffer_Index := 8 + 8 * B;
         begin
            if Id = 1 and then Disable_Sbas then
               Payload (Flags) := Payload (Flags) and not 1;
            end if;
            if Id = 2 then
               if Enable_Galileo then
                  Payload (Flags) := Payload (Flags) or 1;
               else
                  Payload (Flags) := Payload (Flags) and not 1;
               end if;
            end if;
         end;
      end loop;
      return Build (Class_Cfg, Msg_Cfg_Gnss, Payload, False);
   end Gnss_Message;

end Adaflight.UBX_Config;
