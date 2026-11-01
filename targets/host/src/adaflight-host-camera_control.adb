--  The host's camera control: the pin's timer channel taken through the pin
--  map's owners as on the board, no register written, and each setup, key
--  press and return to idle as a line in the file the environment variable
--  ADAFLIGHT_CAMERA_LOG names: the mode, whether the control is on and its
--  period for a setup; the key code, hold, compare value or hi time, wait
--  and end time for a key press, without the board's blocking wait; and the
--  idle compare value when a press ends.
with Ada.Environment_Variables;
with Ada.Text_IO;
with Adaflight.CLI_Resources;
with Adaflight.Config_Runtime;
with Adaflight.STM32.Time;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.Camera_Control is
   package Core renames Adaflight.Camera_Control;
   use type Core.Mode;
   use type Interfaces.Unsigned_8;

   Settings : Core.Settings;
   State    : Core.State;

   function Image (N : Integer) return String is (Integer'Image (N) (2 .. Integer'Image (N)'Last));
   function Image_32 (N : Interfaces.Unsigned_32) return String is
     (Interfaces.Unsigned_32'Image (N) (2 .. Interfaces.Unsigned_32'Image (N)'Last));

   procedure Log (Line : String) is
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_CAMERA_LOG", "adaflight-camera.txt");
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
      Tag   : constant Interfaces.Unsigned_8 := C.Camera_Control_Config.Io_Tag;
      E     : Timer_Entry;
      Slot  : Natural;
      Found : Boolean := False;
   begin
      Settings := Adaflight.Config_Runtime.Camera_Control_Settings_Of (C.Camera_Control_Config);
      if Tag /= 0 and then Settings.Output = Core.Hardware_PWM then
         Allocate (Tag, Adaflight.CLI_Resources.Camera_Control, E, Slot, Found);
      end if;
      Core.Init (State, Settings, Has_Pin => Tag /= 0, Timer_Found => Found);
      Log ("setup," & Image (Core.Mode'Pos (Settings.Output)) & "," & Image (Boolean'Pos (State.Enabled)) & ","
           & Image (State.Period));
   end Init;

   function Enabled return Boolean is (State.Enabled);

   procedure Key_Press
     (Code : Interfaces.Unsigned_8; Hold_Ms : Adaflight.Camera_Control.Hold_Time; OSD_Reset : out Boolean)
   is
      P : Core.Press;
   begin
      Core.Key_Press (State, Settings, Code, Hold_Ms, Adaflight.STM32.Time.Millis, P);
      OSD_Reset := P.OSD_Reset;
      if P.Taken then
         Log ("key," & Image (Integer (Code)) & "," & Image (Hold_Ms) & ","
              & Image (if State.Output = Core.Hardware_PWM then State.Pulse else P.Hi_Time) & ","
              & Image (P.Wait_Ms) & "," & Image_32 (State.End_Ms));
      end if;
   end Key_Press;

   procedure Process (Now_Us : Adaflight.Scheduler.Time_Us) is
      Idle : Boolean;
   begin
      Core.Process (State, Now_Us, Idle);
      if Idle then
         Log ("idle," & Image (State.Pulse));
      end if;
   end Process;

end Adaflight.STM32.Camera_Control;
