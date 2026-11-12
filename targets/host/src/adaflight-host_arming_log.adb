with Ada.Environment_Variables;
with Ada.Text_IO;
with Adaflight.STM32.Pilot;
with Adaflight.STM32.Time;
package body Adaflight.Host_Arming_Log is

   Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_ARMING_LOG", "");
   Was  : Boolean := False;

   procedure Poll is
      Now  : constant Boolean := Adaflight.STM32.Pilot.Armed;
      File : Ada.Text_IO.File_Type;
   begin
      if Name'Length = 0 or else Now = Was then
         return;
      end if;
      Was := Now;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Name);
      exception
         when others =>
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
      end;
      Ada.Text_IO.Put_Line
        (File,
         Adaflight.STM32.Time.Millis'Image
         & (if Now then " armed" else " disarmed " & Adaflight.STM32.Pilot.Last_Disarm_Reason'Image));
      Ada.Text_IO.Close (File);
   exception
      when others =>
         null;
   end Poll;

end Adaflight.Host_Arming_Log;
