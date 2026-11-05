--  The flight log of a build without one: no device, no log step and no end of a log.
package body Adaflight.STM32.Blackbox is
   use type Interfaces.Integer_32;

   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Loop_Time : Adaflight.Blackbox.Loop_Time_Us) is null;

   function Device_Set return Boolean is (False);

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (False);

   procedure Set_Facts (F : Facts) is null;

   function Needs_Info return Boolean is (False);

   procedure Set_Info (I : Adaflight.Blackbox_Header.Sysinfo) is null;

   procedure Update is null;

   procedure Disarmed (Reason : Adaflight.Arming.Disarm_Reason; Now_Us, Now_Ms : Interfaces.Unsigned_32) is null;

   function Recorder return Adaflight.Blackbox.Recorder is
   begin
      return R : Adaflight.Blackbox.Recorder;
   end Recorder;

   procedure Device_State (Working, Full : out Boolean; Log_Number : out Interfaces.Integer_32) is
   begin
      Working := False;
      Full := False;
      Log_Number := -1;
   end Device_State;

end Adaflight.STM32.Blackbox;
