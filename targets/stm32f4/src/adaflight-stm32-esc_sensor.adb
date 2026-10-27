with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.STM32.DShot_Output;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.GPS;
with Adaflight.STM32.Motors;
with Adaflight.STM32.Radio;
package body Adaflight.STM32.ESC_Sensor is
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.STM32.USART.Number;
   package USART renames Adaflight.STM32.USART;
   package Core renames Adaflight.ESC_Sensor;

   Port_Ids : constant array (USART.Number) of Interfaces.Integer_8 :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);
   No_Port : constant Interfaces.Integer_8 := -1;
   Baud    : constant := 115_200;

   Feature : Boolean := False;
   Open    : Boolean := False;
   Which   : USART.Number := USART.UART1;
   Sensor  : Core.Sensor;
   Input   : Byte_Array (0 .. 255);
   --  The electrical rate's factor to revolutions per second from the pole
   --  count, for the rate in revolutions per minute.
   Erpm_To_Hz : Float := 0.0;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32) is
      Poles : constant Positive := Positive'Max (1, Natural (Config.Motor_Config.Motor_Pole_Count));
   begin
      Feature := (Runtime_Features and Adaflight.Config_Fix.Feature_ESC_Sensor) /= 0;
      Erpm_To_Hz := 100.0 / 60.0 / (Float (Poles) / 2.0);
      Open := False;
      if Feature and then Config.Esc_Sensor_Config.Esc_Sensor_Uart /= No_Port then
         for N in USART.Number loop
            if Port_Ids (N) = Config.Esc_Sensor_Config.Esc_Sensor_Uart then
               if not Adaflight.STM32.Radio.Holds (N) and then not Adaflight.STM32.GPS.Holds (N) then
                  Which := N;
                  Open := True;
               end if;
               exit;
            end if;
         end loop;
         Core.Init (Sensor);
      end if;
      if Open then
         USART.Init
           (Which, Baud,
            Line => (On => Config.Esc_Sensor_Config.Half_Duplex /= 0, Push_Pull => False,
                     Resistor => Adaflight.STM32.GPIO.Up));
      end if;
   end Init;

   function Feature_On return Boolean is (Feature);

   function Enabled return Boolean is (Open);

   function Holds (N : USART.Number) return Boolean is (Open and then N = Which);

   function Count_Of (Motors : Natural) return Core.Motor_Count is (Natural'Min (Motors, Core.Motor_Count'Last));

   procedure Run (Now_Us : Interfaces.Unsigned_32; Motors : Natural) is
      Count   : Natural;
      Request : Boolean;
   begin
      if not Open then
         return;
      end if;
      USART.Take (Which, Input, Count);
      for I in 0 .. Count - 1 loop
         Core.Receive (Sensor, Input (I));
      end loop;
      Core.Process (Sensor, Now_Us, Count_Of (Motors), Adaflight.STM32.Motors.Enabled, Request);
      if Request then
         Adaflight.STM32.DShot_Output.Request_Telemetry (Sensor.Motor);
      end if;
   end Run;

   procedure Combined (Motors : Natural; R : out Core.Reading) is
   begin
      Core.Combined_Reading (Sensor, Count_Of (Motors), R);
   end Combined;

   function Values (Motors : Natural) return Adaflight.MSP_Out.ESC_Values is
      V     : Adaflight.MSP_Out.ESC_Values;
      Count : constant Core.Motor_Count := Count_Of (Motors);
   begin
      V.ESC_Sensor := Feature;
      V.Count := Count;
      for M in 0 .. Count - 1 loop
         declare
            D : Core.Reading renames Sensor.Data (M);
            T : Adaflight.MSP_Out.Motor_Telemetry renames V.Motors (M);
         begin
            T.ESC_Temperature := D.Temperature;
            T.ESC_Voltage := D.Voltage;
            T.ESC_Current := D.Current;
            T.ESC_Consumption := D.Consumption;
            T.ESC_Erpm := D.Rpm;
            T.ESC_Rpm := (if D.Rpm > 0 then Float (D.Rpm) * Erpm_To_Hz * 60.0 else 0.0);
         end;
      end loop;
      return V;
   end Values;
end Adaflight.STM32.ESC_Sensor;
