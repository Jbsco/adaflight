with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Telemetry_Port;
package body Adaflight.STM32.IBus is
   package Core renames Adaflight.IBus_Telemetry;
   package Port_Of is new Adaflight.STM32.Telemetry_Port
     (Protocol => 6, Function_Bit => Adaflight.Serial_Feature_Map.Function_IBus, Default_Baud => 5,
      Fixed_Rate => True, Single_Wire => True);

   Sensors : Core.Link;
   Set     : Core.Settings;
   Input   : Byte_Array (0 .. 255);

   procedure Init
     (Config   : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Settings : Core.Settings)
   is
   begin
      Sensors := (others => <>);
      Set := Settings;
      Port_Of.Init (Config, Runtime_Features);
   end Init;

   procedure Check_State (Armed, Box_Present, Box_Active : Boolean) is
   begin
      Port_Of.Check_State (Armed, Box_Present, Box_Active);
   end Check_State;

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (Port_Of.Holds (N));

   procedure Run (Inp : Core.Inputs) is
      Count : Natural;
      O     : Core.Output;
      Line  : Adaflight.STM32.USART.Port;
   begin
      if not Port_Of.Enabled then
         return;
      end if;
      Adaflight.STM32.USART.Take (Port_Of.Line, Input, Count);
      Core.Update (Sensors, Set, Inp, Input (0 .. Count - 1), O);
      if O.Count > 0 then
         Line.Which := Port_Of.Line;
         Adaflight.STM32.USART.Put (Line, O.Tx (0 .. O.Count - 1));
      end if;
   end Run;
end Adaflight.STM32.IBus;
