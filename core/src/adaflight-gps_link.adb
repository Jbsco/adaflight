with Adaflight.Clock;

package body Adaflight.GPS_Link with SPARK_Mode is
   use Adaflight.GPS_Frames;
   use Adaflight.UBX_Config;

   Timeout_Ms             : constant := 2_500;
   Ack_Timeout_Ms         : constant := 150;
   Baud_Change_Interval   : constant := 330;
   Change_Interval        : constant := 110;
   Baud_Test_Count        : constant := 3;
   Sweep_Step_Limit       : constant := 12;
   Sweep_Backoff_Ms       : constant := 30_000;
   Flown_Speed_Threshold  : constant := 15;
   Indicator_Period_Us    : constant := 150_000;

   Step_Detect_Unit  : constant Unsigned_32 := 0;
   Step_Slow_Rate    : constant Unsigned_32 := 1;
   Step_Disable_NMEA : constant Unsigned_32 := 2;
   Step_VTG          : constant Unsigned_32 := 3;
   Step_GSV          : constant Unsigned_32 := 4;
   Step_GLL          : constant Unsigned_32 := 5;
   Step_GGA          : constant Unsigned_32 := 6;
   Step_GSA          : constant Unsigned_32 := 7;
   Step_RMC          : constant Unsigned_32 := 8;
   Step_Model        : constant Unsigned_32 := 9;
   Step_Assistance   : constant Unsigned_32 := 10;
   Step_Sbas         : constant Unsigned_32 := 11;
   Step_Power        : constant Unsigned_32 := 12;
   Step_Pvt          : constant Unsigned_32 := 13;
   Step_Sol          : constant Unsigned_32 := 14;
   Step_Posllh       : constant Unsigned_32 := 15;
   Step_Status       : constant Unsigned_32 := 16;
   Step_Velned       : constant Unsigned_32 := 17;
   Step_Dop          : constant Unsigned_32 := 18;
   Step_Sat_Info     : constant Unsigned_32 := 19;
   Step_Nav_Rate     : constant Unsigned_32 := 20;
   Step_Gnss         : constant Unsigned_32 := 21;
   Step_Complete     : constant Unsigned_32 := 22;

   Rad : constant Float := Float'Machine (Float'Machine (3.14159265358979323846) / 180.0);

   --  Centimetres per unit of latitude at the equator, folded as the
   --  reference's compiler folds it.
   Angle_To_Cm : constant Float :=
     Float'Machine (Float'Machine (Float'Machine (Float'Machine (111.3195) * 1000.0) * 100.0) / 10_000_000.0);

   subtype Local_Cm is Float range -2.4e9 .. 2.4e9;
   subtype Altitude_Difference is Float range -2.2e9 .. 2.2e9;
   subtype Square_Cm is Float range 0.0 .. 5.8e18;
   subtype Altitude_Square is Float range 0.0 .. 4.9e18;
   subtype Sum_Cm is Float range 0.0 .. 1.75e19;
   subtype Root_Cm is Float range 0.0 .. 4.2e9;
   subtype Degrees_100 is Float range -9_001.0 .. 27_001.0;

   function Elapsed (Later, Earlier : Unsigned_32) return Integer_32 renames Adaflight.Clock.Elapsed;

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then -Integer_32 (not U) - 1 else Integer_32 (U));

   function To_Unsigned (I : Integer_32) return Unsigned_32 is
     (if I < 0 then not Unsigned_32 (-(I + 1)) else Unsigned_32 (I));

   --  A difference of latitudes or altitudes in thirty-two bits.
   function Wrapped_Difference (A, B : Integer_32) return Integer_32 is
     (To_Signed (To_Unsigned (A) - To_Unsigned (B)));

   function Baud_Sentence (B : Baud_Rate) return String is
     (case B is
         when B_230400 => "$PUBX,41,1,0003,0001,230400,0*1C" & ASCII.CR & ASCII.LF,
         when B_115200 => "$PUBX,41,1,0003,0001,115200,0*1E" & ASCII.CR & ASCII.LF,
         when B_57600  => "$PUBX,41,1,0003,0001,57600,0*2D" & ASCII.CR & ASCII.LF,
         when B_38400  => "$PUBX,41,1,0003,0001,38400,0*26" & ASCII.CR & ASCII.LF,
         when B_19200  => "$PUBX,41,1,0003,0001,19200,0*23" & ASCII.CR & ASCII.LF,
         when B_9600   => "$PUBX,41,1,0003,0001,9600,0*16" & ASCII.CR & ASCII.LF);

   procedure Set_State (L : in out Link; R : in out Receiver; S : Link_State) is
   begin
      L.Last_Nav_Message := L.Now;
      L.Sensor_Present := False;
      L.State := S;
      L.Position := 0;
      L.State_Ts := L.Now;
      R.UBX.Ack := Idle;
   end Set_State;

   --  A frame goes out and the acknowledgement it names is awaited, or
   --  counted received at once.
   procedure Send (L : in out Link; R : in out Receiver; F : Frame; Tx : in out Transmission;
                   Ignore_Ack : Boolean := False) is
   begin
      if Tx.Length + F.Length <= Max_Tx then
         for I in 0 .. F.Length - 1 loop
            Tx.Data (Tx.Length + I) := F.Data (I);
         end loop;
         Tx.Length := Tx.Length + F.Length;
      else
         Tx.Overflow := True;
      end if;
      R.UBX.Ack_Message := F.Id;
      R.UBX.Ack := (if Ignore_Ack then Idle elsif F.Skip_Ack then Got_Ack else Waiting);
      L.Last_Message_Sent := L.Now;
   end Send;

   procedure Send_Text (Tx : in out Transmission; S : String)
     with Pre => S'Length <= UBX_Config.Max_Frame
   is
   begin
      if Tx.Length + S'Length <= Max_Tx then
         for I in 0 .. S'Length - 1 loop
            Tx.Data (Tx.Length + I) := Byte (Character'Pos (S (S'First + I)));
         end loop;
         Tx.Length := Tx.Length + S'Length;
      else
         Tx.Overflow := True;
      end if;
   end Send_Text;

   --  The GNSS configuration reply is answered with the blocks as selected.
   procedure Answer_Gnss_Reply (L : in out Link; R : in out Receiver; C : Settings; Tx : in out Transmission) is
      Reply : constant Gnss_Reply := Gnss_Reply (R.UBX.Payload (0 .. Gnss_Reply_Size - 1));
   begin
      R.UBX.Gnss_Reply := False;
      Send (L, R, Gnss_Message (Reply, C.Sbas = None, C.Use_Galileo), Tx);
   end Answer_Gnss_Reply;

   procedure Set_Baud (L : in out Link; B : Baud_Rate; E : in out Events) is
   begin
      if L.Port_Baud /= B then
         L.Port_Baud := B;
         E.Baud_Changed := True;
         E.New_Baud := B;
      end if;
   end Set_Baud;

   --  The offsets from the first position to the second over the local
   --  flat earth, north and east in centimetres.
   function North_Cm (From, To : Location) return Local_Cm is
     (Float (Wrapped_Difference (To.Lat, From.Lat)) * Angle_To_Cm);

   function East_Cm (From, To : Location; Cos_Lat : Cosine) return Local_Cm is
     ((Float (Adaflight.Maths.Longitude_Difference (To.Lon, From.Lon)) * Cos_Lat) * Angle_To_Cm);

   --  The distance between two positions in centimetres, with the altitude
   --  when asked.
   function Distance_Cm (From, To : Location; Dist_3D : Boolean; Cos_Lat : Cosine) return Unsigned_32
     with Post => Distance_Cm'Result <= 4_200_000_000
   is
      D_Lat  : constant Local_Cm := North_Cm (From, To);
      D_Lon  : constant Local_Cm := East_Cm (From, To, Cos_Lat);
      D_Alt  : constant Altitude_Difference :=
        (if Dist_3D then Float (Wrapped_Difference (To.Alt_Cm, From.Alt_Cm)) else 0.0);
      Lat_Sq : constant Square_Cm := D_Lat * D_Lat;
      Lon_Sq : constant Square_Cm := D_Lon * D_Lon;
      Alt_Sq : constant Altitude_Square := D_Alt * D_Alt;
      Sum    : constant Sum_Cm := (Lat_Sq + Lon_Sq) + Alt_Sq;
      Root   : constant Root_Cm := Float'Min (Adaflight.Maths.Sqrt_Non_Negative (Sum), 4.2e9);
   begin
      return Unsigned_32 (Float'Truncation (Root));
   end Distance_Cm;

   --  The bearing from the first position to the second, clockwise from
   --  north in hundredths of a degree.
   function Bearing_To (From, To : Location; Cos_Lat : Cosine) return Centidegrees
     with Global => null
   is
      Angle : constant Adaflight.Maths.Half_Turn :=
        Adaflight.Maths.Atan2_Approx (North_Cm (From, To), East_Cm (From, To, Cos_Lat));
      Deg   : constant Degrees_100 := 9_000.0 - (Angle / Rad) * 100.0;
      B     : constant Integer_32 range -9_001 .. 27_001 := Integer_32 (Float'Truncation (Deg));
   begin
      return (if B < 0 then Centidegrees (B + 36_000) else Centidegrees (B));
   end Bearing_To;

   procedure Distance_And_Direction_Home (L : in out Link; R : Receiver) is
   begin
      if L.Fix_Home then
         L.Distance_To_Home_Cm := Distance_Cm (R.Sol.Llh, L.Home, False, L.Cos_Lat);
         L.Distance_To_Home_M := Unsigned_16'Mod (L.Distance_To_Home_Cm / 100);
         L.Direction_To_Home := Integer_16 (Bearing_To (R.Sol.Llh, L.Home, L.Cos_Lat) / 10);
      else
         L.Distance_To_Home_M := 0;
         L.Distance_To_Home_Cm := 0;
         L.Direction_To_Home := 0;
      end if;
   end Distance_And_Direction_Home;

   --  The distance flown adds the movement since the last solution with a
   --  home fix, above the speed threshold.
   procedure Add_Distance_Flown (L : in out Link; R : Receiver; C : Settings) is
      Speed : constant Unsigned_16 := (if C.Use_3D_Speed then R.Sol.Speed_3d else R.Sol.Ground_Speed);
   begin
      if L.Fix_Home and then Speed > Flown_Speed_Threshold then
         L.Distance_Flown_Cm :=
           L.Distance_Flown_Cm + Distance_Cm (R.Sol.Llh, L.Last_Llh, C.Use_3D_Speed, L.Cos_Lat);
      end if;
      L.Last_Llh := R.Sol.Llh;
   end Add_Distance_Flown;

   procedure Reset_Distance_Flown (L : in out Link; R : Receiver) is
   begin
      L.Distance_Flown_Cm := 0;
      L.Last_Llh := R.Sol.Llh;
   end Reset_Distance_Flown;

   --  A solution with a fix: the stamp, the interval and the frequency of
   --  the solutions, the distance home and the distance flown.
   procedure On_New_Data (L : in out Link; R : Receiver; C : Settings; Armed : Boolean) is
      Interval_Ms : constant Unsigned_32 range 50 .. 2_500 :=
        Unsigned_32'Max (50, Unsigned_32'Min (2_500, R.Sol.Nav_Interval_Ms));
   begin
      if not R.Fix then
         return;
      end if;
      L.Stamp := L.Stamp + 1;
      L.Data_Interval_S := Float (Interval_Ms) * 0.001;
      L.Data_Frequency_Hz := 1.0 / L.Data_Interval_S;
      Distance_And_Direction_Home (L, R);
      if Armed then
         Add_Distance_Flown (L, R, C);
      end if;
   end On_New_Data;

   procedure Handle_Frame_Complete (L : in out Link; R : Receiver; C : Settings; Armed : Boolean) is
   begin
      if L.State = Receiving_Data then
         L.Last_Nav_Message := L.Now;
         L.Sensor_Present := True;
      end if;
      L.Tick := not L.Tick;
      On_New_Data (L, R, C, Armed);
   end Handle_Frame_Complete;

   --  The NMEA commands: the command at the offset goes out with its line
   --  end and the offset moves to the next; after the last the offset clears
   --  and the link receives data from here.
   procedure Send_Command (L : in out Link; R : in out Receiver; C : Settings; Tx : in out Transmission) is
      Pos : Natural := L.Command_Offset;
      Len : Natural := 0;
   begin
      while Pos < C.Commands_Length and then C.Commands (Pos + 1) = ' ' loop
         pragma Loop_Invariant (Pos < C.Commands_Length);
         Pos := Pos + 1;
      end loop;
      while Pos + Len < C.Commands_Length and then C.Commands (Pos + Len + 1) /= ' ' loop
         pragma Loop_Invariant (Pos + Len < C.Commands_Length);
         Len := Len + 1;
      end loop;
      if Pos < C.Commands_Length then
         Send_Text (Tx, C.Commands (Pos + 1 .. Pos + Len) & ASCII.CR & ASCII.LF);
         Pos := Pos + Len;
      end if;
      while Pos < C.Commands_Length and then C.Commands (Pos + 1) = ' ' loop
         pragma Loop_Invariant (Pos < C.Commands_Length);
         Pos := Pos + 1;
      end loop;
      if Pos < C.Commands_Length then
         L.Command_Offset := Pos;
      else
         L.Command_Offset := 0;
         Set_State (L, R, Receiving_Data);
      end if;
   end Send_Command;

   --  An NMEA module keeps its own rate: the port is set to the configured
   --  rate and the custom commands go out, one every half second.
   procedure Configure_NMEA (L : in out Link; R : in out Receiver; C : Settings; Tx_Empty : Boolean;
                             E : in out Events) is
   begin
      if Elapsed (L.Now, L.State_Ts) < 500 then
         return;
      end if;
      L.State_Ts := L.Now;
      if not Tx_Empty then
         return;
      end if;
      case L.State is
         when Detect_Baud =>
            Set_State (L, R, Change_Baud);
         when Change_Baud =>
            if L.Position < 1 then
               Set_Baud (L, L.User_Baud, E);
               L.Position := L.Position + 1;
            elsif L.Position < 2 then
               Send_Command (L, R, C, E.Tx);
            end if;
         when others =>
            null;
      end case;
   end Configure_NMEA;

   --  One configuration step of a u-blox module at the position, each
   --  skipped where the generation has no such setting.
   procedure Configure_Step (L : in out Link; R : in out Receiver; C : Settings; E : in out Events) is
      M7 : constant Boolean := R.UBX.M7_Or_Above;
      M8 : constant Boolean := R.UBX.M8_Or_Above;
      M9 : constant Boolean := R.UBX.M9_Or_Above;
   begin
      case L.Position is
         when Step_Detect_Unit =>
            if R.UBX.Version = Undefined then
               Send (L, R, Poll (Class_Mon, Msg_Mon_Ver), E.Tx);
            else
               L.Position := L.Position + 1;
            end if;
         when Step_Slow_Rate =>
            Send (L, R, Nav_Rate (1, 1, 1, M9), E.Tx);
         when Step_Disable_NMEA =>
            if M9 then
               Send (L, R, Disable_NMEA_Message, E.Tx);
               L.Position := Step_RMC;
            else
               L.Position := L.Position + 1;
            end if;
         when Step_VTG =>
            Send (L, R, Message_Rate (Class_NMEA_Std, Msg_NMEA_VTG, 0), E.Tx);
         when Step_GSV =>
            Send (L, R, Message_Rate (Class_NMEA_Std, Msg_NMEA_GSV, 0), E.Tx);
         when Step_GLL =>
            Send (L, R, Message_Rate (Class_NMEA_Std, Msg_NMEA_GLL, 0), E.Tx);
         when Step_GGA =>
            Send (L, R, Message_Rate (Class_NMEA_Std, Msg_NMEA_GGA, 0), E.Tx);
         when Step_GSA =>
            Send (L, R, Message_Rate (Class_NMEA_Std, Msg_NMEA_GSA, 0), E.Tx);
         when Step_RMC =>
            Send (L, R, Message_Rate (Class_NMEA_Std, Msg_NMEA_RMC, 0), E.Tx);
         when Step_Model =>
            Send (L, R, Model_Message (C.Acquire_Model, C.UTC, M9), E.Tx);
         when Step_Assistance =>
            if M7 and then C.Enable_Assistance then
               Send (L, R, Assistance_Message (M9), E.Tx);
            else
               L.Position := L.Position + 1;
            end if;
         when Step_Sbas =>
            Send (L, R, Sbas_Message (C.Sbas, C.Sbas_Integrity, M9), E.Tx);
         when Step_Power =>
            if M8 then
               Send (L, R, Power_Mode_Message (M9), E.Tx);
            else
               L.Position := L.Position + 1;
            end if;
         when Step_Pvt =>
            if M9 then
               Send (L, R, Message_Rate_Key (Key_Nav_Pvt_UART1, 1), E.Tx);
            elsif M7 then
               Send (L, R, Message_Rate (Class_Nav, Msg_Nav_Pvt, 1), E.Tx);
            else
               L.Position := L.Position + 1;
            end if;
         when Step_Sol =>
            if M9 then
               L.Position := L.Position + 1;
            elsif M7 then
               Send (L, R, Message_Rate (Class_Nav, Msg_Nav_Sol, 0), E.Tx);
            else
               Send (L, R, Message_Rate (Class_Nav, Msg_Nav_Sol, 1), E.Tx);
            end if;
         when Step_Posllh =>
            Send (L, R, Message_Rate (Class_Nav, Msg_Nav_Posllh, (if M7 then 0 else 1)), E.Tx);
         when Step_Status =>
            Send (L, R, Message_Rate (Class_Nav, Msg_Nav_Status, (if M7 then 0 else 1)), E.Tx);
         when Step_Velned =>
            Send (L, R, Message_Rate (Class_Nav, Msg_Nav_Velned, (if M7 then 0 else 1)), E.Tx);
         when Step_Dop =>
            if M9 then
               Send (L, R, Message_Rate_Key (Key_Nav_Dop_UART1, 0), E.Tx);
            elsif M7 then
               Send (L, R, Message_Rate (Class_Nav, Msg_Nav_Dop, 0), E.Tx);
            else
               Send (L, R, Message_Rate (Class_Nav, Msg_Nav_Dop, 1), E.Tx);
            end if;
         when Step_Sat_Info =>
            Send (L, R, Satellite_Info_Rate (5, M8, M9), E.Tx);
         when Step_Nav_Rate =>
            L.Update_Rate := C.Update_Rate;
            Send (L, R, Nav_Rate (Measurement_Rate_Hz (C.Update_Rate), 1, 1, M9), E.Tx);
         when Step_Gnss =>
            if C.Sbas = None or else C.Use_Galileo then
               Send (L, R, Poll (Class_Cfg, Msg_Cfg_Gnss), E.Tx);
            else
               L.Position := L.Position + 1;
            end if;
         when Step_Complete =>
            Set_State (L, R, Receiving_Data);
         when others =>
            null;
      end case;
   end Configure_Step;

   --  A u-blox module: the version poll three times at each rate of the
   --  sweep, backed off after two passes; the module's rate change and the
   --  settling time; then the configuration steps on the acknowledgements.
   procedure Configure_UBlox (L : in out Link; R : in out Receiver; C : Settings; Tx_Empty : Boolean;
                              E : in out Events) is
   begin
      if not Tx_Empty then
         return;
      end if;
      case L.State is
         when Detect_Baud =>
            if R.UBX.Version /= Undefined then
               Send_Text (E.Tx, Baud_Sentence (L.User_Baud));
               L.Temp_Baud := L.User_Baud;
               L.Sweep_Steps := 0;
               Set_State (L, R, Change_Baud);
               return;
            end if;
            if L.Message_Counter < Baud_Test_Count then
               if not L.Message_Sent then
                  R.UBX.Version := Undefined;
                  Send (L, R, Poll (Class_Mon, Msg_Mon_Ver), E.Tx, Ignore_Ack => True);
                  L.Message_Sent := True;
               end if;
               if Elapsed (L.Now, L.State_Ts) > Baud_Change_Interval then
                  L.State_Ts := L.Now;
                  L.Message_Sent := False;
                  L.Message_Counter := L.Message_Counter + 1;
               end if;
               return;
            end if;
            L.Message_Counter := 0;
            L.State_Ts := L.Now;
            if L.Sweep_Steps = Sweep_Step_Limit and then Elapsed (L.Now, L.Last_Sweep_Step) < Sweep_Backoff_Ms then
               return;
            end if;
            L.Last_Sweep_Step := L.Now;
            L.Temp_Baud := (if L.Temp_Baud = Baud_Rate'First then Baud_Rate'Last else Baud_Rate'Pred (L.Temp_Baud));
            Set_Baud (L, L.Temp_Baud, E);
            L.Sweep_Steps := Natural'Min (L.Sweep_Steps + 1, Sweep_Step_Limit);
         when Change_Baud =>
            if Elapsed (L.Now, L.State_Ts) < 3 * Baud_Change_Interval then
               return;
            end if;
            Set_Baud (L, L.User_Baud, E);
            Set_State (L, R, Configure);
         when Configure =>
            if not C.Auto_Config then
               Set_State (L, R, Receiving_Data);
               return;
            end if;
            if Elapsed (L.Now, L.State_Ts) < 1_000 then
               return;
            end if;
            if R.UBX.Ack = Idle then
               if L.Last_Step_Time = 0 then
                  L.Last_Step_Time := L.Now;
               end if;
               if Elapsed (L.Now, L.Last_Step_Time) < Change_Interval then
                  return;
               end if;
               L.Last_Step_Time := L.Now;
               Configure_Step (L, R, C, E);
            end if;
            case R.UBX.Ack is
               when Idle =>
                  null;
               when Waiting =>
                  if Elapsed (L.Now, L.Last_Message_Sent) > Ack_Timeout_Ms then
                     R.UBX.Ack := Got_Ack;
                  end if;
               when Got_Ack =>
                  L.Position := L.Position + 1;
                  R.UBX.Ack := Idle;
               when Got_Nack =>
                  if L.Position = Step_Detect_Unit then
                     Set_State (L, R, Configure);
                  else
                     L.Position := L.Position + 1;
                     R.UBX.Ack := Idle;
                  end if;
            end case;
         when others =>
            null;
      end case;
   end Configure_UBlox;

   procedure Indicator (L : in out Link; R : Receiver; C : Settings; Now_Us : Unsigned_32; E : in out Events) is
   begin
      if Elapsed (Now_Us, L.Indicator_Time_Us) >= 0 and then R.Fix and then R.Sol.Num_Sat >= C.Min_Sats then
         L.Indicator_Time_Us := Now_Us + Indicator_Period_Us;
         E.Indicator := True;
      end if;
   end Indicator;

   --  The task rate falls back to normal one call after the last byte.
   procedure Reschedule (L : in out Link; E : in out Events) is
   begin
      if L.Wait < 1 then
         L.Wait := L.Wait + 1;
      elsif L.Wait = 1 then
         L.Wait := L.Wait + 1;
         L.Is_Fast := False;
         E.Rate := Normal;
      end if;
   end Reschedule;

   ----------
   -- Init --
   ----------

   procedure Init (L : out Link; R : in out Receiver; C : Settings; Now_Ms : Unsigned_32; Port_Opened : Boolean) is
   begin
      L := (others => <>);
      R.UBX.Version := Undefined;
      Set_State (L, R, Unknown);
      if C.Source in MSP | Virtual then
         Set_State (L, R, Initialized);
         return;
      end if;
      if not C.Port_Assigned then
         return;
      end if;
      L.Last_Sweep_Step := Now_Ms;
      L.User_Baud := C.Baud;
      L.Temp_Baud := C.Baud;
      if not Port_Opened then
         return;
      end if;
      L.Port_Open := True;
      L.Port_Baud := C.Baud;
      Set_State (L, R, Detect_Baud);
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (L : in out Link; R : in out Receiver; C : Settings; Now_Ms, Now_Us : Unsigned_32;
                     Rx : Byte_Array; Tx_Empty, Armed : Boolean; Clock_Has_Time : in out Boolean; E : out Events) is
      New_Solution : Boolean;
      Clock        : Clock_Request;
   begin
      E := (others => <>);
      L.Now := Now_Ms;
      case C.Source is
         when UBlox | NMEA =>
            if L.Port_Open then
               for I in Rx'Range loop
                  pragma Loop_Invariant (E.Solutions <= I - Rx'First);
                  pragma Loop_Invariant (E.Clock_Sets <= I - Rx'First);
                  L.Wait := 0;
                  if not L.Is_Fast then
                     E.Rate := Fast;
                     L.Is_Fast := True;
                  end if;
                  if C.Source = UBlox then
                     Receive_UBX (R, Rx (I), Clock_Has_Time, New_Solution, Clock);
                  else
                     Receive_NMEA (R, Rx (I), Clock_Has_Time, New_Solution, Clock);
                  end if;
                  if Clock.Set then
                     Clock_Has_Time := True;
                     E.Clock := Clock;
                     E.Clock_Sets := E.Clock_Sets + 1;
                  end if;
                  if R.UBX.Gnss_Reply then
                     Answer_Gnss_Reply (L, R, C, E.Tx);
                  end if;
                  if New_Solution then
                     Handle_Frame_Complete (L, R, C, Armed);
                     E.Solutions := E.Solutions + 1;
                  end if;
               end loop;
               Reschedule (L, E);
            end if;
         when MSP =>
            if L.Solution_Offered then
               if L.State in Initialized | Detect_Baud then
                  L.State := Receiving_Data;
                  L.Position := 0;
                  L.State_Ts := L.Now;
                  R.UBX.Ack := Idle;
               end if;
               L.Last_Nav_Message := L.Now;
               L.Sensor_Present := True;
               L.Tick := not L.Tick;
               Nav_Interval (R);
               On_New_Data (L, R, C, Armed);
               L.Solution_Offered := False;
            elsif Elapsed (L.Now, L.Last_Nav_Message) > Timeout_Ms then
               Set_State (L, R, Lost_Communication);
            end if;
         when Virtual =>
            if Elapsed (L.Now, L.Virtual_Next_Update) > 0 then
               if L.Virtual_Count /= L.Virtual_Last_Count then
                  L.Virtual_Last_Count := L.Virtual_Count;
                  L.Virtual_Last_Change := L.Now;
               end if;
               if L.Virtual_Last_Change /= 0 and then Elapsed (L.Now, L.Virtual_Last_Change) < Timeout_Ms then
                  if L.State in Initialized | Detect_Baud then
                     L.State := Receiving_Data;
                     L.Position := 0;
                     L.State_Ts := L.Now;
                     R.UBX.Ack := Idle;
                  end if;
                  R.Sol := L.Virtual_Sol;
                  R.Sol.Time := L.Now;
                  L.Last_Nav_Message := L.Now;
                  L.Sensor_Present := True;
                  R.Fix := R.Sol.Num_Sat > 3;
                  if R.Fix then
                     R.Fix_Ever := True;
                  end if;
                  L.Tick := not L.Tick;
                  Nav_Interval (R);
                  On_New_Data (L, R, C, Armed);
               end if;
               L.Virtual_Next_Update := L.Now + 100;
            end if;
      end case;
      case L.State is
         when Unknown | Initialized =>
            null;
         when Detect_Baud | Change_Baud | Configure =>
            if L.Port_Open then
               case C.Source is
                  when NMEA  => Configure_NMEA (L, R, C, Tx_Empty, E);
                  when UBlox => Configure_UBlox (L, R, C, Tx_Empty, E);
                  when MSP | Virtual => null;
               end case;
            end if;
         when Lost_Communication =>
            L.Timeouts := L.Timeouts + 1;
            R.Sol.Num_Sat := 0;
            R.Fix := False;
            Set_State (L, R, Detect_Baud);
         when Receiving_Data =>
            if C.Source /= MSP and then C.Auto_Config and then L.Port_Open and then not L.Using_Flight_Model
              and then R.Fix
            then
               L.Using_Flight_Model := True;
               Send (L, R, Model_Message (C.Flight_Model, C.UTC, R.UBX.M9_Or_Above), E.Tx);
            end if;
            if Elapsed (L.Now, L.Last_Nav_Message) > Timeout_Ms then
               Set_State (L, R, Lost_Communication);
            end if;
      end case;
      if L.Sensor_Present then
         Indicator (L, R, C, Now_Us, E);
      end if;
      if not Armed then
         if not C.Set_Home_Once then
            L.Fix_Home := False;
         end if;
         if not L.Has_Beeped and then R.Fix and then R.Sol.Num_Sat >= C.Min_Sats then
            E.Ready_Beep := True;
            L.Has_Beeped := True;
         end if;
      end if;
   end Update;

   --------------------
   -- Offer_Solution --
   --------------------

   procedure Offer_Solution (L : in out Link; R : in out Receiver; Fix : Boolean; Num_Sat : Unsigned_8;
                             Lat, Lon : Integer_32; Alt_M : Unsigned_16; Ground_Speed : Unsigned_16) is
   begin
      R.Fix := Fix;
      if Fix then
         R.Fix_Ever := True;
      end if;
      R.Sol.Num_Sat := Num_Sat;
      R.Sol.Llh := (Lat => Lat, Lon => Lon, Alt_Cm => Integer_32 (Alt_M) * 100);
      R.Sol.Ground_Speed := Ground_Speed;
      L.Solution_Offered := True;
   end Offer_Solution;

   -------------------
   -- Offer_Virtual --
   -------------------

   procedure Offer_Virtual (L : in out Link; Lat, Lon, Alt_Cm : Integer_32;
                            Ground_Speed, Speed_3D, Course : Unsigned_16; Vel_North, Vel_East, Vel_Down : Integer_16) is
   begin
      L.Virtual_Sol :=
        (Llh           => (Lat => Lat, Lon => Lon, Alt_Cm => Alt_Cm),
         Dop           => (Pdop => 10, Hdop => 0, Vdop => 0),
         Acc           => (Horizontal => 500, Vertical => 500, Speed => 400, Heading => 0),
         Velned        => (North => Vel_North, East => Vel_East, Down => Vel_Down),
         Speed_3d      => Speed_3D,
         Ground_Speed  => Ground_Speed,
         Ground_Course => Course,
         Num_Sat       => 12,
         Time          => 0,
         Nav_Interval_Ms => 0,
         Utc           => (others => <>));
      L.Virtual_Count := L.Virtual_Count + 1;
   end Offer_Virtual;

   ----------------
   -- Reset_Home --
   ----------------

   procedure Reset_Home (L : in out Link; R : in out Receiver; C : Settings; Tx : out Transmission) is
   begin
      Tx := (others => <>);
      if not L.Fix_Home or else not C.Set_Home_Once then
         if R.Fix and then R.Sol.Num_Sat >= C.Min_Sats then
            L.Home := R.Sol.Llh;
            L.Cos_Lat := Adaflight.Maths.Cos_Approx ((Float (R.Sol.Llh.Lat) / 10_000_000.0) * Rad);
            L.Fix_Home := True;
         end if;
      end if;
      if C.Source = UBlox then
         Send (L, R, Satellite_Info_Rate (0, R.UBX.M8_Or_Above, R.UBX.M9_Or_Above), Tx);
      end if;
      Reset_Distance_Flown (L, R);
   end Reset_Home;

   -------------------
   -- Take_New_Data --
   -------------------

   procedure Take_New_Data (L : Link; Stamp : in out Unsigned_16; Fresh : out Boolean) is
   begin
      Fresh := Stamp /= L.Stamp;
      if Fresh then
         Stamp := L.Stamp;
      end if;
   end Take_New_Data;

end Adaflight.GPS_Link;
