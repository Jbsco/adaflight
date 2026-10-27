with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Telemetry_Port;
package body Adaflight.STM32.FrSky_Hub is
   package Core renames Adaflight.FrSky_Hub_Telemetry;
   package Port_Of is new Adaflight.STM32.Telemetry_Port
     (Protocol => 1, Function_Bit => Adaflight.Serial_Feature_Map.Function_FrSky_Hub, Default_Baud => 1,
      Fixed_Rate => True, Inverted_Default => True);

   Stream : Core.Stream;
   Set    : Core.Settings;

   procedure Init
     (Config   : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Settings : Core.Settings)
   is
   begin
      Stream := (others => <>);
      Set := Settings;
      Port_Of.Init (Config, Runtime_Features);
   end Init;

   procedure Check_State (Armed, Box_Present, Box_Active : Boolean) is
   begin
      Port_Of.Check_State (Armed, Box_Present, Box_Active);
   end Check_State;

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (Port_Of.Holds (N));

   procedure Run (Inp : Core.Inputs) is
      O    : Core.Output;
      Line : Adaflight.STM32.USART.Port;
   begin
      if not Port_Of.Enabled then
         return;
      end if;
      Core.Update (Stream, Set, Inp, O);
      if O.Count > 0 then
         Line.Which := Port_Of.Line;
         Adaflight.STM32.USART.Put (Line, O.Tx (0 .. O.Count - 1));
      end if;
   end Run;
end Adaflight.STM32.FrSky_Hub;
