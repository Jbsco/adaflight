with Ada.Calendar;
with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Interfaces;
with DFU.Flash;
with DFU.Layout;
with DFU.Plan;
with DFU.Session;
with DFU.Transport;

--  Flashes an image directory, or files at given addresses, through the STM32 bootloader over USB.
procedure Adaflight_DFU with SPARK_Mode => Off is

   use Ada.Text_IO;
   use type Ada.Calendar.Time;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use DFU.Plan;

   type Data_Access is access DFU.Byte_Array;
   type Text_Access is access String;

   Usage_Error : exception;
   Flash_Error : exception;

   Hex_Digits : constant String := "0123456789abcdef";

   function Hex (A : DFU.Address) return String is
      Result : String (1 .. 10) := "0x00000000";
      V      : DFU.Address := A;
   begin
      for J in reverse 3 .. 10 loop
         Result (J) := Hex_Digits (Natural (V mod 16) + 1);
         V := V / 16;
      end loop;
      return Result;
   end Hex;

   function Decimal (N : Interfaces.Unsigned_64) return String is
     (Ada.Strings.Fixed.Trim (Interfaces.Unsigned_64'Image (N), Ada.Strings.Left));

   function Seconds (Since : Ada.Calendar.Time) return String is
      Tenths : constant Natural := Natural (Float (Ada.Calendar.Clock - Since) * 10.0);
   begin
      return Decimal (Interfaces.Unsigned_64 (Tenths / 10)) & "." & Decimal (Interfaces.Unsigned_64 (Tenths mod 10))
        & " s";
   end Seconds;

   function Parse_Address (Text : String) return DFU.Address is
      Value : Interfaces.Unsigned_64;
   begin
      if Text'Length > 2 and then (Text (Text'First .. Text'First + 1) = "0x"
                                   or else Text (Text'First .. Text'First + 1) = "0X")
      then
         Value := Interfaces.Unsigned_64'Value ("16#" & Text (Text'First + 2 .. Text'Last) & "#");
      else
         Value := Interfaces.Unsigned_64'Value (Text);
      end if;
      if Value > Interfaces.Unsigned_64 (DFU.Address'Last) then
         raise Usage_Error with "address " & Text & " is beyond 32 bits";
      end if;
      return DFU.Address (Value);
   exception
      when Constraint_Error =>
         raise Usage_Error with "address " & Text & " is not a number";
   end Parse_Address;

   function Load (Name : String) return Data_Access is
      use Ada.Streams;
      use type Stream_IO.Count;
      File   : Stream_IO.File_Type;
      Size   : Stream_IO.Count;
      Last   : Stream_Element_Offset;
      Result : Data_Access;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Name);
      Size := Stream_IO.Size (File);
      if Size = 0 or else Size > DFU.Max_Data then
         Stream_IO.Close (File);
         raise Usage_Error with Name & " is empty or larger than 16 MB";
      end if;
      declare
         type Raw_Access is access Stream_Element_Array;
         Raw : constant Raw_Access := new Stream_Element_Array (1 .. Stream_Element_Offset (Size));
      begin
         Stream_IO.Read (File, Raw.all, Last);
         Stream_IO.Close (File);
         if Last /= Raw'Last then
            raise Flash_Error with "short read of " & Name;
         end if;
         Result := new DFU.Byte_Array (0 .. Natural (Size) - 1);
         for J in Result'Range loop
            Result (J) := DFU.Byte (Raw (Stream_Element_Offset (J) + 1));
         end loop;
      end;
      return Result;
   exception
      when Stream_IO.Name_Error | Stream_IO.Use_Error =>
         raise Usage_Error with "cannot open " & Name;
   end Load;

   Names     : array (Image_Index) of Text_Access;
   Addresses : array (Image_Index) of DFU.Address := (others => 0);
   Files     : array (Image_Index) of Data_Access;
   Count     : Image_Count := 0;
   Pair      : Boolean := False;
   Unprotect : Boolean := False;

   procedure Read_Arguments is
      Directory : Text_Access := new String'(".");
      Named     : Boolean := False;
   begin
      for J in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (J);
            At_Sign : constant Natural := Ada.Strings.Fixed.Index (Arg, "@", Ada.Strings.Backward);
         begin
            if Arg = "-h" or else Arg = "--help" then
               raise Usage_Error with "";
            elsif Arg = "--unprotect" then
               Unprotect := True;
            elsif At_Sign = 0 then
               if Named or else Count > 0 then
                  raise Usage_Error with "a directory is the only file argument";
               end if;
               Directory := new String'(Arg);
               Named := True;
            elsif Named then
               raise Usage_Error with "a directory is the only file argument";
            elsif Count = Max_Images then
               raise Usage_Error with "at most four files";
            else
               Count := Count + 1;
               Names (Count) := new String'(Arg (Arg'First .. At_Sign - 1));
               Addresses (Count) := Parse_Address (Arg (At_Sign + 1 .. Arg'Last));
            end if;
         end;
      end loop;
      if Count = 0 then
         Pair := True;
         Count := 2;
         Names (1) := new String'(Directory.all & "/sector0.bin");
         Names (2) := new String'(Directory.all & "/code.bin");
      end if;
      for K in 1 .. Count loop
         Files (K) := Load (Names (K).all);
      end loop;
   end Read_Arguments;

   M        : DFU.Layout.Memory;
   Options  : DFU.Layout.Memory;
   Optional : Boolean;
   Guard    : DFU.Session.Protection;
   Transfer : DFU.Session.Transfer_Size;
   Images   : Image_Array := (others => (First => 0, Length => 0));
   Offsets  : DFU.Flash.Offset_Array := (others => 0);
   Data     : Data_Access;
   Ok       : Boolean;
   Failed   : DFU.Address;
   Pages    : Natural;
   Bytes    : Interfaces.Unsigned_64;
   Start    : Ada.Calendar.Time;
   Total    : Natural := 0;

   procedure Place is
   begin
      if Pair then
         Place_Pair (M, Files (1)'Length, Files (2)'Length, Images, Ok);
         if not Ok then
            raise Flash_Error with "sector0.bin must fit the first page and code.bin the flash from its third page";
         end if;
      else
         for K in 1 .. Count loop
            Images (K) := (First => Addresses (K), Length => Files (K)'Length);
         end loop;
         --  Lowest address first: the bootloader leaves through the first image.
         for K in 2 .. Count loop
            for L in reverse 2 .. K loop
               exit when Images (L - 1).First <= Images (L).First;
               declare
                  I : constant Image := Images (L);
                  F : constant Data_Access := Files (L);
               begin
                  Images (L) := Images (L - 1);
                  Images (L - 1) := I;
                  Files (L) := Files (L - 1);
                  Files (L - 1) := F;
               end;
            end loop;
         end loop;
         if not Valid (M, Images, Count) then
            raise Flash_Error with "each file must lie within the flash, apart from the others";
         end if;
      end if;
      for K in 1 .. Count loop
         if not DFU.Session.Blocks_Fit (Images (K).Length, Transfer) then
            raise Flash_Error with "an image needs more blocks than the transfer size allows";
         end if;
         Offsets (K) := Total;
         Total := Total + Images (K).Length;
      end loop;
      if Total > DFU.Max_Data then
         raise Flash_Error with "the images exceed 16 MB together";
      end if;
      Data := new DFU.Byte_Array (0 .. Total - 1);
      for K in 1 .. Count loop
         Data (Offsets (K) .. Offsets (K) + Images (K).Length - 1) := Files (K).all;
      end loop;
   end Place;

begin
   Read_Arguments;
   DFU.Transport.Open (Ok);
   if not Ok then
      raise Flash_Error with "no device in DFU mode (0483:df11), or no access to it";
   end if;
   DFU.Session.Read_Layout (M, Options, Optional, Transfer, Ok);
   if not Ok then
      raise Flash_Error with "the device names no internal flash";
   end if;
   Put_Line ("internal flash from " & Hex (M.First (1)) & " to " & Hex (M.Last (M.Pages)) & " in"
             & Natural'Image (M.Pages) & " pages, transfer size" & Natural'Image (Transfer));
   Place;

   DFU.Session.Clear_Status (False, Ok);
   if not Ok then
      raise Flash_Error with "the bootloader did not reach its idle state";
   end if;

   if Optional then
      DFU.Session.Check_Protection (Options, Guard);
      case Guard is
         when DFU.Session.Readable =>
            null;
         when DFU.Session.Read_Protected =>
            if not Unprotect then
               raise Flash_Error with "the flash is read protected; --unprotect removes the protection and erases"
                 & " the whole flash, its configuration included";
            end if;
            DFU.Session.Unprotect (Ok);
            if not Ok then
               raise Flash_Error with "the bootloader did not reset after the unprotect request";
            end if;
            Put_Line ("read protection removed and the flash erased; flash again once the board is in DFU mode");
            DFU.Transport.Close;
            return;
         when DFU.Session.Unknown =>
            raise Flash_Error with "the option bytes check failed";
      end case;
   end if;

   Start := Ada.Calendar.Clock;
   DFU.Flash.Erase (M, Images, Count, Pages, Bytes, Failed, Ok);
   if not Ok then
      raise Flash_Error with "erase failed at " & Hex (Failed) & ", the flash may be read protected";
   end if;
   Put_Line ("erased" & Natural'Image (Pages) & " pages (" & Decimal (Bytes / 1024) & " KB) in " & Seconds (Start));

   Start := Ada.Calendar.Clock;
   DFU.Flash.Write (Images, Offsets, Count, Data.all, Transfer, Failed, Ok);
   if not Ok then
      raise Flash_Error with "write failed in the image at " & Hex (Failed);
   end if;
   for K in 1 .. Count loop
      Put_Line ("wrote " & Names (K).all & "," & Natural'Image (Images (K).Length) & " bytes at "
                & Hex (Images (K).First));
   end loop;
   Put_Line ("written in " & Seconds (Start));

   Start := Ada.Calendar.Clock;
   DFU.Flash.Verify (Images, Offsets, Count, Data.all, Transfer, Failed, Ok);
   if not Ok then
      raise Flash_Error with "verify failed at " & Hex (Failed);
   end if;
   Put_Line ("verified in " & Seconds (Start));

   DFU.Session.Leave (Images (1).First, Ok);
   if not Ok then
      raise Flash_Error with "the bootloader did not accept the leave request";
   end if;
   Put_Line ("started the image at " & Hex (Images (1).First));
   DFU.Transport.Close;
exception
   when E : Usage_Error =>
      if Ada.Exceptions.Exception_Message (E) /= "" then
         Put_Line (Standard_Error, "adaflight_dfu: " & Ada.Exceptions.Exception_Message (E));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
      Put_Line (Standard_Error, "usage: adaflight_dfu [--unprotect] [DIRECTORY | FILE@ADDRESS ...]");
      Put_Line (Standard_Error, "  DIRECTORY     sector0.bin at the flash's start and code.bin from its third page,"
                & " . when unset");
      Put_Line (Standard_Error, "  FILE@ADDRESS  each file at its address, such as code.bin@0x08008000");
      Put_Line (Standard_Error, "  --unprotect   remove read protection, which erases the whole flash");
   when E : Flash_Error =>
      Put_Line (Standard_Error, "adaflight_dfu: " & Ada.Exceptions.Exception_Message (E));
      DFU.Transport.Close;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Adaflight_DFU;
