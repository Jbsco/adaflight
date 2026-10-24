--  A sonar's pins and echo interrupt as steps that do nothing, the shape the
--  HC-SR04 proof takes.
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Sensor_Bus_Steps; use Adaflight.Sensor_Bus_Steps;

package Adaflight.Sonar_Pin_Steps with SPARK_Mode is

   procedure Step_Pin_Owned (D : in out Bus_Line; Tag : Byte; Owned : out Boolean)
     with Global => null;

   procedure Step_Config_Pin (D : in out Bus_Line; Tag : Byte; Input : Boolean)
     with Global => null;

end Adaflight.Sonar_Pin_Steps;
