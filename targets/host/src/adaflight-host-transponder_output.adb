--  The host's transponder output: the transponder's pin takes its timer
--  channel and names its stream as on the board, and each transmission adds
--  a line to the file the environment variable ADAFLIGHT_TRANSPONDER_LOG
--  names: the uptime in
--  milliseconds, the coding, the prescaler, the period and the one-toggle
--  value its timer takes from that timer's clock, the count of toggles, and
--  the toggles, a 1 for one at that value, a 0 for silence and a 2 for any
--  other value.
with Ada.Environment_Variables;
with Ada.Text_IO;
with Adaflight.CLI_Resources;
with Adaflight.STM32.Time;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
package body Adaflight.STM32.Transponder_Output is
   use Interfaces;
   package Core renames Adaflight.Transponder;

   Toggles  : Core.Pattern;
   Taken    : Boolean := False;
   Coding   : Core.Provider := Core.None;
   Prescale : Unsigned_16 := 0;
   Period   : Unsigned_16 := 0;
   Toggle   : Unsigned_16 := 0;
   Channel  : Timer_Entry;
   Stream   : DMA_Stream;

   procedure Log (Line : String) is
      Name : constant String :=
        Ada.Environment_Variables.Value ("ADAFLIGHT_TRANSPONDER_LOG", "adaflight-transponder.txt");
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

   function Image (N : Unsigned_32) return String is
      S : constant String := Unsigned_32'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Image;

   procedure Take (Tag : Unsigned_8; Found : out Boolean) is
      E     : Timer_Entry;
      Index : Natural;
   begin
      Taken := False;
      Found := False;
      if Tag = 0 then
         return;
      end if;
      Allocate (Tag, Adaflight.CLI_Resources.Transponder, E, Index, Found);
      if not Found then
         return;
      end if;
      declare
         O      : constant DMA_Options := Options_Of (E.Timer, E.Channel);
         Option : constant Integer := Option_Of (Index);
      begin
         Found := Option in 0 .. O'Length - 1;
         if Found then
            Channel := E;
            Stream := O (O'First + Option);
            Taken := True;
         end if;
      end;
   end Take;

   procedure Configure (P : Core.Provider) is
      Clock : constant Unsigned_32 := Timer_Clock_Hz (Channel.Timer);
   begin
      if not Taken then
         return;
      end if;
      Coding := P;
      Prescale := Core.Prescaler (Clock, P);
      Period := Core.Period (Clock, Prescale, P);
      Toggle := Core.Toggle_Of (Period);
   end Configure;

   function Ready return Boolean is (Taken);

   procedure Load (Data : Core.Code) is
   begin
      if Taken then
         Core.Encode (Coding, Data, Toggle, Toggles);
      end if;
   end Load;

   procedure Transmit is
      Text : String (1 .. Toggles.Length);
   begin
      if not Taken then
         return;
      end if;
      for I in Text'Range loop
         Text (I) := (if Toggles.Buffer (I - 1) = 0 then '0' elsif Toggles.Buffer (I - 1) = Toggle then '1' else '2');
      end loop;
      Log ("transmit," & Image (Adaflight.STM32.Time.Millis) & "," & Core.Provider'Image (Coding) & ","
           & Image (Unsigned_32 (Prescale)) & "," & Image (Unsigned_32 (Period)) & "," & Image (Unsigned_32 (Toggle))
           & "," & Image (Unsigned_32 (Toggles.Length)) & "," & Text);
   end Transmit;

   function Stream_Number return Natural is (if Taken then (Stream.Controller - 1) * 8 + Stream.Stream + 1 else 0);

end Adaflight.STM32.Transponder_Output;
