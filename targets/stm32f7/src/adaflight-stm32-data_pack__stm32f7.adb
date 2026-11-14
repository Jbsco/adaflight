with Interfaces;
with System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;
with Adaflight.Build_Features;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.LZMA;
with Adaflight.STM32.Cache;

package body Adaflight.STM32.Data_Pack is

   Packed_Start : Character with Import, Convention => C, External_Name => "__packed_start";
   Packed_End   : Character with Import, Convention => C, External_Name => "__packed_end";
   Boot_Start   : Character with Import, Convention => C, External_Name => "__boot_start";
   Boot_End     : Character with Import, Convention => C, External_Name => "__boot_end";
   Rom_End      : Character with Import, Convention => C, External_Name => "__rom_end";
   Flash_End    : Character with Import, Convention => C, External_Name => "__flash_end";
   Scratch      : Character with Import, Convention => C, External_Name => "__unpack_scratch";

   --  A stream decoded into its range, with the model's probabilities in the
   --  main stack, below the start-up's frames. A stream that does not decode
   --  stops the start.
   procedure Decode_Into (Source : Byte_Array; To : System.Address; Length : Natural) is
      use type Adaflight.LZMA.Status;
      Target : Byte_Array (0 .. Length - 1) with Import, Address => To;
      M      : Adaflight.LZMA.Model with Import, Address => Scratch'Address;
      Result : Adaflight.LZMA.Status;
   begin
      Adaflight.LZMA.Decode (Source, Target, M, Result);
      if Result /= Adaflight.LZMA.Done then
         loop
            null;
         end loop;
      end if;
   end Decode_Into;

   procedure Unpack is
      Length : constant Integer_Address := To_Integer (Packed_End'Address) - To_Integer (Packed_Start'Address);
      Room   : constant Integer_Address := To_Integer (Flash_End'Address) - To_Integer (Rom_End'Address);
      ITCM_Start : Character with Import, Convention => C, External_Name => "__itcm_start";
      ITCM_End   : Character with Import, Convention => C, External_Name => "__itcm_end";
      ITCM_Load  : Character with Import, Convention => C, External_Name => "__itcm_load";
      ITCM_Bytes : constant Integer_Address := To_Integer (ITCM_End'Address) - To_Integer (ITCM_Start'Address);
   begin
      if not Adaflight.Build_Features.Packed_Data then
         --  A plain image's ITCM code is in flash as it is.
         if ITCM_Bytes = 0 then
            return;
         end if;
         declare
            type Word_Array is array (Integer_Address range <>) of Interfaces.Unsigned_32;
            Words : constant Integer_Address := ITCM_Bytes / 4;
            From  : constant Word_Array (0 .. Words - 1) with Import, Address => ITCM_Load'Address;
            To    : Word_Array (0 .. Words - 1) with Import, Address => ITCM_Start'Address;
         begin
            for K in To'Range loop
               To (K) := From (K);
            end loop;
            System.Machine_Code.Asm ("dsb" & ASCII.LF & ASCII.HT & "isb", Volatile => True);
         end;
         return;
      end if;
      --  A packed image has, after .rodata, the length of its ITCM code's
      --  stream in four bytes from the low one, that stream, and the packed
      --  range's stream.
      if Room < 4 then
         loop
            null;
         end loop;
      end if;
      declare
         use type Interfaces.Unsigned_32;
         Source : constant Byte_Array (0 .. Natural (Room) - 1) with Import, Address => Rom_End'Address;
         Head   : constant Interfaces.Unsigned_32 :=
           Interfaces.Unsigned_32 (Source (0)) or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Source (1)), 8)
           or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Source (2)), 16)
           or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Source (3)), 24);
         First  : Natural;
      begin
         if Head > Interfaces.Unsigned_32 (Room - 4) then
            loop
               null;
            end loop;
         end if;
         First := Natural (Head);
         if ITCM_Bytes > 0 then
            Decode_Into (Source (4 .. 3 + First), ITCM_Start'Address, Natural (ITCM_Bytes));
            System.Machine_Code.Asm ("dsb" & ASCII.LF & ASCII.HT & "isb", Volatile => True);
         end if;
         if Length > 0 then
            Decode_Into (Source (4 + First .. Source'Last), Packed_Start'Address, Natural (Length));
            Adaflight.STM32.Cache.Sync_Code
              (Boot_Start'Address, Natural (To_Integer (Boot_End'Address) - To_Integer (Boot_Start'Address)));
         end if;
      end;
   end Unpack;

   type Start_Hook is access procedure with Convention => C;
   Entry_Hook : constant Start_Hook := Unpack'Access
     with Export, External_Name => "adaflight_data_pack_entry", Linker_Section => ".init_array.00001";

end Adaflight.STM32.Data_Pack;
