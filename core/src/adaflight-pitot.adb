with Adaflight.Clock;

package body Adaflight.Pitot with SPARK_Mode is

   subtype Signal is Adaflight.Maths.Signal;

   --  The source whose read answered this pass, in the reference's order of
   --  trial: an explicit selection reads only its own backend.
   function Active_Source (S : Sensor; C : Settings; Inp : Inputs) return Source is
      I2C_Ok : constant Boolean := S.I2C_Ready and then Inp.I2C_Read;
      Age    : constant Interfaces.Integer_32 := Adaflight.Clock.Elapsed (Inp.Now_Us, Inp.Can_Update_Us);
      Can_Ok : constant Boolean := Inp.Can_Frame and then Age >= 0 and then Age < Dronecan_Stale_Us;
   begin
      case C.Hardware is
         when MS4525 =>
            return (if I2C_Ok then MS4525 else None);
         when Dronecan =>
            return (if Can_Ok then Dronecan else None);
         when Default =>
            return (if I2C_Ok then MS4525 elsif Can_Ok then Dronecan else None);
         when None =>
            return None;
      end case;
   end Active_Source;

   --  Indicated airspeed in centimetres per second from a differential
   --  pressure, the sign carrying the flow direction. The root of a pressure
   --  within twice the signal bound stays far below the cap.
   function Airspeed_From_Pressure (P : Float) return Float
     with Pre => abs P <= 2.0 * Signal_Bound
   is
      Q : constant Float range 0.0 .. 2.0 * Signal_Bound := abs P;
      V : constant Float range 0.0 .. 1.0e6 :=
        Float'Min (1.0e6, Adaflight.Maths.Sqrt_Non_Negative (2.0 * Q / Air_Density));
   begin
      return (if P < 0.0 then -V else V) * 100.0;
   end Airspeed_From_Pressure;

   ----------
   -- Init --
   ----------

   procedure Init (S : out Sensor; C : Settings; I2C_Detected : Boolean) is
   begin
      S := (Airspeed          => 0.0,
            Diff_Pressure     => 0.0,
            Temperature       => 0.0,
            Pressure_Zero     => 0.0,
            Calibration_Count => 0,
            Calibration_Accum => 0.0,
            Zeros             => (others => 0.0),
            Calibrated        => (others => False),
            Lpf               => (State => 0.0, K => 0.0),
            Lpf_Initialised   => False,
            I2C_Ready         => Is_Configured (C) and then C.Hardware in MS4525 | Default and then I2C_Detected,
            Active            => None,
            Last_Valid_Us     => 0);
   end Init;

   -----------------------
   -- Start_Calibration --
   -----------------------

   procedure Start_Calibration (S : in out Sensor) is
   begin
      S.Calibration_Accum := 0.0;
      S.Calibration_Count := Calibration_Samples;
      if S.Active /= None then
         S.Calibrated (S.Active) := False;
      end if;
   end Start_Calibration;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out Sensor; C : Settings; Inp : Inputs) is
      Src      : constant Source := Active_Source (S, C, Inp);
      Filtered : Signal;
   begin
      if Src = None then
         if S.Active /= None and then Adaflight.Clock.Elapsed (Inp.Now_Us, S.Last_Valid_Us) > Signal_Timeout_Us then
            S.Active := None;
            S.Diff_Pressure := 0.0;
            S.Airspeed := 0.0;
         end if;
         return;
      end if;
      S.Last_Valid_Us := Inp.Now_Us;

      if Src /= S.Active then
         S.Active := Src;
         S.Lpf_Initialised := False;
         if not S.Calibrated (Src) and then not Inp.Armed then
            Start_Calibration (S);
         end if;
      end if;

      if not S.Lpf_Initialised then
         Adaflight.Filters.PT1_Init (S.Lpf, Adaflight.Filters.PT1_Gain (Lpf_Hz, 1.0 / Float (Rate_Hz)));
         S.Lpf_Initialised := True;
      end if;
      Adaflight.Filters.PT1_Apply (S.Lpf, (if Src = MS4525 then Inp.I2C_Pressure else Inp.Can_Pressure), Filtered);

      if S.Calibration_Count > 0 then
         if Inp.Armed then
            S.Calibration_Count := 0;
         else
            S.Calibration_Accum :=
              Float'Max (Accumulated'First, Float'Min (Accumulated'Last, S.Calibration_Accum + Filtered));
            S.Calibration_Count := S.Calibration_Count - 1;
            if S.Calibration_Count = 0 then
               S.Zeros (Src) := S.Calibration_Accum / Float (Calibration_Samples);
               S.Calibrated (Src) := True;
            end if;
         end if;
      end if;

      S.Pressure_Zero := S.Zeros (Src);
      S.Temperature := (if Src = MS4525 then Inp.I2C_Temperature else Inp.Can_Temperature);
      S.Diff_Pressure := Filtered - S.Zeros (Src);
      S.Airspeed := Airspeed_From_Pressure (S.Diff_Pressure);
   end Update;

end Adaflight.Pitot;
