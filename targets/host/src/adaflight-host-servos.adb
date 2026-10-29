--  The host's servo outputs: each servo with a pin takes its timer channel
--  through the pin map's owners as on the board, and the first servo
--  refused ends the setup. Each output's setup and each change of its pulse
--  add a line to the file the environment variable ADAFLIGHT_SERVO_LOG
--  names: the servo, its period and its center pulse for a setup, and the
--  servo and the compare register's value for a change.
with Ada.Environment_Variables;
with Ada.Text_IO;
with Interfaces;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.Servos is
   use Interfaces;
   Configured : array (0 .. Max_Servos - 1) of Boolean := (others => False);
   Pulses     : array (0 .. Max_Servos - 1) of Unsigned_32 := (others => 0);

   function Image (N : Unsigned_32) return String is
     (Unsigned_32'Image (N) (2 .. Unsigned_32'Image (N)'Last));

   procedure Log (Line : String) is
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_SERVO_LOG", "adaflight-servo.txt");
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

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      use Adaflight.STM32.Timers;
      Dev : Adaflight.Config_Groups.Servo_Dev_Config_Record renames C.Servo_Config.Dev;
   begin
      for N in 0 .. Max_Servos - 1 loop
         if Dev.Io_Tags (N) /= 0 then
            declare
               E     : Timer_Entry;
               Index : Natural;
               Found : Boolean;
            begin
               Allocate (Dev.Io_Tags (N), Servo, E, Index, Found);
               exit when not Found;
               Configured (N) := True;
               Pulses (N) := 0;
               Log ("setup," & Image (Unsigned_32 (N)) & ","
                    & Image (Unsigned_32 (Adaflight.PWM_Output.Servo_Period (Dev.Servo_Pwm_Rate))) & ","
                    & Image (Unsigned_32 (Dev.Servo_Center_Pulse)));
            end;
         end if;
      end loop;
   end Init;

   procedure Write (Index : Natural; Value : Float) is
   begin
      if Index < Max_Servos
        and then Configured (Index)
        and then Adaflight.PWM_Output.Servo_Pulse (Held (Value)) /= Pulses (Index)
      then
         Pulses (Index) := Adaflight.PWM_Output.Servo_Pulse (Held (Value));
         Log ("pulse," & Image (Unsigned_32 (Index)) & "," & Image (Pulses (Index)));
      end if;
   end Write;
end Adaflight.STM32.Servos;
