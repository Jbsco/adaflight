pragma SPARK_Mode (On);
--  The Nooploop rangefinder driver over a port that does nothing, the shape
--  the proof covers.
with Adaflight.Nooploop;
with Adaflight.Serial_Port_Steps;

package Adaflight.Nooploop_Shape is new Adaflight.Nooploop
  (Serial_Device => Adaflight.Serial_Port_Steps.Port_Line,
   Open_Port     => Adaflight.Serial_Port_Steps.Step_Open_Port,
   Bytes_Waiting => Adaflight.Serial_Port_Steps.Step_Bytes_Waiting,
   Read_Byte     => Adaflight.Serial_Port_Steps.Step_Read_Byte,
   Millis        => Adaflight.Serial_Port_Steps.Step_Millis);
