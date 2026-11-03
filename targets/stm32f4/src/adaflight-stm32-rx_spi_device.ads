--  The SPI receiver's chip on its bus: the select pin and bus the
--  configuration names, mode 0 at 13.5 MHz, or 6.5 MHz during start-up, and
--  the interrupt line whose rising edges record their time and call the
--  edge handler set.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups;
package Adaflight.STM32.RX_SPI_Device is
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  The select pin pulled up and high before the buses start.
   procedure Preinit (C : Adaflight.Config_Groups.Rx_Spi_Config_Record);
   --  The bus and the select pin; false when the configuration names no
   --  started bus.
   procedure Init (C : Adaflight.Config_Groups.Rx_Spi_Config_Record; Ok : out Boolean);

   procedure Set_Normal_Speed (Hz : Unsigned_32);
   procedure Normal_Speed;
   procedure Startup_Speed;

   function Exti_Configured return Boolean;
   --  The line armed on its rising edge with the pin pulled down or
   --  floating, and a pin already high taken as an edge.
   procedure Exti_Init (Pull_Down : Boolean);
   function Exti_State return Boolean;
   function Poll_Exti return Boolean;
   procedure Reset_Exti;
   function Last_Exti_Time return Unsigned_32;
   type Edge_Handler is access procedure;
   procedure Set_Edge_Handler (H : Edge_Handler);
   --  One selection each: the bytes exchanged in place, sent, a head sent
   --  then a tail exchanged in place, and a head and a tail sent.
   procedure Exchange (Data : in out Byte_Array)
     with Pre => Data'Length < Max_Buffer;
   procedure Send (Data : Byte_Array)
     with Pre => Data'Length < Max_Buffer;
   procedure Exchange_Pair (Head : Byte_Array; Tail : in out Byte_Array)
     with Pre => Head'Length + Tail'Length < Max_Buffer;
   procedure Send_Pair (Head : Byte_Array; Tail : Byte_Array)
     with Pre => Head'Length + Tail'Length < Max_Buffer;

   procedure Write_Byte (Data : Byte);
   procedure Write_Command (Command : Byte; Data : Byte);
   procedure Write_Command_Multi (Command : Byte; Data : Byte_Array)
     with Pre => Data'Length < Max_Buffer;
   procedure Read_Command (Command : Byte; Value : out Byte);
   procedure Read_Command_Multi (Command : Byte; Data : out Byte_Array)
     with Pre => Data'Length < Max_Buffer;
end Adaflight.STM32.RX_SPI_Device;
