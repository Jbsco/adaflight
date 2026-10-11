with Adaflight.Maths; use Adaflight.Maths;

package body Adaflight.Position_Filter with SPARK_Mode is

   --  An innovation covariance below this leaves the state untouched.
   Min_Innovation_Covariance : constant Float := 1.0e-9;

   --  A gain or a covariance held to its range; a gain within the ratio of
   --  two variances stays far inside its bound (DESIGN.md D32).
   Gain_Bound : constant := 2.0 ** 16;
   subtype Gain is Float range -Gain_Bound .. Gain_Bound;

   function Held (V : Float) return Value is (Constrain_F (V, -State_Bound, State_Bound));
   function Held_Covariance (V : Float) return Covariance is (Constrain_F (V, -Variance_Bound, Variance_Bound));
   function Held_Gain (V : Float) return Gain is (Constrain_F (V, -Gain_Bound, Gain_Bound));

   --  The product of a three by three matrix with the covariance, then with
   --  the transpose of a second matrix: the reference's two accumulations.
   subtype Factor_Entry is Float range -2.0 ** 17 .. 2.0 ** 17;
   type Factor is array (Component, Component) of Factor_Entry;
   subtype Half_Product is Float range -2.0 ** 60 .. 2.0 ** 60;
   type Half_Products is array (Component, Component) of Half_Product;
   subtype Full_Product is Float range -2.0 ** 80 .. 2.0 ** 80;

   --  One entry of the second accumulation: the row of the first product
   --  against a row of the second matrix.
   function Second (AP : Half_Products; B : Factor; Row : Component; Column : Component) return Half_Product is
      Sum : Full_Product := 0.0;
   begin
      for I in Component loop
         Sum := Constrain_F (Sum + AP (Row, I) * B (Column, I), -2.0 ** 80, 2.0 ** 80);
      end loop;
      return Constrain_F (Sum, -2.0 ** 60, 2.0 ** 60);
   end Second;

   procedure Sandwich (A : Factor; P : Matrix; B : Factor; Result : out Half_Products)
     with Post => (for all R in Component => (for all C in Component => abs Result (R, C) <= 2.0 ** 60))
   is
      AP : Half_Products := (others => (others => 0.0));
   begin
      for Row in Component loop
         for Column in Component loop
            for I in Component loop
               AP (Row, Column) :=
                 Constrain_F (AP (Row, Column) + A (Row, I) * P (I, Column), -2.0 ** 60, 2.0 ** 60);
            end loop;
         end loop;
      end loop;
      Result :=
        (Position     => (Position     => Second (AP, B, Position, Position),
                          Velocity     => Second (AP, B, Position, Velocity),
                          Acceleration => Second (AP, B, Position, Acceleration)),
         Velocity     => (Position     => Second (AP, B, Velocity, Position),
                          Velocity     => Second (AP, B, Velocity, Velocity),
                          Acceleration => Second (AP, B, Velocity, Acceleration)),
         Acceleration => (Position     => Second (AP, B, Acceleration, Position),
                          Velocity     => Second (AP, B, Acceleration, Velocity),
                          Acceleration => Second (AP, B, Acceleration, Acceleration)));
   end Sandwich;

   ----------
   -- Init --
   ----------

   procedure Init
     (F : out Filter; Pos : Value; Vel : Value; Acc : Value;
      Pos_Var : Variance; Vel_Var : Variance; Acc_Var : Variance; Q_Jerk : Jerk_Density)
   is
   begin
      F := (X => (Position => Pos, Velocity => Vel, Acceleration => Acc),
            P => (others => (others => 0.0)),
            Q_Jerk => Q_Jerk);
      F.P (Position, Position) := Pos_Var;
      F.P (Velocity, Velocity) := Vel_Var;
      F.P (Acceleration, Acceleration) := Acc_Var;
   end Init;

   -------------
   -- Predict --
   -------------

   procedure Predict (F : in out Filter; Dt : Period) is
      subtype Power is Float range 0.0 .. 2.0 ** 34;
      Dt2      : constant Power := Dt * Dt;
      Half_Dt2 : constant Power := 0.5 * Dt2;
      Dt3      : constant Power := Dt2 * Dt;
      Dt4      : constant Power := Dt3 * Dt;
      Dt5      : constant Power := Dt4 * Dt;
      Q        : constant Jerk_Density := F.Q_Jerk;
      Transition : constant Factor :=
        (Position     => (Position => 1.0, Velocity => Dt, Acceleration => Half_Dt2),
         Velocity     => (Position => 0.0, Velocity => 1.0, Acceleration => Dt),
         Acceleration => (Position => 0.0, Velocity => 0.0, Acceleration => 1.0));
      Predicted : Half_Products;
      subtype Noise_Entry is Float range 0.0 .. 2.0 ** 55;
      Process_Noise : constant array (Component, Component) of Noise_Entry :=
        (Position     => (Position => Q * Dt5 / 20.0, Velocity => Q * Dt4 / 8.0, Acceleration => Q * Dt3 / 6.0),
         Velocity     => (Position => Q * Dt4 / 8.0, Velocity => Q * Dt3 / 3.0, Acceleration => Q * Dt2 / 2.0),
         Acceleration => (Position => Q * Dt3 / 6.0, Velocity => Q * Dt2 / 2.0, Acceleration => Q * Dt));
   begin
      F.X (Position) := Held (F.X (Position) + (F.X (Velocity) * Dt + Half_Dt2 * F.X (Acceleration)));
      F.X (Velocity) := Held (F.X (Velocity) + F.X (Acceleration) * Dt);
      Sandwich (Transition, F.P, Transition, Predicted);
      for Row in Component loop
         for Column in Component loop
            F.P (Row, Column) := Held_Covariance (Predicted (Row, Column) + Process_Noise (Row, Column));
         end loop;
      end loop;
   end Predict;

   --------------------
   -- Shift_Position --
   --------------------

   procedure Shift_Position (F : in out Filter; Delta_Position : Value) is
   begin
      F.X (Position) := Held (F.X (Position) + Delta_Position);
   end Shift_Position;

   ---------------------
   -- Update_Position --
   ---------------------

   procedure Update_Position (F : in out Filter; Measured : Value; R : Noise) is
      S : constant Float := F.P (Position, Position) + R;
   begin
      if S < Min_Innovation_Covariance then
         return;
      end if;
      declare
         G          : constant Gain := Held_Gain (F.P (Position, Position) / S);
         Innovation : constant Float := Measured - F.X (Position);
         Scale      : constant Float := 1.0 - G;
      begin
         F.X (Position) := Held (F.X (Position) + G * Innovation);
         F.P (Position, Position) := Held_Covariance (F.P (Position, Position) * Scale);
         F.P (Position, Velocity) := Held_Covariance (F.P (Position, Velocity) * Scale);
         F.P (Velocity, Position) := F.P (Position, Velocity);
         F.P (Position, Acceleration) := Held_Covariance (F.P (Position, Acceleration) * Scale);
         F.P (Acceleration, Position) := F.P (Position, Acceleration);
      end;
   end Update_Position;

   --  The covariance after a gain in Joseph form: the state transition of the
   --  gain around the covariance, plus the gain's outer product scaled by the
   --  measurement noise.
   type Vector_Gain is array (Component) of Gain;

   procedure Joseph_Update (F : in out Filter; A : Factor; K : Vector_Gain; R : Noise)
     with Post => F.X = F.X'Old and then F.Q_Jerk = F.Q_Jerk'Old
   is
      Updated : Half_Products;
   begin
      Sandwich (A, F.P, A, Updated);
      for Row in Component loop
         for Column in Component loop
            F.P (Row, Column) := Held_Covariance (Updated (Row, Column) + K (Row) * R * K (Column));
         end loop;
      end loop;
   end Joseph_Update;

   ---------------------------------
   -- Update_Velocity_To_Position --
   ---------------------------------

   procedure Update_Velocity_To_Position (F : in out Filter; Measured : Value; R : Noise) is
      Pvv : constant Covariance := F.P (Velocity, Velocity);
      S   : constant Float := Pvv + R;
   begin
      if S < Min_Innovation_Covariance then
         return;
      end if;
      declare
         Innovation : constant Float := Measured - F.X (Velocity);
         K : constant Vector_Gain :=
           (Position => Held_Gain (F.P (Position, Velocity) / S), Velocity => Held_Gain (Pvv / S), Acceleration => 0.0);
         A : constant Factor :=
           (Position     => (Position => 1.0, Velocity => -K (Position), Acceleration => 0.0),
            Velocity     => (Position => 0.0, Velocity => 1.0 - K (Velocity), Acceleration => 0.0),
            Acceleration => (Position => 0.0, Velocity => -K (Acceleration), Acceleration => 1.0));
      begin
         F.X (Position) := Held (F.X (Position) + K (Position) * Innovation);
         F.X (Velocity) := Held (F.X (Velocity) + K (Velocity) * Innovation);
         Joseph_Update (F, A, K, R);
      end;
   end Update_Velocity_To_Position;

   ---------------------------------
   -- Update_Position_To_Velocity --
   ---------------------------------

   procedure Update_Position_To_Velocity (F : in out Filter; Measured : Value; R : Noise) is
      Ppp : constant Covariance := F.P (Position, Position);
      S   : constant Float := Ppp + R;
   begin
      if S < Min_Innovation_Covariance then
         return;
      end if;
      declare
         Innovation : constant Float := Measured - F.X (Position);
         K : constant Vector_Gain :=
           (Position => Held_Gain (Ppp / S), Velocity => Held_Gain (F.P (Velocity, Position) / S), Acceleration => 0.0);
         A : constant Factor :=
           (Position     => (Position => 1.0 - K (Position), Velocity => 0.0, Acceleration => 0.0),
            Velocity     => (Position => -K (Velocity), Velocity => 1.0, Acceleration => 0.0),
            Acceleration => (Position => -K (Acceleration), Velocity => 0.0, Acceleration => 1.0));
      begin
         F.X (Position) := Held (F.X (Position) + K (Position) * Innovation);
         F.X (Velocity) := Held (F.X (Velocity) + K (Velocity) * Innovation);
         Joseph_Update (F, A, K, R);
      end;
   end Update_Position_To_Velocity;

   -------------------------
   -- Update_Acceleration --
   -------------------------

   procedure Update_Acceleration (F : in out Filter; Measured : Value; R : Noise) is
      Paa : constant Covariance := F.P (Acceleration, Acceleration);
      S   : constant Float := Paa + R;
   begin
      if S < Min_Innovation_Covariance then
         return;
      end if;
      declare
         G          : constant Gain := Held_Gain (Paa / S);
         Innovation : constant Float := Measured - F.X (Acceleration);
         Scale      : constant Float := 1.0 - G;
      begin
         F.X (Acceleration) := Held (F.X (Acceleration) + G * Innovation);
         F.P (Acceleration, Acceleration) := Held_Covariance (F.P (Acceleration, Acceleration) * Scale);
         F.P (Position, Acceleration) := Held_Covariance (F.P (Position, Acceleration) * Scale);
         F.P (Acceleration, Position) := F.P (Position, Acceleration);
         F.P (Velocity, Acceleration) := Held_Covariance (F.P (Velocity, Acceleration) * Scale);
         F.P (Acceleration, Velocity) := F.P (Velocity, Acceleration);
      end;
   end Update_Acceleration;

end Adaflight.Position_Filter;
