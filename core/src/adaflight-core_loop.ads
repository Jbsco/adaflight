--  The core loop's cadence and the stick rule before the RC command. The
--  PID loop counts gyro samples up to the loop ratio: the gyro filtering
--  runs when the count wraps and the controller halfway through the ratio.
--  The yaw command is reset while arming by stick at low throttle, except
--  on a tricopter whose servo moves when disarmed and on the fixed wings.
with Adaflight.Mixer_Init;
with Adaflight.Modes;
with Adaflight.RC_Command;

package Adaflight.Core_Loop with SPARK_Mode is

   subtype Loop_Ratio is Positive range 1 .. 255;
   subtype Sample_Count is Natural range 0 .. 255;

   type Cadence is record
      Counter : Sample_Count := 0;
   end record;

   --  A gyro sample taken: a count at a multiple of the ratio starts over,
   --  then the sample counts; the byte wraps should the ratio shrink under
   --  it.
   procedure Gyro_Sampled (C : in out Cadence; Ratio : Loop_Ratio)
     with Post => C.Counter = (if C.Counter'Old mod Ratio = 0 then 1 else (C.Counter'Old + 1) mod 256);

   function Filter_Ready (C : Cadence; Ratio : Loop_Ratio) return Boolean is (C.Counter mod Ratio = 0);

   function PID_Ready (C : Cadence; Ratio : Loop_Ratio) return Boolean is (C.Counter mod Ratio = Ratio / 2);

   --  Whether the yaw command is reset before the RC command: arming by
   --  stick with the throttle at or below the minimum check, in normalized
   --  units, on a craft other than a tricopter with its servo live when
   --  disarmed or a fixed wing.
   function Resets_Yaw
     (Sticks_Arm : Boolean; Throttle : RC_Command.Channel_Value; Min_Check : Natural;
      Mode : Mixer_Init.Mixer_Mode; Tri_Unarmed_Servo : Boolean) return Boolean is
     (Sticks_Arm and then Modes.Normalized (Throttle) <= Modes.Normalized (Float (Min_Check))
      and then not (Mode in Mixer_Init.Tri | Mixer_Init.Custom_Tri and then Tri_Unarmed_Servo)
      and then Mode not in Mixer_Init.Airplane | Mixer_Init.Flying_Wing);

end Adaflight.Core_Loop;
