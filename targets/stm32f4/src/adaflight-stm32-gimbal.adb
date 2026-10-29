with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Runtime;
with Adaflight.STM32.ESC_Sensor;
with Adaflight.STM32.GPS;
with Adaflight.STM32.OSD_Custom_Text;
with Adaflight.STM32.Radio;
with Adaflight.STM32.Rangefinder;
with Adaflight.STM32.VTX;
package body Adaflight.STM32.Gimbal is
   use type Interfaces.Integer_8;
   use type Adaflight.STM32.USART.Number;
   package USART renames Adaflight.STM32.USART;
   package Core renames Adaflight.Gimbal_Control;

   Port_Ids : constant array (USART.Number) of Interfaces.Integer_8 :=
     (USART.UART1 => 51, USART.UART2 => 52, USART.UART3 => 53, USART.UART4 => 54, USART.UART5 => 55, USART.UART6 => 56);
   Baud     : constant := 115_200;

   Open  : Boolean := False;
   Which : USART.Number := USART.UART1;
   Port  : USART.Port;
   State : Core.State;

   function Settings_Of (Config : Adaflight.Config_Groups.Configuration) return Core.Settings is
     (Adaflight.Config_Runtime.Gimbal_Settings_Of (Config.Gimbal_Track_Config, Config.Rx_Config, Open));

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Sticks : Core.Sticks) is
   begin
      Open := False;
      for N of USART.Present_Set loop
         if Port_Ids (N) = Config.Gimbal_Track_Config.Gimbal_Uart then
            if not Adaflight.STM32.Rangefinder.Holds (N) and then not Adaflight.STM32.Radio.Holds (N)
              and then not Adaflight.STM32.GPS.Holds (N) and then not Adaflight.STM32.OSD_Custom_Text.Holds (N)
              and then not Adaflight.STM32.ESC_Sensor.Holds (N) and then not Adaflight.STM32.VTX.Holds (N)
            then
               Which := N;
               Open := True;
            end if;
            exit;
         end if;
      end loop;
      if Open then
         Port.Which := Which;
         USART.Init (Which, Baud);
      end if;
      Core.Init (State, Settings_Of (Config), Sticks);
   end Init;

   function Holds (N : USART.Number) return Boolean is (Open and then N = Which);

   procedure Update
     (Config : Adaflight.Config_Groups.Configuration; Sticks : Core.Sticks; Now_Us : Interfaces.Unsigned_32;
      Stop_Task : out Boolean)
   is
      Input : Byte_Array (0 .. Core.Max_Input - 1);
      Count : Natural := 0;
      O     : Core.Output;
   begin
      loop
         if Open then
            USART.Take (Which, Input, Count);
         end if;
         Core.Update (State, Settings_Of (Config), Sticks, Now_Us, Input (0 .. Count - 1), O);
         if O.Length > 0 then
            USART.Put (Port, O.Bytes (0 .. O.Length - 1));
         end if;
         Stop_Task := O.Disable_Task;
         exit when Count < Input'Length;
      end loop;
   end Update;
end Adaflight.STM32.Gimbal;
