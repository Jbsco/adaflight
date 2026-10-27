with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
package body Adaflight.STM32.Flash is
   function File_Name return String is
     (Ada.Environment_Variables.Value ("ADAFLIGHT_EEPROM", "adaflight-eeprom.bin"));

   procedure Load is
      use Ada.Streams;
      File   : Stream_IO.File_Type;
      Buffer : Stream_Element_Array (1 .. Config_Size);
      Last   : Stream_Element_Offset;
   begin
      if not Ada.Directories.Exists (File_Name) then
         return;
      end if;
      Stream_IO.Open (File, Stream_IO.In_File, File_Name);
      Stream_IO.Read (File, Buffer, Last);
      Stream_IO.Close (File);
      for I in 1 .. Last loop
         Config (Natural (I) - 1) := Byte (Buffer (I));
      end loop;
   end Load;

   procedure Write (Data : Byte_Array; OK : out Boolean) is
      use Ada.Streams;
      File   : Stream_IO.File_Type;
      Buffer : Stream_Element_Array (1 .. Config_Size);
   begin
      Config := (others => 16#FF#);
      Config (0 .. Data'Length - 1) := Data;
      for I in Buffer'Range loop
         Buffer (I) := Stream_Element (Config (Natural (I) - 1));
      end loop;
      Stream_IO.Create (File, Stream_IO.Out_File, File_Name);
      Stream_IO.Write (File, Buffer);
      Stream_IO.Close (File);
      OK := True;
   exception
      when others =>
         OK := False;
   end Write;
begin
   Load;
end Adaflight.STM32.Flash;
