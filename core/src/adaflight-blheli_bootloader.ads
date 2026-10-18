--  The BLHeli bootloader protocol the 4-way interface speaks to an ESC over
--  its signal pin. The line is a software serial line of 52 microsecond bits
--  timed from the board's clock: a byte goes out as a high bit, a low start
--  bit, eight data bits from the lowest and a high stop bit, and comes in
--  sampled three quarters into its start bit and then once a bit. A buffer
--  goes out with a CRC-16 of polynomial 16#A001# while a device is
--  connected, and comes back with its check and an acknowledgement. The
--  commands connect with the boot message, keep the bootloader alive,
--  restart the ESC, and read, write, erase and verify its flash and EEPROM
--  at an address.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Four_Way;

generic
   type Line is limited private;
   with procedure Read_Micros (L : in out Line; Now : out Interfaces.Unsigned_32);
   with procedure Read_Millis (L : in out Line; Now : out Interfaces.Unsigned_32);
   with procedure Read_Pin (L : in out Line; ESC : Byte; High : out Boolean);
   with procedure Pin_Low (L : in out Line; ESC : Byte);
   with procedure Pin_High (L : in out Line; ESC : Byte);
   with procedure Pin_Input (L : in out Line; ESC : Byte);
   with procedure Pin_Output (L : in out Line; ESC : Byte);
package Adaflight.BLHeli_Bootloader with SPARK_Mode is
   use type Four_Way.Request_Kind;

   function Handles (Kind : Four_Way.Request_Kind) return Boolean is
     (Kind in Four_Way.BL_Connect | Four_Way.BL_Keep_Alive | Four_Way.BL_Restart | Four_Way.BL_Page_Erase
            | Four_Way.BL_Read_Flash | Four_Way.BL_Read_EEPROM | Four_Way.BL_Write_Flash
            | Four_Way.BL_Write_EEPROM | Four_Way.BL_Verify_Flash);

   --  One bootloader operation for the ESC the request names. Info is the
   --  interface's device information, which tells whether a device is
   --  connected; a connect or a restart changes it. Params holds the bytes a
   --  write or a verify sends and is the buffer a read fills. The code is 1
   --  for success and 0 for failure, and for a verify the bootloader's
   --  acknowledgement.
   procedure Perform
     (L      : in out Line;
      R      : Four_Way.Request;
      Info   : Four_Way.Device_Info;
      Params : Four_Way.Param_Buffer;
      Result : out Four_Way.Result)
     with Pre => Handles (R.Kind);

end Adaflight.BLHeli_Bootloader;
