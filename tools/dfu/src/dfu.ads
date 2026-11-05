with Interfaces;

--  USB DFU flashing of STM32 boards through their ROM bootloader.
package DFU with Pure, SPARK_Mode is

   subtype Byte is Interfaces.Unsigned_8;
   subtype Address is Interfaces.Unsigned_32;

   Max_Data : constant := 2 ** 24;
   subtype Data_Index is Natural range 0 .. Max_Data;
   type Byte_Array is array (Data_Index range <>) of Byte;

end DFU;
