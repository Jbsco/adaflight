pragma SPARK_Mode (On);
--  The command line over a reply record and a board that does nothing.
with Adaflight.CLI_Board_Steps;
with Adaflight.CLI_Reply;
with Adaflight.Command_Line;

package Adaflight.Reply_Command_Line is new Adaflight.Command_Line
  (Sink                   => Adaflight.CLI_Reply.Reply,
   Put                    => Adaflight.CLI_Reply.Put,
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
