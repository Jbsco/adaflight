pragma SPARK_Mode (On);
--  The log file list over a flash that reads as zeros.
with Adaflight.Virtual_FAT.Logs;
with Adaflight.Virtual_FAT_Steps;

package Adaflight.Blank_Flash_Logs is new Adaflight.Virtual_FAT.Logs (Read => Adaflight.Virtual_FAT_Steps.Read);
