--  The host's motor outputs: the DShot protocols drive the mix's motors
--  when each motor's pin has a timer channel with a DMA option, and the
--  analog protocols when each has a timer channel, which the motor holds
--  against other outputs as on the board, so the image runs the board's
--  motor path, and a frame or a pulse has no hardware to reach. Each
--  analog motor's setup and each change of its pulse add a line to the
--  file the environment variable ADAFLIGHT_PWM_LOG names: the motor, its
--  counting rate, its period and its idle pulse for a setup, and the motor
--  and the compare register's value for a change. Each frame of a DShot command, a value from 1 to 47,
--  that the transfers send adds a line of the motor, the value and the
--  telemetry request to the file the environment variable
--  ADAFLIGHT_DSHOT_LOG names. With bidirectional DShot set, each motor answers
--  its frame with a reply the transfers capture at the timer's sixteen
--  counts a bit: zero eRPM below the first throttle value, else an eRPM
--  thirty times the throttle value above it.
with Ada.Environment_Variables;
with Ada.Text_IO;
with Adaflight.CLI_Resources;
with Adaflight.PWM_Output;
with Adaflight.STM32.Time;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.Motors is
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   Driven : Natural range 0 .. 8 := 0;
   Is_On  : Boolean := False;
   Bidir  : Boolean := False;
   Deadtime_Us : Interfaces.Integer_32 := 0;
   Kind   : Adaflight.MSP_Motor_In.Device_Kind := Adaflight.MSP_Motor_In.No_Device;

   function Telemetry_Configured (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (C.Motor_Config.Dev.Use_Dshot_Telemetry /= 0 and then C.Motor_Config.Dev.Motor_Protocol in 5 .. 7);

   function Image (N : Interfaces.Unsigned_32) return String is
     (Interfaces.Unsigned_32'Image (N) (2 .. Interfaces.Unsigned_32'Image (N)'Last));

   procedure Log (Line : String) is
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_PWM_LOG", "adaflight-pwm.txt");
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

   --  Each analog motor's timing and the last pulse it logged.
   Timings : array (0 .. 7) of Adaflight.PWM_Output.Motor_Timing;
   Pulses  : array (0 .. 7) of Interfaces.Unsigned_32 := (others => 0);

   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural; Three_D : Boolean) is
      use Adaflight.STM32.Timers;
      Dev    : Adaflight.Config_Groups.Motor_Dev_Config_Record renames C.Motor_Config.Dev;
      Analog : constant Boolean := Dev.Motor_Protocol in Adaflight.PWM_Output.Protocol;
      Idle   : constant Interfaces.Unsigned_16 :=
        (if Three_D then C.Flight3_D_Config.Neutral3d else C.Motor_Config.Mincommand);
   begin
      Driven := 0;
      Bidir := Telemetry_Configured (C);
      Kind := Adaflight.MSP_Motor_In.No_Device;
      if not Analog and then Dev.Motor_Protocol not in 5 .. 7 then
         return;
      end if;
      for M in 0 .. Natural'Min (Count, 8) - 1 loop
         declare
            Order : constant Natural := Natural (Dev.Motor_Output_Reordering (M)) mod 8;
            E     : Timer_Entry;
            Index : Natural;
            Found : Boolean;
         begin
            Allocate (Dev.Io_Tags (Order), Adaflight.CLI_Resources.Motor, E, Index, Found, Ordinal => Order + 1);
            if not Found or else (not Analog and then Option_Of (Index) < 0) then
               Driven := 0;
               return;
            end if;
            if Analog then
               Timings (M) := Adaflight.PWM_Output.Motor_Timing_Of
                 (Dev.Motor_Protocol, Dev.Motor_Pwm_Rate, Dev.Use_Continuous_Update /= 0, Timer_Clock_Hz (E.Timer),
                  Idle);
               Pulses (M) := 0;
               Log ("setup," & Image (Interfaces.Unsigned_32 (M)) & "," & Image (Timings (M).Hz) & ","
                    & Image (Interfaces.Unsigned_32 (Adaflight.PWM_Output.Period_Of (Timings (M)))) & ","
                    & Image (Interfaces.Unsigned_32 (Timings (M).Idle)));
            end if;
            Driven := M + 1;
         end;
      end loop;
      Kind :=
        (if Driven = 0 then Adaflight.MSP_Motor_In.No_Device
         elsif Analog then Adaflight.MSP_Motor_In.PWM
         else Adaflight.MSP_Motor_In.DShot);
      Deadtime_Us := 35 + Interfaces.Integer_32
        (Interfaces.Unsigned_32'(320_000_000)
         / (case Dev.Motor_Protocol is when 5 => 3_000_000, when 6 => 6_000_000, when others => 12_000_000));
   end Init;

   procedure Shutdown is
   begin
      Is_On := False;
   end Shutdown;

   procedure Write_Pulse (Index : Natural; Value : Float) is
   begin
      if Index < Driven then
         declare
            P : constant Interfaces.Unsigned_32 := Adaflight.PWM_Output.Motor_Pulse
              (Timings (Index), Float'Max (Adaflight.PWM_Output.Write_Value'First,
                                           Float'Min (Adaflight.PWM_Output.Write_Value'Last, Value)));
         begin
            if P /= Pulses (Index) then
               Pulses (Index) := P;
               Log ("pulse," & Image (Interfaces.Unsigned_32 (Index)) & "," & Image (P));
            end if;
         end;
      end if;
   end Write_Pulse;

   procedure Complete_Pulses is null;

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

   --  Each motor's capture of its last reply, and the time the first motor
   --  switched to input.
   Captured : Adaflight.DShot.Captures;
   Stamp    : Interfaces.Unsigned_32 := 0;
   Base     : Interfaces.Unsigned_32 := 0;

   GCR : constant array (Interfaces.Unsigned_32 range 0 .. 15) of Interfaces.Unsigned_32 :=
     (16#19#, 16#1B#, 16#12#, 16#13#, 16#1D#, 16#15#, 16#16#, 16#17#, 16#1A#, 16#09#, 16#0A#, 16#0B#, 16#1E#,
      16#0D#, 16#0E#, 16#0F#);

   --  A motor's reply to a frame value: its period word of the eRPM as the
   --  edges of its GCR transitions, sixteen counts a bit from the line's
   --  first falling edge, with the closing edge of a reply that ends low.
   procedure Answer (M : Natural; Value : Natural) is
      use Interfaces;
      Raw    : Unsigned_32 := 16#0FFF#;
      Period : Unsigned_32;
      E      : Natural := 0;
   begin
      if Value >= 48 then
         Period := 60_000_000 / Unsigned_32 (30 * (Value - 47));
         while Period >= 512 loop
            Period := Shift_Right (Period, 1);
            E := E + 1;
         end loop;
         Raw := Shift_Left (Unsigned_32 (E), 9) or Period;
      end if;
      declare
         Csum  : constant Unsigned_32 := (not (Raw xor Shift_Right (Raw, 4) xor Shift_Right (Raw, 8))) and 16#F#;
         Word  : constant Unsigned_32 := Shift_Left (Raw, 4) or Csum;
         Bits  : constant Unsigned_32 :=
           Shift_Left (1, 20) or Shift_Left (GCR (Shift_Right (Word, 12) and 16#F#), 15)
           or Shift_Left (GCR (Shift_Right (Word, 8) and 16#F#), 10) or Shift_Left (GCR (Shift_Right (Word, 4) and 16#F#), 5)
           or GCR (Word and 16#F#);
         Count : Natural := 0;
         Ones  : Natural := 0;
      begin
         Captured (M).Buffer := (others => 0);
         for B in reverse 0 .. 20 loop
            if (Shift_Right (Bits, B) and 1) /= 0 then
               Captured (M).Buffer (Count) := Base + Unsigned_32 (16 * (20 - B));
               Count := Count + 1;
               Ones := Ones + 1;
            end if;
         end loop;
         if Ones mod 2 = 1 then
            Captured (M).Buffer (Count) := Base + 16 * 21;
            Count := Count + 1;
         end if;
         Captured (M).Edges := Count;
      end;
   end Answer;

   function Telemetry_On return Boolean is (Bidir);

   procedure Captures (C : out Adaflight.DShot.Captures; Stamp_Us : out Interfaces.Unsigned_32) is
   begin
      C := Captured;
      Stamp_Us := Stamp;
   end Captures;

   procedure Leave_Input (Processed : Natural; Done : Boolean) is
   begin
      for M in 0 .. Natural'Min (Processed, Captured'Length) - 1 loop
         Captured (M).Input := False;
      end loop;
      if Done then
         Stamp := 0;
      end if;
   end Leave_Input;

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

   function Image (N : Natural) return String is (Image (Interfaces.Unsigned_32 (N)));

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
         if Bidir and then Frames (M).Loaded and then M < Driven then
            Base := Base + 4_000;
            Answer (M, Frames (M).Value);
            Captured (M).Input := True;
            Captured (M).Deadtime := Deadtime_Us;
            if Stamp = 0 then
               Stamp := Adaflight.STM32.Time.Micros;
            end if;
         end if;
         Frames (M).Loaded := False;
      end loop;
   end Start_Transfers;

   --  The host drives the motors through the timer driver's model only.
   function Bitbang_Active (C : Adaflight.Config_Groups.Configuration) return Boolean is (False);
   function Bitbang_On return Boolean is (False);
   function Bitbang_OK return Boolean is (True);
   procedure Post_Init (C : Adaflight.Config_Groups.Configuration; Strip_Stream : Natural) is null;
   procedure Update_Init is null;
   procedure Telemetry_Wait (Ports : in out Adaflight.DShot_Bitbang.Port_Inputs) is null;

   procedure Port_Samples
     (Ports : in out Adaflight.DShot_Bitbang.Port_Inputs; Used : out Adaflight.DShot_Bitbang.Port_Total;
      Pins : out Adaflight.DShot_Bitbang.Motor_Pins; Configured : out Adaflight.DShot.Motor_Total)
   is
      pragma Unreferenced (Ports);
   begin
      Used := 0;
      Pins := (others => <>);
      Configured := 0;
   end Port_Samples;
end Adaflight.STM32.Motors;
