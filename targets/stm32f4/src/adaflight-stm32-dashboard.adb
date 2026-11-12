with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.OLED_Display;
with Adaflight.STM32.I2C;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Dashboard is
   package Core renames Adaflight.Dashboard;
   use type Core.Operation_Kind;

   --  The display's place on a bus; Named is false when the configuration
   --  names no bus.
   type Link is record
      Bus     : Adaflight.STM32.I2C.Bus := Adaflight.STM32.I2C.I2C1;
      Address : Byte := 16#3C#;
      Named   : Boolean := False;
   end record;

   procedure Write (D : in out Link; Control : Byte; Value : Byte; OK : out Boolean) is
   begin
      if D.Named and then Adaflight.STM32.I2C.Started (D.Bus) then
         Adaflight.STM32.I2C.Write (D.Bus, D.Address, Control, Value, OK);
      else
         OK := False;
      end if;
   end Write;

   package Display is new Adaflight.OLED_Display (I2C_Device => Link, Write => Write);

   Device  : Link;
   Screen  : constant Display.Display := (others => <>);
   State   : Core.State;
   Answers : Boolean := False;
   --  The operations of one update, kept out of the stack and of main RAM.
   Ops     : Core.Output with Linker_Section => ".bss.ccm", Suppress_Initialization;

   procedure Perform (O : Core.Operation) is
   begin
      case O.Kind is
         when Core.Start =>
            null;
         when Core.Clear =>
            Display.Clear_Quick (Device);
         when Core.Position =>
            Display.Set_XY (Device, O.Column, O.Row);
         when Core.Line =>
            Display.Set_Line (Device, O.Row);
         when Core.Char =>
            Display.Send_Char (Device, Screen, Character'Pos (O.Glyph));
         when Core.Text =>
            Display.Send_String (Device, Screen, O.Data (1 .. O.Length));
      end case;
   end Perform;

   --  One update, or the start with its first update. The core's update
   --  reads whether the display answered the start it asks for, and it
   --  asks for every start ahead of its drawing. So a first run on a copy
   --  of the state tells how many starts this update makes, the display
   --  is started that many times, and the run that counts reads the last
   --  answer.
   procedure Run (Now_Us : Interfaces.Unsigned_32; R : Core.Readings; First : Boolean) is
      Given  : Core.Readings := R;
      Trial  : Core.State := State;
      Starts : Natural := 0;

      procedure Pass (S : in out Core.State) is
      begin
         if First then
            Core.Init (S, Now_Us, Given, Ops);
         else
            Ops.Count := 0;
            Core.Update (S, Now_Us, Given, Ops);
         end if;
      end Pass;
   begin
      Given.Grabbed := False;
      Given.Present := Answers;
      Pass (Trial);
      for I in 1 .. Ops.Count loop
         if Ops.Operations (I).Kind = Core.Start then
            Starts := Starts + 1;
         end if;
      end loop;
      if Starts = 0 then
         State := Trial;
      else
         for N in 1 .. Starts loop
            Display.Init (Device, Screen, Answers);
            if First and then N = 1 then
               Adaflight.STM32.Time.Delay_Ms (200);
            end if;
         end loop;
         Given.Present := Answers;
         Pass (State);
      end if;
      for I in 1 .. Ops.Count loop
         Perform (Ops.Operations (I));
      end loop;
   end Run;

   procedure Init
     (C : Adaflight.Config_Groups.Configuration; Now_Us : Interfaces.Unsigned_32; R : Core.Readings)
   is
      Number : constant Interfaces.Integer_8 := C.Dashboard_Config.Device;
   begin
      Device :=
        (Bus     => (case Number is
                        when 2 => Adaflight.STM32.I2C.I2C2,
                        when 3 => Adaflight.STM32.I2C.I2C3,
                        when 4 => Adaflight.STM32.I2C.I2C4,
                        when others => Adaflight.STM32.I2C.I2C1),
         Address => C.Dashboard_Config.Address,
         Named   => Number in 1 .. 4);
      State := (others => <>);
      Answers := False;
      Adaflight.STM32.Time.Delay_Ms (200);
      Run (Now_Us, R, First => True);
   end Init;

   procedure Update (Now_Us : Interfaces.Unsigned_32; R : Core.Readings) is
   begin
      Run (Now_Us, R, First => False);
   end Update;

   procedure Enable_Cycling is
   begin
      Core.Enable_Cycling (State);
   end Enable_Cycling;

   procedure Disable_Cycling is
   begin
      Core.Disable_Cycling (State);
   end Disable_Cycling;

   procedure Reset_Cycling is
   begin
      Core.Reset_Cycling (State);
   end Reset_Cycling;

   function Present return Boolean is (Answers);

end Adaflight.STM32.Dashboard;
