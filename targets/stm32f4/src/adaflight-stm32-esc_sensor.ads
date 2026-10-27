--  The ESC sensor on a UART: the port with the ESC sensor function at
--  115200 baud, receiving only, over its transmit pin alone when the half
--  duplex setting is on, and the ESC sensor task, which takes the bytes
--  received, polls each motor in turn through its DShot telemetry request,
--  and keeps the readings for the battery and the MSP replies. The command
--  line's ESC information read takes the bytes that arrive while it runs.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.ESC_Info;
with Adaflight.ESC_Sensor;
with Adaflight.MSP_Out;
with Adaflight.STM32.USART;
package Adaflight.STM32.ESC_Sensor is
   --  The port, opened when the ESC sensor feature is on and a UART has the
   --  ESC sensor function, and every reading marked as not yet received.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32);
   --  Whether the ESC sensor feature is on, and whether its port is open.
   function Feature_On return Boolean;
   function Enabled return Boolean;
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the task over the mixer's motors.
   procedure Run (Now_Us : Interfaces.Unsigned_32; Motors : Natural);
   --  The reading over every motor, for the battery's meters.
   procedure Combined (Motors : Natural; R : out Adaflight.ESC_Sensor.Reading);
   --  The readings of the mixer's motors as the MSP replies take them.
   function Values (Motors : Natural) return Adaflight.MSP_Out.ESC_Values;
   --  An ESC information read: the bytes received before it go to the
   --  telemetry frame in flight, the bytes after it fill the information
   --  frame, and the frame with its count ends the read.
   procedure Info_Read_Start;
   procedure Info_Read_Bytes (F : out Adaflight.ESC_Info.Frame; Count : out Natural);
end Adaflight.STM32.ESC_Sensor;
