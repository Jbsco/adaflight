--  The position navigation target: a leg's target east, north and up in
--  metres with its cruise speed, arrival radius and completion speed; the
--  horizontal velocity toward it under the position gain, the approach brake
--  and the acceleration limits, or the velocity its owner states; the
--  vertical ramp that walks the commanded altitude at the leg's rate, braked
--  into the leg altitude and leashed to the craft; and the arrival test with
--  its hysteresis and settle timeout. The owner that issues the legs stays
--  with the target: an update reports a leg reached, and the owner sets the
--  next leg or finishes the reached one.
with Interfaces;
with Adaflight.Position_Filter;

package Adaflight.Position_Nav with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Position_Gain          : constant := 1.0;
   Min_Distance_M         : constant := 0.01;
   Hysteresis_Factor      : constant := 1.5;
   Vert_Ramp_Leash_S      : constant := 1.0;
   Vert_Ramp_Leash_Min_M  : constant := 1.0;
   Vert_Ramp_Decel_Mps2   : constant := 2.0;
   Vert_Acceptance_M      : constant := 0.5;

   --  The estimate in centimetres, and the leg's quantities in metres and
   --  metres per second: positions within the estimator's bound, speeds
   --  below a kilometre per second, rates that a ramp cut short can reach
   --  the altitude error over a task interval, and accelerations, radii and
   --  times in their settings' ranges.
   subtype Cm is Position_Filter.Value;
   Metres_Bound : constant := 2.0 ** 18;
   subtype Metres is Float range -Metres_Bound .. Metres_Bound;
   subtype Speed_Mps is Float range 0.0 .. 1_000.0;
   subtype Stated_Speed_Mps is Float range -1_000.0 .. 1_000.0;
   Rate_Bound : constant := 2.0 ** 60;
   subtype Rate_Mps is Float range -Rate_Bound .. Rate_Bound;
   Ramp_Rate_Bound : constant := 2.0 ** 34;
   subtype Ramp_Rate_Mps is Float range -Ramp_Rate_Bound .. Ramp_Rate_Bound;
   subtype Accel_Mps2 is Float range 0.0 .. 1_000.0;
   subtype Radius_M is Float range 0.0 .. 100_000.0;
   --  An acceptance radius below zero never lets a leg arrive by itself.
   subtype Acceptance_M is Float range -1.0 .. 100_000.0;
   subtype Seconds is Float range 0.0 .. 100.0;
   subtype Settle_Seconds is Float range 0.0 .. 2.0 ** 30;
   subtype Angle_Deg is Float range 0.0 .. 90.0;
   Velocity_Cm_Bound : constant := 100.0 * 2.0 ** 60;
   subtype Velocity_Cm_S is Float range -Velocity_Cm_Bound .. Velocity_Cm_Bound;

   type Position_M is record
      East, North, Up : Metres := 0.0;
   end record;

   type Velocity_M is record
      East, North : Stated_Speed_Mps := 0.0;
   end record;

   type Velocity_3_Mps is record
      East, North, Up : Rate_Mps := 0.0;
   end record;

   type Velocity_3_Cm_S is record
      East, North, Up : Velocity_Cm_S := 0.0;
   end record;

   type Position_Cm is record
      East, North, Up : Cm := 0.0;
   end record;

   --  The estimate's position and velocity, east, north and up.
   type Estimate is record
      Position : Position_Cm;
      Velocity : Position_Cm;
   end record;

   --  A leg: its target and how to fly it, the vertical ramp's state, the
   --  approach, the stated velocity, the limits, and the arrival policy.
   type Command is record
      Active                    : Boolean := False;
      Sequence                  : Unsigned_32 := 0;
      Completed                 : Boolean := False;
      Completion_Signalled      : Boolean := False;
      Target                    : Position_M;
      Fixed_Target              : Boolean := False;
      Include_Altitude          : Boolean := False;
      Cruise_Speed              : Speed_Mps := 0.0;
      Vert_Rate                 : Stated_Speed_Mps := 0.0;
      Acceptance_Radius         : Acceptance_M := 0.0;
      Completion_Speed          : Speed_Mps := 0.0;
      Settle_Timeout            : Seconds := 0.0;
      Settle                    : Settle_Seconds := 0.0;
      Ramp_Alt                  : Metres := 0.0;
      Ramp_Valid                : Boolean := False;
      Ramp_Rate                 : Ramp_Rate_Mps := 0.0;
      Ramp_Rate_Slewed          : Boolean := False;
      Approach_Decel            : Accel_Mps2 := 0.0;
      Approach_Still_Radius     : Radius_M := 0.0;
      Approach_Still            : Boolean := False;
      Velocity_FF_Valid         : Boolean := False;
      Velocity_FF               : Velocity_M;
      Velocity_From_Craft       : Boolean := False;
      Max_Accel                 : Accel_Mps2 := 0.0;
      Max_Decel                 : Accel_Mps2 := 0.0;
      Max_Angle                 : Angle_Deg := 0.0;
      Auto_Clear_On_Reach       : Boolean := False;
      Altitude_Arrival_Required : Boolean := False;
   end record;

   --  The navigator: the leg, the velocity commanded before this cycle, the
   --  velocity commanded now in centimetres per second, and the arrival
   --  windows entered.
   type Navigator is record
      Cmd             : Command;
      Previous_Vel    : Velocity_3_Mps;
      Previous_Valid  : Boolean := False;
      Target_Vel      : Velocity_3_Cm_S;
      Within_Radius   : Boolean := False;
      Within_Altitude : Boolean := False;
   end record;

   --  Every leg cleared with the sequence kept, so a consumer still sees the
   --  next leg as a change; the navigator starts the same way.
   procedure Reset (N : in out Navigator);
   procedure Init (N : in out Navigator) renames Reset;

   --  A new leg, taking over the velocity commanded so far and, from a leg
   --  still flying, the ramp's rate to slew out of.
   procedure Set_Target (N : in out Navigator; Target : Position_M; Cruise_Speed : Speed_Mps;
                         Acceptance_Radius : Acceptance_M; Completion_Speed : Speed_Mps; Include_Altitude : Boolean);

   --  The active leg's target moved without disturbing the ramp or the
   --  arrival state; the leg flies a moving target from then on.
   procedure Move_Target (N : in out Navigator; Target : Position_M);

   --  The active leg's target altitude lowered to Up_M, never raised.
   procedure Lower_Target_Altitude (N : in out Navigator; Up_M : Metres);

   procedure Clear_Target (N : in out Navigator);

   function Has_Active_Target (N : Navigator) return Boolean is (N.Cmd.Active);
   function Target_Reached (N : Navigator) return Boolean is (N.Cmd.Completed);

   --  The leg's vertical rate and the altitude the ramp starts from; a rate
   --  at or below zero falls back to the cruise speed.
   procedure Set_Vertical_Profile (N : in out Navigator; Rate : Stated_Speed_Mps; Start_Alt_M : Metres);

   procedure Set_Accel_Limits (N : in out Navigator; Max_Accel, Max_Decel : Accel_Mps2);

   --  The horizontal velocity the owner states for the leg in place of the
   --  chase toward the target.
   procedure Set_Velocity_Feedforward (N : in out Navigator; Vel : Velocity_M);

   --  The active leg starts from no velocity commanded before it.
   procedure Start_Afresh (N : in out Navigator);

   --  The brake onto the target at a constant deceleration, coming to rest
   --  at the still radius.
   procedure Set_Approach_Brake (N : in out Navigator; Decel : Accel_Mps2; Still_Radius : Radius_M);

   --  The speed the approach allows at a distance from the target: the
   --  position gain over the last stretch, joined to the braking curve where
   --  their slopes meet, within the cruise speed.
   function Approach_Speed (Cruise_Speed : Speed_Mps; Decel : Accel_Mps2; Still_Radius : Radius_M;
                            Dist : Float) return Float
     with Pre  => abs Dist <= 2.0 ** 20,
          Post => Approach_Speed'Result in 0.0 .. Cruise_Speed;

   procedure Set_Altitude_Arrival_Required (N : in out Navigator; Required : Boolean);
   procedure Set_Settle_Timeout (N : in out Navigator; Timeout : Seconds);
   procedure Set_Max_Angle (N : in out Navigator; Angle : Angle_Deg);
   procedure Set_Auto_Clear_On_Reach (N : in out Navigator; Auto_Clear : Boolean);

   --  One control cycle: the target velocity from the estimate and the
   --  arrival test. Reached is set on the cycle a leg completes; the owner
   --  then sets the next leg or finishes this one. A task interval is zero
   --  or at least a tenth of a millisecond.
   procedure Update (N : in out Navigator; Dt : Seconds; Est : Estimate; Reached : out Boolean)
     with Pre => Dt = 0.0 or else Dt >= 1.0e-4;

   --  The reached leg with no leg after it: the horizontal velocity cleared
   --  and the leg cleared when it clears itself.
   procedure Finish_Leg (N : in out Navigator);

   function Target_Velocity_Cm_S (N : Navigator) return Velocity_3_Cm_S is (N.Target_Vel);

   --  The altitude the vertical channel commands now: the ramp, or the leg
   --  altitude when the leg has no altitude or no ramp yet.
   function Target_Altitude_Cm (N : Navigator) return Float is
     (if not N.Cmd.Include_Altitude or else not N.Cmd.Ramp_Valid then N.Cmd.Target.Up * 100.0
      else N.Cmd.Ramp_Alt * 100.0);

   --  The leg's rate cap in centimetres per second, or the rate a ramp is
   --  still slewing out of when that is faster; zero without a leg.
   function Vertical_Rate_Limit_Cm_S (N : Navigator) return Float;

end Adaflight.Position_Nav;
