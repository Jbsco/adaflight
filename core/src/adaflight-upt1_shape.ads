pragma SPARK_Mode (On);
--  The UP-T1 driver over a port that does nothing, the shape the proof
--  covers.
with Adaflight.UPT1;
with Adaflight.Serial_Port_Steps;

package Adaflight.UPT1_Shape is new Adaflight.UPT1
  (Serial_Device => Adaflight.Serial_Port_Steps.Port_Line,
   Open_Port     => Adaflight.Serial_Port_Steps.Step_Open_Port,
   Bytes_Waiting => Adaflight.Serial_Port_Steps.Step_Bytes_Waiting,
   Read_Byte     => Adaflight.Serial_Port_Steps.Step_Read_Byte,
   Write_Bytes   => Adaflight.Serial_Port_Steps.Step_Write_Bytes,
   Micros        => Adaflight.Serial_Port_Steps.Step_Millis);
