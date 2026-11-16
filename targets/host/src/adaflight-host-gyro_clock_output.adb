--  The host's gyro clock output: no register written, and a line in the
--  file the environment variable ADAFLIGHT_GYRO_CLOCK_LOG names, when it
--  names one: the pin's port and number, the timer and channel by their
--  positions, the timer's clock, the period and the pulse.
with Ada.Environment_Variables;
with Ada.Text_IO;
with Adaflight.Pins;
package body Adaflight.STM32.Gyro_Clock_Output is
   function Image (N : Interfaces.Unsigned_32) return String is
     (Interfaces.Unsigned_32'Image (N) (2 .. Interfaces.Unsigned_32'Image (N)'Last));

   procedure Start
     (E : Adaflight.STM32.Timers.Timer_Entry; Timer_Hz : Interfaces.Unsigned_32; Period : Interfaces.Unsigned_16;
      Pulse : Interfaces.Unsigned_16)
   is
      use Adaflight.STM32.Timers;
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_GYRO_CLOCK_LOG", "");
      File : Ada.Text_IO.File_Type;
   begin
      if Name'Length = 0 then
         return;
      end if;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Name);
      exception
         when Ada.Text_IO.Name_Error =>
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
      end;
      Ada.Text_IO.Put_Line
        (File,
         "clock " & Image (Adaflight.Pins.Port_Name'Pos (E.Where.Port)) & " "
         & Image (Interfaces.Unsigned_32 (E.Where.Number)) & " " & Timer_Name'Image (E.Timer) & " "
         & Image (Interfaces.Unsigned_32 (E.Channel)) & " " & Image (Timer_Hz) & " "
         & Image (Interfaces.Unsigned_32 (Period)) & " " & Image (Interfaces.Unsigned_32 (Pulse)));
      Ada.Text_IO.Close (File);
   end Start;
end Adaflight.STM32.Gyro_Clock_Output;
