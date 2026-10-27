--  The host's pins: every output level kept with its rising edges, so a
--  model reads the select pin of its device, and the SD card detect pin
--  high while the environment names a card image in ADAFLIGHT_SD_IMAGE.
with Ada.Environment_Variables;
with Adaflight.Board;
with Adaflight.Host_Pins;
package body Adaflight.STM32.GPIO is
   Levels : array (Port_Name, Pin_Number) of Boolean := (others => (others => True));

   procedure Enable_Port (Port : Port_Name) is null;
   procedure Set_Output (P : Pin) is null;
   procedure Set_Open_Drain (P : Pin) is null;
   procedure Set_Input (P : Pin; Resistor : Pull := No_Pull) is null;
   procedure Set_Analog (P : Pin) is null;
   procedure Set_Alternate
     (P : Pin; Func : Alternate_Function; Resistor : Pull := No_Pull; Rate : Speed := High) is null;

   function Is_High (P : Pin) return Boolean is
   begin
      if P = Adaflight.Board.SDCARD_Detect_Pin then
         return Ada.Environment_Variables.Exists ("ADAFLIGHT_SD_IMAGE");
      end if;
      return Levels (P.Port, P.Number);
   end Is_High;

   procedure Set_High (P : Pin) is
   begin
      if not Levels (P.Port, P.Number) then
         Adaflight.Host_Pins.Rose (P);
      end if;
      Levels (P.Port, P.Number) := True;
   end Set_High;

   procedure Set_Low (P : Pin) is
   begin
      Levels (P.Port, P.Number) := False;
   end Set_Low;

   procedure Toggle (P : Pin) is
   begin
      if not Levels (P.Port, P.Number) then
         Adaflight.Host_Pins.Rose (P);
      end if;
      Levels (P.Port, P.Number) := not Levels (P.Port, P.Number);
   end Toggle;
end Adaflight.STM32.GPIO;
