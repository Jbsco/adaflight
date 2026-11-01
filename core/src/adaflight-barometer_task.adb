package body Adaflight.Barometer_Task with SPARK_Mode is

   ----------
   -- Step --
   ----------

   procedure Step
     (T           : in out State;
      B           : in out Barometer.State;
      C           : Barometer.Settings;
      D           : Device;
      Now_Us      : Unsigned_32;
      Bus_Busy    : Boolean;
      Done        : Boolean;
      Pressure    : Integer_32;
      Temperature : Barometer.Temperature_Centi;
      R           : out Report)
   is
   begin
      T.Taps.Stepped := True;
      T.Taps.Entry_Phase := T.Current;
      R := (Ran => T.Current, Sleep_Us => Default_Sleep_Us, others => False);
      if Bus_Busy then
         R.Ignore_State_Time := True;
         return;
      end if;
      case T.Current is
         when Temperature_Start =>
            T.Cycle_Start_Us := Now_Us;
            T.Current := Temperature_Read;
            R.Sleep_Us := Unsigned_32 (D.Temperature_Delay_Us);
         when Temperature_Read =>
            if Done then
               T.Current := Temperature_Sample;
            else
               R.Ignore_Exec_Time := True;
            end if;
         when Temperature_Sample =>
            if Done then
               T.Current := Pressure_Start;
            else
               R.Ignore_Exec_Time := True;
            end if;
         when Pressure_Start =>
            T.Current := Pressure_Read;
            R.Sleep_Us := Unsigned_32 (D.Pressure_Delay_Us);
         when Pressure_Read =>
            if Done then
               T.Current := Pressure_Sample;
            else
               R.Ignore_Exec_Time := True;
            end if;
         when Pressure_Sample =>
            if Done then
               Barometer.Sample (B, C, Pressure, Temperature, Now_Us);
               if D.Combined_Read then
                  T.Current := Pressure_Start;
               else
                  T.Current := Temperature_Start;
                  declare
                     Elapsed : constant Unsigned_32 := Now_Us - T.Cycle_Start_Us;
                  begin
                     if Elapsed < Cycle_Period_Us then
                        R.Sleep_Us := Cycle_Period_Us - Elapsed;
                     end if;
                  end;
               end if;
            else
               R.Ignore_Exec_Time := True;
            end if;
      end case;
      R.Ignore_Exec_Rate := T.Current /= Pressure_Start;
   end Step;

   ------------
   -- Finish --
   ------------

   procedure Finish (T : in out State; Ran : Phase; Elapsed_Us : Unsigned_32; Next_State_Us : out Integer_32) is
      use type Interfaces.Integer_64;
   begin
      if Elapsed_Us > T.Duration (Ran) then
         T.Duration (Ran) := Elapsed_Us;
      end if;
      if T.Duration (T.Current) <= Unsigned_32 (Integer_32'Last) then
         Next_State_Us := Integer_32 (T.Duration (T.Current));
      else
         Next_State_Us := Integer_32 (Interfaces.Integer_64 (T.Duration (T.Current)) - 2 ** 32);
      end if;
   end Finish;

end Adaflight.Barometer_Task;
