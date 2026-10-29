--  The I2C buses as masters at 400 kHz, for the register devices on them:
--  a bus started on its pins, a register read of a device as one write of
--  the register and one read of the bytes, and a register write as one
--  write of two bytes, each failed by a missing acknowledge or a bus that
--  does not finish in time.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins;
package Adaflight.STM32.I2C is
   type Bus is (I2C1, I2C2, I2C3, I2C4);
   Speed_KHz : constant := 400;
   procedure Init (B : Bus; SCL, SDA : Adaflight.Pins.Pin);
   function Started (B : Bus) return Boolean;
   --  Data'Length bytes from the device's register, OK when every byte was
   --  acknowledged and the transfer finished.
   procedure Read (B : Bus; Address : Byte; Register : Byte; Data : out Byte_Array; OK : out Boolean)
     with Pre => Data'Length in 1 .. 255;
   procedure Write (B : Bus; Address : Byte; Register : Byte; Value : Byte; OK : out Boolean);
   --  The time a transfer may take before it counts as failed.
   Timeout_Us : constant Interfaces.Unsigned_32 := 25_000;
end Adaflight.STM32.I2C;
