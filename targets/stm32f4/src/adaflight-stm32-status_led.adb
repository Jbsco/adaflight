with Interfaces;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.Status_LEDs;
with Adaflight.STM32.GPIO;
package body Adaflight.STM32.Status_LED is
   use type Interfaces.Unsigned_8;

   package Core renames Adaflight.Status_LEDs;
   package GPIO renames Adaflight.STM32.GPIO;

   State : Core.State;

   function Tagged_Pin (Tag : Interfaces.Unsigned_8) return Boolean is
     (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Interfaces.Unsigned_8) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   procedure Apply (X : Core.Op) is
   begin
      if not Tagged_Pin (X.Tag) then
         return;
      end if;
      case X.Kind is
         when Core.Nothing =>
            null;
         when Core.Claim =>
            GPIO.Enable_Port (Pin_Of (X.Tag).Port);
         when Core.Set_Output =>
            GPIO.Set_Output (Pin_Of (X.Tag));
         when Core.Write_Level =>
            if X.High then
               GPIO.Set_High (Pin_Of (X.Tag));
            else
               GPIO.Set_Low (Pin_Of (X.Tag));
            end if;
         when Core.Toggle_Pin =>
            GPIO.Toggle (Pin_Of (X.Tag));
      end case;
   end Apply;

   procedure Init (C : Adaflight.Config_Groups.Status_Led_Config_Record) is
      O : Core.Ops;
   begin
      Core.Init (State, (C.Io_Tags (0), C.Io_Tags (1), C.Io_Tags (2)), C.Inversion, O);
      for K in 1 .. O.Count loop
         Apply (O.List (K));
      end loop;
   end Init;

   procedure Set (LED : Integer; On : Boolean) is
   begin
      Apply (Core.Set (State, LED, On));
   end Set;

   procedure Toggle (LED : Integer) is
   begin
      Apply (Core.Toggle (State, LED));
   end Toggle;

   procedure Warn (Call : Adaflight.Warning_LED.LED_Call) is
   begin
      case Call is
         when Adaflight.Warning_LED.None =>
            null;
         when Adaflight.Warning_LED.Set_Off =>
            Set (0, False);
         when Adaflight.Warning_LED.Set_On =>
            Set (0, True);
         when Adaflight.Warning_LED.Toggle =>
            Toggle (0);
      end case;
   end Warn;
end Adaflight.STM32.Status_LED;
