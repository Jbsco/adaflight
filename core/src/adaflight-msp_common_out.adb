package body Adaflight.MSP_Common_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   --  A displayed voltage in tenths of a volt, rounded and held to a byte.
   function Tenths (Centivolts : Unsigned_16) return Unsigned_8 is
     (Unsigned_8 (Natural'Min ((Natural (Centivolts) + 5) / 10, 255)));

   --  A cell voltage in tenths of a volt, rounded and wrapped to a byte.
   function Cell_Tenths (Centivolts : Unsigned_16) return Unsigned_8 is
     (Unsigned_8 (((Natural (Centivolts) + 5) / 10) mod 256));

   function Saturated (V : Interfaces.Integer_64) return Unsigned_16 is
     (Unsigned_16 (Interfaces.Integer_64'Max (0, Interfaces.Integer_64'Min (V, 65_535))));

   function Wrapped (V : Integer_16) return Unsigned_16 is
     (Unsigned_16 (Interfaces.Integer_32 (V) mod 65_536));

   function Bit (Set : Boolean; Index : Natural) return Unsigned_32 is
     (if Set then Interfaces.Shift_Left (1, Index) else 0)
     with Pre => Index < 32;

   procedure Write_Text (B : in out Byte_Array; S : in out Stream; T : Text)
     with Pre  => Fits (S, B) and then Remaining (S) >= 1 + Max_Text,
          Post => S.Next - S.Next'Old in 1 .. 1 + Max_Text and then S.Last = S.Last'Old
   is
   begin
      Write_Prefixed_String (B, S, T.Data (1 .. T.Length));
   end Write_Text;

   procedure Board_Info (B : in out Byte_Array; S : in out Stream; Board : Board_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next - S.Next'Old in 0 .. 53 + 3 * Max_Text and then S.Last = S.Last'Old
   is
      Start        : constant Position := S.Next with Ghost;
      Capabilities : constant Unsigned_32 :=
        Bit (Board.VCP, 0) or Bit (Board.Soft_Serial, 1) or Bit (Board.Flash_Boot_Loader, 3) or Bit (Board.RX_Bind, 6);
      Problems     : constant Unsigned_32 :=
        Bit (Board.Acc_Needs_Calibration, 0) or Bit (Board.Motor_Protocol_Disabled, 1);
   begin
      Write_String (B, S, Board.Identifier);
      Write_U16 (B, S, Board.Hardware_Revision);
      Write_U8 (B, S, (if Board.MAX7456 then 2 else 0));
      Write_U8 (B, S, Unsigned_8 (Capabilities and 16#FF#));
      Write_Text (B, S, Board.Target_Name);
      pragma Assert (S.Next - Start in 9 .. 9 + Max_Text);
      if Board.Board_Info then
         Write_Text (B, S, Board.Board_Name);
         Write_Text (B, S, Board.Manufacturer);
      else
         Write_U8 (B, S, 0);
         Write_U8 (B, S, 0);
      end if;
      pragma Assert (S.Next - Start in 11 .. 11 + 3 * Max_Text);
      Write_Data (B, S, Board.Signature);
      Write_U8 (B, S, MCU_Type_By_Name);
      Write_U8 (B, S, Board.Configuration_State);
      Write_U16 (B, S, Unsigned_16 (Board.Gyro_Rate_Hz mod 65_536));
      Write_U32 (B, S, Problems);
      Write_U8 (B, S, Board.SPI_Devices);
      Write_U8 (B, S, Board.I2C_Devices);
   end Board_Info;

   procedure Build_Info (B : in out Byte_Array; S : in out Stream; Firmware : Firmware_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next - S.Next'Old = 26 + 2 * Firmware.Option_Count and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      Write_String (B, S, Firmware.Build_Date);
      Write_String (B, S, Firmware.Build_Time);
      Write_String (B, S, Firmware.Revision);
      for I in 1 .. Firmware.Option_Count loop
         Write_U16 (B, S, Firmware.Options (I));
         pragma Loop_Invariant (S.Next = Start + 26 + 2 * I and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Build_Info;

   procedure Voltage_Meters (B : in out Byte_Array; S : in out Stream; Meters : Meter_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length
                  and then Listed (Meters.Voltage_Count, Meters) in 0 .. Max_Meters,
          Post => S.Next - S.Next'Old in 0 .. 2 * Max_Meters and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
      Count : constant Natural := Listed (Meters.Voltage_Count, Meters);
   begin
      for I in 1 .. Count loop
         Write_U8 (B, S, Meters.Voltages (I).Id);
         Write_U8 (B, S, Tenths (Meters.Voltages (I).Display_Filtered));
         pragma Loop_Invariant (S.Next = Start + 2 * I and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Voltage_Meters;

   procedure Current_Meters (B : in out Byte_Array; S : in out Stream; Meters : Meter_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length
                  and then Listed (Meters.Current_Count, Meters) in 0 .. Max_Meters,
          Post => S.Next - S.Next'Old in 0 .. 5 * Max_Meters and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
      Count : constant Natural := Listed (Meters.Current_Count, Meters);
   begin
      for I in 1 .. Count loop
         Write_U8 (B, S, Meters.Currents (I).Id);
         Write_U16 (B, S, Saturated (Interfaces.Integer_64 (Meters.Currents (I).mAh_Drawn)));
         Write_U16 (B, S, Saturated (Interfaces.Integer_64 (Meters.Currents (I).Amperage) * 10));
         pragma Loop_Invariant (S.Next = Start + 5 * I and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Current_Meters;

   procedure Voltage_Meter_Config (B : in out Byte_Array; S : in out Stream; Meters : Meter_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next - S.Next'Old = 1 + 6 * Meters.Sensor_Count and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      Write_U8 (B, S, Unsigned_8 (Meters.Sensor_Count));
      for I in 1 .. Meters.Sensor_Count loop
         Write_U8 (B, S, 5);
         Write_U8 (B, S, Meters.Sensors (I).Id);
         Write_U8 (B, S, 0);
         Write_U8 (B, S, Meters.Sensors (I).Scale);
         Write_U8 (B, S, Meters.Sensors (I).Divider);
         Write_U8 (B, S, Meters.Sensors (I).Multiplier);
         pragma Loop_Invariant (S.Next = Start + 1 + 6 * I and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Voltage_Meter_Config;

   procedure Current_Meter_Config (B : in out Byte_Array; S : in out Stream; Meters : Meter_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next - S.Next'Old in 8 .. 15 and then S.Last = S.Last'Old
   is
      ADC_Meter     : constant := 10;
      Virtual_Meter : constant := 80;
      ADC_Sensor     : constant := 1;
      Virtual_Sensor : constant := 0;
   begin
      Write_U8 (B, S, (if Meters.Virtual then 2 else 1));
      Write_U8 (B, S, 6);
      Write_U8 (B, S, ADC_Meter);
      Write_U8 (B, S, ADC_Sensor);
      Write_U16 (B, S, Wrapped (Meters.Current_Scale));
      Write_U16 (B, S, Wrapped (Meters.Current_Offset));
      if Meters.Virtual then
         Write_U8 (B, S, 6);
         Write_U8 (B, S, Virtual_Meter);
         Write_U8 (B, S, Virtual_Sensor);
         Write_U16 (B, S, Wrapped (Meters.Virtual_Scale));
         Write_U16 (B, S, Wrapped (Meters.Virtual_Offset));
      end if;
   end Current_Meter_Config;

   procedure Transponder_Config (B : in out Byte_Array; S : in out Stream; T : Transponder_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next - S.Next'Old in 0 .. 8 + Transponder_Data_Length and then S.Last = S.Last'Old
   is
      type Requirement is record
         Provider    : Unsigned_8;
         Data_Length : Natural range 1 .. Transponder_Data_Length;
      end record;
      type Requirements is array (1 .. 3) of Requirement;
      Table : constant Requirements := ((1, 6), (2, 9), (3, 1));
   begin
      if not T.Built_In then
         Write_U8 (B, S, 0);
         return;
      end if;
      Write_U8 (B, S, 3);
      for R of Table loop
         Write_U8 (B, S, R.Provider);
         Write_U8 (B, S, Unsigned_8 (R.Data_Length));
      end loop;
      Write_U8 (B, S, Unsigned_8 (T.Provider));
      if T.Provider /= 0 then
         Write_Data (B, S, T.Data (1 .. Table (T.Provider).Data_Length));
      end if;
   end Transponder_Config;

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
   begin
      if not Supported (Command, V) then
         return;
      end if;
      case Command is
         when API_Version_Command =>
            Write_U8 (B, S, Protocol_Version);
            Write_U8 (B, S, API_Version_Major);
            Write_U8 (B, S, API_Version_Minor);
         when FC_Variant_Command =>
            Write_String (B, S, V.Firmware.Variant);
         when FC_Version_Command =>
            Write_U8 (B, S, Unsigned_8 (V.Firmware.Year - Calendar_Base_Year));
            Write_U8 (B, S, V.Firmware.Month);
            Write_U8 (B, S, V.Firmware.Patch);
            if not V.VTX_Port then
               Write_Text (B, S, V.Firmware.Version);
            end if;
         when MCU_Info_Command =>
            Write_U8 (B, S, MCU_Type_By_Name);
            Write_Text (B, S, V.Firmware.MCU_Name);
         when Board_Info_Command =>
            Board_Info (B, S, V.Board);
         when Build_Info_Command =>
            Build_Info (B, S, V.Firmware);
         when UID_Command =>
            for Word of V.Firmware.UID loop
               Write_U32 (B, S, Word);
            end loop;
         when Feature_Config_Command =>
            Write_U32 (B, S, V.Features);
         when Beeper_Config_Command =>
            Write_U32 (B, S, V.Beeper_Off_Flags);
            Write_U8 (B, S, V.Beacon_Tone);
            Write_U32 (B, S, V.Beacon_Off_Flags);
         when Voltage_Meters_Command =>
            Voltage_Meters (B, S, V.Meters);
         when Current_Meters_Command =>
            Current_Meters (B, S, V.Meters);
         when Voltage_Meter_Config_Command =>
            Voltage_Meter_Config (B, S, V.Meters);
         when Current_Meter_Config_Command =>
            Current_Meter_Config (B, S, V.Meters);
         when Battery_Config_Command =>
            Write_U8 (B, S, Cell_Tenths (V.Battery.Min_Cell));
            Write_U8 (B, S, Cell_Tenths (V.Battery.Max_Cell));
            Write_U8 (B, S, Cell_Tenths (V.Battery.Warning_Cell));
            Write_U16 (B, S, V.Battery.Capacity);
            Write_U8 (B, S, V.Battery.Voltage_Source);
            Write_U8 (B, S, V.Battery.Current_Source);
            Write_U16 (B, S, V.Battery.Min_Cell);
            Write_U16 (B, S, V.Battery.Max_Cell);
            Write_U16 (B, S, V.Battery.Warning_Cell);
         when Transponder_Config_Command =>
            Transponder_Config (B, S, V.Transponder);
         when OSD_Canvas_Command =>
            if V.OSD then
               Write_U8 (B, S, V.Canvas_Columns);
               Write_U8 (B, S, V.Canvas_Rows);
            end if;
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Common_Out;
