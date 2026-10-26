--  The MAX7456 and AT7456E character OSD chips. Detection reads the OSD
--  insertion register at 5 MHz, tells the AT7456E by its ninth character
--  address bit, sets the clock from the configured setting and resets the
--  chip. The video system, the offsets, the brightness, the display memory
--  mode and the background are set when a stall check or the video signal
--  asks for it. Characters go to a layer of 480; a draw compares the layer
--  with a shadow of what the chip shows and sends the changed characters in
--  address runs, bounded by a byte budget and an encoding time, and a full
--  refresh draws until the screen is done. A font character is written to
--  the chip's character memory and stops further drawing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The chip's SPI device: the select pin before and during detection, the
--  bus instance, the clock divisor for a frequency and the clock a divisor
--  gives, register writes, register reads with the read bit set, a byte or a
--  buffer written alone, a transfer started for the bus to finish, whether
--  the bus is busy, uses DMA or still has the driver's transfer pending, a
--  wait for the bus, the millisecond and microsecond clocks, delays and the
--  status LED.
generic
   type SPI_Device is limited private;
   with procedure Preinit_CS (D : in out SPI_Device; Tag : Byte; Push_Pull : Boolean);
   with procedure Attach_Bus (D : in out SPI_Device; Instance : Byte; OK : out Boolean);
   with procedure Check_CS_Free (D : in out SPI_Device; Free : out Boolean);
   with procedure Prepare_CS (D : in out SPI_Device);
   with procedure Release_CS (D : in out SPI_Device);
   with procedure Claim_CS (D : in out SPI_Device);
   with procedure Divider (D : in out SPI_Device; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16);
   with function Clock_Of (D : SPI_Device; Divisor : Interfaces.Unsigned_16) return Interfaces.Unsigned_32;
   with procedure Set_Divisor (D : in out SPI_Device; Divisor : Interfaces.Unsigned_16);
   with procedure Write_Byte (D : in out SPI_Device; Value : Byte);
   with procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : Byte);
   with procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte);
   with procedure Write_Buffer (D : in out SPI_Device; Data : Byte_Array);
   with procedure Start_Transfer (D : in out SPI_Device; Data : Byte_Array);
   with procedure Check_Busy (D : in out SPI_Device; Busy : out Boolean);
   with function Uses_DMA (D : SPI_Device) return Boolean;
   with function Transfer_Pending (D : SPI_Device) return Boolean;
   with procedure Wait (D : in out SPI_Device);
   with procedure Millis (D : in out SPI_Device; Now : out Interfaces.Unsigned_32);
   with procedure Micros (D : in out SPI_Device; Now : out Interfaces.Unsigned_32);
   with procedure Delay_Ms (D : in out SPI_Device; Ms : Natural);
   with procedure Delay_Us (D : in out SPI_Device; Us : Natural);
   with procedure Toggle_LED (D : in out SPI_Device);
package Adaflight.MAX7456 with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   Chars_Per_Line : constant := 30;
   Lines_PAL      : constant := 16;
   Lines_NTSC     : constant := 13;
   Chars_PAL      : constant := 480;
   Chars_NTSC     : constant := 390;

   subtype Screen_Index is Natural range 0 .. Chars_PAL - 1;
   type Screen is array (Screen_Index) of Byte;

   --  The foreground and the background layer.
   subtype Layer_Index is Natural range 0 .. 1;
   type Layer_Buffers is array (Layer_Index) of Screen;

   subtype Screen_Count is Natural range Chars_NTSC .. Chars_PAL;

   --  The transfer a draw builds, with room for the 6 bytes an encoding can
   --  pass the reference's 250.
   subtype Transfer_Index is Natural range 0 .. 255;
   subtype Transfer_Buffer is Byte_Array (Transfer_Index);

   subtype Font_Bytes is Byte_Array (0 .. 53);

   subtype Debug_Index is Natural range 0 .. 7;
   type Debug_Values is array (Debug_Index) of Interfaces.Integer_16;

   Signal_Debug : constant := 22;
   Clock_Debug  : constant := 23;

   type Init_Status is (Init_OK, Init_Not_Found, Init_Not_Configured);

   --  The SPI clock setting (half, nominal, double, anything else nominal),
   --  the select pin's tag (0 when the board has none), the bus instance and
   --  whether the pin rests driven high before the driver starts.
   type Config is record
      Clock_Config : Byte := 1;
      CS_Tag       : Byte := 0;
      SPI_Instance : Byte := 0;
      Pre_Init_OPU : Boolean := False;
   end record;

   --  The video system (automatic, PAL, NTSC, HD) and the character offsets.
   type Video_Profile is record
      Video_System : Byte := 0;
      H_Offset     : Interfaces.Integer_8 := 0;
      V_Offset     : Interfaces.Integer_8 := 0;
   end record;

   type Device_Kind is (MAX_Device, AT_Device);

   --  The layers, the shadow of the chip's display memory, the transfer
   --  buffer, the register values the driver keeps, the times of the stall
   --  and signal checks, the draw position, the debug mode and values.
   type State is record
      Layers            : Layer_Buffers := (others => (others => 0));
      Active_Layer      : Layer_Index := 0;
      Detected          : Boolean := False;
      Clock_Divisor     : Interfaces.Unsigned_16 := 0;
      Screen_Size       : Screen_Count := Chars_PAL;
      Shadow            : Screen := (others => 0);
      Transfer          : Transfer_Buffer := (others => 0);
      Video_Config      : Byte := 0;
      Video_Register    : Byte := 16#08#;
      DMM_Register      : Byte := 0;
      HOS               : Byte := 0;
      VOS               : Byte := 0;
      Device_Type       : Device_Kind := MAX_Device;
      Background        : Natural := 0;
      Previous_BW       : Byte := 255;
      Previous_Invert   : Byte := 255;
      Last_Signal_Check : Interfaces.Unsigned_32 := 0;
      Video_Detect_Time : Interfaces.Unsigned_32 := 0;
      Reinit_Count      : Interfaces.Unsigned_16 := 0;
      Last_Stall_Check  : Interfaces.Unsigned_32 := 500;
      Position          : Screen_Index := 0;
      Debug_Mode        : Byte := 0;
      Debug             : Debug_Values := (others => 0);
   end record;

   procedure Preinit (D : in out SPI_Device; C : Config);

   procedure Hardware_Reset (D : in out SPI_Device);

   procedure Init
     (D             : in out SPI_Device;
      S             : in out State;
      C             : Config;
      Profile       : Video_Profile;
      CPU_Overclock : Boolean;
      Status        : out Init_Status);

   procedure Invert (D : in out SPI_Device; S : in out State; On : Boolean);

   procedure Brightness (D : in out SPI_Device; S : in out State; Black : Byte; White : Byte);

   procedure Clear_Screen (S : in out State)
     with Global => null;

   procedure Write_Char (S : in out State; X : Byte; Y : Byte; C : Byte)
     with Global => null;

   --  The text up to its first 0 or the end of the line.
   procedure Write (S : in out State; X : Byte; Y : Byte; Text : Byte_Array)
     with Global => null;

   function Layer_Supported (Layer : Natural) return Boolean is (Layer = 0);

   procedure Layer_Select (S : in out State; Layer : Natural; Selected : out Boolean)
     with Global => null;

   procedure Layer_Copy (S : in out State; Destination : Natural; Source : Natural; Copied : out Boolean)
     with Global => null;

   function DMA_In_Progress (D : SPI_Device) return Boolean is (Transfer_Pending (D));

   function Buffers_Synced (S : State) return Boolean
     with Global => null;

   function Rows_Count (S : State) return Byte is
     (if (S.Video_Register and 16#40#) /= 0 then Lines_PAL else Lines_NTSC);

   procedure Re_Init_If_Required
     (D                 : in out SPI_Device;
      S                 : in out State;
      Force_Stall_Check : Boolean;
      Stalled           : out Boolean);

   procedure Draw_Screen (D : in out SPI_Device; S : in out State; In_Progress : out Boolean);

   procedure Refresh_All (D : in out SPI_Device; S : in out State);

   procedure Write_NVM
     (D            : in out SPI_Device;
      S            : State;
      Char_Address : Byte;
      Font_Data    : Font_Bytes;
      Written      : out Boolean);

   procedure Set_Background (D : in out SPI_Device; S : in out State; Background : Natural);

end Adaflight.MAX7456;
