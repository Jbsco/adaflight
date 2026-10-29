with Interfaces;
with Adaflight.STM32.Time;
with Adaflight.STM32.USART;
with Adaflight.STM32.USB;
package body Adaflight.STM32.Serial is
   use type Interfaces.Unsigned_32;
   package USART renames Adaflight.STM32.USART;

   Write_Timeout_Ms : constant := 50;

   function Number_Of (Which : Line) return USART.Number is
     (USART.Number'Val (Line'Pos (Which) - 1))
     with Pre => Which /= VCP;

   --  The bytes toward the host while it has the port configured, retried
   --  while a transfer runs, for up to the write timeout.
   procedure Write_VCP (Data : Byte_Array) is
      Start    : constant Interfaces.Unsigned_32 := Adaflight.STM32.Time.Millis;
      Next     : Natural := Data'First;
      Accepted : Natural;
   begin
      if not Adaflight.STM32.USB.Configured then
         return;
      end if;
      while Next <= Data'Last loop
         Adaflight.STM32.USB.Send (Data (Next .. Data'Last), Accepted);
         Next := Next + Accepted;
         exit when Adaflight.STM32.Time.Millis - Start > Write_Timeout_Ms;
      end loop;
   end Write_VCP;

   procedure Put (Into : in out Port; Text : String) is
      Data : Byte_Array (0 .. Text'Length - 1);
   begin
      for I in Data'Range loop
         Data (I) := Character'Pos (Text (Text'First + I));
      end loop;
      Put (Into, Data);
   end Put;

   procedure Put (Into : in out Port; Data : Byte_Array) is
   begin
      if Into.Which = VCP then
         Write_VCP (Data);
      else
         declare
            P : USART.Port;
         begin
            P.Which := Number_Of (Into.Which);
            USART.Put (P, Data);
         end;
      end if;
   end Put;

   procedure Take (Which : Line; Into : out Byte_Array; Count : out Natural) is
   begin
      if Which = VCP then
         Adaflight.STM32.USB.Take (Into, Count);
      else
         USART.Take (Number_Of (Which), Into, Count);
      end if;
   end Take;
end Adaflight.STM32.Serial;
