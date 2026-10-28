package body Adaflight.MSP_Box with SPARK_Mode is
   use Adaflight.Modes;
   use type Interfaces.Unsigned_32;

   --  The box names in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Box_Name_Pool_Length : constant := 483;
   Box_Name_Text : constant String (1 .. Box_Name_Pool_Length + 24) :=
     "ARMANGLEHORIZONMAGALTHOLDHEADFREECHIRPPASSTHRUFAILSAFEPOS HOLDGPS RESCUEAUTOPILOTANTI GRAVITYHEADADJCAMS"
     & "TABBEEPERLEDLOWCALIBOSD DISABLETELEMETRYSERVO1SERVO2SERVO3BLACKBOXAIR MODE3D DISABLEFPV ANGLE MIXBLACKBO"
     & "X ERASECAMERA CONTROL 1CAMERA CONTROL 2CAMERA CONTROL 3FLIP OVER AFTER CRASHPREARMGPS BEEP SATELLITE COU"
     & "NTVTX PIT MODEPARALYZEUSER1USER2USER3USER4PID AUDIOACRO TRAINERVTX CONTROL DISABLELAUNCH CONTROLMSP OVER"
     & "RIDESTICK COMMANDS DISABLEBEEPER MUTEREADYLAP TIMER RESETWP CAPTURE                        ";
   type Box_Name_Start is range 0 .. Box_Name_Pool_Length;
   type Box_Name_Length is range 3 .. 24;
   Box_Name_Starts : constant array (Box) of Box_Name_Start :=
     (Arm => 0, Angle => 3, Horizon => 8, Mag => 15, Alt_Hold => 18, Headfree => 25, Chirp => 33, Passthru => 38,
      Failsafe => 46, Pos_Hold => 54, GPS_Rescue => 62, Autopilot => 72, Anti_Gravity => 81, Head_Adj => 93,
      Cam_Stab => 100, Beeper_On => 107, LED_Low => 113, Calib => 119, OSD => 124, Telemetry => 135, Servo_1 => 144,
      Servo_2 => 150, Servo_3 => 156, Blackbox => 162, Airmode => 170, Three_D => 178, FPV_Angle_Mix => 188,
      Blackbox_Erase => 201, Camera_1 => 215, Camera_2 => 231, Camera_3 => 247, Crash_Flip => 263, Prearm => 284,
      Beep_GPS_Count => 290, VTX_Pit_Mode => 314, Paralyze => 326, User_1 => 334, User_2 => 339, User_3 => 344,
      User_4 => 349, PID_Audio => 354, Acro_Trainer => 363, VTX_Control_Disable => 375, Launch_Control => 394,
      MSP_Override => 408, Stick_Command_Disable => 420, Beeper_Mute => 442, Ready => 453, Lap_Timer_Reset => 458,
      WP_Capture => 473, Launch => 394);
   Box_Name_Lengths : constant array (Box) of Box_Name_Length :=
     (Arm => 3, Angle => 5, Horizon => 7, Mag => 3, Alt_Hold => 7, Headfree => 8, Chirp => 5, Passthru => 8,
      Failsafe => 8, Pos_Hold => 8, GPS_Rescue => 10, Autopilot => 9, Anti_Gravity => 12, Head_Adj => 7,
      Cam_Stab => 7, Beeper_On => 6, LED_Low => 6, Calib => 5, OSD => 11, Telemetry => 9, Servo_1 => 6,
      Servo_2 => 6, Servo_3 => 6, Blackbox => 8, Airmode => 8, Three_D => 10, FPV_Angle_Mix => 13,
      Blackbox_Erase => 14, Camera_1 => 16, Camera_2 => 16, Camera_3 => 16, Crash_Flip => 21, Prearm => 6,
      Beep_GPS_Count => 24, VTX_Pit_Mode => 12, Paralyze => 8, User_1 => 5, User_2 => 5, User_3 => 5, User_4 => 5,
      PID_Audio => 9, Acro_Trainer => 12, VTX_Control_Disable => 19, Launch_Control => 14, MSP_Override => 12,
      Stick_Command_Disable => 22, Beeper_Mute => 11, Ready => 5, Lap_Timer_Reset => 15, WP_Capture => 10,
      Launch => 6);

   function Box_Name (B : Box) return String is
     (Box_Name_Text (Natural (Box_Name_Starts (B)) + 1
                     .. Natural (Box_Name_Starts (B)) + Natural (Box_Name_Lengths (B))));

   function Permanent_Id (B : Box) return Byte is
     (case B is
         when Arm => 0, when Angle => 1, when Horizon => 2, when Alt_Hold => 3, when Anti_Gravity => 4,
         when Mag => 5, when Headfree => 6, when Head_Adj => 7, when Cam_Stab => 8, when Pos_Hold => 11,
         when Passthru => 12, when Beeper_On => 13, when LED_Low => 15, when Calib => 17, when OSD => 19,
         when Telemetry => 20, when Servo_1 => 23, when Servo_2 => 24, when Servo_3 => 25, when Blackbox => 26,
         when Failsafe => 27, when Airmode => 28, when Three_D => 29, when FPV_Angle_Mix => 30,
         when Blackbox_Erase => 31, when Camera_1 => 32, when Camera_2 => 33, when Camera_3 => 34,
         when Crash_Flip => 35, when Prearm => 36, when Beep_GPS_Count => 37, when VTX_Pit_Mode => 39,
         when User_1 => 40, when User_2 => 41, when User_3 => 42, when User_4 => 43, when PID_Audio => 44,
         when Paralyze => 45, when GPS_Rescue => 46, when Acro_Trainer => 47, when VTX_Control_Disable => 48,
         when Launch_Control => 49, when MSP_Override => 50, when Stick_Command_Disable => 51,
         when Beeper_Mute => 52, when Ready => 53, when Lap_Timer_Reset => 54, when Chirp => 55,
         when Autopilot => 56, when WP_Capture => 57, when Launch => 58);

   ---------------------------
   -- Find_By_Permanent_Id --
   ---------------------------

   procedure Find_By_Permanent_Id (Id : Byte; Found : out Boolean; B : out Box) is
   begin
      Found := False;
      B := Arm;
      for Candidate in Box loop
         if Permanent_Id (Candidate) = Id then
            Found := True;
            B := Candidate;
            return;
         end if;
      end loop;
   end Find_By_Permanent_Id;

   ------------------------
   -- Serialize_Box_Name --
   ------------------------

   procedure Serialize_Box_Name (B : in out Byte_Array; S : in out Stream; Which : Box; Names : User_Names;
                                 Written : out Integer) is
      Custom : constant Boolean := Which in User_Box and then Names (Which).Length > 0;
      Length : constant Natural :=
        (if Custom then Names (Which).Length else Box_Name (Which)'Length);
   begin
      if Adaflight.Stream_Buffers.Remaining (S) < Length + 1 then
         Written := -1;
         return;
      end if;
      if Custom then
         Adaflight.Stream_Buffers.Write_String (B, S, Names (Which).Text (1 .. Names (Which).Length));
      else
         Adaflight.Stream_Buffers.Write_String (B, S, Box_Name (Which));
      end if;
      Adaflight.Stream_Buffers.Write_U8 (B, S, Character'Pos (';'));
      Written := Length + 1;
   end Serialize_Box_Name;

   --------------------------------
   -- Serialize_Box_Permanent_Id --
   --------------------------------

   procedure Serialize_Box_Permanent_Id (B : in out Byte_Array; S : in out Stream; Which : Box;
                                         Written : out Integer) is
   begin
      if Adaflight.Stream_Buffers.Remaining (S) < 1 then
         Written := -1;
         return;
      end if;
      Adaflight.Stream_Buffers.Write_U8 (B, S, Permanent_Id (Which));
      Written := 1;
   end Serialize_Box_Permanent_Id;

   -------------------------
   -- Serialize_Box_Reply --
   -------------------------

   procedure Serialize_Box_Reply (B : in out Byte_Array; S : in out Stream; Active : Active_Mask; Page : Natural;
                                  Kind : Reply_Kind; Names : User_Names) is
      Index      : Natural := 0;
      Page_Start : constant Natural := Page * Page_Size;
      Page_End   : constant Natural := Page_Start + Page_Size;
      Written    : Integer;
   begin
      for Which in Box loop
         pragma Loop_Invariant (Index <= Box'Pos (Which));
         pragma Loop_Invariant (Adaflight.Stream_Buffers.Fits (S, B));
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry);
         pragma Loop_Invariant (S.Next >= S.Next'Loop_Entry);
         if Active (Which) then
            if Index >= Page_Start and then Index < Page_End then
               case Kind is
                  when Box_Names =>
                     Serialize_Box_Name (B, S, Which, Names, Written);
                  when Box_Permanent_Ids =>
                     Serialize_Box_Permanent_Id (B, S, Which, Written);
               end case;
               if Written < 0 then
                  return;
               end if;
            end if;
            Index := Index + 1;
         end if;
      end loop;
   end Serialize_Box_Reply;

   --  The flight mode a flight mode box reads.
   function Flight_Mode_Of (Which : Box) return Adaflight.Arming.Flight_Mode is
     (case Which is
         when Angle => Adaflight.Arming.Angle_Mode, when Horizon => Adaflight.Arming.Horizon_Mode,
         when Mag => Adaflight.Arming.Mag_Mode, when Alt_Hold => Adaflight.Arming.Alt_Hold_Mode,
         when Headfree => Adaflight.Arming.Headfree_Mode, when Chirp => Adaflight.Arming.Chirp_Mode,
         when Passthru => Adaflight.Arming.Passthru_Mode, when Failsafe => Adaflight.Arming.Failsafe_Mode,
         when Pos_Hold => Adaflight.Arming.Pos_Hold_Mode, when GPS_Rescue => Adaflight.Arming.GPS_Rescue_Mode,
         when Autopilot => Adaflight.Arming.Autopilot_Mode, when others => Adaflight.Arming.Angle_Mode)
     with Pre => Which in Angle .. Autopilot;

   ---------------
   -- Box_State --
   ---------------

   function Box_State (Which : Box; Armed : Boolean; Flight : Mode_Set; Switches : Active_Mask; Wing : Boolean)
                       return Boolean is
     (if Which = Arm then Armed
      elsif Wing and then Which = Launch then Flight (Adaflight.Arming.Launch_Mode)
      elsif Which <= Autopilot then Flight (Flight_Mode_Of (Which))
      else Switches (Which));

   ----------------------------
   -- Pack_Flight_Mode_Flags --
   ----------------------------

   procedure Pack_Flight_Mode_Flags (Active : Active_Mask; Armed : Boolean; Flight : Mode_Set; Switches : Active_Mask;
                                     Wing : Boolean; Packed : out Packed_Words; Count : out Natural) is
      Index : Natural := 0;
   begin
      Packed := (others => 0);
      for Which in Box loop
         pragma Loop_Invariant (Index <= Box'Pos (Which));
         if Active (Which) then
            if Box_State (Which, Armed, Flight, Switches, Wing) then
               Packed (Index / 32) := Packed (Index / 32) or Interfaces.Shift_Left (1, Index mod 32);
            end if;
            Index := Index + 1;
         end if;
      end loop;
      Count := Index;
   end Pack_Flight_Mode_Flags;

end Adaflight.MSP_Box;
