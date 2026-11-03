with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.EXTI;
with Adaflight.STM32.EXTI_Dispatch;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.RX_SPI_Device is
   use type Interfaces.Unsigned_8;

   Max_Clock_Hz     : constant := 13_500_000;
   Startup_Clock_Hz : constant := 6_500_000;
   Dummy            : constant Byte := 16#FF#;

   Bus           : SPI.Bus := SPI.SPI1;
   CS            : Pin := (Port_A, 0);
   Has_CS        : Boolean := False;
   Normal_Hz     : Unsigned_32 := Max_Clock_Hz;
   Divisor       : Interfaces.Unsigned_16 := 256;
   Exti_Pin      : Pin := (Port_A, 0);
   Has_Exti      : Boolean := False;
   Exti_Occurred : Boolean := False with Atomic;
   Exti_Time     : Unsigned_32 := 0 with Atomic;
   On_Edge       : Edge_Handler := null with Atomic;

   function Has_Tag (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   procedure Preinit (C : Adaflight.Config_Groups.Rx_Spi_Config_Record) is
   begin
      if Has_Tag (C.Csn_Tag) then
         declare
            P : constant Pin := Pin_Of (Natural (C.Csn_Tag));
         begin
            GPIO.Enable_Port (P.Port);
            GPIO.Set_Input (P, GPIO.Up);
            GPIO.Set_High (P);
         end;
      end if;
   end Preinit;

   procedure Init (C : Adaflight.Config_Groups.Rx_Spi_Config_Record; Ok : out Boolean) is
   begin
      Ok := C.Spibus in 1 .. 6 and then SPI.Started (SPI.Bus'Val (C.Spibus - 1));
      if not Ok then
         return;
      end if;
      Bus := SPI.Bus'Val (C.Spibus - 1);
      Has_CS := Has_Tag (C.Csn_Tag);
      if Has_CS then
         CS := Pin_Of (Natural (C.Csn_Tag));
         GPIO.Enable_Port (CS.Port);
         GPIO.Set_Output (CS);
      end if;
      Normal_Speed;
      if Has_CS then
         GPIO.Set_High (CS);
      end if;
      Has_Exti := Has_Tag (C.Exti_Io_Tag);
      if Has_Exti then
         Exti_Pin := Pin_Of (Natural (C.Exti_Io_Tag));
      end if;
   end Init;

   procedure Set_Normal_Speed (Hz : Unsigned_32) is
   begin
      Normal_Hz := Hz;
   end Set_Normal_Speed;

   procedure Normal_Speed is
   begin
      Divisor := SPI.Divider (Normal_Hz);
   end Normal_Speed;

   procedure Startup_Speed is
   begin
      Divisor := SPI.Divider (Startup_Clock_Hz);
   end Startup_Speed;

   --  The line's edge: its time and the flag the protocol polls.
   procedure Exti_Edge is
   begin
      Exti_Time := Time.Micros;
      Exti_Occurred := True;
      if On_Edge /= null then
         On_Edge.all;
      end if;
   end Exti_Edge;

   function Exti_Configured return Boolean is (Has_Exti);

   procedure Exti_Init (Pull_Down : Boolean) is
   begin
      if not Has_Exti then
         return;
      end if;
      EXTI_Dispatch.Register (Exti_Pin.Number, Exti_Edge'Access);
      GPIO.Enable_Port (Exti_Pin.Port);
      GPIO.Set_Input (Exti_Pin, (if Pull_Down then GPIO.Down else GPIO.No_Pull));
      EXTI.Enable_Rising (Exti_Pin);
      if Exti_State then
         Exti_Edge;
      end if;
   end Exti_Init;

   function Exti_State return Boolean is (GPIO.Is_High (Exti_Pin));

   function Poll_Exti return Boolean is (Exti_Occurred);

   procedure Reset_Exti is
   begin
      Exti_Occurred := False;
   end Reset_Exti;

   function Last_Exti_Time return Unsigned_32 is (Exti_Time);

   procedure Set_Edge_Handler (H : Edge_Handler) is
   begin
      On_Edge := H;
   end Set_Edge_Handler;

   --  One selection of the chip in mode 0 at its divisor, the bus left in
   --  mode 3 for the other devices.
   procedure Frame (Tx : Byte_Array; Rx : out Byte_Array)
     with Pre => Rx'Length >= Tx'Length
   is
   begin
      SPI.Set_Mode (Bus, Leading_Edge => True);
      SPI.Set_Divisor (Bus, Divisor);
      if Has_CS then
         GPIO.Set_Low (CS);
      end if;
      SPI.Transfer (Bus, Tx, Rx);
      if Has_CS then
         GPIO.Set_High (CS);
      end if;
      SPI.Set_Mode (Bus, Leading_Edge => False);
   end Frame;

   procedure Write_Byte (Data : Byte) is
      Rx : Byte_Array (0 .. 0);
   begin
      Frame ((0 => Data), Rx);
   end Write_Byte;

   procedure Write_Command (Command : Byte; Data : Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Frame ((Command, Data), Rx);
   end Write_Command;

   procedure Write_Command_Multi (Command : Byte; Data : Byte_Array) is
      Tx : Byte_Array (0 .. Data'Length);
      Rx : Byte_Array (0 .. Data'Length);
   begin
      Tx (0) := Command;
      Tx (1 .. Data'Length) := Data;
      Frame (Tx, Rx);
   end Write_Command_Multi;

   procedure Read_Command (Command : Byte; Value : out Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Frame ((Command, Dummy), Rx);
      Value := Rx (1);
   end Read_Command;

   procedure Read_Command_Multi (Command : Byte; Data : out Byte_Array) is
      Tx : Byte_Array (0 .. Data'Length) := (others => Dummy);
      Rx : Byte_Array (0 .. Data'Length);
   begin
      Tx (0) := Command;
      Frame (Tx, Rx);
      Data := Rx (1 .. Data'Length);
   end Read_Command_Multi;

   procedure Exchange (Data : in out Byte_Array) is
      Tx : constant Byte_Array (0 .. Data'Length - 1) := Data;
      Rx : Byte_Array (0 .. Data'Length - 1);
   begin
      Frame (Tx, Rx);
      Data := Rx;
   end Exchange;

   procedure Send (Data : Byte_Array) is
      Tx : constant Byte_Array (0 .. Data'Length - 1) := Data;
      Rx : Byte_Array (0 .. Data'Length - 1);
   begin
      Frame (Tx, Rx);
   end Send;

   procedure Exchange_Pair (Head : Byte_Array; Tail : in out Byte_Array) is
      Tx : constant Byte_Array (0 .. Head'Length + Tail'Length - 1) := Head & Tail;
      Rx : Byte_Array (Tx'Range);
   begin
      Frame (Tx, Rx);
      Tail := Rx (Head'Length .. Rx'Last);
   end Exchange_Pair;

   procedure Send_Pair (Head : Byte_Array; Tail : Byte_Array) is
      Tx : constant Byte_Array (0 .. Head'Length + Tail'Length - 1) := Head & Tail;
      Rx : Byte_Array (Tx'Range);
   begin
      Frame (Tx, Rx);
   end Send_Pair;
end Adaflight.STM32.RX_SPI_Device;
