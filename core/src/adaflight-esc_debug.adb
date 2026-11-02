with Interfaces;

package body Adaflight.ESC_Debug with SPARK_Mode is
   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_16;

   function Count (V : Interfaces.Unsigned_16) return Debug.Integer_16 is (Debug.Wrapped (Interfaces.Integer_32 (V)));

   --  The rate in tens of revolutions per minute as upstream computes it:
   --  the signed count read as an unsigned one, to revolutions per minute,
   --  a tenth, rounded, then wrapped into sixteen bits; past the conversion
   --  bound a float is an integer already.
   function Rpm_Tens (Rpm : Interfaces.Integer_16; Erpm_To_Hz : DShot.Rate_Factor) return Debug.Integer_16 is
      Erpm : constant Float range 0.0 .. 2.0 ** 32 := Float (Interfaces.Unsigned_32'Mod (Rpm));
      X    : constant Float range 0.0 .. 2.0 ** 42 := Erpm * Erpm_To_Hz * 60.0 / 10.0;
   begin
      if X <= Debug.Conversion_Bound then
         return Debug.Rounded (X);
      else
         return Debug.Wrapped (Interfaces.Integer_32 (Interfaces.Unsigned_16'Mod (Interfaces.Unsigned_64 (X))));
      end if;
   end Rpm_Tens;

   procedure Record_Process (D : in out Debug.State; E : in out ESC_Sensor.Sensor; Requested : Boolean;
                             Erpm_To_Hz : DShot.Rate_Factor) is
   begin
      if Debug.Selected (D, Debug.ESC_Sensor) then
         if Requested then
            Debug.Set (D, Debug.ESC_Sensor, 0, Debug.Integer_16 (E.Motor) + 1);
         end if;
         if E.Taps.Timed_Out then
            E.Timeouts := E.Timeouts + 1;
            Debug.Set (D, Debug.ESC_Sensor, 1, Count (E.Timeouts));
         end if;
         if E.Taps.Checksum_Failed then
            E.Checksum_Errors := E.Checksum_Errors + 1;
            Debug.Set (D, Debug.ESC_Sensor, 2, Count (E.Checksum_Errors));
         end if;
      end if;
      if E.Taps.Frame_Decoded and then E.Taps.Frame_Motor < 4 then
         if Debug.Selected (D, Debug.ESC_Sensor_RPM) then
            Debug.Set (D, Debug.ESC_Sensor_RPM, E.Taps.Frame_Motor,
                       Rpm_Tens (E.Data (E.Taps.Frame_Motor).Rpm, Erpm_To_Hz));
         end if;
         if Debug.Selected (D, Debug.ESC_Sensor_Tmp) then
            Debug.Set (D, Debug.ESC_Sensor_Tmp, E.Taps.Frame_Motor,
                       Debug.Integer_16 (E.Data (E.Taps.Frame_Motor).Temperature));
         end if;
      end if;
   end Record_Process;

   procedure Record_Combined (D : in out Debug.State; E : ESC_Sensor.Sensor) is
   begin
      if Debug.Selected (D, Debug.ESC_Sensor) then
         Debug.Set (D, Debug.ESC_Sensor, 3, Debug.Integer_16 (E.Combined.Data_Age));
      end if;
   end Record_Combined;

end Adaflight.ESC_Debug;
