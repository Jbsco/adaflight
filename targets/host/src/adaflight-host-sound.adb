--  The host's beeper: no pin, and each change of its state as a line in the
--  file the environment variable ADAFLIGHT_BEEPER_LOG names: the time in
--  milliseconds, then one for on or zero for off. Nothing is written without
--  the variable.
with Ada.Environment_Variables;
with Ada.Text_IO;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Sound is
   Is_On : Boolean := False;

   procedure Init (P : Pin; Frequency : Interfaces.Unsigned_16; Inverted, Open_Drain : Boolean) is null;

   procedure Set (On : Boolean) is
      File : Ada.Text_IO.File_Type;
   begin
      if On = Is_On then
         return;
      end if;
      Is_On := On;
      if not Ada.Environment_Variables.Exists ("ADAFLIGHT_BEEPER_LOG") then
         return;
      end if;
      declare
         Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_BEEPER_LOG");
         Now  : constant String := Interfaces.Unsigned_32'Image (Adaflight.STM32.Time.Millis);
      begin
         begin
            Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Name);
         exception
            when Ada.Text_IO.Name_Error =>
               Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
         end;
         Ada.Text_IO.Put_Line (File, Now (2 .. Now'Last) & "," & (if On then "1" else "0"));
         Ada.Text_IO.Close (File);
      end;
   end Set;
end Adaflight.STM32.Sound;
