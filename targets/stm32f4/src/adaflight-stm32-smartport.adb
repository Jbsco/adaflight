with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Telemetry_Port;
package body Adaflight.STM32.SmartPort is
   package Core renames Adaflight.SmartPort_Telemetry;
   package Port_Of is new Adaflight.STM32.Telemetry_Port
     (Protocol => 4, Function_Bit => Adaflight.Serial_Feature_Map.Function_SmartPort, Default_Baud => 4,
      Fixed_Rate => True, Inverted_Default => True, Half_Duplex_Use => True);

   Pending_Size : constant := 256;
   --  Every value of the tables gets its turn within one run.
   Attempts     : constant := Core.Max_Values + Core.Max_ESC_Values;

   Stream  : Core.Stream;
   Pending : Byte_Array (0 .. Pending_Size - 1) := (others => 0);
   Waiting : Natural range 0 .. Pending_Size := 0;
   Input   : Byte_Array (0 .. 255);

   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Build  : Core.Build_Inputs)
   is
   begin
      Stream := (others => <>);
      Core.Build (Stream, Build);
      Waiting := 0;
      Port_Of.Init (Config, Runtime_Features);
   end Init;

   procedure Check_State (Armed, Box_Present, Box_Active : Boolean) is
   begin
      Port_Of.Check_State (Armed, Box_Present, Box_Active);
   end Check_State;

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (Port_Of.Holds (N));

   procedure Run (Inp : Core.Inputs) is
      Count    : Natural;
      Consumed : Natural;
      O        : Core.Output;
      Line     : Adaflight.STM32.USART.Port;
   begin
      if not Port_Of.Enabled then
         return;
      end if;
      Adaflight.STM32.USART.Take (Port_Of.Line, Input, Count);
      for I in 0 .. Count - 1 loop
         exit when Waiting = Pending_Size;
         Pending (Waiting) := Input (I);
         Waiting := Waiting + 1;
      end loop;
      Core.Update (Stream, Inp, Pending (0 .. Waiting - 1), Attempts, O, Consumed);
      Pending (0 .. Waiting - Consumed - 1) := Pending (Consumed .. Waiting - 1);
      Waiting := Waiting - Consumed;
      if O.Count > 0 then
         Line.Which := Port_Of.Line;
         Adaflight.STM32.USART.Put (Line, O.Tx (0 .. O.Count - 1));
      end if;
   end Run;
end Adaflight.STM32.SmartPort;
