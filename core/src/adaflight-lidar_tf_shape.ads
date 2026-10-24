pragma SPARK_Mode (On);
--  The TF rangefinder driver over a port that does nothing, the shape the
--  proof covers.
with Adaflight.Lidar_TF;
with Adaflight.Serial_Port_Steps;

package Adaflight.Lidar_TF_Shape is new Adaflight.Lidar_TF
  (Serial_Device => Adaflight.Serial_Port_Steps.Port_Line,
   Open_Port     => Adaflight.Serial_Port_Steps.Step_Open_Port,
   Bytes_Waiting => Adaflight.Serial_Port_Steps.Step_Bytes_Waiting,
   Read_Byte     => Adaflight.Serial_Port_Steps.Step_Read_Byte,
   Write_Bytes   => Adaflight.Serial_Port_Steps.Step_Write_Bytes,
   Millis        => Adaflight.Serial_Port_Steps.Step_Millis);
