package body Adaflight.Jeti_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;
   use type Adaflight.Jeti_Ex_Bus.Frame_State_Kind;

   type Data_Type is (Type_22b, Type_GPS, Type_Description);

   type Label_Text is record
      Label : String (1 .. 15);
      Label_Length : Natural range 0 .. 15;
      Unit : String (1 .. 3);
      Unit_Length : Natural range 0 .. 3;
      Kind : Data_Type;
      Decimals : Unsigned_8;
   end record;

   Degree : constant Character := Character'Val (16#B0#);

   function Entry_Of
     (Label : String; Unit : String; Kind : Data_Type; Decimals : Unsigned_8) return Label_Text
     with Pre => Label'Length <= 15 and then Unit'Length <= 3 and then Decimals <= 3
   is
      R : Label_Text :=
        (Label => (others => ' '), Label_Length => Label'Length, Unit => (others => ' '),
         Unit_Length => Unit'Length, Kind => Kind, Decimals => Interfaces.Shift_Left (Decimals, 5));
   begin
      for K in 0 .. Label'Length - 1 loop
         R.Label (1 + K) := Label (Label'First + K);
      end loop;
      for K in 0 .. Unit'Length - 1 loop
         R.Unit (1 + K) := Unit (Unit'First + K);
      end loop;
      return R;
   end Entry_Of;

   function Sensor (I : Sensor_Index) return Label_Text is
     (case I is
        when 0 => Entry_Of ("BF D1", "", Type_Description, 0),
        when 1 => Entry_Of ("Voltage", "V", Type_22b, 1),
        when 2 => Entry_Of ("Current", "A", Type_22b, 2),
        when 3 => Entry_Of ("Altitude", "m", Type_22b, 2),
        when 4 => Entry_Of ("Capacity", "mAh", Type_22b, 0),
        when 5 => Entry_Of ("Power", "W", Type_22b, 1),
        when 6 => Entry_Of ("Roll angle", (1 => Degree), Type_22b, 1),
        when 7 => Entry_Of ("Pitch angle", (1 => Degree), Type_22b, 1),
        when 8 => Entry_Of ("Heading", (1 => Degree), Type_22b, 1),
        when 9 => Entry_Of ("Vario", "m/s", Type_22b, 2),
        when 10 => Entry_Of ("GPS Sats", "", Type_22b, 0),
        when 11 => Entry_Of ("GPS Long", "", Type_GPS, 0),
        when 12 => Entry_Of ("GPS Lat", "", Type_GPS, 0),
        when 13 => Entry_Of ("GPS Speed", "m/s", Type_22b, 2),
        when 14 => Entry_Of ("GPS H-Distance", "m", Type_22b, 0),
        when 15 => Entry_Of ("GPS H-Direction", (1 => Degree), Type_22b, 1),
        when 16 => Entry_Of ("BF D2", "", Type_Description, 0),
        when 17 => Entry_Of ("GPS Heading", (1 => Degree), Type_22b, 1),
        when 18 => Entry_Of ("GPS Altitude", "m", Type_22b, 2),
        when 19 => Entry_Of ("G-Force X", "", Type_22b, 3),
        when 20 => Entry_Of ("G-Force Y", "", Type_22b, 3),
        when 21 => Entry_Of ("G-Force Z", "", Type_22b, 3),
        when 22 => Entry_Of ("RPM", "", Type_22b, 0),
        when 23 => Entry_Of ("Trip Distance", "m", Type_22b, 1),
        when 24 => Entry_Of ("DEBUG0", "", Type_22b, 0),
        when 25 => Entry_Of ("DEBUG1", "", Type_22b, 0),
        when 26 => Entry_Of ("DEBUG2", "", Type_22b, 0),
        when 27 => Entry_Of ("DEBUG3", "", Type_22b, 0),
        when 28 => Entry_Of ("DEBUG4", "", Type_22b, 0),
        when 29 => Entry_Of ("DEBUG5", "", Type_22b, 0),
        when 30 => Entry_Of ("DEBUG6", "", Type_22b, 0),
        when 31 => Entry_Of ("DEBUG7", "", Type_22b, 0));

   Type_Code : constant array (Data_Type) of Unsigned_8 := (Type_22b => 4, Type_GPS => 9, Type_Description => 255);

   function Value_Length (Kind : Data_Type) return Positive is
     (case Kind is when Type_22b => 3, when Type_GPS => 4, when Type_Description => 1);

   GPS_Sensors : constant array (1 .. 8) of Sensor_Index := (10, 11, 12, 13, 14, 15, 17, 18);

   procedure Enable_GPS (S : in out State; On : Boolean)
     with Global => null
   is
   begin
      for G of GPS_Sensors loop
         S.Enabled (G) := On;
      end loop;
   end Enable_GPS;

   function Next_Active (S : State; Current : Sensor_Index) return Sensor_Index is
      I : Natural := Current + 1;
   begin
      while I < Sensor_Count loop
         pragma Loop_Invariant (I in Current + 1 .. Sensor_Count - 1);
         pragma Loop_Variant (Increases => I);
         if S.Enabled (I) then
            return I;
         end if;
         I := I + 1;
      end loop;
      return S.First_Active;
   end Next_Active;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
   begin
      S := (others => <>);
      if C.Voltage_Meter then
         S.Enabled (1) := True;
      end if;
      if C.Current_Meter then
         S.Enabled (2) := True;
      end if;
      if C.Voltage_Meter and then C.Current_Meter then
         S.Enabled (5) := True;
         S.Enabled (4) := True;
      end if;
      if C.Baro then
         S.Enabled (3) := True;
         S.Enabled (9) := True;
      end if;
      if C.Acc then
         S.Enabled (6) := True;
         S.Enabled (7) := True;
         S.Enabled (19) := True;
         S.Enabled (20) := True;
         S.Enabled (21) := True;
      end if;
      if C.Mag then
         S.Enabled (8) := True;
      end if;
      Enable_GPS (S, C.GPS_Feature);
      if C.ESC_Feature then
         S.Enabled (22) := True;
      end if;
      if C.Debug_Mode then
         for D in 24 .. 31 loop
            S.Enabled (D) := True;
         end loop;
      end if;
      S.First_Active := Next_Active (S, 0);
   end Init;

   function CRC8 (Data : Frame_Bytes; First : Positive; Count : Natural) return Unsigned_8
     with Pre => First <= Max_Frame and then Count <= Max_Frame - First + 1
   is
      CRC : Unsigned_8 := 0;
   begin
      for K in 0 .. Count - 1 loop
         CRC := CRC xor Data (First + K);
         CRC := CRC xor Interfaces.Shift_Left (CRC, 1) xor Interfaces.Shift_Left (CRC, 2)
           xor Unsigned_8 (Interfaces.Shift_Right (Unsigned_32 (16#0E09_0700#), Natural ((CRC / 8) and 16#18#))
                           and 16#FF#);
      end loop;
      return CRC;
   end CRC8;

   --  Degrees and thousandths of a minute, with the longitude and sign flags.
   function GPS_Value (Value : Integer_32; Is_Long : Boolean) return Unsigned_32 is
      Abs_Value : constant Interfaces.Integer_64 := abs Interfaces.Integer_64 (Value);
      Degrees   : constant Unsigned_32 := Unsigned_32 (Abs_Value / 10_000_000);
      Minutes   : constant Unsigned_32 :=
        Unsigned_32 ((Abs_Value - Interfaces.Integer_64 (Degrees) * 10_000_000) * 6 / 1_000);
      High      : Unsigned_32 := Degrees;
   begin
      if Is_Long then
         High := High or 16#2000#;
      end if;
      if Value < 0 then
         High := High or 16#4000#;
      end if;
      return Minutes or Interfaces.Shift_Left (High, 16);
   end GPS_Value;

   function G_Force (ADC : Acc_Reading; One_G : Positive) return Integer_32 is
      Scaled : constant Float := ADC / Float (One_G) * 1000.0;
   begin
      if Scaled >= 32_767.0 then
         return 32_767;
      elsif Scaled <= -32_768.0 then
         return -32_768;
      end if;
      return Integer_32 (Float'Truncation (Scaled));
   end G_Force;

   --  The nearest whole number with a tie going to the even one.
   function Round_To_Even (X : Float) return Integer_32
     with Pre => X in 0.0 .. 2.0E8
   is
      Base     : constant Integer_32 := Integer_32 (Float'Truncation (X));
      Fraction : constant Float := X - Float'Truncation (X);
   begin
      if Fraction > 0.5 or else (Fraction = 0.5 and then Base mod 2 = 1) then
         return Base + 1;
      end if;
      return Base;
   end Round_To_Even;

   function Average_Rpm (Inp : Inputs) return Integer_32 is
      Sum   : Natural range 0 .. Max_Motors * Erpm_Hundreds'Last := 0;
      Valid : Natural range 0 .. Max_Motors := 0;
   begin
      for M in 0 .. Inp.Motor_Count - 1 loop
         pragma Loop_Invariant (Valid <= M and then Sum <= M * Erpm_Hundreds'Last);
         if Inp.Data_Age (M) < 255 then
            Sum := Sum + Inp.Rpm (M);
            Valid := Valid + 1;
         end if;
      end loop;
      if Valid = 0 then
         return 0;
      end if;
      declare
         Rpm : constant Float := Float (Sum) * Inp.Erpm_To_Hz * 60.0;
      begin
         return Round_To_Even (Rpm / 10.0 / Float (Valid));
      end;
   end Average_Rpm;

   function Power (Inp : Inputs) return Integer_32 is
      Product : constant Interfaces.Integer_64 :=
        Interfaces.Integer_64 (Inp.Pack_Voltage) * Interfaces.Integer_64 (Inp.Amperage);
      Wrapped : constant Interfaces.Integer_64 := (Product + 2 ** 31) mod 2 ** 32 - 2 ** 31;
   begin
      return Integer_32 (Wrapped / 1_000);
   end Power;

   function Sensor_Value (Inp : Inputs; I : Sensor_Index) return Integer_32 is
     (case I is
        when 1 => Integer_32 (Inp.Legacy_Voltage),
        when 2 => Inp.Amperage,
        when 3 => Inp.Altitude_Cm,
        when 4 => Inp.MAh_Drawn,
        when 5 => Power (Inp),
        when 6 => Integer_32 (Inp.Roll),
        when 7 => Integer_32 (Inp.Pitch),
        when 8 => Integer_32 (Inp.Yaw),
        when 9 => Integer_32 (Inp.Vario),
        when 10 => Integer_32 (Inp.Satellites),
        when 11 | 12 => 0,
        when 13 => Integer_32 (Inp.Ground_Speed),
        when 14 => Integer_32 (Inp.Home_Distance),
        when 15 => Integer_32 (Inp.Home_Direction) / 10,
        when 17 => Integer_32 (Inp.Ground_Course),
        when 18 => Inp.GPS_Altitude_Cm,
        when 19 .. 21 => G_Force (Inp.Acc_ADC (I - 19), Inp.One_G),
        when 22 => Average_Rpm (Inp),
        when 23 => 0,
        when 24 .. 31 => Integer_32 (Inp.Debug (I - 24)),
        when 0 | 16 => -1);

   function Bits_Of (V : Integer_32) return Unsigned_32 is
     (if V >= 0 then Unsigned_32 (V) else Unsigned_32 (Interfaces.Integer_64 (V) + 2 ** 32));

   function Sensor_Bits (Inp : Inputs; I : Sensor_Index) return Unsigned_32 is
     (case I is
        when 11 => GPS_Value (Inp.Longitude, True),
        when 12 => GPS_Value (Inp.Latitude, False),
        when others => Bits_Of (Sensor_Value (Inp, I)));

   --  The EX message starts after the six bytes of the EX Bus header: its
   --  sync byte, the type and length, the serial number, the reserved byte,
   --  then the data from the identifier on.
   Ex     : constant := 7;
   Ex_Id  : constant := Ex + 7;

   procedure Text_Message (O : in out Output; Id : Sensor_Index; Ex_Len : out Natural)
     with Global => null, Post => Ex_Len <= 26
   is
      T : constant Label_Text := Sensor (Id);
      Len : constant Natural := 8 + T.Label_Length + T.Unit_Length;
   begin
      Ex_Len := Len;
      O.Data (Ex + 1) := Unsigned_8 (Len);
      O.Data (Ex + 4) := Unsigned_8 (Id) and 16#F0#;
      O.Data (Ex_Id) := Unsigned_8 (Id) and 16#0F#;
      O.Data (Ex_Id + 1) := Unsigned_8 (T.Label_Length * 8 + T.Unit_Length);
      for K in 1 .. T.Label_Length loop
         O.Data (Ex_Id + 1 + K) := Character'Pos (T.Label (K));
      end loop;
      for K in 1 .. T.Unit_Length loop
         O.Data (Ex_Id + 1 + T.Label_Length + K) := Character'Pos (T.Unit (K));
      end loop;
      O.Data (Ex + 1 + Len) := CRC8 (O.Data, Ex + 1, Len);
   end Text_Message;

   procedure Value_Message
     (S : State; Inp : Inputs; O : in out Output; Item : in out Sensor_Index; Ex_Len : out Natural)
     with Global => null, Post => Ex_Len <= 26
   is
      Start     : constant Sensor_Index := Item;
      Max_Group : constant Natural := Item / 16 * 16 + 16;
      Used      : Natural range 0 .. 20 := 0;
   begin
      O.Data (Ex + 4) := Unsigned_8 (Item / 16 * 16);
      while Item < Max_Group loop
         pragma Loop_Invariant (Used <= 15);
         declare
            T     : constant Label_Text := Sensor (Item);
            Value : Unsigned_32 := Sensor_Bits (Inp, Item);
         begin
            O.Data (Ex_Id + Used) := Interfaces.Shift_Left (Unsigned_8 (Item mod 16), 4) or Type_Code (T.Kind);
            Used := Used + 1;
            for K in 1 .. Value_Length (T.Kind) - 1 loop
               pragma Loop_Invariant (Used = Used'Loop_Entry + K - 1);
               O.Data (Ex_Id + Used) := Unsigned_8 (Value and 16#FF#);
               Value := Interfaces.Shift_Right (Value, 8);
               Used := Used + 1;
            end loop;
            if T.Kind /= Type_GPS then
               O.Data (Ex_Id + Used) := (Unsigned_8 (Value and 16#FF#) and 16#9F#) or T.Decimals;
            else
               O.Data (Ex_Id + Used) := Unsigned_8 (Value and 16#FF#);
            end if;
            Used := Used + 1;
         end;
         Item := Next_Active (S, Item);
         exit when Start >= Item;
         exit when Used + Value_Length (Sensor (Item).Kind) + 1 >= 18;
      end loop;
      O.Data (Ex + 1) := 16#40# or Unsigned_8 (6 + Used);
      O.Data (Ex + 1 + 6 + Used) := CRC8 (O.Data, Ex + 1, 6 + Used);
      Ex_Len := 6 + Used;
   end Value_Message;

   procedure Bus_Message (O : in out Output; Packet_Id : Unsigned_8; Ex_Len : Natural)
     with Global => null, Pre => Ex_Len <= 26
   is
      Sub_Len : constant Natural := Ex_Len + 2;
      Msg_Len : constant Natural := 8 + Sub_Len;
      Bus     : Adaflight.Jeti_Ex_Bus.Frame_Bytes := (others => 0);
      CRC     : Unsigned_16;
   begin
      O.Data (4) := Packet_Id;
      O.Data (6) := Unsigned_8 (Sub_Len);
      O.Data (3) := Unsigned_8 (Msg_Len);
      for K in 0 .. Msg_Len - 3 loop
         Bus (K) := Natural (O.Data (1 + K));
      end loop;
      CRC := Adaflight.Jeti_Ex_Bus.Frame_CRC16 (Bus, Msg_Len - 2);
      O.Data (Msg_Len - 1) := Unsigned_8 (CRC and 16#FF#);
      O.Data (Msg_Len) := Unsigned_8 (Interfaces.Shift_Right (CRC, 8));
      O.Length := Msg_Len;
   end Bus_Message;

   procedure Send (S : in out State; C : Settings; Inp : Inputs; Packet_Id : Unsigned_8; O : in out Output)
     with Global => null
   is
      Ex_Len : Natural;
   begin
      if S.Request_Loop /= 0 then
         for Step in 1 .. Sensor_Count + 1 loop
            S.Description := S.Description + 1;
            exit when S.Description >= Sensor_Count;
            exit when S.Enabled (Natural (S.Description))
              or else Sensor (Natural (S.Description)).Kind = Type_Description;
         end loop;
         if S.Description >= Sensor_Count then
            S.Description := 0;
         end if;
         Text_Message (O, Natural (S.Description), Ex_Len);
         Bus_Message (O, Packet_Id, Ex_Len);
         S.Request_Loop := S.Request_Loop - 1;
         if S.Request_Loop = 0 then
            S.Item := S.First_Active;
            if C.GPS_Feature then
               Enable_GPS (S, False);
               S.All_Active := False;
            end if;
         end if;
      elsif S.First_Active /= 0 then
         declare
            Item : Sensor_Index := S.Item;
         begin
            Value_Message (S, Inp, O, Item, Ex_Len);
            S.Item := Item;
         end;
         Bus_Message (O, Packet_Id, Ex_Len);
         if not S.All_Active and then Inp.GPS_Sensor then
            Enable_GPS (S, True);
            S.All_Active := True;
         end if;
      end if;
   end Send;

   ------------
   -- Handle --
   ------------

   procedure Handle
     (S       : in out State;
      Rx      : in out Adaflight.Jeti_Ex_Bus.State;
      C       : Settings;
      Inp     : Inputs;
      Now_Us  : Unsigned_32;
      Waiting : Natural;
      O       : out Output)
   is
      Msg_Len : constant Natural := Rx.Request_Frame (Adaflight.Jeti_Ex_Bus.Header_Msg_Len);
   begin
      O := (others => <>);
      O.Data (1 .. 16) := (16#3B#, 16#01#, 0, 0, 16#3A#, 0, 16#9F#, 0, 16#1E#, 16#A4#, 0, 0, 0, 0, 0, 0);
      if not Rx.Can_Tx or else Rx.Request_State /= Adaflight.Jeti_Ex_Bus.Received then
         return;
      end if;
      if Now_Us - Rx.Request_Stamp_Us > 3_000 then
         Rx.Request_State := Adaflight.Jeti_Ex_Bus.Zero;
      elsif Rx.Request_Frame (4) = 16#3A#
        and then Msg_Len <= Adaflight.Jeti_Ex_Bus.Max_Channel_Frame
        and then Adaflight.Jeti_Ex_Bus.Frame_CRC16 (Rx.Request_Frame, Msg_Len) = 0
      then
         if Waiting = 0 then
            Send (S, C, Inp, Unsigned_8 (Rx.Request_Frame (3)), O);
            Rx.Can_Tx := False;
            Rx.Request_State := Adaflight.Jeti_Ex_Bus.Processed;
         end if;
      else
         Rx.Request_State := Adaflight.Jeti_Ex_Bus.Zero;
      end if;
   end Handle;

end Adaflight.Jeti_Telemetry;
