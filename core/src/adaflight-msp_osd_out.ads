--  The MSP out messages of the OSD: the configuration with the display
--  device, alarms, element positions, statistics, timers, warnings,
--  profiles, stick overlay and camera frame, and the warnings line with its
--  severity and blink. A configuration reply to the MSP display port's own
--  serial port keeps the layout of the first 80 elements without the RSSI
--  dBm alarm. The caller gathers the settings, the display device's type and
--  readiness and the rendered warnings line into a snapshot.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Format;
with Adaflight.OSD_Stats;
with Adaflight.OSD_Task;
with Adaflight.OSD_Warnings;

package Adaflight.MSP_OSD_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   OSD_Config_Command   : constant := 84;
   OSD_Warnings_Command : constant := 16#3005#;

   Item_Count        : constant := Adaflight.OSD_Elements.Item_Count;
   Legacy_Item_Count : constant := 80;
   Stat_Count        : constant := Adaflight.OSD_Stats.Stat'Pos (Adaflight.OSD_Stats.Stat'Last) + 1;
   Warning_Count     : constant :=
     Adaflight.OSD_Warnings.Warning_Kind'Pos (Adaflight.OSD_Warnings.Warning_Kind'Last) + 1;
   Timer_Count       : constant := 2;
   Max_Reply_Length  : constant := 32 + 2 * Item_Count + Stat_Count;

   type Snapshot is record
      OSD                 : Boolean := False;
      --  The build's options: the analog video system setting, the OSD
      --  profiles, the stick overlay, the MSP display port's font and the
      --  frame buffer OSD.
      Video_System_Option : Boolean := False;
      Profiles            : Boolean := False;
      Stick_Overlay       : Boolean := False;
      Display_Port_Font   : Boolean := False;
      Frame_Buffer_OSD    : Boolean := False;
      --  The request came from the MSP display port's serial port.
      VTX_Port            : Boolean := False;
      Device              : Adaflight.OSD_Task.Device_Kind := Adaflight.OSD_Task.None;
      Device_Ready        : Boolean := False;
      Video_System        : Unsigned_8 := 0;
      Units               : Adaflight.OSD_Format.Unit_System := Adaflight.OSD_Format.Metric;
      RSSI_Alarm          : Unsigned_8 := 0;
      Cap_Alarm           : Unsigned_16 := 0;
      Alt_Alarm           : Unsigned_16 := 0;
      Positions           : Adaflight.OSD_Elements.Positions := (others => 0);
      Stats               : Adaflight.OSD_Stats.Stat_Set := (others => False);
      Timers              : Adaflight.OSD_Elements.Timer_Settings := (others => 0);
      Warnings            : Adaflight.OSD_Warnings.Warning_Set := (others => False);
      Profile_Index       : Adaflight.OSD_Elements.Profile_Number := 1;
      Overlay_Radio_Mode  : Unsigned_8 := 0;
      Camera_Frame_Width  : Unsigned_8 := 0;
      Camera_Frame_Height : Unsigned_8 := 0;
      Link_Quality_Alarm  : Unsigned_16 := 0;
      RSSI_Dbm_Alarm      : Integer_16 := 0;
      Warning_Line        : Adaflight.OSD_Warnings.Text;
      Warning_Blinking    : Boolean := False;
      Warning_Severity    : Adaflight.OSD_Warnings.Severity := Adaflight.OSD_Warnings.Normal;
   end record;

   --  Both messages need the OSD built.
   function Handles (Command : Unsigned_16; V : Snapshot) return Boolean is
     (Command in OSD_Config_Command | OSD_Warnings_Command and then V.OSD);

   --  The reply to one of these out messages; a command not handled writes
   --  nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Handles (Command, V) then S.Next = S.Next'Old);

end Adaflight.MSP_OSD_Out;
