--  The MS4525DO differential pressure sensor: a register-less I2C device
--  whose four byte read holds two status bits and a 14 bit pressure count,
--  then an 11 bit temperature count; the count scales over 10 to 90 percent
--  of its range to -1 to +1 psi, in pascals, and the temperature to kelvin.
--  A stale or faulted status voids the frame. The bus stays with the target.
with Interfaces;
with Adaflight.Bytes;
package Adaflight.MS4525 with SPARK_Mode is
   Default_Address : constant Interfaces.Unsigned_8 := 16#28#;
   Frame_Length    : constant := 4;

   subtype Frame is Adaflight.Bytes.Byte_Array (0 .. Frame_Length - 1);
   subtype Pressure_Pa is Float range -1.0e4 .. 1.0e4;
   subtype Kelvin is Float range 200.0 .. 500.0;

   --  The frame decoded: Valid for a fresh status, with the differential
   --  pressure and the temperature in the reference's single precision order.
   procedure Decode (F : Frame; Valid : out Boolean; Pressure : out Pressure_Pa; Temperature : out Kelvin);
end Adaflight.MS4525;
