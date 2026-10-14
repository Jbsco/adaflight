package body Adaflight.MSP_OSD_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;

   --  The OSD flags: the feature, then the device's hardware bit and, when
   --  it is ready, the detected bit.
   function Flags (V : Snapshot) return Unsigned_8 is
      Feature_Bit      : constant Unsigned_8 := 16#01#;
      Frame_Buffer_Bit : constant Unsigned_8 := 16#04#;
      FrSky_Bit        : constant Unsigned_8 := 16#08#;
      MAX7456_Bit      : constant Unsigned_8 := 16#10#;
      Detected_Bit     : constant Unsigned_8 := (if V.Device_Ready then 16#20# else 0);
      MSP_Bit          : constant Unsigned_8 := 16#40#;
      Font_Bit         : constant Unsigned_8 := (if V.Display_Port_Font then 16#80# else 0);
   begin
      case V.Device is
         when Adaflight.OSD_Task.MAX7456 =>
            return Feature_Bit or MAX7456_Bit or Detected_Bit;
         when Adaflight.OSD_Task.FrSky_OSD =>
            return Feature_Bit or FrSky_Bit or Detected_Bit;
         when Adaflight.OSD_Task.MSP =>
            return Feature_Bit or MSP_Bit or Font_Bit or Detected_Bit;
         when Adaflight.OSD_Task.Framebuffer =>
            return (if V.Frame_Buffer_OSD then Feature_Bit or Frame_Buffer_Bit or Detected_Bit else Feature_Bit);
         when Adaflight.OSD_Task.None | Adaflight.OSD_Task.Auto =>
            return Feature_Bit;
      end case;
   end Flags;

   --  The enabled warnings as bits in the warnings' order.
   function Warning_Bits (W : Adaflight.OSD_Warnings.Warning_Set) return Interfaces.Unsigned_32 is
      use Adaflight.OSD_Warnings;
      Bits : Interfaces.Unsigned_32 := 0;
   begin
      for K in Warning_Kind loop
         if W (K) then
            Bits := Bits or Interfaces.Shift_Left (1, Warning_Kind'Pos (K));
         end if;
      end loop;
      return Bits;
   end Warning_Bits;

   function Wrapped (V : Integer_16) return Unsigned_16 is
     (if V < 0 then Unsigned_16 (Integer (V) + 65_536) else Unsigned_16 (V));

   procedure Config (B : in out Byte_Array; S : in out Stream; V : Snapshot)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next - S.Next'Old in 0 .. Max_Reply_Length and then S.Last = S.Last'Old
   is
      Count : constant Natural := (if V.VTX_Port then Legacy_Item_Count else Item_Count);
      Start : constant Position := S.Next with Ghost;
      Bits  : constant Interfaces.Unsigned_32 := Warning_Bits (V.Warnings);
   begin
      Write_U8 (B, S, Flags (V));
      Write_U8 (B, S, (if V.Video_System_Option then V.Video_System else 3));
      Write_U8 (B, S, Adaflight.OSD_Format.Unit_System'Pos (V.Units));
      Write_U8 (B, S, V.RSSI_Alarm);
      Write_U16 (B, S, V.Cap_Alarm);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, Unsigned_8 (Count));
      Write_U16 (B, S, V.Alt_Alarm);
      for I in 0 .. Count - 1 loop
         pragma Loop_Invariant (S.Next = Start + 10 + 2 * I and then S.Last = S.Last'Loop_Entry);
         Write_U16 (B, S, V.Positions (Adaflight.OSD_Elements.Item'Val (I)));
      end loop;
      Write_U8 (B, S, Stat_Count);
      for St in Adaflight.OSD_Stats.Stat loop
         pragma Loop_Invariant
           (S.Next = Start + 11 + 2 * Count + Adaflight.OSD_Stats.Stat'Pos (St) and then S.Last = S.Last'Loop_Entry);
         Write_U8 (B, S, Boolean'Pos (V.Stats (St)));
      end loop;
      Write_U8 (B, S, Timer_Count);
      Write_U16 (B, S, V.Timers (0));
      Write_U16 (B, S, V.Timers (1));
      Write_U16 (B, S, Unsigned_16 (Bits and 16#FFFF#));
      Write_U8 (B, S, Warning_Count);
      Write_U32 (B, S, Bits);
      if V.Profiles then
         Write_U8 (B, S, Adaflight.OSD_Elements.Profile_Count);
         Write_U8 (B, S, Unsigned_8 (V.Profile_Index));
      else
         Write_U8 (B, S, 1);
         Write_U8 (B, S, 1);
      end if;
      Write_U8 (B, S, (if V.Stick_Overlay then V.Overlay_Radio_Mode else 0));
      Write_U8 (B, S, V.Camera_Frame_Width);
      Write_U8 (B, S, V.Camera_Frame_Height);
      Write_U16 (B, S, V.Link_Quality_Alarm);
      if not V.VTX_Port then
         Write_U16 (B, S, Wrapped (V.RSSI_Dbm_Alarm));
      end if;
   end Config;

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
   begin
      if not Handles (Command, V) then
         return;
      end if;
      case Command is
         when OSD_Config_Command =>
            Config (B, S, V);
         when OSD_Warnings_Command =>
            Write_U8
              (B, S,
               Adaflight.OSD_Warnings.Severity'Pos (V.Warning_Severity)
               + (if V.Warning_Blinking then 16#80# else 0));
            Write_Prefixed_String (B, S, V.Warning_Line.Data (1 .. V.Warning_Line.Length));
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_OSD_Out;
