package body Adaflight.OSD_Elements with SPARK_Mode is

   procedure Sync_Blink (B : in out Blink; Now_Us : Unsigned_32) is
   begin
      B.State := (Now_Us mod Blink_Period_Us) < Blink_Period_Us / 2;
   end Sync_Blink;

   procedure Reset_Alarms (B : in out Blink) is
   begin
      B.Bits := (others => False);
   end Reset_Alarms;

   function Alarm_Altitude (Alt : Altitude_Range; Units : Adaflight.OSD_Format.Unit_System) return Integer_32 is
      Converted : constant Float := Adaflight.OSD_Format.Meters_To_Unit (Alt, Units);
   begin
      pragma Assert (abs Converted <= 2.0e9);
      return Integer_32 (Float'Truncation (Converted / 100.0));
   end Alarm_Altitude;

   procedure Update_Alarms (B : in out Blink; C : Alarm_Settings; Inp : Alarm_Inputs) is
      Alt           : constant Integer_32 := Alarm_Altitude (Inp.Altitude_Cm, C.Units);
      Capacity      : constant Unsigned_16 := Capacity_Alarm (C, Inp.Profile_Capacity);
      Over_Capacity : constant Boolean := Capacity > 0 and then Inp.MAh_Drawn >= Integer_32 (Capacity);
      Low_Battery   : constant Boolean := Inp.Battery /= Adaflight.Battery.OK;
      Blink_ESC     : Boolean := False;
   begin
      B.Bits (RSSI_Value) := Inp.RSSI_Percent < C.RSSI_Alarm;
      B.Bits (RSSI_Dbm_Value) := Inp.RSSI_Dbm < C.RSSI_Dbm_Alarm;
      B.Bits (Link_Quality) := Inp.Link_Quality < C.Link_Quality_Alarm;
      B.Bits (Main_Battery_Voltage) := Low_Battery;
      B.Bits (Average_Cell_Voltage) := Low_Battery;
      B.Bits (GPS_Sats) := not Inp.GPS_Fix or else Inp.Satellites < 4
        or else (Inp.Satellites < C.Rescue_Min_Sats and then Inp.Rescue_Configured);
      for T in Timer_Index loop
         declare
            Timer      : constant Unsigned_16 := C.Timers (T);
            Time       : constant Unsigned_32 :=
              Adaflight.OSD_Format.Timer_Value (Adaflight.OSD_Format.Timer_Source_Of (Timer), Inp.Clocks);
            Alarm_Time : constant Unsigned_32 := Unsigned_32 (Adaflight.OSD_Format.Timer_Alarm_Of (Timer)) * 60_000_000;
         begin
            B.Bits (if T = 0 then Timer_1 else Timer_2) := Alarm_Time /= 0 and then Time >= Alarm_Time;
         end;
      end loop;
      B.Bits (MAh_Drawn) := Over_Capacity;
      B.Bits (Remaining_Time_Estimate) := Over_Capacity;
      B.Bits (Main_Battery_Usage) := Over_Capacity or else (Capacity = 0 and then Low_Battery);
      B.Bits (Altitude) := Alt >= Integer_32 (C.Alt_Alarm) and then Inp.Clocks.Armed;
      B.Bits (Home_Distance) := Inp.GPS_Present and then Inp.Clocks.Armed and then Inp.GPS_Fix and then Inp.GPS_Fix_Home
        and then C.Distance_Alarm /= 0 and then Inp.Home_Distance_M >= C.Distance_Alarm;
      if Inp.ESC_Sensor_Feature then
         Blink_ESC := C.ESC_Temp_Alarm /= 0 and then Inp.ESC_Temperature >= C.ESC_Temp_Alarm;
      elsif C.ESC_Temp_Alarm /= 0 then
         for K in Motor_Index loop
            exit when Blink_ESC or else K >= Inp.Motors;
            Blink_ESC := Inp.DShot (K).Has_Temperature
              and then Inp.DShot (K).Temperature >= Unsigned_16 (C.ESC_Temp_Alarm);
         end loop;
      end if;
      B.Bits (ESC_Temperature) := Blink_ESC;
   end Update_Alarms;

   procedure Add (A : in out Active_List; Pos : Positions; Profile : Profile_Mask; I : Item)
     with Pre  => A.Count < Max_Active,
          Post => A.Count in A.Count'Old .. A.Count'Old + 1
   is
   begin
      if Visible (Pos (I), Profile) then
         A.Count := A.Count + 1;
         A.Items (A.Count) := I;
      end if;
   end Add;

   procedure Add_Active_Elements (A : out Active_List; Pos : Positions; Profile : Profile_Mask; Inp : Element_Inputs) is
   begin
      A := (others => <>);
      if Inp.Acc_Present then
         Add (A, Pos, Profile, Artificial_Horizon);
         Add (A, Pos, Profile, G_Force);
         Add (A, Pos, Profile, Up_Down_Reference);
      end if;
      pragma Assert (A.Count <= 3);
      for K in Display_Order'Range loop
         pragma Loop_Invariant (A.Count <= 3 + (K - Display_Order'First));
         Add (A, Pos, Profile, Display_Order (K));
      end loop;
      pragma Assert (A.Count <= 76);
      if Inp.GPS_Present then
         Add (A, Pos, Profile, GPS_Sats);
         Add (A, Pos, Profile, GPS_Speed);
         Add (A, Pos, Profile, GPS_Latitude);
         Add (A, Pos, Profile, GPS_Longitude);
         Add (A, Pos, Profile, Home_Distance);
         Add (A, Pos, Profile, Home_Direction);
         Add (A, Pos, Profile, Flight_Distance);
         Add (A, Pos, Profile, Efficiency);
         Add (A, Pos, Profile, WP_Number);
         Add (A, Pos, Profile, WP_Current_Lat);
         Add (A, Pos, Profile, WP_Current_Lon);
         Add (A, Pos, Profile, WP_Current_Alt);
         Add (A, Pos, Profile, WP_Distance);
         Add (A, Pos, Profile, WP_Direction);
         Add (A, Pos, Profile, WP_Next_Number);
         Add (A, Pos, Profile, WP_ETA);
         Add (A, Pos, Profile, Nav_Map);
      end if;
      pragma Assert (A.Count <= 93);
      if Inp.ESC_Sensor_Feature or else Inp.DShot_Telemetry then
         Add (A, Pos, Profile, ESC_Temperature);
         Add (A, Pos, Profile, ESC_RPM);
         Add (A, Pos, Profile, ESC_RPM_Frequency);
      end if;
      pragma Assert (A.Count <= 96);
      if Inp.GPS_Present then
         Add (A, Pos, Profile, GPS_Lap_Time_Current);
         Add (A, Pos, Profile, GPS_Lap_Time_Previous);
         Add (A, Pos, Profile, GPS_Lap_Time_Best3);
      end if;
      pragma Assert (A.Count <= 99);
      Add (A, Pos, Profile, Total_Flights);
      Add (A, Pos, Profile, Airspeed);
   end Add_Active_Elements;

end Adaflight.OSD_Elements;
