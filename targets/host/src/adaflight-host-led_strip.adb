--  The host's LED strip: the strip's pin takes its timer channel and stream
--  as on the board, and each change of a LED's color adds a line to the file
--  the environment variable ADAFLIGHT_LED_LOG names: the LED and its color as
--  six hexadecimal digits of red, green and blue.
with Ada.Environment_Variables;
with Ada.Text_IO;
with Interfaces;
with Adaflight.CLI_Resources;
with Adaflight.Color;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.LED_Strip is
   use Interfaces;
   use type Adaflight.Color.RGB;

   Configured : Boolean := False;
   Last       : Adaflight.LED_Strip.Led_Output := (others => (0, 0, 0));

   procedure Log (Line : String) is
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_LED_LOG", "adaflight-led.txt");
      File : Ada.Text_IO.File_Type;
   begin
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Name);
      exception
         when Ada.Text_IO.Name_Error =>
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
      end;
      Ada.Text_IO.Put_Line (File, Line);
      Ada.Text_IO.Close (File);
   end Log;

   function Hex (B : Unsigned_8) return String is
      Digits_Of : constant String := "0123456789ABCDEF";
   begin
      return Digits_Of (Natural (B / 16) + 1) & Digits_Of (Natural (B mod 16) + 1);
   end Hex;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      use Adaflight.STM32.Timers;
      Tag   : constant Unsigned_8 := C.Led_Strip_Config.Io_Tag;
      E     : Timer_Entry;
      Index : Natural;
      Found : Boolean;
   begin
      Configured := False;
      if Tag = 0 then
         return;
      end if;
      Allocate (Tag, Adaflight.CLI_Resources.LED_Strip, E, Index, Found);
      if Found and then Option_Of (Index) in 0 .. Options_Of (E.Timer, E.Channel)'Length - 1 then
         Configured := True;
         Last := (others => (0, 0, 0));
      end if;
   end Init;

   function Ready return Boolean is (Configured);
   function Stream_Number return Natural is (0);

   procedure Send (Colors : Adaflight.LED_Strip.Led_Output) is
   begin
      if not Configured then
         return;
      end if;
      for L in Colors'Range loop
         if Colors (L) /= Last (L) then
            Last (L) := Colors (L);
            Log ("led," & Natural'Image (L) (2 .. Natural'Image (L)'Last) & ","
                 & Hex (Colors (L).R) & Hex (Colors (L).G) & Hex (Colors (L).B));
         end if;
      end loop;
   end Send;
end Adaflight.STM32.LED_Strip;
