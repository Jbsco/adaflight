with Ada.Environment_Variables;
with Ada.Text_IO;
with Interfaces;
with Adaflight.STM32.Time;
package body Adaflight.Host_Pin_Log is
   use type Interfaces.Unsigned_8;

   Read    : Boolean := False;
   Open    : Boolean := False;
   File    : Ada.Text_IO.File_Type;
   Chosen  : array (Port_Name, Pin_Number) of Boolean := (others => (others => False));
   SPI_Bus : Natural := 0;

   --  The file opened and the choices read at the first use.
   procedure Setup is
      Path  : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_PIN_LOG", "");
      Names : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_PIN_LOG_PINS", "");
      Bus   : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_PIN_LOG_SPI", "");
      At_K  : Natural := Names'First;
   begin
      Read := True;
      if Path'Length = 0 then
         return;
      end if;
      while At_K + 2 <= Names'Last loop
         if Names (At_K) in 'A' .. 'K' and then Names (At_K + 1) in '0' .. '1' and then Names (At_K + 2) in '0' .. '9'
         then
            declare
               Port   : constant Natural := Character'Pos (Names (At_K)) - Character'Pos ('A');
               Number : constant Natural :=
                 10 * (Character'Pos (Names (At_K + 1)) - Character'Pos ('0'))
                 + Character'Pos (Names (At_K + 2)) - Character'Pos ('0');
            begin
               if Port <= Port_Name'Pos (Port_Name'Last) and then Number <= Natural (Pin_Number'Last) then
                  Chosen (Port_Name'Val (Port), Pin_Number (Number)) := True;
               end if;
            end;
         end if;
         At_K := At_K + 4;
      end loop;
      if Bus'Length = 1 and then Bus (Bus'First) in '1' .. '6' then
         SPI_Bus := Character'Pos (Bus (Bus'First)) - Character'Pos ('0');
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Open := True;
   exception
      when others =>
         Open := False;
   end Setup;

   function Stamp return String is
      Text : constant String := Interfaces.Unsigned_32'Image (Adaflight.STM32.Time.Millis);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Stamp;

   procedure Level (P : Pin; High : Boolean) is
      Digit : constant String := "0123456789";
      N     : constant Natural := Natural (P.Number);
   begin
      if not Read then
         Setup;
      end if;
      if Open and then Chosen (P.Port, P.Number) then
         Ada.Text_IO.Put_Line
           (File,
            Stamp & " pin " & Character'Val (Character'Pos ('A') + Port_Name'Pos (P.Port))
            & Digit (N / 10 + 1) & Digit (N mod 10 + 1) & (if High then " 1" else " 0"));
         Ada.Text_IO.Flush (File);
      end if;
   end Level;

   procedure Transfer (Bus : Positive; Tx : Byte_Array) is
      Hex  : constant String := "0123456789ABCDEF";
      Text : String (1 .. 2 * Tx'Length);
   begin
      if not Read then
         Setup;
      end if;
      if Open and then Bus = SPI_Bus then
         for K in 0 .. Tx'Length - 1 loop
            Text (2 * K + 1) := Hex (Natural (Tx (Tx'First + K) / 16) + 1);
            Text (2 * K + 2) := Hex (Natural (Tx (Tx'First + K) mod 16) + 1);
         end loop;
         Ada.Text_IO.Put_Line (File, Stamp & " spi" & Integer'Image (Bus) & " " & Text);
         Ada.Text_IO.Flush (File);
      end if;
   end Transfer;
end Adaflight.Host_Pin_Log;
