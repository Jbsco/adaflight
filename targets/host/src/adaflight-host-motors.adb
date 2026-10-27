--  The host's motor outputs: the DShot protocols drive every motor of the
--  mix, so the image runs the board's motor path, and a write has no
--  hardware to reach.
package body Adaflight.STM32.Motors is
   Driven : Natural range 0 .. 8 := 0;
   Is_On  : Boolean := False;
   Kind   : Adaflight.MSP_Motor_In.Device_Kind := Adaflight.MSP_Motor_In.No_Device;

   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural) is
   begin
      Driven := (if C.Motor_Config.Dev.Motor_Protocol in 5 .. 7 then Natural'Min (Count, 8) else 0);
      Kind := (if Driven > 0 then Adaflight.MSP_Motor_In.DShot else Adaflight.MSP_Motor_In.No_Device);
   end Init;

   procedure Enable is
   begin
      Is_On := Driven > 0;
   end Enable;

   function Enabled return Boolean is (Is_On);

   function Motor_Enabled (Index : Natural) return Boolean is (Index < Driven);

   function Count return Natural is (Driven);

   function Device return Adaflight.MSP_Motor_In.Device_Kind is (Kind);

   procedure Write_All (Values : Adaflight.Mixer.Motor_Outputs) is
      pragma Unreferenced (Values);
   begin
      null;
   end Write_All;
end Adaflight.STM32.Motors;
