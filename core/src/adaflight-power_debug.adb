with Interfaces;

package body Adaflight.Power_Debug with SPARK_Mode is

   function Flag (B : Boolean) return Debug.Integer_16 is (if B then 1 else 0);

   function Centi (V : Battery.Centivolts) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (V)));

   procedure Record_Battery (D : in out Debug.State; S : Battery.State; C : Battery.Settings) is
   begin
      if Debug.Selected (D, Debug.Battery) and then S.Taps.Voltage_Updated then
         Debug.Set (D, Debug.Battery, 0, Centi (S.Voltage.Unfiltered));
         Debug.Set (D, Debug.Battery, 1, Centi (S.Voltage.Display_Filtered));
         Debug.Set (D, Debug.Battery, 3, Debug.Wrapped (Interfaces.Integer_32 (S.Voltage.Stable_Bits)));
         Debug.Set (D, Debug.Battery, 4, Flag (Battery.Voltage_Is_Stable (S)));
         Debug.Set (D, Debug.Battery, 5, Flag (Battery.Voltage_From_Battery (S, C)));
         Debug.Set (D, Debug.Battery, 6, Centi (S.Voltage.Stable_Prev_Filtered));
         Debug.Set (D, Debug.Battery, 7, Debug.Integer_16 (Battery.Battery_State'Pos (S.Taps.Voltage_State_Seen)));
      end if;
   end Record_Battery;

   procedure Record_Current (D : in out Debug.State; S : Battery.State) is
   begin
      if Debug.Selected (D, Debug.Current_Sensor) and then S.Taps.ADC_Current then
         Debug.Set (D, Debug.Current_Sensor, 0, Debug.Wrapped (S.Taps.Sensor_Millivolts));
         Debug.Set (D, Debug.Current_Sensor, 1, Debug.Wrapped (S.Taps.Sensor_Centiamps));
         Debug.Set (D, Debug.Current_Sensor, 2, Debug.Wrapped (S.Taps.Sensor_Latest));
         Debug.Set (D, Debug.Current_Sensor, 3, Debug.Wrapped (S.Taps.Sensor_Drawn));
      end if;
   end Record_Current;

   procedure Record_Internal_ADC (D : in out Debug.State; S : Internal_ADC.Sampler) is
   begin
      if Debug.Selected (D, Debug.ADC_Internal) and then S.Taps.Processed then
         Debug.Set (D, Debug.ADC_Internal, 0, S.Core_Temperature);
         Debug.Set (D, Debug.ADC_Internal, 1, Debug.Wrapped (Interfaces.Integer_32 (S.Taps.Vref_Sample)));
         Debug.Set (D, Debug.ADC_Internal, 2, Debug.Wrapped (Interfaces.Integer_32 (S.Taps.Temp_Sample)));
         Debug.Set (D, Debug.ADC_Internal, 3, Debug.Wrapped (Interfaces.Integer_32 (S.Vref_Mv)));
      end if;
   end Record_Internal_ADC;

end Adaflight.Power_Debug;
