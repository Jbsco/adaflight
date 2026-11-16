with Adaflight.CLI_Resources;
with Adaflight.STM32.Gyro_Clock_Output;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.Gyro_Clock is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   Pin_Tag     : Interfaces.Unsigned_8 := 0;
   Running     : Boolean := False;
   Running_Tag : Interfaces.Unsigned_8 := 0;

   procedure Set_Pin (Tag : Interfaces.Unsigned_8) is
   begin
      Pin_Tag := Tag;
   end Set_Pin;

   procedure Start (Ordinal : Positive; Started : out Boolean) is
      use Adaflight.STM32.Timers;
      E      : Timer_Entry;
      Slot   : Natural;
      Found  : Boolean;
      Period : Interfaces.Unsigned_32;
   begin
      if Running then
         Started := Running_Tag = Pin_Tag;
         return;
      end if;
      Started := False;
      if Pin_Tag = 0 then
         return;
      end if;
      Allocate (Pin_Tag, Adaflight.CLI_Resources.Gyro_Clkin, E, Slot, Found, Ordinal => Ordinal);
      if not Found then
         return;
      end if;
      Period := Timer_Clock_Hz (E.Timer) / Clock_Hz;
      if Period not in 2 .. 65_535 then
         return;
      end if;
      Adaflight.STM32.Gyro_Clock_Output.Start
        (E, Timer_Clock_Hz (E.Timer), Interfaces.Unsigned_16 (Period), Interfaces.Unsigned_16 (Period / 2));
      Running_Tag := Pin_Tag;
      Running := True;
      Started := True;
   end Start;
end Adaflight.STM32.Gyro_Clock;
