--  The flight statistics: the flights, the armed seconds and the metres
--  flown accumulate on each disarm past a minimum armed time, the battery
--  draw is recorded, and the save of the configuration waits until the
--  craft lies still and no other change is pending. The configuration
--  store, the beeper and the scheduler stay with the target.
with Interfaces;

package Adaflight.Flight_Stats with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_8;
   use type Interfaces.Unsigned_8;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_32 is Interfaces.Integer_32;

   --  The delay before the save, so the disarm completes first.
   Save_Delay_Us : constant := 500_000;

   --  A minimum armed time below zero turns the statistics off.
   Off : constant Integer_8 := -1;

   type Settings is record
      Min_Armed_Time_S : Integer_8 := Off;
      Save_Move_Limit  : Unsigned_8 := 20;
   end record;

   --  The totals the configuration carries.
   type Totals is record
      Flights  : Unsigned_32 := 0;
      Time_S   : Unsigned_32 := 0;
      Dist_M   : Unsigned_32 := 0;
      Mah_Used : Unsigned_32 := 0;
   end record;

   type Tracker is record
      Arm_Ms          : Unsigned_32 := 0;
      Arm_Distance_Cm : Unsigned_32 := 0;
      Save_Required   : Boolean := False;
   end record;

   --  A gyro rate in degrees per second.
   subtype Rate is Float range -1.0e6 .. 1.0e6;

   --  What the scheduled save does: write the configuration and repeat the
   --  disarm beep, ask for another pass after the delay, or nothing.
   type Save_Action is (Nothing, Save, Retry);

   procedure On_Arm (S : in out Tracker; Now_Ms : Unsigned_32; Distance_Cm : Unsigned_32);

   --  Schedule says the save was asked for after the delay.
   procedure On_Disarm (S : in out Tracker; C : Settings; T : in out Totals; Now_Ms, Distance_Cm : Unsigned_32;
                        Mah_Drawn : Integer_32; Schedule : out Boolean);

   --  The scheduled save, with the arming state, whether another change
   --  waits for its save, and the gyro rates.
   procedure Write (S : in out Tracker; C : Settings; Armed, Config_Dirty : Boolean; Roll, Pitch, Yaw : Rate;
                    Action : out Save_Action);

end Adaflight.Flight_Stats;
