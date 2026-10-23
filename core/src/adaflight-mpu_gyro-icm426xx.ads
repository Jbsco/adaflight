--  The ICM-42605, ICM-42622-P, ICM-42686-P, ICM-42688-P, IIM-42652 and
--  IIM-42653 gyros over the SPI gyro layer. Detection resets the chip, wakes
--  it and reads its identity up to 21 times, 1 ms apart; a found ICM-42688-P
--  takes the external clock on builds with a clock input. Initialization sets
--  a 24 MHz clock, runs the layer's with the chip's data registers, turns the
--  sensors off, writes the anti-alias filters of the gyro, from the filter
--  setting, and of the accelerometer, the user interface filters, the data
--  ready interrupt and its pulse, disables the AFSR, turns the sensors on and
--  sets the ranges and the output data rate from the sample rate divider.
generic
   External_Clock : Boolean;
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Start_Clock_In (D : in out SPI_Device; Started : out Boolean);
package Adaflight.MPU_Gyro.ICM426xx with SPARK_Mode is

   Sensor_ICM42605  : constant Byte := 12;
   Sensor_ICM42622P : constant Byte := 13;
   Sensor_ICM42686P : constant Byte := 14;
   Sensor_ICM42688P : constant Byte := 15;
   Sensor_IIM42652  : constant Byte := 16;
   Sensor_IIM42653  : constant Byte := 17;

   function Is_ICM426xx (Sensor : Byte) return Boolean is (Sensor in Sensor_ICM42605 .. Sensor_IIM42653);

   --  The chip probe of the layer's detection.
   procedure Detect (D : in out SPI_Device; Sensor : out Byte);

   --  The gyro's scale with the chip's temperature scale and zero.
   procedure Gyro_Detect (S : in out State; Found : out Boolean; Scale : out Float);

   function Acc_Detect (S : State) return Boolean is (Is_ICM426xx (S.Sensor));

   --  The accelerometer's one g: 1024 for the 32 g IIM-42653, else 2048.
   function Acc_One_G (S : State) return Interfaces.Unsigned_16 is
     (if S.Sensor = Sensor_IIM42653 then 1024 else 2048);

   --  The filter setting is the gyro configuration's.
   procedure Gyro_Init
     (D             : in out SPI_Device;
      S             : in out State;
      Filter        : Byte;
      Divider_Drops : Byte);

end Adaflight.MPU_Gyro.ICM426xx;
