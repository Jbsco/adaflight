package body Adaflight.MAX7456 with SPARK_Mode is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;

   subtype U16 is Interfaces.Unsigned_16;
   subtype U32 is Interfaces.Unsigned_32;
   subtype I16 is Interfaces.Integer_16;

   Max_SPI_Clock_Hz      : constant := 10_000_000;
   Init_Max_SPI_Clock_Hz : constant := 5_000_000;

   VM0_Address  : constant Byte := 16#00#;
   VM1_Address  : constant Byte := 16#01#;
   HOS_Address  : constant Byte := 16#02#;
   VOS_Address  : constant Byte := 16#03#;
   DMM_Address  : constant Byte := 16#04#;
   DMAH_Address : constant Byte := 16#05#;
   DMAL_Address : constant Byte := 16#06#;
   DMDI_Address : constant Byte := 16#07#;
   CMM_Address  : constant Byte := 16#08#;
   CMAH_Address : constant Byte := 16#09#;
   CMAL_Address : constant Byte := 16#0A#;
   CMDI_Address : constant Byte := 16#0B#;
   OSDM_Address : constant Byte := 16#0C#;
   RB0_Address  : constant Byte := 16#10#;
   STAT_Address : constant Byte := 16#A0#;

   Chip_Reset    : constant Byte := 16#02#;
   OSD_Enable    : constant Byte := 16#08#;
   Video_PAL     : constant Byte := 16#40#;
   Auto_Inc      : constant Byte := 16#01#;
   Invert_Pixels : constant Byte := 16#08#;
   End_String    : constant Byte := 16#FF#;
   Write_NVR     : constant Byte := 16#A0#;

   Stat_PAL      : constant Byte := 16#01#;
   Stat_NTSC     : constant Byte := 16#02#;
   Stat_LOS      : constant Byte := 16#04#;
   Stat_NVR_Busy : constant Byte := 16#20#;

   OSDM_Default : constant Byte := 16#1B#;

   --  The two's complement byte of an offset.
   function Signed_Byte (V : Interfaces.Integer_8) return Byte is
     (if V >= 0 then Byte (V) else Byte (256 + Integer (V)))
     with Global => null;

   Video_Auto : constant Byte := 0;
   Video_PAL_System : constant Byte := 1;
   Video_NTSC_System : constant Byte := 2;

   Background_Transparent : constant := 0;
   Background_Black       : constant := 1;
   Background_Light_Gray  : constant := 3;

   Signal_Check_Interval_Ms : constant := 1000;
   Stall_Check_Interval_Ms  : constant := 1000;
   Video_Debounce_Ms        : constant := 100;

   Max_Bytes_DMA       : constant := 250;
   Max_Bytes_Polled    : constant := 12;
   Max_Encode_Us_DMA   : constant := 20;
   Max_Encode_Us_Polled : constant := 10;

   function VIN_Is_PAL (Sense : Byte) return Boolean is
     ((Sense and Stat_LOS) = 0 and then (Sense and Stat_PAL) /= 0);
   function VIN_Is_NTSC (Sense : Byte) return Boolean is
     ((Sense and Stat_LOS) = 0 and then (Sense and Stat_NTSC) /= 0);
   --  No loss of signal and no PAL counts as NTSC, as some AT7456E chips
   --  read the standard bits as zero.
   function VIN_Is_NTSC_Alt (Sense : Byte) return Boolean is
     ((Sense and Stat_LOS) = 0 and then (Sense and Stat_PAL) = 0);

   --  The low 16 bits as two's complement, as a debug value takes them.
   function Debug_Value (V : U32) return I16 is
     (if V mod 2 ** 16 >= 2 ** 15 then I16 (Integer (V mod 2 ** 16) - 2 ** 16) else I16 (V mod 2 ** 16))
     with Global => null;

   procedure Set_Debug (S : in out State; Mode : Byte; Index : Debug_Index; Value : U32)
     with Global => null
   is
   begin
      if S.Debug_Mode = Mode then
         S.Debug (Index) := Debug_Value (Value);
      end if;
   end Set_Debug;

   procedure Set_Register_VM1 (D : in out SPI_Device; S : State) is
      Gray : Byte := 4;
      VM1  : Byte := 16#04# or 16#03#;
   begin
      if S.Background /= Background_Transparent then
         VM1 := VM1 or 16#80#;
         if S.Background = Background_Black then
            Gray := 0;
         elsif S.Background = Background_Light_Gray then
            Gray := 7;
         else
            Gray := 4;
         end if;
      end if;
      VM1 := VM1 or Gray * 16;
      Write_Register (D, VM1_Address, VM1);
   end Set_Register_VM1;

   procedure Clear_Shadow (S : in out State)
     with Global => null
   is
   begin
      for I in 0 .. S.Screen_Size - 1 loop
         S.Shadow (I) := 0;
      end loop;
   end Clear_Shadow;

   procedure Clear_Layer (S : in out State; Layer : Layer_Index)
     with Global => null
   is
   begin
      S.Layers (Layer) := (others => 16#20#);
   end Clear_Layer;

   procedure Re_Init (D : in out SPI_Device; S : in out State) is
      Sense : Byte;
   begin
      if S.Video_Config = Video_PAL_System then
         S.Video_Register := Video_PAL or OSD_Enable;
      elsif S.Video_Config = Video_NTSC_System then
         S.Video_Register := OSD_Enable;
      elsif S.Video_Config = Video_Auto then
         Read_Register (D, STAT_Address, Sense);
         if VIN_Is_NTSC (Sense) then
            S.Video_Register := OSD_Enable;
         elsif VIN_Is_PAL (Sense) then
            S.Video_Register := Video_PAL or OSD_Enable;
         else
            S.Video_Register := Video_PAL or OSD_Enable;
         end if;
      end if;
      S.Screen_Size := (if (S.Video_Register and Video_PAL) /= 0 then Chars_PAL else Chars_NTSC);
      S.Previous_BW := 255;
      Brightness (D, S, 0, 2);
      Write_Register (D, VM0_Address, S.Video_Register);
      Write_Register (D, HOS_Address, S.HOS);
      Write_Register (D, VOS_Address, S.VOS);
      Set_Register_VM1 (D, S);
      Clear_Shadow (S);
   end Re_Init;

   procedure Preinit (D : in out SPI_Device; C : Config) is
   begin
      Preinit_CS (D, C.CS_Tag, C.Pre_Init_OPU);
   end Preinit;

   procedure Hardware_Reset (D : in out SPI_Device) is
   begin
      Delay_Ms (D, 50);
   end Hardware_Reset;

   procedure Init
     (D             : in out SPI_Device;
      S             : in out State;
      C             : Config;
      Profile       : Video_Profile;
      CPU_Overclock : Boolean;
      Status        : out Init_Status)
   is
      OK      : Boolean;
      Free    : Boolean;
      Divisor : U16;
      Value   : Byte;
   begin
      S.Detected := False;
      S.Background := Background_Transparent;
      for L in Layer_Index loop
         Clear_Layer (S, L);
      end loop;
      Hardware_Reset (D);
      if C.CS_Tag = 0 then
         Status := Init_Not_Configured;
         return;
      end if;
      Attach_Bus (D, C.SPI_Instance, OK);
      if not OK then
         Status := Init_Not_Configured;
         return;
      end if;
      Check_CS_Free (D, Free);
      if not Free then
         Status := Init_Not_Configured;
         return;
      end if;
      Prepare_CS (D);
      Divider (D, Init_Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Write_Byte (D, End_String);
      Read_Register (D, OSDM_Address, Value);
      if Value /= OSDM_Default then
         Release_CS (D);
         Status := Init_Not_Found;
         return;
      end if;
      S.Detected := True;
      Claim_CS (D);
      Write_Register (D, CMAL_Address, 16#40#);
      Read_Register (D, CMAL_Address, Value);
      S.Device_Type := (if (Value and 16#40#) /= 0 then AT_Device else MAX_Device);
      if C.Clock_Config = 0 then
         Divider (D, Max_SPI_Clock_Hz / 2, S.Clock_Divisor);
      elsif C.Clock_Config = 2 then
         Divider (D, Max_SPI_Clock_Hz * 2, S.Clock_Divisor);
      else
         Divider (D, Max_SPI_Clock_Hz, S.Clock_Divisor);
      end if;
      Set_Debug (S, Clock_Debug, 0, Boolean'Pos (CPU_Overclock));
      Set_Debug (S, Clock_Debug, 1, Device_Kind'Pos (S.Device_Type));
      Set_Debug (S, Clock_Debug, 2, U32 (S.Clock_Divisor));
      Set_Debug (S, Clock_Debug, 3, Clock_Of (D, S.Clock_Divisor) / 10_000);
      Set_Divisor (D, S.Clock_Divisor);
      Write_Register (D, VM0_Address, Chip_Reset);
      Delay_Us (D, 200);
      loop
         Read_Register (D, VM0_Address, Value);
         exit when (Value and Chip_Reset) = 0;
      end loop;
      S.Video_Config := Profile.Video_System;
      S.HOS := 32 - Signed_Byte (Profile.H_Offset);
      S.VOS := 16 - Signed_Byte (Profile.V_Offset);
      Status := Init_OK;
   end Init;

   procedure Invert (D : in out SPI_Device; S : in out State; On : Boolean) is
   begin
      if On then
         S.DMM_Register := S.DMM_Register or Invert_Pixels;
      else
         S.DMM_Register := S.DMM_Register and not Invert_Pixels;
      end if;
      if S.DMM_Register /= S.Previous_Invert then
         Clear_Shadow (S);
         S.Previous_Invert := S.DMM_Register;
         Write_Register (D, DMM_Address, S.DMM_Register);
      end if;
   end Invert;

   procedure Brightness (D : in out SPI_Device; S : in out State; Black : Byte; White : Byte) is
      Value  : constant Byte := (Black * 4) or (3 - White);
      Buffer : Byte_Array (0 .. 31) := (others => 0);
   begin
      if Value /= S.Previous_BW then
         S.Previous_BW := Value;
         for I in 0 .. 15 loop
            Buffer (2 * I) := RB0_Address + Byte (I);
            Buffer (2 * I + 1) := Value;
         end loop;
         Write_Buffer (D, Buffer);
      end if;
   end Brightness;

   procedure Clear_Screen (S : in out State) is
   begin
      Clear_Layer (S, S.Active_Layer);
   end Clear_Screen;

   procedure Write_Char (S : in out State; X : Byte; Y : Byte; C : Byte) is
   begin
      if X < Chars_Per_Line and then Y < Lines_PAL then
         S.Layers (S.Active_Layer) (Natural (Y) * Chars_Per_Line + Natural (X)) := C;
      end if;
   end Write_Char;

   procedure Write (S : in out State; X : Byte; Y : Byte; Text : Byte_Array) is
      Offset : Natural;
      Column : Natural := Natural (X);
   begin
      if Y < Lines_PAL then
         Offset := Natural (Y) * Chars_Per_Line;
         for I in Text'Range loop
            exit when Text (I) = 0 or else Column >= Chars_Per_Line;
            S.Layers (S.Active_Layer) (Offset + Column) := Text (I);
            Column := Column + 1;
         end loop;
      end if;
   end Write;

   procedure Layer_Select (S : in out State; Layer : Natural; Selected : out Boolean) is
   begin
      if Layer_Supported (Layer) then
         S.Active_Layer := Layer;
         Selected := True;
      else
         Selected := False;
      end if;
   end Layer_Select;

   procedure Layer_Copy (S : in out State; Destination : Natural; Source : Natural; Copied : out Boolean) is
   begin
      if Source /= Destination and then Layer_Supported (Source) and then Layer_Supported (Destination) then
         S.Layers (Destination) := S.Layers (Source);
         Copied := True;
      else
         Copied := False;
      end if;
   end Layer_Copy;

   function Buffers_Synced (S : State) return Boolean is
   begin
      for I in 0 .. S.Screen_Size - 1 loop
         if S.Layers (0) (I) /= S.Shadow (I) then
            return False;
         end if;
      end loop;
      return True;
   end Buffers_Synced;

   procedure Re_Init_If_Required
     (D                 : in out SPI_Device;
      S                 : in out State;
      Force_Stall_Check : Boolean;
      Stalled           : out Boolean)
   is
      Now   : U32;
      Later : U32;
      Value : Byte;
      Sense : Byte;
   begin
      Millis (D, Now);
      Stalled := False;
      if Force_Stall_Check or else S.Last_Stall_Check + Stall_Check_Interval_Ms < Now then
         S.Last_Stall_Check := Now;
         Write_Byte (D, End_String);
         Read_Register (D, VM0_Address, Value);
         Stalled := Value /= S.Video_Register;
      end if;
      if Stalled then
         Re_Init (D, S);
      elsif S.Video_Config = Video_Auto and then Now - S.Last_Signal_Check > Signal_Check_Interval_Ms then
         Write_Byte (D, End_String);
         Read_Register (D, STAT_Address, Sense);
         Set_Debug (S, Signal_Debug, 0, U32 (S.Video_Register and Video_PAL));
         Set_Debug (S, Signal_Debug, 1, U32 (Sense and 7));
         Set_Debug (S, Signal_Debug, 3, U32 (Rows_Count (S)));
         if (Sense and Stat_LOS) /= 0 then
            S.Video_Detect_Time := 0;
         elsif (VIN_Is_PAL (Sense) and then (S.Video_Register and Video_PAL) = 0)
           or else (VIN_Is_NTSC_Alt (Sense) and then (S.Video_Register and Video_PAL) /= 0)
         then
            if S.Video_Detect_Time /= 0 then
               Millis (D, Later);
               if Later - S.Video_Detect_Time > Video_Debounce_Ms then
                  Re_Init (D, S);
                  if S.Debug_Mode = Signal_Debug then
                     S.Reinit_Count := S.Reinit_Count + 1;
                     S.Debug (2) := Debug_Value (U32 (S.Reinit_Count));
                  end if;
               end if;
            else
               Millis (D, Later);
               S.Video_Detect_Time := Later;
            end if;
         end if;
         S.Last_Signal_Check := Now;
      end if;
   end Re_Init_If_Required;

   --  A time difference in microseconds as a signed 32-bit value.
   function Elapsed (Now : U32; Start : U32) return Interfaces.Integer_32 is
     (if Now - Start >= 2 ** 31 then Interfaces.Integer_32 (Interfaces.Integer_64 (Now - Start) - 2 ** 32)
      else Interfaces.Integer_32 (Now - Start))
     with Global => null;

   --  Whether the character after a position changed. Past the end of the
   --  buffers it counts as changed.
   function Next_Changed (S : State; Layer : Layer_Index; Position : Screen_Index) return Boolean is
     (if Position < Screen_Index'Last then S.Layers (Layer) (Position + 1) /= S.Shadow (Position + 1) else True)
     with Global => null;

   procedure Draw_Screen (D : in out SPI_Device; S : in out State; In_Progress : out Boolean) is
      Layer       : constant Layer_Index := S.Active_Layer;
      Index       : Natural := 0;
      Max_Start   : Natural;
      Max_Encode  : Interfaces.Integer_32;
      Set_Address : Boolean := True;
      Increment   : Boolean := False;
      Pos_Limit   : Natural;
      Busy        : Boolean;
      Start       : U32;
      Now         : U32;
      P           : Screen_Index;
   begin
      Pos_Limit := S.Position + S.Screen_Size / 2;
      if Uses_DMA (D) then
         Max_Start := Max_Bytes_DMA;
         Max_Encode := Max_Encode_Us_DMA;
      else
         Max_Start := Max_Bytes_Polled;
         Max_Encode := Max_Encode_Us_Polled;
      end if;
      Check_Busy (D, Busy);
      if Busy then
         In_Progress := True;
         return;
      end if;
      Micros (D, Start);
      Max_Start := Max_Start - 4;
      loop
         exit when Index >= Max_Start or else S.Position >= Pos_Limit;
         Micros (D, Now);
         exit when Elapsed (Now, Start) >= Max_Encode;
         pragma Loop_Invariant (Index mod 2 = 0 and then Index < Max_Start and then Max_Start <= 246);
         P := S.Position;
         if S.Layers (Layer) (P) /= S.Shadow (P) then
            if S.Layers (Layer) (P) = 16#FF# then
               S.Layers (Layer) (P) := 16#20#;
            end if;
            if Set_Address or else not Increment then
               S.Transfer (Index) := DMM_Address;
               if Next_Changed (S, Layer, P) then
                  S.Transfer (Index + 1) := S.DMM_Register or Auto_Inc;
                  Increment := True;
               else
                  S.Transfer (Index + 1) := S.DMM_Register;
                  Increment := False;
               end if;
               S.Transfer (Index + 2) := DMAH_Address;
               S.Transfer (Index + 3) := Byte (P / 256);
               S.Transfer (Index + 4) := DMAL_Address;
               S.Transfer (Index + 5) := Byte (P mod 256);
               Index := Index + 6;
               Set_Address := False;
            end if;
            S.Transfer (Index) := DMDI_Address;
            S.Transfer (Index + 1) := S.Layers (Layer) (P);
            Index := Index + 2;
            S.Shadow (P) := S.Layers (Layer) (P);
         elsif not Set_Address then
            Set_Address := True;
            if Increment then
               S.Transfer (Index) := DMDI_Address;
               S.Transfer (Index + 1) := End_String;
               Index := Index + 2;
            end if;
         end if;
         if P + 1 >= S.Screen_Size then
            S.Position := 0;
            exit;
         end if;
         S.Position := P + 1;
      end loop;
      if Increment then
         if not Set_Address then
            S.Transfer (Index) := DMDI_Address;
            S.Transfer (Index + 1) := End_String;
            Index := Index + 2;
         end if;
         S.Transfer (Index) := DMM_Address;
         S.Transfer (Index + 1) := S.DMM_Register;
         Index := Index + 2;
      end if;
      if Index > 0 then
         Start_Transfer (D, S.Transfer (0 .. Index - 1));
      end if;
      In_Progress := S.Position /= 0;
   end Draw_Screen;

   procedure Refresh_All (D : in out SPI_Device; S : in out State) is
      Unused_Stalled : Boolean;
      In_Progress    : Boolean;
   begin
      Re_Init_If_Required (D, S, True, Unused_Stalled);
      loop
         Draw_Screen (D, S, In_Progress);
         exit when not In_Progress;
      end loop;
   end Refresh_All;

   procedure Write_NVM
     (D            : in out SPI_Device;
      S            : State;
      Char_Address : Byte;
      Font_Data    : Font_Bytes;
      Written      : out Boolean)
   is
      Value : Byte;
   begin
      if not S.Detected then
         Written := False;
         return;
      end if;
      Wait (D);
      Write_Register (D, VM0_Address, 0);
      Write_Register (D, CMAH_Address, Char_Address);
      for X in Font_Data'Range loop
         Write_Register (D, CMAL_Address, Byte (X));
         Write_Register (D, CMDI_Address, Font_Data (X));
         Toggle_LED (D);
      end loop;
      Write_Register (D, CMM_Address, Write_NVR);
      loop
         Read_Register (D, STAT_Address, Value);
         exit when (Value and Stat_NVR_Busy) = 0;
      end loop;
      Written := True;
   end Write_NVM;

   procedure Set_Background (D : in out SPI_Device; S : in out State; Background : Natural) is
   begin
      S.Background := Background;
      Set_Register_VM1 (D, S);
   end Set_Background;

end Adaflight.MAX7456;
