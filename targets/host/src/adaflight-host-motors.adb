--  The host's motor outputs: the DShot protocols drive the mix's motors
--  when each motor's pin has a timer channel with a DMA option, which the
--  motor holds against other outputs as on the board, so the image runs the
--  board's motor path, and a frame has no hardware to reach. Each frame of a DShot command, a value from 1 to 47,
--  that the transfers send adds a line of the motor, the value and the
--  telemetry request to the file the environment variable
--  ADAFLIGHT_DSHOT_LOG names.
with Ada.Environment_Variables;
with Ada.Text_IO;
with Adaflight.Board;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.Motors is
   Driven : Natural range 0 .. 8 := 0;
   Is_On  : Boolean := False;
   Kind   : Adaflight.MSP_Motor_In.Device_Kind := Adaflight.MSP_Motor_In.No_Device;

   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural) is
      use Adaflight.STM32.Timers;
   begin
      Driven := 0;
      Kind := Adaflight.MSP_Motor_In.No_Device;
      if C.Motor_Config.Dev.Motor_Protocol not in 5 .. 7 then
         return;
      end if;
      for M in 0 .. Natural'Min (Count, 8) - 1 loop
         declare
            Order : constant Natural := Natural (C.Motor_Config.Dev.Motor_Output_Reordering (M)) mod 8;
            E     : Timer_Entry;
            Index : Natural;
            Found : Boolean;
         begin
            Allocate (C.Motor_Config.Dev.Io_Tags (Order), Motor, E, Index, Found);
            if not Found or else Adaflight.Board.Timer_Map (Index).DMA_Option < 0 then
               Driven := 0;
               return;
            end if;
            Driven := M + 1;
         end;
      end loop;
      Kind := (if Driven > 0 then Adaflight.MSP_Motor_In.DShot else Adaflight.MSP_Motor_In.No_Device);
   end Init;

   procedure Enable is
   begin
      Is_On := Driven > 0;
   end Enable;

   procedure Hold_Idle is null;

   procedure Disable is
   begin
      Is_On := False;
   end Disable;

   function Enabled return Boolean is (Is_On);

   function Motor_Enabled (Index : Natural) return Boolean is (Index < Driven);

   --  The host's motors use no DMA streams.
   function Stream_Of (Index : Natural) return Natural is
      pragma Unreferenced (Index);
   begin
      return 0;
   end Stream_Of;

   function Count return Natural is (Driven);

   function Device return Adaflight.MSP_Motor_In.Device_Kind is (Kind);

   --  Each motor's frame loaded since the last transfers.
   type Frame is record
      Loaded  : Boolean := False;
      Value   : Natural := 0;
      Request : Boolean := False;
   end record;
   Frames : array (0 .. 7) of Frame;

   procedure Send_Frame (Index : Natural; Value : Interfaces.Unsigned_16; Request : Boolean) is
   begin
      if Index <= Frames'Last then
         Frames (Index) := (Loaded => True, Value => Natural (Value), Request => Request);
      end if;
   end Send_Frame;

   function Image (N : Natural) return String is
     (Natural'Image (N) (2 .. Natural'Image (N)'Last));

   procedure Start_Transfers is
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_DSHOT_LOG", "adaflight-dshot.txt");
      File : Ada.Text_IO.File_Type;
   begin
      for M in Frames'Range loop
         if Frames (M).Loaded and then Frames (M).Value in 1 .. 47 then
            begin
               Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Name);
            exception
               when Ada.Text_IO.Name_Error =>
                  Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
            end;
            Ada.Text_IO.Put_Line
              (File, Image (M) & "," & Image (Frames (M).Value) & "," & (if Frames (M).Request then "1" else "0"));
            Ada.Text_IO.Close (File);
         end if;
         Frames (M).Loaded := False;
      end loop;
   end Start_Transfers;
end Adaflight.STM32.Motors;
