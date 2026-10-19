with Interfaces;

package body Adaflight.CC2500 with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   FIFO_Register  : constant Byte := 16#3F#;
   PA_Table       : constant Byte := 16#3E#;
   Frequency_1    : constant Byte := 16#0E#;
   Reset_Value    : constant Byte := 16#C4#;
   Read_Single    : constant Byte := 16#80#;
   Write_Burst    : constant Byte := 16#40#;
   Read_Burst     : constant Byte := 16#C0#;
   Reset_Strobe   : constant Byte := 16#30#;
   Transmit       : constant Byte := 16#35#;
   Flush_Transmit : constant Byte := 16#3B#;
   Reset_Wait_Us  : constant := 1000;

   type Power_Table is array (0 .. Max_Power_Level) of Byte;

   Power_Values : constant Power_Table := (16#C5#, 16#97#, 16#6E#, 16#7F#, 16#A9#, 16#BB#, 16#FE#, 16#FF#);

   procedure Read_FIFO (D : in out Radio_Device; Data : out Byte_Array) is
   begin
      Bus_Read_Command_Multi (D, FIFO_Register or Read_Burst, Data);
   end Read_FIFO;

   procedure Write_FIFO (D : in out Radio_Device; Data : Byte_Array) is
   begin
      Strobe (D, Flush_Transmit);
      Bus_Write_Command_Multi (D, FIFO_Register or Write_Burst, Data);
      Strobe (D, Transmit);
   end Write_FIFO;

   procedure Read_Register_Multi (D : in out Radio_Device; Address : Byte; Data : out Byte_Array) is
   begin
      Bus_Read_Command_Multi (D, Address, Data);
   end Read_Register_Multi;

   procedure Write_Register_Multi (D : in out Radio_Device; Address : Byte; Data : Byte_Array) is
   begin
      Bus_Write_Command_Multi (D, Address, Data);
   end Write_Register_Multi;

   procedure Read_Register (D : in out Radio_Device; Register : Byte; Value : out Byte) is
   begin
      Bus_Read_Command (D, Register or Read_Single, Value);
   end Read_Register;

   procedure Strobe (D : in out Radio_Device; Command : Byte) is
   begin
      Bus_Write_Byte (D, Command);
   end Strobe;

   procedure Write_Register (D : in out Radio_Device; Address : Byte; Value : Byte) is
   begin
      Bus_Write_Command (D, Address, Value);
   end Write_Register;

   procedure Set_Power (D : in out Radio_Device; Power : Byte) is
      Level : constant Natural := Natural'Min (Natural (Power), Max_Power_Level);
   begin
      Write_Register (D, PA_Table, Power_Values (Level));
   end Set_Power;

   procedure Reset (D : in out Radio_Device; OK : out Boolean) is
      Value : Byte;
   begin
      Bus_DMA_Enable (D, False);
      Strobe (D, Reset_Strobe);
      Delay_Us (D, Reset_Wait_Us);
      Read_Register (D, Frequency_1, Value);
      OK := Value = Reset_Value;
   end Reset;

end Adaflight.CC2500;
