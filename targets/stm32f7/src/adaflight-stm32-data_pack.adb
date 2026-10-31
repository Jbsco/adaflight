with System.Storage_Elements; use System.Storage_Elements;
with Adaflight.Build_Features;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.LZSS;

package body Adaflight.STM32.Data_Pack is

   Packed_Start : Character with Import, Convention => C, External_Name => "__packed_start";
   Packed_End   : Character with Import, Convention => C, External_Name => "__packed_end";
   Rom_End      : Character with Import, Convention => C, External_Name => "__rom_end";
   Flash_End    : Character with Import, Convention => C, External_Name => "__flash_end";

   procedure Unpack is
      use type Adaflight.LZSS.Status;
      Length : constant Integer_Address := To_Integer (Packed_End'Address) - To_Integer (Packed_Start'Address);
      Room   : constant Integer_Address := To_Integer (Flash_End'Address) - To_Integer (Rom_End'Address);
   begin
      if not Adaflight.Build_Features.Packed_Data or else Length <= 0 then
         return;
      end if;
      declare
         Source : constant Byte_Array (0 .. Natural (Room) - 1)
           with Import, Address => Rom_End'Address;
         Target : Byte_Array (0 .. Natural (Length) - 1)
           with Import, Address => Packed_Start'Address;
         Result : Adaflight.LZSS.Status;
      begin
         Adaflight.LZSS.Decode (Source, Target, Result);
         if Result /= Adaflight.LZSS.Done then
            loop
               null;
            end loop;
         end if;
      end;
   end Unpack;

   type Start_Hook is access procedure with Convention => C;
   Entry_Hook : constant Start_Hook := Unpack'Access
     with Export, External_Name => "adaflight_data_pack_entry", Linker_Section => ".init_array.00001";

end Adaflight.STM32.Data_Pack;
