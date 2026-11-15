with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Telemetry_Port;
package body Adaflight.STM32.HoTT is
   package Core renames Adaflight.HoTT_Telemetry;
   package Port_Of is new Adaflight.STM32.Telemetry_Port
     (Protocol => 2, Function_Bit => Adaflight.Serial_Feature_Map.Function_HoTT, Default_Baud => 2,
      Fixed_Rate => True, Half_Duplex_Use => True);

   Link    : Core.Link;
   Set     : Core.Settings;
   Waiting : Byte_Array (0 .. 63) := (others => 0);
   Count   : Natural range 0 .. 64 := 0;
   Open    : Boolean := False;

   --  The port's waiting bytes dropped.
   procedure Flush is
      Got : Natural;
   begin
      loop
         Adaflight.STM32.USART.Take (Port_Of.Line, Waiting, Got);
         exit when Got = 0;
      end loop;
      Count := 0;
   end Flush;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32) is
   begin
      Core.Init (Link);
      Set.Alarm_Interval_S := Config.Telemetry_Config.Hott_Alarm_Sound_Interval;
      Count := 0;
      Open := False;
      Port_Of.Init (Config, Runtime_Features);
   end Init;

   procedure Check_State (Armed, Box_Present, Box_Active : Boolean) is
   begin
      Port_Of.Check_State (Armed, Box_Present, Box_Active);
      if Port_Of.Enabled and then not Open then
         --  A port just opened starts in receive: no message on its way out.
         Link.Sending := False;
         Link.Pending := Core.No_Message;
         Flush;
      end if;
      Open := Port_Of.Enabled;
   end Check_State;

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (Port_Of.Holds (N));

   procedure Run
     (Inp : Core.Inputs; GPS_Present : Boolean; Reschedule : out Boolean; Period_Us : out Interfaces.Integer_32)
   is
      O    : Core.Output;
      Line : Adaflight.STM32.USART.Port;
      Got  : Natural;
   begin
      Reschedule := False;
      Period_Us := 0;
      if not Port_Of.Enabled then
         return;
      end if;
      Set.GPS_Present := GPS_Present;
      Adaflight.STM32.USART.Take (Port_Of.Line, Waiting (Count .. Waiting'Last), Got);
      Count := Count + Got;
      Core.Update (Link, Set, Inp, Waiting (0 .. Count - 1), O);
      Waiting (0 .. Count - O.Consumed - 1) := Waiting (O.Consumed .. Count - 1);
      Count := Count - O.Consumed;
      if O.Sent then
         Line.Which := Port_Of.Line;
         Adaflight.STM32.USART.Put (Line, Byte_Array'(0 => O.B));
      end if;
      Reschedule := O.Reschedule;
      Period_Us := O.Period_Us;
   end Run;
end Adaflight.STM32.HoTT;
