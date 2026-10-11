--  The position filter: a three-state Kalman filter for one axis, position,
--  velocity, and acceleration, with a constant-jerk process model and
--  measurement updates of each state alone or of velocity and position
--  through their shared covariance, in Joseph form.
package Adaflight.Position_Filter with SPARK_Mode, Pure is

   type Component is (Position, Velocity, Acceleration);

   --  Positions in centimeters, velocities in centimeters per second, and
   --  accelerations in centimeters per second squared, within a bound no
   --  flight reaches; covariance entries within a bound far above the
   --  initial variances (DESIGN.md D32).
   State_Bound : constant := 2.0 ** 24;
   subtype Value is Float range -State_Bound .. State_Bound;
   type Vector is array (Component) of Value;
   Variance_Bound : constant := 2.0 ** 40;
   subtype Covariance is Float range -Variance_Bound .. Variance_Bound;
   subtype Variance is Float range 0.0 .. Variance_Bound;
   type Matrix is array (Component, Component) of Covariance;
   subtype Jerk_Density is Float range 0.0 .. 2.0 ** 20;
   subtype Period is Float range 0.0 .. 100.0;
   subtype Noise is Float range 0.0 .. 2.0 ** 30;

   type Filter is record
      X      : Vector := (others => 0.0);
      P      : Matrix := (others => (others => 0.0));
      Q_Jerk : Jerk_Density := 0.0;
   end record;

   procedure Init
     (F : out Filter; Pos : Value; Vel : Value; Acc : Value;
      Pos_Var : Variance; Vel_Var : Variance; Acc_Var : Variance; Q_Jerk : Jerk_Density);

   --  The state and covariance advanced by one period under the
   --  constant-jerk model.
   procedure Predict (F : in out Filter; Dt : Period);

   procedure Shift_Position (F : in out Filter; Delta_Position : Value);

   --  A position measurement against the position alone.
   procedure Update_Position (F : in out Filter; Measured : Value; R : Noise);

   --  A velocity measurement corrects velocity and, through their covariance,
   --  position.
   procedure Update_Velocity_To_Position (F : in out Filter; Measured : Value; R : Noise);

   --  A position measurement corrects position and, through their
   --  covariance, velocity.
   procedure Update_Position_To_Velocity (F : in out Filter; Measured : Value; R : Noise);

   --  An acceleration measurement against the acceleration alone.
   procedure Update_Acceleration (F : in out Filter; Measured : Value; R : Noise);

end Adaflight.Position_Filter;
