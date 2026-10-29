--  The F4 crate drives no I2C bus yet: no bus starts, and every transfer
--  fails, so a device configured on one is not found.
package body Adaflight.STM32.I2C is
   procedure Init (B : Bus; SCL, SDA : Adaflight.Pins.Pin) is null;
   function Started (B : Bus) return Boolean is (False);
   procedure Read (B : Bus; Address : Byte; Register : Byte; Data : out Byte_Array; OK : out Boolean) is
   begin
      Data := (others => 0);
      OK := False;
   end Read;
   procedure Write (B : Bus; Address : Byte; Register : Byte; Value : Byte; OK : out Boolean) is
   begin
      OK := False;
   end Write;
end Adaflight.STM32.I2C;
