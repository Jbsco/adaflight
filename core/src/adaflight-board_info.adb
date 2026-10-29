with Adaflight.MSP_Allocation;
with Adaflight.Serial_Feature_Map;

package body Adaflight.Board_Info with SPARK_Mode is
   use type Interfaces.Integer_8;
   use type Interfaces.Unsigned_8;

   function To_Identity (Text : String) return Identity_Text is
      T : Identity_Text;
   begin
      for K in 1 .. Text'Length loop
         T.Data (K) := Text (Text'First + (K - 1));
      end loop;
      T.Length := Text'Length;
      return T;
   end To_Identity;

   --  The stored bytes before the first zero.
   function Stored_Text (B : Bytes) return String
     with Pre => B'Length <= 32, Post => Stored_Text'Result'First = 1 and then Stored_Text'Result'Length <= B'Length
   is
      Text : String (1 .. B'Length) := (others => ' ');
      Last : Natural := 0;
   begin
      for K in B'Range loop
         pragma Loop_Invariant (Last = K - B'First and then Last < B'Length);
         exit when B (K) = 0;
         Last := Last + 1;
         Text (Last) := Character'Val (B (K));
      end loop;
      return Text (1 .. Last);
   end Stored_Text;

   procedure Init (Board : in out State; C : Configuration) is
   begin
      Board.Information_Set := C.Board_Config.Board_Information_Set /= 0;
      if Board.Information_Set then
         Board.Manufacturer :=
           To_Identity (Stored_Text (C.Board_Config.Manufacturer_Id (0 .. Manufacturer_Length - 1)));
         Board.Name := To_Identity (Stored_Text (C.Board_Config.Board_Name (0 .. Board_Name_Length - 1)));
      end if;
      Board.Signature_Set := C.Board_Config.Signature_Set /= 0;
      if Board.Signature_Set then
         for K in Board.Signature'Range loop
            Board.Signature (K) := C.Board_Config.Signature (K);
         end loop;
      end if;
   end Init;

   procedure Store_Information (C : in out Configuration; Board : State) is
   begin
      C.Board_Config.Manufacturer_Id := (others => 0);
      for K in 0 .. Natural'Min (Board.Manufacturer.Length, Manufacturer_Length) - 1 loop
         C.Board_Config.Manufacturer_Id (K) := Character'Pos (Board.Manufacturer.Data (K + 1));
      end loop;
      C.Board_Config.Board_Name := (others => 0);
      for K in 0 .. Natural'Min (Board.Name.Length, Board_Name_Length) - 1 loop
         C.Board_Config.Board_Name (K) := Character'Pos (Board.Name.Data (K + 1));
      end loop;
      C.Board_Config.Board_Information_Set := 1;
   end Store_Information;

   procedure Store_Signature (C : in out Configuration; Board : State) is
   begin
      for K in Board.Signature'Range loop
         C.Board_Config.Signature (K) := Board.Signature (K);
      end loop;
      C.Board_Config.Signature_Set := 1;
   end Store_Signature;

   procedure Reset_Config (C : in out Configuration; Board : State) is
      H : Hardware_Defaults renames Board.Hardware;
   begin
      if Board.Information_Set then
         Store_Information (C, Board);
      end if;
      if Board.Signature_Set then
         Store_Signature (C, Board);
      end if;
      C.Adc_Config.Vbat.Enabled := H.Vbat.Enabled;
      C.Adc_Config.Vbat.Io_Tag := H.Vbat.Io_Tag;
      C.Adc_Config.External1.Enabled := H.External1.Enabled;
      C.Adc_Config.External1.Io_Tag := H.External1.Io_Tag;
      C.Adc_Config.Current.Enabled := H.Current.Enabled;
      C.Adc_Config.Current.Io_Tag := H.Current.Io_Tag;
      C.Adc_Config.Rssi.Enabled := H.RSSI.Enabled;
      C.Adc_Config.Rssi.Io_Tag := H.RSSI.Io_Tag;
      C.Beeper_Dev_Config.Is_Open_Drain := (if H.Beeper_Inverted then 0 else 1);
      C.Beeper_Dev_Config.Is_Inverted := (if H.Beeper_Inverted then 1 else 0);
      C.Beeper_Dev_Config.Io_Tag := H.Beeper_Tag;
      C.Beeper_Dev_Config.Frequency := H.Beeper_Frequency;
      C.Battery_Config.Voltage_Meter_Source := H.Voltage_Source;
      C.Battery_Config.Current_Meter_Source := H.Current_Source;
      C.Voltage_Sensor_Adc_Config (0).Vbatscale := H.Voltage_Scale;
      C.Current_Sensor_Adc_Config.Scale := H.Current_Scale;
      C.Max7456_Config.Cs_Tag := H.OSD_CS_Tag;
      C.Max7456_Config.Spi_Device := H.OSD_SPI_Device;
      C.Sdcard_Config.Device := H.SD_SPI_Device;
      C.Sdcard_Config.Chip_Select_Tag := H.SD_CS_Tag;
      C.Sdcard_Config.Card_Detect_Tag := H.SD_Detect_Tag;
      C.Sdcard_Config.Card_Detect_Inverted := (if H.SD_Detect_Low then 1 else 0);
      C.Sdcard_Config.Mode := (if H.SD_SPI_Device > 0 and then H.SD_CS_Tag /= 0 then 1 else 0);
      C.Flash_Config.Spi_Device := H.Flash_SPI_Device;
      C.Flash_Config.Cs_Tag := H.Flash_CS_Tag;
      C.Blackbox_Config.Device := H.Blackbox_Device;
      for I in PINIO_Bytes'Range loop
         C.Pinio_Config.Io_Tag (I) := H.PINIO_Tags (I);
         C.Pinio_Config.Config (I) := H.PINIO_Configs (I);
         C.Pinio_Box_Config.Permanent_Id (I) := H.PINIO_Boxes (I);
      end loop;
      for I in Motor_Bytes'Range loop
         C.Motor_Config.Dev.Io_Tags (I) := H.Motor_Tags (I);
      end loop;
      C.Led_Strip_Config.Io_Tag := H.LED_Strip_Tag;
      declare
         Slots : constant Serial_Feature_Map.MSP_Ports :=
           MSP_Allocation.Default_Slots (H.MSP_First_Port, H.MSP_UART, H.MSP_Other_UART, H.MSP_Display_Port_UART);
      begin
         for S in Slots'Range loop
            C.Msp_Config.Msp_Uart (Natural (S) - 1) := Interfaces.Integer_8 (Slots (S));
         end loop;
      end;
   end Reset_Config;

   procedure Persist_Information (C : in out Configuration; Board : in out State) is
   begin
      Store_Information (C, Board);
      Init (Board, C);
   end Persist_Information;

   procedure Persist_Signature (C : in out Configuration; Board : in out State) is
   begin
      Store_Signature (C, Board);
      Init (Board, C);
   end Persist_Signature;

end Adaflight.Board_Info;
