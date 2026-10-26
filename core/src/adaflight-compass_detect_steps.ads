--  A compass's bus type, interrupt pin, MPU slave bus, DroneCAN stack and chip
--  detection as steps that do nothing, the shape the compass detection's proof
--  takes.
with Adaflight.Compass_Detect;
with Adaflight.Sensor_Bus_Steps;

package Adaflight.Compass_Detect_Steps with SPARK_Mode is

   subtype Byte is Adaflight.Compass_Detect.Byte;

   function Step_Bus_Type (D : Adaflight.Sensor_Bus_Steps.Bus_Line) return Byte
     with Global => null;

   procedure Step_Set_Interrupt_Pin (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Tag : Byte)
     with Global => null;

   procedure Step_Set_MPU_Slave (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Address : Byte)
     with Global => null;

   procedure Step_Set_Bus_Type (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Bus : Byte)
     with Global => null;

   procedure Step_Detect_DroneCAN (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Found : out Boolean)
     with Global => null;

   procedure Step_Detect_Chip
     (D : in out Adaflight.Sensor_Bus_Steps.Bus_Line; Chip : Adaflight.Compass_Detect.Driver; Found : out Boolean)
     with Global => null;

end Adaflight.Compass_Detect_Steps;
