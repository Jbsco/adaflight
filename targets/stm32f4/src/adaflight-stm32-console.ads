--  The command line over the board's serial ports and its terminal. The board's DShot
--  programming, passthrough starts, gyro register reads and flash tools are
--  the core's units that do nothing until their drivers land.
with Adaflight.CLI_Board_Steps;
with Adaflight.Command_Line;
with Adaflight.Command_Line.Terminal;
with Adaflight.STM32.Serial;

package Adaflight.STM32.Console is

   package CLI is new Adaflight.Command_Line
     (Sink                   => Adaflight.STM32.Serial.Port,
      Put                    => Adaflight.STM32.Serial.Put,
      DShot_Write            => Adaflight.CLI_Board_Steps.DShot_Write,
      Motors_Disable         => Adaflight.CLI_Board_Steps.Motors_Disable,
      Motors_Enable          => Adaflight.CLI_Board_Steps.Motors_Enable,
      ESC_Read_Start         => Adaflight.CLI_Board_Steps.ESC_Read_Start,
      ESC_Read_Bytes         => Adaflight.CLI_Board_Steps.ESC_Read_Bytes,
      Delay_Ms               => Adaflight.CLI_Board_Steps.Delay_Ms,
      ESC_Passthrough        => Adaflight.CLI_Board_Steps.ESC_Passthrough,
      GPS_Passthrough        => Adaflight.CLI_Board_Steps.GPS_Passthrough,
      Gyro_Read_Register     => Adaflight.CLI_Board_Steps.Gyro_Read_Register,
      Flash_Supported        => Adaflight.CLI_Board_Steps.Flash_Supported,
      Flash_Erase_Completely => Adaflight.CLI_Board_Steps.Flash_Erase_Completely,
      Flash_Ready            => Adaflight.CLI_Board_Steps.Flash_Ready,
      Flash_Erase_Async      => Adaflight.CLI_Board_Steps.Flash_Erase_Async,
      Flash_Verify           => Adaflight.CLI_Board_Steps.Flash_Verify,
      Flash_Seek             => Adaflight.CLI_Board_Steps.Flash_Seek,
      Flash_Write            => Adaflight.CLI_Board_Steps.Flash_Write,
      Flash_Flush            => Adaflight.CLI_Board_Steps.Flash_Flush,
      Flash_Read             => Adaflight.CLI_Board_Steps.Flash_Read);

   package Terminal is new CLI.Terminal;

end Adaflight.STM32.Console;
