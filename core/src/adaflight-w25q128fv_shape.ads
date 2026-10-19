pragma SPARK_Mode (On);
--  The W25Q128FV driver over a quad SPI controller that does nothing, the
--  shape the proof covers.
with Adaflight.Flash_Device.W25Q128FV;
with Adaflight.Quad_Bus_Steps;

package Adaflight.W25Q128FV_Shape is new Adaflight.Flash_Device.W25Q128FV
  (Quad_Device              => Adaflight.Quad_Bus_Steps.Quad_Line,
   Transmit                 => Adaflight.Quad_Bus_Steps.Step_Transmit,
   Receive                  => Adaflight.Quad_Bus_Steps.Step_Receive,
   Instruction_With_Address => Adaflight.Quad_Bus_Steps.Step_Instruction_With_Address,
   Receive_With_Address     => Adaflight.Quad_Bus_Steps.Step_Receive_With_Address,
   Run                      => Adaflight.Quad_Bus_Steps.Step_Run,
   Wait                     => Adaflight.Quad_Bus_Steps.Step_Wait,
   Millis                   => Adaflight.Quad_Bus_Steps.Step_Millis,
   Report_Written           => Adaflight.Quad_Bus_Steps.Step_Report_Written);
