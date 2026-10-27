with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.Board;
with Adaflight.MAX7456;
with Adaflight.MAX7456.Display_Port;
with Adaflight.OSD_Canvas;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.OSD is
   use type Interfaces.Unsigned_8;
   use type Adaflight.OSD_Task.Device_Kind;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  The chip's SPI device: its bus, its select pin and the divisor its
   --  transfers take.
   type Chip_Bus is limited record
      Bus     : SPI.Bus := SPI.SPI3;
      CS      : Pin := (Port_A, 0);
      Has_CS  : Boolean := False;
      Divisor : Unsigned_16 := 256;
   end record;

   function Tagged_Pin (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Byte) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   --  One selection of the chip: the select pin low, the bytes out at the
   --  chip's divisor, the select pin high.
   procedure Frame (D : in out Chip_Bus; Tx : Byte_Array; Rx : out Byte_Array)
     with Pre => Rx'Length >= Tx'Length
   is
   begin
      GPIO.Set_Low (D.CS);
      SPI.Set_Divisor (D.Bus, D.Divisor);
      SPI.Transfer (D.Bus, Tx, Rx);
      GPIO.Set_High (D.CS);
   end Frame;

   procedure Preinit_CS (D : in out Chip_Bus; Tag : Byte; Push_Pull : Boolean) is
   begin
      if not Tagged_Pin (Tag) then
         return;
      end if;
      D.CS := Pin_Of (Tag);
      D.Has_CS := True;
      GPIO.Enable_Port (D.CS.Port);
      if Push_Pull then
         GPIO.Set_Output (D.CS);
         GPIO.Set_High (D.CS);
      else
         GPIO.Set_Input (D.CS, GPIO.Up);
      end if;
   end Preinit_CS;

   procedure Attach_Bus (D : in out Chip_Bus; Instance : Byte; OK : out Boolean) is
   begin
      OK := Instance in 1 .. 3 and then SPI.Started (SPI.Bus'Val (Instance - 1));
      if OK then
         D.Bus := SPI.Bus'Val (Instance - 1);
      end if;
   end Attach_Bus;

   procedure Check_CS_Free (D : in out Chip_Bus; Free : out Boolean) is
   begin
      Free := D.Has_CS;
   end Check_CS_Free;

   procedure Prepare_CS (D : in out Chip_Bus) is
   begin
      GPIO.Enable_Port (D.CS.Port);
      GPIO.Set_Output (D.CS);
      GPIO.Set_High (D.CS);
   end Prepare_CS;

   procedure Release_CS (D : in out Chip_Bus) is
   begin
      GPIO.Set_Input (D.CS, GPIO.Up);
   end Release_CS;

   procedure Claim_CS (D : in out Chip_Bus) is
      pragma Unreferenced (D);
   begin
      null;
   end Claim_CS;

   procedure Divider (D : in out Chip_Bus; Hz : Unsigned_32; Divisor : out Unsigned_16) is
      pragma Unreferenced (D);
   begin
      Divisor := SPI.Divider (Hz);
   end Divider;

   function Clock_Of (D : Chip_Bus; Divisor : Unsigned_16) return Unsigned_32 is
      pragma Unreferenced (D);
   begin
      return SPI.Clock_Of (Divisor);
   end Clock_Of;

   procedure Set_Divisor (D : in out Chip_Bus; Divisor : Unsigned_16) is
   begin
      D.Divisor := Divisor;
   end Set_Divisor;

   procedure Write_Byte (D : in out Chip_Bus; Value : Byte) is
      Rx : Byte_Array (0 .. 0);
   begin
      Frame (D, (0 => Value), Rx);
   end Write_Byte;

   procedure Write_Register (D : in out Chip_Bus; Register : Byte; Value : Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Frame (D, (Register, Value), Rx);
   end Write_Register;

   procedure Read_Register (D : in out Chip_Bus; Register : Byte; Value : out Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Frame (D, (Register or 16#80#, 16#FF#), Rx);
      Value := Rx (1);
   end Read_Register;

   procedure Write_Buffer (D : in out Chip_Bus; Data : Byte_Array) is
      Rx : Byte_Array (0 .. Data'Length - 1);
   begin
      if Data'Length > 0 then
         Frame (D, Data, Rx);
      end if;
   end Write_Buffer;

   procedure Check_Busy (D : in out Chip_Bus; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
   end Check_Busy;

   function Uses_DMA (D : Chip_Bus) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Uses_DMA;

   function Transfer_Pending (D : Chip_Bus) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Transfer_Pending;

   procedure Wait (D : in out Chip_Bus) is
      pragma Unreferenced (D);
   begin
      null;
   end Wait;

   procedure Millis (D : in out Chip_Bus; Now : out Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Time.Millis;
   end Millis;

   procedure Micros (D : in out Chip_Bus; Now : out Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Time.Micros;
   end Micros;

   procedure Delay_Ms (D : in out Chip_Bus; Ms : Natural) is
      pragma Unreferenced (D);
   begin
      Time.Delay_Ms (Ms);
   end Delay_Ms;

   procedure Delay_Us (D : in out Chip_Bus; Us : Natural) is
      pragma Unreferenced (D);
   begin
      Time.Delay_Us (Us);
   end Delay_Us;

   procedure Toggle_LED (D : in out Chip_Bus) is
      pragma Unreferenced (D);
   begin
      GPIO.Toggle (Adaflight.Board.LED0_Pin);
   end Toggle_LED;

   package Chip is new Adaflight.MAX7456
     (SPI_Device       => Chip_Bus,
      Preinit_CS       => Preinit_CS,
      Attach_Bus       => Attach_Bus,
      Check_CS_Free    => Check_CS_Free,
      Prepare_CS       => Prepare_CS,
      Release_CS       => Release_CS,
      Claim_CS         => Claim_CS,
      Divider          => Divider,
      Clock_Of         => Clock_Of,
      Set_Divisor      => Set_Divisor,
      Write_Byte       => Write_Byte,
      Write_Register   => Write_Register,
      Read_Register    => Read_Register,
      Write_Buffer     => Write_Buffer,
      Start_Transfer   => Write_Buffer,
      Check_Busy       => Check_Busy,
      Uses_DMA         => Uses_DMA,
      Transfer_Pending => Transfer_Pending,
      Wait             => Wait,
      Millis           => Millis,
      Micros           => Micros,
      Delay_Ms         => Delay_Ms,
      Delay_Us         => Delay_Us,
      Toggle_LED       => Toggle_LED);

   package Chip_Port is new Chip.Display_Port;

   Dev        : Chip_Bus;
   Chip_State : Chip.State;
   Port       : Chip_Port.Port;
   Kind       : Adaflight.OSD_Task.Device_Kind := Adaflight.OSD_Task.None;
   Present    : Boolean := False;

   function Chip_Config (C : Adaflight.Config_Groups.Configuration) return Chip.Config is
     ((Clock_Config => C.Max7456_Config.Clock_Config, CS_Tag => C.Max7456_Config.Cs_Tag,
       SPI_Instance => C.Max7456_Config.Spi_Device, Pre_Init_OPU => C.Max7456_Config.Pre_Init_Opu));

   function Video (C : Adaflight.Config_Groups.Configuration) return Chip.Video_Profile is
     ((Video_System => C.Vcd_Profile.Video_System, H_Offset => C.Vcd_Profile.H_Offset,
       V_Offset => C.Vcd_Profile.V_Offset));

   function Display (C : Adaflight.Config_Groups.Configuration) return Chip_Port.Display_Profile is
     ((Col_Adjust       => C.Display_Port_Profile_Max7456.Col_Adjust,
       Row_Adjust       => C.Display_Port_Profile_Max7456.Row_Adjust,
       Invert           => C.Display_Port_Profile_Max7456.Invert,
       Black_Brightness => C.Display_Port_Profile_Max7456.Black_Brightness,
       White_Brightness => C.Display_Port_Profile_Max7456.White_Brightness));

   function Overclock (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (C.System_Config.Cpu_Overclock /= 0);

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is
   begin
      Chip.Preinit (Dev, Chip_Config (C));
   end Preinit;

   procedure Init
     (C : in out Adaflight.Config_Groups.Configuration; Feature_OSD : Boolean; Disable_Feature : out Boolean)
   is
      Setting   : constant Byte := C.Osd_Config.Display_Port_Device;
      Available : Boolean;
      Ready     : Boolean;
   begin
      Disable_Feature := False;
      if not Feature_OSD then
         return;
      end if;
      if Setting = Adaflight.OSD_Task.Device_Kind'Pos (Adaflight.OSD_Task.Auto)
        or else Setting = Adaflight.OSD_Task.Device_Kind'Pos (Adaflight.OSD_Task.MAX7456)
      then
         Chip_Port.Init (Dev, Chip_State, Port, Chip_Config (C), Video (C), Display (C), Overclock (C), Available,
                         Ready);
         if Available or else Setting = Adaflight.OSD_Task.Device_Kind'Pos (Adaflight.OSD_Task.MAX7456) then
            Kind := Adaflight.OSD_Task.MAX7456;
            Present := Available;
         end if;
      end if;
      if Present then
         Adaflight.OSD_Canvas.Fit (C.Osd_Config, C.Osd_Element_Config, Port.Rows, Port.Cols);
      end if;
      Disable_Feature := Kind = Adaflight.OSD_Task.None;
   end Init;

   function Device return Adaflight.OSD_Task.Device_Kind is (Kind);

   function Port_Present return Boolean is (Present);

   procedure Dimensions (Columns, Rows : out Interfaces.Unsigned_8) is
   begin
      Columns := (if Present then Port.Cols else 0);
      Rows := (if Present then Port.Rows else 0);
   end Dimensions;

   procedure Check_Ready (C : Adaflight.Config_Groups.Configuration; Armed : Boolean; Ready : out Boolean) is
   begin
      if not Present then
         Ready := False;
         return;
      end if;
      Chip_Port.Check_Ready (Dev, Chip_State, Port, Chip_Config (C), Video (C), Display (C), Overclock (C), Armed,
                             Rescan => True, Ready => Ready);
   end Check_Ready;

   function Font_Write_Taken return Boolean is (Present and then Chip_State.Detected);

   procedure Write_Font (Address : Interfaces.Unsigned_16; Data : Adaflight.MSP_Font_In.Character_Data) is
      Bytes          : Chip_Port.Character_Data;
      Unused_Written : Boolean;
   begin
      for I in Data'Range loop
         Bytes (Bytes'First + I) := Data (I);
      end loop;
      Chip_Port.Write_Font_Character (Dev, Chip_State, Address, Bytes, Unused_Written);
   end Write_Font;
end Adaflight.STM32.OSD;
