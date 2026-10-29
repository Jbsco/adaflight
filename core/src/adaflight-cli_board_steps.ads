--  The board's DShot programming, passthrough starts, gyro register reads,
--  flash tools and serial passthrough ports as units that do nothing, the
--  shapes the command line's proof takes.
with Interfaces;
with Adaflight.ESC_Info;

package Adaflight.CLI_Board_Steps with SPARK_Mode is

   procedure DShot_Write (Index : Natural; Motors : Natural; Command : Interfaces.Unsigned_8)
     with Global => null;

   procedure Motors_Disable
     with Global => null;

   procedure Motors_Enable
     with Global => null;

   procedure ESC_Read_Start
     with Global => null;

   procedure ESC_Read_Bytes (F : out ESC_Info.Frame; Count : out Natural)
     with Global => null;

   procedure Delay_Ms (Ms : Natural)
     with Global => null;

   procedure ESC_Passthrough (Index : Natural; Protocol : Interfaces.Unsigned_8; Started : out Boolean)
     with Global => null;

   procedure GPS_Passthrough (Started : out Boolean)
     with Global => null;

   procedure Gyro_Read_Register (Gyro : Natural; Register : Interfaces.Unsigned_8; Value : out Interfaces.Unsigned_8)
     with Global => null;

   function Flash_Supported return Boolean is (False)
     with Global => null;

   procedure Flash_Erase_Completely
     with Global => null;

   procedure Flash_Ready (Ready : out Boolean)
     with Global => null;

   procedure Flash_Erase_Async
     with Global => null;

   procedure Flash_Verify (OK : out Boolean)
     with Global => null;

   procedure Flash_Seek (Address : Interfaces.Unsigned_32)
     with Global => null;

   procedure Flash_Write (Data : String)
     with Global => null;

   procedure Flash_Flush
     with Global => null;

   procedure Flash_Read (Address : Interfaces.Unsigned_32; Length : Natural; Data : out String; Count : out Natural)
     with Global => null;

   procedure Port_State
     (Id : Interfaces.Integer_32; Open : out Boolean; Baud : out Interfaces.Unsigned_32;
      Mode : out Interfaces.Unsigned_8; Options : out Interfaces.Unsigned_32; Callback : out Boolean)
     with Global => null;

   procedure Port_Open
     (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32; Mode : Interfaces.Unsigned_8;
      Options : Interfaces.Unsigned_32; Opened : out Boolean)
     with Global => null;

   procedure Port_Set_Baud (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32) is null;

   procedure Port_Set_Mode (Id : Interfaces.Integer_32; Mode : Interfaces.Unsigned_8) is null;

   procedure Port_Remove_Callback (Id : Interfaces.Integer_32) is null;

   procedure Port_Baud_From_USB (USB : Interfaces.Integer_32; Target : Interfaces.Integer_32) is null;

   procedure Port_DTR_Reset (USB : Interfaces.Integer_32) is null;

   procedure Port_DTR_PINIO (USB : Interfaces.Integer_32; PINIO : Natural) is null;

   procedure ESC_Sensor_Pins_Idle is null;

   procedure Port_Forward (Left : Interfaces.Integer_32; Right : Interfaces.Integer_32) is null;

end Adaflight.CLI_Board_Steps;
