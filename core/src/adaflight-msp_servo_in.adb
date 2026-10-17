with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Servo_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_32;

   Servo_Count   : constant := 8;
   Rule_Count    : constant := 16;
   Source_Count  : constant := 14;
   Channel_Count : constant := 18;
   Pulse_Min     : constant := 500;
   Pulse_Max     : constant := 2_500;
   Box_Max       : constant := 3;
   Source_Bits   : constant Interfaces.Unsigned_32 := 2 ** Source_Count - 1;

   --  A servo, then its minimum, maximum and middle pulses, rate, forwarded
   --  channel and reversed sources, in exactly thirteen bytes.
   procedure Set_Servo_Configuration (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Servo    : constant Integer_64 := U8 (Request, 0);
      Minimum  : constant Integer_64 := S16 (Request, 1);
      Maximum  : constant Integer_64 := S16 (Request, 3);
      Middle   : constant Integer_64 := S16 (Request, 5);
      Rate     : constant Integer_64 := S8 (Request, 7);
      Forward  : constant Integer_64 := S8 (Request, 8);
      Reversed : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (U32 (Request, 9));
   begin
      if Request'Length /= 13
        or else Servo >= Servo_Count
        or else Minimum not in Pulse_Min .. Pulse_Max
        or else Maximum not in Pulse_Min .. Pulse_Max
        or else Middle not in Minimum .. Maximum
        or else Rate not in -100 .. 100
        or else Forward >= Channel_Count
        or else (Reversed and not Source_Bits) /= 0
      then
         R := Error;
         return;
      end if;
      declare
         S : Servo_Param_Record renames C.Servo_Params (Natural (Servo));
      begin
         S.Min := Interfaces.Integer_16 (Minimum);
         S.Max := Interfaces.Integer_16 (Maximum);
         S.Middle := Interfaces.Integer_16 (Middle);
         S.Rate := Interfaces.Integer_8 (Rate);
         S.Forward_From_Channel := Interfaces.Integer_8 (Forward);
         S.Reversed_Sources := Reversed;
      end;
      R := Ack;
   end Set_Servo_Configuration;

   --  A rule, then its target servo, input source, rate, speed, range and
   --  box.
   procedure Set_Servo_Mix_Rule (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Rule    : constant Integer_64 := U8 (Request, 0);
      Target  : constant Integer_64 := U8 (Request, 1);
      Input   : constant Integer_64 := U8 (Request, 2);
      Rate    : constant Integer_64 := S8 (Request, 3);
      Minimum : constant Integer_64 := S8 (Request, 5);
      Maximum : constant Integer_64 := S8 (Request, 6);
      Box     : constant Integer_64 := U8 (Request, 7);
   begin
      if Rule >= Rule_Count
        or else Target >= Servo_Count
        or else Input >= Source_Count
        or else Rate not in -100 .. 100
        or else Minimum not in 0 .. 100
        or else Maximum not in 0 .. 100
        or else Minimum >= Maximum
        or else Box > Box_Max
      then
         R := Error;
         return;
      end if;
      declare
         M : Servo_Mixer_Record renames C.Custom_Servo_Mixers (Natural (Rule));
      begin
         M.Target_Channel := Byte (Target);
         M.Input_Source := Byte (Input);
         M.Rate := Interfaces.Integer_8 (Rate);
         M.Speed := Byte (U8 (Request, 4));
         M.Min := Interfaces.Integer_8 (Minimum);
         M.Max := Interfaces.Integer_8 (Maximum);
         M.Box := Byte (Box);
      end;
      E.Mixer_Load := True;
      R := Ack;
   end Set_Servo_Mix_Rule;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
   is
   begin
      E := No_Effects;
      case Command is
         when Set_Servo_Configuration_Command =>
            Set_Servo_Configuration (C, Request, R);
         when Set_Servo_Mix_Rule_Command =>
            Set_Servo_Mix_Rule (C, Request, R, E);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Servo_In;
