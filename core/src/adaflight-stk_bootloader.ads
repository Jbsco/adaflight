--  The STK500v2 bootloader protocol the 4-way interface speaks to an Atmel
--  ESC over its signal pin. The line carries a pulse code: a one is a high
--  and a low of 64 microseconds each, a zero two highs and lows of 32. A
--  receiver times each bit from its call to the end of the next rising edge
--  and calls it a zero below a threshold it learns from the leader. A
--  message is a leader, a start byte, the sequence number, the length of
--  the body, a token, the body with the command and its status, and an XOR
--  check. The commands sign on, read the signature, erase the chip, set an
--  address, and read and program the flash and EEPROM.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Four_Way;

generic
   type Line is limited private;
   with procedure Read_Micros (L : in out Line; Now : out Interfaces.Unsigned_32);
   with procedure Delay_Micros (L : in out Line; Micros : Natural);
   with procedure Read_Pin (L : in out Line; ESC : Byte; High : out Boolean);
   with procedure Pin_Low (L : in out Line; ESC : Byte);
   with procedure Pin_High (L : in out Line; ESC : Byte);
   with procedure Pin_Input (L : in out Line; ESC : Byte);
   with procedure Pin_Output (L : in out Line; ESC : Byte);
package Adaflight.STK_Bootloader with SPARK_Mode is
   use type Four_Way.Request_Kind;

   --  What the protocol keeps between operations: the sequence number of
   --  the last message sent and the buffer the short replies land in.
   subtype In_Buffer_Index is Natural range 0 .. 15;
   type Link is record
      Sequence  : Byte := 0;
      In_Buffer : Byte_Array (In_Buffer_Index) := (others => 0);
   end record;

   function Handles (Kind : Four_Way.Request_Kind) return Boolean is
     (Kind in Four_Way.STK_Connect | Four_Way.STK_Sign_On | Four_Way.STK_Chip_Erase | Four_Way.STK_Read_Flash
            | Four_Way.STK_Read_EEPROM | Four_Way.STK_Write_Flash | Four_Way.STK_Write_EEPROM);

   --  One bootloader operation for the ESC the request names. Info is the
   --  interface's device information, whose first two bytes a connect sets
   --  to the signature. Params holds the bytes a write sends and is the
   --  buffer a read fills. The code is 1 for success and 0 for failure.
   procedure Perform
     (L      : in out Line;
      K      : in out Link;
      R      : Four_Way.Request;
      Info   : Four_Way.Device_Info;
      Params : Four_Way.Param_Buffer;
      Result : out Four_Way.Result)
     with Pre => Handles (R.Kind);

end Adaflight.STK_Bootloader;
