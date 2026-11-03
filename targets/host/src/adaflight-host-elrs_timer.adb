--  The host drives no ExpressLRS timer: its start fails.
package body Adaflight.STM32.ELRS_Timer is

   procedure Init (Number : Natural; H : Handler; Ok : out Boolean) is
      pragma Unreferenced (Number, H);
   begin
      Ok := False;
   end Init;

   procedure Set_Time_Base (Max_Period : Natural) is null;

   procedure Set_Period (Period : Interfaces.Unsigned_32) is null;

   procedure Reset_Counter is null;

   procedure Set_Running (Running : Boolean) is null;

   procedure Enable_Interrupt is null;

end Adaflight.STM32.ELRS_Timer;
