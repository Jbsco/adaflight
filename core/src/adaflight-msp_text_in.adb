with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Text_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   Pilot_Name_Text           : constant := 1;
   Craft_Name_Text           : constant := 2;
   PID_Profile_Name_Text     : constant := 3;
   Rate_Profile_Name_Text    : constant := 4;
   First_Message_Text        : constant := 7;
   Last_Message_Text         : constant := 10;
   Battery_Profile_Name_Text : constant := 11;

   Name_Length           : constant := 16;
   Profile_Name_Length   : constant := 8;
   Battery_Profile_Bytes : constant := 13;
   Battery_Profile_Count : constant := 3;
   Max_Cell_Count        : constant := 24;
   Max_Warning_Percent   : constant := 100;

   --  A text of a length from the request at an offset, zero past its end,
   --  at the start of a field, then a zero after it; the field's later bytes
   --  keep their values.
   procedure Put_Text (Field : in out Config_Groups.Bytes; Request : Byte_Array; Offset : Natural; Length : Natural)
     with Pre => Request'Length <= Max_Request and then Offset <= 2 and then Length <= Name_Length
                 and then Field'First <= Field'Last and then Length <= Field'Last - Field'First
   is
   begin
      Field (Field'First + Length) := 0;
      for K in 0 .. Length - 1 loop
         Field (Field'First + K) := Byte (U8 (Request, Offset + K));
      end loop;
   end Put_Text;

   --  A text by its type: a length byte, cut at the text's room, then the
   --  text. A craft or pilot name has the OSD's elements analyzed again; a
   --  type outside the named ones is an error.
   procedure Set_Text (C : in out Configuration; Request : Byte_Array; R : out Result; E : out Effects)
     with Pre  => Profiles_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects)
   is
      Kind         : constant Integer_64 := U8 (Request, 0);
      Name_Size    : constant Natural := Natural (Integer_64'Min (U8 (Request, 1), Name_Length));
      Profile_Size : constant Natural := Natural (Integer_64'Min (U8 (Request, 1), Profile_Name_Length));
   begin
      R := Ack;
      E := No_Effects;
      case Kind is
         when Pilot_Name_Text =>
            Put_Text (C.Pilot_Config.Pilot_Name, Request, 2, Name_Size);
            E.OSD_Elements := True;
         when Craft_Name_Text =>
            Put_Text (C.Pilot_Config.Craft_Name, Request, 2, Name_Size);
            E.OSD_Elements := True;
         when PID_Profile_Name_Text =>
            Put_Text (C.Pid_Profiles (Natural (C.System_Config.Pid_Profile_Index)).Profile_Name, Request, 2,
                      Profile_Size);
         when Rate_Profile_Name_Text =>
            Put_Text (C.Control_Rate_Profiles (Natural (C.System_Config.Active_Rate_Profile)).Profile_Name,
                      Request, 2, Profile_Size);
         when First_Message_Text .. Last_Message_Text =>
            Put_Text (C.Pilot_Config.Message (Natural (Kind - First_Message_Text)), Request, 2, Name_Size);
         when Battery_Profile_Name_Text =>
            Put_Text (C.Battery_Profiles (Natural (C.System_Config.Active_Battery_Profile)).Profile_Name,
                      Request, 2, Profile_Size);
         when others =>
            R := Error;
      end case;
   end Set_Text;

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

   --  A profile, its minimum, maximum, warning and full cell voltages, its
   --  capacity, forced cell count and consumption warning percentage, in at
   --  least thirteen bytes; the voltages in order, at most 24 cells and 100
   --  percent.
   procedure Set_Battery_Profile (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Profile  : constant Integer_64 := U8 (Request, 0);
      Minimum  : constant Integer_64 := U16 (Request, 1);
      Maximum  : constant Integer_64 := U16 (Request, 3);
      Warning  : constant Integer_64 := U16 (Request, 5);
      Full     : constant Integer_64 := U16 (Request, 7);
      Capacity : constant Integer_64 := U16 (Request, 9);
      Cells    : constant Integer_64 := U8 (Request, 11);
      Percent  : constant Integer_64 := U8 (Request, 12);
      P        : Plan;
   begin
      if Request'Length < Battery_Profile_Bytes
        or else Profile >= Battery_Profile_Count
        or else Minimum > Warning
        or else Warning > Full
        or else Full > Maximum
        or else Cells > Max_Cell_Count
        or else Percent > Max_Warning_Percent
      then
         R := Error;
         return;
      end if;
      Add (P, Vbat_Min_Cell_Voltage, Minimum, Natural (Profile));
      Add (P, Vbat_Max_Cell_Voltage, Maximum, Natural (Profile));
      Add (P, Vbat_Warning_Cell_Voltage, Warning, Natural (Profile));
      Add (P, Vbat_Full_Cell_Voltage, Full, Natural (Profile));
      Add (P, Bat_Capacity, Capacity, Natural (Profile));
      Add (P, Force_Battery_Cell_Count, Cells, Natural (Profile));
      Add (P, Cbat_Alert_Percent, Percent, Natural (Profile));
      Set_Fields (C, P, R);
   end Set_Battery_Profile;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
   is
      P : Plan;
   begin
      E := No_Effects;
      case Command is
         when Set_Name_Command =>
            C.Pilot_Config.Craft_Name := (others => 0);
            Put_Text (C.Pilot_Config.Craft_Name, Request, 0, Natural'Min (Name_Length, Request'Length));
            E.OSD_Elements := True;
            R := Ack;
         when Set_Text_Command =>
            Set_Text (C, Request, R, E);
         when Set_LED_Strip_Values_Command =>
            Add (P, Ledstrip_Brightness, U8 (Request, 0), 0);
            Add (P, Ledstrip_Rainbow_Delta, U16 (Request, 1), 0);
            Add (P, Ledstrip_Rainbow_Freq, U16 (Request, 3), 0);
            Set_Fields (C, P, R);
         when Set_Battery_Profile_Command =>
            Set_Battery_Profile (C, Request, R);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Text_In;
