with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.RTC6705 is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.VTX_RTC6705.Operation_Kind;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   package Core renames Adaflight.VTX_RTC6705;
   package GPIO renames Adaflight.STM32.GPIO;
   package SPI renames Adaflight.STM32.SPI;

   --  The time a software SPI level lasts, the SPI bus clock and the pause
   --  after a bus write.
   Level_Us  : constant := 10;
   Bus_Hz    : constant := 1_000_000;
   Pause_Us  : constant := 10;

   --  Room for three lists of the core's operations: one that waits and two
   --  from the task calls within its wait.
   Queue_Size : constant := 3 * Core.Max_Operations;
   type Queue_Index is mod Queue_Size;

   Ready     : Boolean := False;
   On_Bus    : Boolean := False;
   Bus       : SPI.Bus := SPI.SPI1;
   CS        : Pin := (Port_A, 0);
   Clock     : Pin := (Port_A, 0);
   Data      : Pin := (Port_A, 0);
   Power     : Pin := (Port_A, 0);
   Has_Power : Boolean := False;

   Queue     : array (Queue_Index) of Core.Operation := (others => (Core.Write_Register, 0, 0));
   Head      : Queue_Index := 0;
   Count     : Natural range 0 .. Queue_Size := 0;
   Waiting   : Boolean := False;
   Wait_From : Unsigned_32 := 0;

   function Tagged_Pin (Tag : Unsigned_8) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Unsigned_8) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   procedure Init (C : Adaflight.Config_Groups.Configuration; OK : out Boolean) is
      IO : Adaflight.Config_Groups.Vtx_Io_Config_Record renames C.Vtx_Io_Config;
   begin
      OK := False;
      Ready := False;
      Count := 0;
      Waiting := False;
      if not Tagged_Pin (IO.Cs_Tag) then
         return;
      end if;
      CS := Pin_Of (IO.Cs_Tag);
      Has_Power := Tagged_Pin (IO.Power_Tag);
      if Has_Power then
         Power := Pin_Of (IO.Power_Tag);
         GPIO.Enable_Port (Power.Port);
         GPIO.Set_High (Power);
         GPIO.Set_Output (Power);
      end if;
      if IO.Spi_Device in 1 .. 6 and then SPI.Started (SPI.Bus'Val (Natural (IO.Spi_Device) - 1)) then
         On_Bus := True;
         Bus := SPI.Bus'Val (Natural (IO.Spi_Device) - 1);
      elsif Tagged_Pin (IO.Data_Tag) and then Tagged_Pin (IO.Clock_Tag) then
         On_Bus := False;
         Data := Pin_Of (IO.Data_Tag);
         Clock := Pin_Of (IO.Clock_Tag);
         GPIO.Enable_Port (Data.Port);
         GPIO.Set_Output (Data);
         GPIO.Enable_Port (Clock.Port);
         GPIO.Set_Low (Clock);
         GPIO.Set_Output (Clock);
      else
         return;
      end if;
      --  The select pin is high before it is an output, so the transmitter
      --  sees no low level on it.
      GPIO.Enable_Port (CS.Port);
      GPIO.Set_High (CS);
      GPIO.Set_Output (CS);
      Ready := True;
      OK := True;
   end Init;

   --  A register write as 25 bits, lowest first: four of the address, a set
   --  write bit and twenty of the value, each taken at the clock's rise.
   procedure Write_Pins (Address : Unsigned_8; Value : Unsigned_32) is
      procedure Bit (On : Boolean) is
      begin
         if On then
            GPIO.Set_High (Data);
         else
            GPIO.Set_Low (Data);
         end if;
         GPIO.Set_High (Clock);
         Adaflight.STM32.Time.Delay_Us (Level_Us);
         GPIO.Set_Low (Clock);
         Adaflight.STM32.Time.Delay_Us (Level_Us);
      end Bit;
   begin
      GPIO.Set_Low (CS);
      Adaflight.STM32.Time.Delay_Us (Level_Us);
      for I in 0 .. 3 loop
         Bit ((Interfaces.Shift_Right (Address, I) and 1) /= 0);
      end loop;
      Bit (True);
      for I in 0 .. 19 loop
         Bit ((Interfaces.Shift_Right (Value, I) and 1) /= 0);
      end loop;
      GPIO.Set_High (CS);
   end Write_Pins;

   function Reversed (B : Unsigned_8) return Unsigned_8 is
      Result : Unsigned_8 := 0;
   begin
      for I in 0 .. 7 loop
         if (Interfaces.Shift_Right (B, I) and 1) /= 0 then
            Result := Result or Interfaces.Shift_Left (1, 7 - I);
         end if;
      end loop;
      return Result;
   end Reversed;

   --  The same 25 bits on an SPI bus, which sends each byte highest bit
   --  first: four bytes with their bits reversed, the rest of them zero.
   procedure Write_Bus (Address : Unsigned_8; Value : Unsigned_32) is
      Command : constant Unsigned_32 :=
        Unsigned_32 (Address and 16#0F#) or 16#10# or Interfaces.Shift_Left (Value and 16#F_FFFF#, 5);
      Tx      : Byte_Array (0 .. 3);
      Rx      : Byte_Array (0 .. 3);
   begin
      for K in Tx'Range loop
         Tx (K) := Reversed (Unsigned_8 (Interfaces.Shift_Right (Command, 8 * K) and 16#FF#));
      end loop;
      SPI.Set_Divisor (Bus, SPI.Divider (Bus_Hz));
      GPIO.Set_Low (CS);
      SPI.Transfer (Bus, Tx, Rx);
      GPIO.Set_High (CS);
      Adaflight.STM32.Time.Delay_Us (Pause_Us);
   end Write_Bus;

   --  The operation at the queue's head, apart from a wait.
   procedure Carry_Out (Op : Core.Operation) is
   begin
      case Op.Kind is
         when Core.Write_Register =>
            if On_Bus then
               Write_Bus (Op.Address, Op.Value);
            else
               Write_Pins (Op.Address, Op.Value);
            end if;
         when Core.Power_On =>
            if Has_Power then
               GPIO.Set_Low (Power);
            end if;
         when Core.Power_Off =>
            if Has_Power then
               GPIO.Set_High (Power);
            end if;
         when Core.Wait =>
            null;
      end case;
   end Carry_Out;

   procedure Drop_Head is
   begin
      Head := Head + 1;
      Count := Count - 1;
      Waiting := False;
   end Drop_Head;

   procedure Run (Now_Ms : Unsigned_32) is
   begin
      while Count > 0 loop
         if Queue (Head).Kind = Core.Wait then
            if not Waiting then
               Waiting := True;
               Wait_From := Now_Ms;
            end if;
            exit when Now_Ms - Wait_From < Queue (Head).Value;
         else
            Carry_Out (Queue (Head));
         end if;
         Drop_Head;
      end loop;
   end Run;

   --  A full queue gives up its head operation at once, a wait in place:
   --  no operation is lost and their order stays.
   procedure Submit (Ops : Core.Operations) is
   begin
      if not Ready then
         return;
      end if;
      for K in 1 .. Ops.Count loop
         if Count = Queue_Size then
            if Queue (Head).Kind = Core.Wait then
               Adaflight.STM32.Time.Delay_Ms (Natural (Unsigned_32'Min (Queue (Head).Value, 1_000)));
            else
               Carry_Out (Queue (Head));
            end if;
            Drop_Head;
         end if;
         Queue (Head + Queue_Index (Count mod Queue_Size)) := Ops.List (K);
         Count := Count + 1;
      end loop;
   end Submit;
end Adaflight.STM32.RTC6705;
