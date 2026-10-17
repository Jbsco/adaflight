with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_OSD_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   General_Address : constant := 255;
   Timer_Address   : constant := 254;
   Timer_Count     : constant := 2;
   Stat_Count      : constant := 31;
   Item_Count      : constant := 99;
   Profile_Count   : constant := 3;
   NTSC            : constant := 2;
   HD              : constant := 3;
   HD_Cols         : constant := 53;
   HD_Rows         : constant := 20;
   SD_Cols         : constant := 30;
   NTSC_Rows       : constant := 13;
   PAL_Rows        : constant := 16;
   Device_Auto     : constant := 1;
   Device_MSP      : constant := 3;
   Configured      : constant := 1;

   --  A plan of writes, checked together.
   procedure Set_Fields (C : in out Configuration; Fields : Plan; R : out Result)
     with Pre  => Fits (Fields),
          Post => (if R = Error then C = C'Old)
   is
   begin
      if not Valid (Fields) then
         R := Error;
         return;
      end if;
      Apply (C, Fields);
      R := Ack;
   end Set_Fields;

   --  The video system, with the canvas and display port of HD or SD when
   --  it switches between them, the units, the alarms, and while bytes
   --  remain the warnings in 16 and then 32 bits, a profile up to the three,
   --  the stick overlay, the camera frame, and the link quality and RSSI
   --  alarms.
   procedure Set_General (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Video   : constant Integer_64 := U8 (Request, 1);
      Stored  : constant Interfaces.Unsigned_8 := C.Vcd_Profile.Video_System;
      Pos     : Natural range 10 .. 22 := 10;
      Profile : Integer_64 := -1;
      P       : Plan;

      --  The bytes the request holds past a position.
      function Remaining (At_Pos : Natural) return Natural is
        (if Request'Length > At_Pos then Request'Length - At_Pos else 0);
   begin
      Add (P, Vcd_Video_System, Video, 0);
      Add (P, Osd_Units, U8 (Request, 2), 0);
      Add (P, Osd_Rssi_Alarm, U8 (Request, 3), 0);
      Add (P, Osd_Cap_Alarm, U16 (Request, 4), 0);
      Add (P, Osd_Alt_Alarm, U16 (Request, 8), 0);
      if Remaining (Pos) >= 2 then
         Add (P, Osd_Warn_Bitmask, U16 (Request, Pos), 0);
         Pos := Pos + 2;
      end if;
      if Remaining (Pos) >= 4 then
         Add (P, Osd_Warn_Bitmask, U32 (Request, Pos), 0);
         Pos := Pos + 4;
      end if;
      if Remaining (Pos) >= 1 then
         if U8 (Request, Pos) <= Profile_Count then
            Profile := U8 (Request, Pos);
            Add (P, Osd_Profile, Profile, 0);
         end if;
         Pos := Pos + 1;
      end if;
      if Remaining (Pos) >= 1 then
         Add (P, Osd_Stick_Overlay_Radio_Mode, U8 (Request, Pos), 0);
         Pos := Pos + 1;
      end if;
      if Remaining (Pos) >= 2 then
         Add (P, Osd_Camera_Frame_Width, U8 (Request, Pos), 0);
         Add (P, Osd_Camera_Frame_Height, U8 (Request, Pos + 1), 0);
         Pos := Pos + 2;
      end if;
      if Remaining (Pos) >= 2 then
         Add (P, Osd_Link_Quality_Alarm, U16 (Request, Pos), 0);
         Pos := Pos + 2;
      end if;
      if Remaining (Pos) >= 2 then
         Add (P, Osd_Rssi_Dbm_Alarm, S16 (Request, Pos), 0);
      end if;
      if not Valid (P) then
         R := Error;
         return;
      end if;
      if Video = HD and then Stored /= HD then
         C.Osd_Config.Canvas_Cols := HD_Cols;
         C.Osd_Config.Canvas_Rows := HD_Rows;
         C.Osd_Config.Display_Port_Device := Device_MSP;
      elsif Video /= HD and then Stored = HD then
         C.Osd_Config.Canvas_Cols := SD_Cols;
         C.Osd_Config.Canvas_Rows := (if Video = NTSC then NTSC_Rows else PAL_Rows);
         C.Osd_Config.Display_Port_Device := Device_Auto;
      end if;
      Apply (C, P);
      if Profile >= 0 then
         E.Profile_Change := True;
         E.Profile := Byte (Profile);
         E.OSD_Elements := True;
      end if;
      R := Ack;
   end Set_General;

   --  A timer by index, within the two, and its value.
   procedure Set_Timer (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Index : constant Integer_64 := U8 (Request, 1);
      P     : Plan;
   begin
      if Index >= Timer_Count then
         R := Error;
         return;
      end if;
      Add (P, (if Index = 0 then Osd_Tim1 else Osd_Tim2), U16 (Request, 2), 0);
      Set_Fields (C, P, R);
   end Set_Timer;

   --  A statistic's switch on the post flight screen, or an element's
   --  position on the flight screens; the screen is the flight screen
   --  when the request leaves it out.
   procedure Set_Element (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Address : constant Integer_64 := U8 (Request, 0);
      Value   : constant Integer_64 := U16 (Request, 1);
      Screen  : constant Integer_64 := (if Request'Length > 3 then U8 (Request, 3) else 1);
   begin
      if Screen = 0 and then Address < Stat_Count then
         declare
            Bit : constant Interfaces.Unsigned_32 := Interfaces.Shift_Left (1, Natural (Address));
         begin
            if Value /= 0 then
               C.Osd_Config.Enabled_Stats := C.Osd_Config.Enabled_Stats or Bit;
            else
               C.Osd_Config.Enabled_Stats := C.Osd_Config.Enabled_Stats and not Bit;
            end if;
         end;
      elsif Address < Item_Count then
         C.Osd_Element_Config.Item_Pos (Natural (Address)) := Interfaces.Unsigned_16 (Value);
         E.OSD_Elements := True;
      else
         R := Error;
         return;
      end if;
      R := Ack;
   end Set_Element;

   --  The canvas size; a board not yet in HD with the MSP display port
   --  switches to both and asks for its configuration to be written and a
   --  restart.
   procedure Set_Canvas (C : in out Configuration; Request : Byte_Array; E : in out Effects)
     with Pre => Request'Length <= Max_Request
   is
   begin
      C.Osd_Config.Canvas_Cols := Byte (U8 (Request, 0));
      C.Osd_Config.Canvas_Rows := Byte (U8 (Request, 1));
      if C.Vcd_Profile.Video_System /= HD or else C.Osd_Config.Display_Port_Device /= Device_MSP then
         C.Vcd_Profile.Video_System := HD;
         C.Osd_Config.Display_Port_Device := Device_MSP;
         C.System_Config.Configuration_State := Configured;
         E.Save := True;
         E.Reboot := True;
      end if;
   end Set_Canvas;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
   is
   begin
      E := No_Effects;
      case Command is
         when Set_OSD_Config_Command =>
            case U8 (Request, 0) is
               when General_Address =>
                  Set_General (C, Request, R, E);
               when Timer_Address =>
                  Set_Timer (C, Request, R);
               when others =>
                  Set_Element (C, Request, R, E);
            end case;
         when Set_OSD_Canvas_Command =>
            Set_Canvas (C, Request, E);
            R := Ack;
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_OSD_In;
