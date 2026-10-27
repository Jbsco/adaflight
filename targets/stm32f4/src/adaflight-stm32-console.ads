--  The command line over the board's serial ports and its terminal, with the
--  DShot commands through the motors' DShot output and the flash tools on the
--  flash chip. The board's ESC information reads, delays, passthrough starts
--  and gyro register reads are the core's units that do nothing until their
--  drivers land.
with Adaflight.CLI_Board_Steps;
with Adaflight.STM32.DShot_Output;
with Adaflight.STM32.Flash_Chip;
with Adaflight.Command_Line;
with Adaflight.Command_Line.Terminal;
with Adaflight.STM32.Serial;

package Adaflight.STM32.Console is

   package CLI is new Adaflight.Command_Line
     (Sink                   => Adaflight.STM32.Serial.Port,
      Put                    => Adaflight.STM32.Serial.Put,
      DShot_Write            => Adaflight.STM32.DShot_Output.Write_Blocking,
      Motors_Disable         => Adaflight.STM32.DShot_Output.Disable,
      Motors_Enable          => Adaflight.STM32.DShot_Output.Enable,
      ESC_Read_Start         => Adaflight.CLI_Board_Steps.ESC_Read_Start,
      ESC_Read_Bytes         => Adaflight.CLI_Board_Steps.ESC_Read_Bytes,
      Delay_Ms               => Adaflight.CLI_Board_Steps.Delay_Ms,
      ESC_Passthrough        => Adaflight.CLI_Board_Steps.ESC_Passthrough,
      GPS_Passthrough        => Adaflight.CLI_Board_Steps.GPS_Passthrough,
      Gyro_Read_Register     => Adaflight.CLI_Board_Steps.Gyro_Read_Register,
      Flash_Supported        => Adaflight.STM32.Flash_Chip.Supported,
      Flash_Erase_Completely => Adaflight.STM32.Flash_Chip.Erase_Completely,
      Flash_Ready            => Adaflight.STM32.Flash_Chip.Is_Ready,
      Flash_Erase_Async      => Adaflight.STM32.Flash_Chip.Erase_Step,
      Flash_Verify           => Adaflight.STM32.Flash_Chip.Verify,
      Flash_Seek             => Adaflight.STM32.Flash_Chip.Seek,
      Flash_Write            => Adaflight.STM32.Flash_Chip.Write_Text,
      Flash_Flush            => Adaflight.STM32.Flash_Chip.Flush_Sync,
      Flash_Read             => Adaflight.STM32.Flash_Chip.Read_Text);

   package Terminal is new CLI.Terminal;

end Adaflight.STM32.Console;
