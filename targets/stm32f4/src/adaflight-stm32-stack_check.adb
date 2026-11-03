with System.Storage_Elements; use System.Storage_Elements;
package body Adaflight.STM32.Stack_Check is

   Stack_Start : Character with Import, Convention => C, External_Name => "__stack_start";
   Stack_End   : Character with Import, Convention => C, External_Name => "__stack_end";
   Fill        : constant Storage_Element := 16#A5#;
   Margin      : constant := 256;

   function Total return Interfaces.Unsigned_32 is
     (Interfaces.Unsigned_32 (To_Integer (Stack_End'Address) - To_Integer (Stack_Start'Address)));

   function High return Interfaces.Unsigned_32 is (Interfaces.Unsigned_32 (To_Integer (Stack_End'Address)));

   procedure Paint is
      Marker : aliased Interfaces.Unsigned_32 := 0;
      Low    : constant Integer_Address := To_Integer (Stack_Start'Address);
      Top    : constant Integer_Address := To_Integer (Marker'Address) - Margin;
   begin
      if Top <= Low then
         return;
      end if;
      declare
         Region : Storage_Array (0 .. Storage_Offset (Top - Low) - 1)
           with Import, Volatile, Address => Stack_Start'Address;
      begin
         for K in Region'Range loop
            Region (K) := Fill;
         end loop;
      end;
   end Paint;

   function Used return Interfaces.Unsigned_32 is
      Marker : aliased Interfaces.Unsigned_32 := 0;
      Low    : constant Integer_Address := To_Integer (Stack_Start'Address);
      Here   : constant Integer_Address := To_Integer (Marker'Address);
      Next   : Integer_Address := Low;
   begin
      if Here > Low then
         declare
            Region : Storage_Array (0 .. Storage_Offset (Here - Low) - 1)
              with Import, Volatile, Address => Stack_Start'Address;
         begin
            for K in Region'Range loop
               exit when Region (K) /= Fill;
               Next := Next + 1;
            end loop;
         end;
      end if;
      return Interfaces.Unsigned_32 (To_Integer (Stack_End'Address) - Next);
   end Used;

end Adaflight.STM32.Stack_Check;
