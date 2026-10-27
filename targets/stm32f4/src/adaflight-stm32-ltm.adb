with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Telemetry_Port;
package body Adaflight.STM32.LTM is
   package Core renames Adaflight.LTM_Telemetry;
   package Port_Of is new Adaflight.STM32.Telemetry_Port
     (Protocol => 3, Function_Bit => Adaflight.Serial_Feature_Map.Function_LTM, Default_Baud => 2);

   Stream : Core.Stream;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32) is
   begin
      Stream := (others => <>);
      Port_Of.Init (Config, Runtime_Features);
   end Init;

   procedure Check_State (Armed, Box_Present, Box_Active : Boolean) is
   begin
      Port_Of.Check_State (Armed, Box_Present, Box_Active);
   end Check_State;

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (Port_Of.Holds (N));

   procedure Run (Now_Ms : Interfaces.Unsigned_32; Inp : Core.Inputs) is
      O    : Core.Output;
      Line : Adaflight.STM32.USART.Port;
   begin
      if not Port_Of.Enabled then
         return;
      end if;
      Core.Update (Stream, Inp, Now_Ms, True, O);
      if O.Count > 0 then
         Line.Which := Port_Of.Line;
         Adaflight.STM32.USART.Put (Line, O.Data (0 .. O.Count - 1));
      end if;
   end Run;
end Adaflight.STM32.LTM;
