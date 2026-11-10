with Interfaces;

--  A client of the MSP protocol for a flight controller on a serial port or a TCP port.
package MSP with Pure, SPARK_Mode is

   subtype Byte is Interfaces.Unsigned_8;

   Max_Data : constant := 2 ** 16;
   subtype Data_Index is Natural range 0 .. Max_Data;
   type Byte_Array is array (Data_Index range <>) of Byte;

end MSP;
