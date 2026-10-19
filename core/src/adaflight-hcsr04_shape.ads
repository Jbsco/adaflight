pragma SPARK_Mode (On);
--  The HC-SR04 rangefinder over pins that do nothing, the shape the proof
--  covers.
with Adaflight.HCSR04;
with Adaflight.Baro_Pin_Steps;
with Adaflight.Sensor_Bus_Steps;
with Adaflight.Sonar_Pin_Steps;

package Adaflight.HCSR04_Shape is new Adaflight.HCSR04
  (Pin_Device       => Adaflight.Sensor_Bus_Steps.Bus_Line,
   Pin_Owned        => Adaflight.Sonar_Pin_Steps.Step_Pin_Owned,
   Init_Pin         => Adaflight.Baro_Pin_Steps.Step_Init_Pin,
   Config_Pin       => Adaflight.Sonar_Pin_Steps.Step_Config_Pin,
   Pin_High         => Adaflight.Baro_Pin_Steps.Step_Pin_High,
   Pin_Low          => Adaflight.Baro_Pin_Steps.Step_Pin_Low,
   Read_Pin         => Adaflight.Baro_Pin_Steps.Step_Read_Pin,
   Release_Pin      => Adaflight.Baro_Pin_Steps.Step_Release_Pin,
   Interrupt_Init   => Adaflight.Baro_Pin_Steps.Step_Interrupt_Init,
   Interrupt_Config => Adaflight.Baro_Pin_Steps.Step_Interrupt_Pin,
   Interrupt_Enable => Adaflight.Baro_Pin_Steps.Step_Interrupt_Pin,
   Delay_Ms         => Adaflight.Sensor_Bus_Steps.Step_Delay_Ms,
   Delay_Us         => Adaflight.Sensor_Bus_Steps.Step_Delay_Us,
   Millis           => Adaflight.Sensor_Bus_Steps.Step_Millis);
