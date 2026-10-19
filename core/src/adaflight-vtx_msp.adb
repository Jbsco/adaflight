package body Adaflight.VTX_MSP with SPARK_Mode is
   use type Interfaces.Integer_64;

   Sync_Byte          : constant Byte := 16#C8#;
   MSP_Response_Type  : constant Byte := 16#7B#;
   Receiver_Address   : constant Byte := 16#EC#;
   Controller_Address : constant Byte := 16#C8#;
   Start_Version_2    : constant Byte := 16#50#;
   Ext_Type_CRC       : constant := 4;
   Header_Length      : constant := 6;

   function Powf (X, Y : Float) return Float
     with Import, Convention => C, External_Name => "powf", Global => null;

   function To_Int32 (U : Unsigned_32) return Interfaces.Integer_32 is
     (if U >= 2 ** 31 then Interfaces.Integer_32 (Interfaces.Integer_64 (U) - 2 ** 32) else Interfaces.Integer_32 (U));

   function Low (V : Unsigned_16) return Byte is (Byte (V and 16#FF#));
   function High (V : Unsigned_16) return Byte is (Byte (Interfaces.Shift_Right (V, 8)));

   procedure Set_Ready (D : in out Driver; T : Adaflight.VTX_Table.Table; On_Link : Boolean) is
   begin
      if D.Current /= Ready and then T.Bands > 0 and then T.Channels > 0 and then T.Power_Levels > 0
        and then On_Link
      then
         D.Current := Ready;
      end if;
   end Set_Ready;

   procedure Prepare_Frame (D : Driver; S : Settings; T : Adaflight.VTX_Table.Table; Low_Power : Boolean;
                            Frame : out Config_Frame) is
   begin
      Frame := (0  => Device_Type,
                1  => S.Band,
                2  => S.Channel,
                3  => (if Low_Power then 1 else S.Power),
                4  => D.Conf_Pit_Mode,
                5  => Low (S.Freq),
                6  => High (S.Freq),
                7  => (if D.Current = Ready then 1 else 0),
                8  => Byte (Adaflight.VTX_Settings.Low_Power_Disarm'Pos (S.Low_Power)),
                9  => Low (S.Pit_Mode_Freq),
                10 => High (S.Pit_Mode_Freq),
                11 => 1,
                12 => Byte (T.Bands),
                13 => Byte (T.Channels),
                14 => Byte (T.Power_Levels));
   end Prepare_Frame;

   procedure Process (D : in out Driver; S : Settings; T : Adaflight.VTX_Table.Table; Inp : Inputs;
                      Frame : out Config_Frame; Send : out Boolean) is
      use type Interfaces.Integer_32;
      Low_Power : constant Boolean := Low_Power_Disarmed (S, Inp.Armed, Inp.Was_Ever_Armed, Inp.Failsafe);
   begin
      Frame := (others => 0);
      Send := False;
      if D.Current = Ready then
         if Low_Power /= D.Prev_Low_Power then
            D.Config_Changed := True;
            D.Prev_Low_Power := Low_Power;
         end if;
         if D.Config_Changed and then To_Int32 (Inp.Now_Us - D.Last_Time_Us) >= Request_Period_Us then
            Prepare_Frame (D, S, T, Low_Power, Frame);
            Send := True;
            D.Packets := D.Packets + 1;
            D.Last_Time_Us := Inp.Now_Us;
            D.Config_Changed := False;
         end if;
      end if;
   end Process;

   procedure CRSF_Push (Command : Unsigned_16; Payload : Byte_Array; Frame : out CRSF_Frame; Length : out Natural) is
      Size   : constant Unsigned_16 := Unsigned_16 (Payload'Length);
      Header : constant Byte_Array (0 .. Header_Length - 1) :=
        (Start_Version_2, 0, Low (Command), High (Command), Low (Size), High (Size));
      Full   : constant Natural := Payload'Length + Header_Length + 1;
      Check  : Byte;
      Pos    : Natural;
   begin
      Frame := (others => 0);
      Check := CRC8_Update (0, Header (1 .. Header_Length - 1), DVB_S2_Polynomial);
      Check := CRC8_Update (Check, Payload, DVB_S2_Polynomial);
      Frame (0) := Sync_Byte;
      Frame (1) := Byte (Full + Ext_Type_CRC);
      Frame (2) := MSP_Response_Type;
      Frame (3) := Receiver_Address;
      Frame (4) := Controller_Address;
      Frame (5 .. 5 + Header_Length - 1) := Header;
      Pos := 5 + Header_Length;
      for K in Payload'Range loop
         pragma Loop_Invariant (Pos = 5 + Header_Length + (K - Payload'First));
         Frame (Pos) := Payload (K);
         Pos := Pos + 1;
      end loop;
      Frame (Pos) := Check;
      Pos := Pos + 1;
      Frame (Pos) := CRC8_Update (0, Frame (2 .. Pos - 1), DVB_S2_Polynomial);
      Length := Pos + 1;
   end CRSF_Push;

   procedure Set_Band_Channel (D : in out Driver; Band, Channel : Unsigned_8) is
   begin
      if Band /= D.Conf_Band or else Channel /= D.Conf_Channel then
         D.Config_Changed := True;
      end if;
      D.Conf_Band := Band;
      D.Conf_Channel := Channel;
   end Set_Band_Channel;

   procedure Set_Power_Index (D : in out Driver; T : Adaflight.VTX_Table.Table; Index : Unsigned_8) is
   begin
      if Adaflight.VTX_Table.Has_Power_Value (T, Natural (Index)) then
         declare
            Value : constant Unsigned_16 := Adaflight.VTX_Table.Power_Value_Of (T, Natural (Index));
         begin
            if Value /= D.Conf_Power then
               D.Config_Changed := True;
            end if;
            D.Conf_Power := Value;
         end;
      end if;
   end Set_Power_Index;

   procedure Set_Pit_Mode (D : in out Driver; On : Boolean) is
      Value : constant Unsigned_8 := (if On then 1 else 0);
   begin
      if Value /= D.Conf_Pit_Mode then
         D.Config_Changed := True;
      end if;
      D.Conf_Pit_Mode := Value;
   end Set_Pit_Mode;

   procedure Set_Frequency (D : in out Driver; Freq : Unsigned_16) is
   begin
      if Freq /= D.Conf_Freq then
         D.Config_Changed := True;
      end if;
      D.Conf_Freq := Freq;
   end Set_Frequency;

   procedure Get_Band_Channel (D : Driver; Band, Channel : out Unsigned_8; Known : out Boolean) is
   begin
      Band := 0;
      Channel := 0;
      Known := Is_Ready (D);
      if Known then
         Band := D.Conf_Band;
         Channel := D.Conf_Channel;
      end if;
   end Get_Band_Channel;

   procedure Get_Power_Index (D : Driver; T : Adaflight.VTX_Table.Table; Index : in out Unsigned_8;
                              Known : out Boolean) is
   begin
      Known := False;
      if not Is_Ready (D) then
         return;
      end if;
      if D.Conf_Power = 0 then
         Index := 0;
         Known := True;
         return;
      end if;
      for I in 1 .. T.Power_Levels loop
         if D.Conf_Power = T.Power_Value (I) then
            Index := Unsigned_8 (I);
            Known := True;
            return;
         end if;
      end loop;
   end Get_Power_Index;

   procedure Get_Frequency (D : Driver; T : Adaflight.VTX_Table.Table; Freq : out Unsigned_16; Known : out Boolean) is
   begin
      Freq := 0;
      Known := Is_Ready (D);
      if Known then
         Freq := Adaflight.VTX_Table.Frequency_Of (T, Natural (D.Conf_Band), Natural (D.Conf_Channel));
      end if;
   end Get_Frequency;

   procedure Get_Status (D : Driver; Pit_Mode : out Boolean; Known : out Boolean) is
   begin
      Pit_Mode := False;
      Known := Is_Ready (D);
      if Known then
         Pit_Mode := D.Conf_Pit_Mode /= 0;
      end if;
   end Get_Status;

   procedure Get_Power_Levels (D : Driver; T : Adaflight.VTX_Table.Table; Count : out Adaflight.VTX_Table.Power_Count;
                               Levels, Powers : out Level_Values) is
      Milliwatts : Float;
   begin
      Levels := (others => 0);
      Powers := (others => 0);
      Count := 0;
      if not Is_Ready (D) then
         return;
      end if;
      Count := T.Power_Levels;
      for I in 1 .. T.Power_Levels loop
         Levels (I) := T.Power_Value (I);
         Milliwatts := Powf (10.0, Float (Levels (I)) / 10.0);
         Powers (I) := Unsigned_16 (Float'Truncation (Float'Max (0.0, Float'Min (Milliwatts, 65_535.0))));
      end loop;
   end Get_Power_Levels;

end Adaflight.VTX_MSP;
