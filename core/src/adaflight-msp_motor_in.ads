--  The MSP in message that sets the motors' values while disarmed, for the
--  motor test: one 16-bit value per motor of the mixer, converted for the
--  motor protocol. A request reads the motors' values in order; one shorter
--  than the motor count's values is an error that sets nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Motor_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Motor_Command : constant := 214;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is (Command = Set_Motor_Command);

   type Result is (Ack, Error);

   --  The motor output the board drives: none, analog pulses, or DShot.
   type Device_Kind is (No_Device, PWM, DShot);

   Max_Motors : constant := 8;
   subtype Motor_Count is Natural range 0 .. Max_Motors;
   type Motor_Values is array (0 .. Max_Motors - 1) of Float;

   --  The disarmed motor values a request sets, zero for the motors past the
   --  count.
   type Effects is record
      Set    : Boolean := False;
      Values : Motor_Values := (others => 0.0);
   end record;

   No_Effects : constant Effects := (Set => False, Values => (others => 0.0));

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  Three_D says the 3D feature runs, which the DShot conversion reads.
   procedure Process
     (Request : Byte_Array; Motors : Motor_Count; Device : Device_Kind; Three_D : Boolean; R : out Result;
      E : out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then E = No_Effects);

end Adaflight.MSP_Motor_In;
