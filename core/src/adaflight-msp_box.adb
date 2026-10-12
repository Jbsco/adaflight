package body Adaflight.MSP_Box with SPARK_Mode is
   use Adaflight.Modes;
   use type Interfaces.Unsigned_32;

   function Box_Name (B : Box) return String is
     (case B is
         when Arm => "ARM", when Angle => "ANGLE", when Horizon => "HORIZON", when Mag => "MAG",
         when Alt_Hold => "ALTHOLD", when Headfree => "HEADFREE", when Chirp => "CHIRP",
         when Passthru => "PASSTHRU", when Failsafe => "FAILSAFE", when Pos_Hold => "POS HOLD",
         when GPS_Rescue => "GPS RESCUE", when Autopilot => "AUTOPILOT", when Anti_Gravity => "ANTI GRAVITY",
         when Head_Adj => "HEADADJ", when Cam_Stab => "CAMSTAB", when Beeper_On => "BEEPER",
         when LED_Low => "LEDLOW", when Calib => "CALIB", when OSD => "OSD DISABLE",
         when Telemetry => "TELEMETRY", when Servo_1 => "SERVO1", when Servo_2 => "SERVO2",
         when Servo_3 => "SERVO3", when Blackbox => "BLACKBOX", when Airmode => "AIR MODE",
         when Three_D => "3D DISABLE", when FPV_Angle_Mix => "FPV ANGLE MIX",
         when Blackbox_Erase => "BLACKBOX ERASE", when Camera_1 => "CAMERA CONTROL 1",
         when Camera_2 => "CAMERA CONTROL 2", when Camera_3 => "CAMERA CONTROL 3",
         when Crash_Flip => "FLIP OVER AFTER CRASH", when Prearm => "PREARM",
         when Beep_GPS_Count => "GPS BEEP SATELLITE COUNT", when VTX_Pit_Mode => "VTX PIT MODE",
         when Paralyze => "PARALYZE", when User_1 => "USER1", when User_2 => "USER2", when User_3 => "USER3",
         when User_4 => "USER4", when PID_Audio => "PID AUDIO", when Acro_Trainer => "ACRO TRAINER",
         when VTX_Control_Disable => "VTX CONTROL DISABLE", when Launch_Control => "LAUNCH CONTROL",
         when MSP_Override => "MSP OVERRIDE", when Stick_Command_Disable => "STICK COMMANDS DISABLE",
         when Beeper_Mute => "BEEPER MUTE", when Ready => "READY", when Lap_Timer_Reset => "LAP TIMER RESET",
         when WP_Capture => "WP CAPTURE", when Launch => "LAUNCH");

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
