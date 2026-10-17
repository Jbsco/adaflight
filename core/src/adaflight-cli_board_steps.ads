--  The board's DShot programming as units that do nothing, the shapes the
--  command line's proof takes.
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

end Adaflight.CLI_Board_Steps;
