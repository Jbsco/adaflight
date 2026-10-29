--  The command line over the board's serial ports and its terminal, with the
--  DShot commands through the motors' DShot output, the ESC information
--  reads on the ESC sensor, the flash tools on the flash chip and the waits
--  on the board's clock. The board's passthrough starts and gyro register
--  reads are the core's units that do nothing until their drivers land.
with Adaflight.CLI_Board_Steps;
with Adaflight.STM32.DShot_Output;
with Adaflight.STM32.ESC_Sensor;
with Adaflight.STM32.Flash_Chip;
with Adaflight.STM32.Passthrough;
with Adaflight.Command_Line;
with Adaflight.Command_Line.Terminal;
with Adaflight.STM32.Serial;
with Adaflight.STM32.Time;

package Adaflight.STM32.Console is

   package CLI is new Adaflight.Command_Line
     (Sink                   => Adaflight.STM32.Serial.Port,
      Put                    => Adaflight.STM32.Serial.Put,
      DShot_Write            => Adaflight.STM32.DShot_Output.Write_Blocking,
      Motors_Disable         => Adaflight.STM32.DShot_Output.Disable,
      Motors_Enable          => Adaflight.STM32.DShot_Output.Enable,
      ESC_Read_Start         => Adaflight.STM32.ESC_Sensor.Info_Read_Start,
      ESC_Read_Bytes         => Adaflight.STM32.ESC_Sensor.Info_Read_Bytes,
      Delay_Ms               => Adaflight.STM32.Time.Delay_Ms,
      ESC_Passthrough        => Adaflight.CLI_Board_Steps.ESC_Passthrough,
      GPS_Passthrough        => Adaflight.STM32.Passthrough.GPS_Passthrough,
      Gyro_Read_Register     => Adaflight.CLI_Board_Steps.Gyro_Read_Register,
      Flash_Supported        => Adaflight.STM32.Flash_Chip.Supported,
      Flash_Erase_Completely => Adaflight.STM32.Flash_Chip.Erase_Completely,
      Flash_Ready            => Adaflight.STM32.Flash_Chip.Is_Ready,
      Flash_Erase_Async      => Adaflight.STM32.Flash_Chip.Erase_Step,
      Flash_Verify           => Adaflight.STM32.Flash_Chip.Verify,
      Flash_Seek             => Adaflight.STM32.Flash_Chip.Seek,
      Flash_Write            => Adaflight.STM32.Flash_Chip.Write_Text,
      Flash_Flush            => Adaflight.STM32.Flash_Chip.Flush_Sync,
      Flash_Read             => Adaflight.STM32.Flash_Chip.Read_Text,
      Port_State             => Adaflight.STM32.Passthrough.Port_State,
      Port_Open              => Adaflight.STM32.Passthrough.Port_Open,
      Port_Set_Baud          => Adaflight.STM32.Passthrough.Port_Set_Baud,
      Port_Set_Mode          => Adaflight.STM32.Passthrough.Port_Set_Mode,
      Port_Remove_Callback   => Adaflight.STM32.Passthrough.Port_Remove_Callback,
      Port_Baud_From_USB     => Adaflight.STM32.Passthrough.Port_Baud_From_USB,
      Port_DTR_Reset         => Adaflight.STM32.Passthrough.Port_DTR_Reset,
      Port_DTR_PINIO         => Adaflight.STM32.Passthrough.Port_DTR_PINIO,
      ESC_Sensor_Pins_Idle   => Adaflight.STM32.Passthrough.ESC_Sensor_Pins_Idle,
      Port_Forward           => Adaflight.STM32.Passthrough.Port_Forward);

   package Terminal is new CLI.Terminal;

end Adaflight.STM32.Console;
