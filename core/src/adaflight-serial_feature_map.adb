package body Adaflight.Serial_Feature_Map with SPARK_Mode is
   use type Adaflight.OSD_Task.Device_Kind;

   Telemetry_Shareable : constant Unsigned_32 := Function_FrSky_Hub or Function_LTM or Function_MAVLink;
   Telemetry_Functions : constant Unsigned_32 := Telemetry_Shareable or Function_HoTT or Function_SmartPort;

   function Has (Mask, Bits : Unsigned_32) return Boolean is ((Mask and Bits) /= 0);

   --  The VTX's functions from its device.
   function VTX_Mask (O : Options; A : Assignments) return Unsigned_32 is
     (case A.VTX_Type is
         when SmartAudio => (if O.SmartAudio then Function_SmartAudio else 0),
         when Tramp => (if O.Tramp then Function_Tramp else 0),
         when MSP_VTX => (if O.VTX_MSP then Function_VTX_MSP or Function_MSP else 0),
         when Unsupported | RTC6705 | Unknown => 0);

   --  The OSD's functions from its display device.
   function OSD_Mask (O : Options; A : Assignments) return Unsigned_32 is
     (case A.Display_Device is
         when Adaflight.OSD_Task.FrSky_OSD => Function_FrSky_OSD,
         when Adaflight.OSD_Task.MSP => (if O.MSP_Display_Port then Function_MSP else 0),
         when Adaflight.OSD_Task.None | Adaflight.OSD_Task.Auto | Adaflight.OSD_Task.MAX7456
            | Adaflight.OSD_Task.Framebuffer => 0);

   --  A telemetry protocol's function when the build has it.
   function Provider_Mask (O : Options; Protocol : Telemetry_Protocol) return Unsigned_32 is
     (case Protocol is
         when FrSky_Hub => (if O.FrSky_Hub then Function_FrSky_Hub else 0),
         when HoTT => (if O.HoTT then Function_HoTT else 0),
         when LTM => (if O.LTM then Function_LTM else 0),
         when SmartPort => (if O.SmartPort then Function_SmartPort else 0),
         when MAVLink => (if O.MAVLink then Function_MAVLink else 0),
         when IBus => (if O.IBus then Function_IBus else 0),
         when No_Telemetry => 0);

   function Slot (I : Positive) return Telemetry_Slot is (Telemetry_Slot (I))
     with Pre => I <= Max_Telemetry_Slots;

   -------------------
   -- Function_Mask --
   -------------------

   function Function_Mask (O : Options; A : Assignments; Port : Port_Id) return Unsigned_32 is
      Mask : Unsigned_32 := 0;
   begin
      if Port = No_Port then
         return 0;
      end if;
      for S in MSP_Slot loop
         if A.MSP_Port (S) = Port then
            Mask := Mask or Function_MSP;
            exit;
         end if;
      end loop;
      if O.GPS and then A.GPS_Port = Port then
         Mask := Mask or Function_GPS;
      end if;
      if O.Receiver and then A.RX_Port = Port then
         Mask := Mask or Function_RX_Serial;
      end if;
      if O.Blackbox and then A.Blackbox_Port = Port then
         Mask := Mask or Function_Blackbox;
      end if;
      if O.ESC_Sensor and then A.ESC_Sensor_Port = Port then
         Mask := Mask or Function_ESC_Sensor;
      end if;
      if O.RCDevice and then A.RCDevice_Port = Port then
         Mask := Mask or Function_RCDevice;
      end if;
      if O.Gimbal and then A.Gimbal_Port = Port then
         Mask := Mask or Function_Gimbal;
      end if;
      if O.VTX and then A.VTX_Port = Port then
         Mask := Mask or VTX_Mask (O, A);
      end if;
      if O.Rangefinder and then A.Rangefinder_Port = Port then
         Mask := Mask or Function_Lidar;
      end if;
      if O.Optical_Flow and then A.Optical_Flow_Port = Port then
         Mask := Mask or Function_Lidar;
      end if;
      if O.OSD then
         if A.OSD_Port = Port then
            Mask := Mask or OSD_Mask (O, A);
         end if;
         if A.Custom_Text_Port = Port then
            Mask := Mask or Function_OSD_Custom_Text;
         end if;
      end if;
      for I in 1 .. Telemetry_Slots (O) loop
         if A.Telemetry (Slot (I)).Port = Port then
            Mask := Mask or Provider_Mask (O, A.Telemetry (Slot (I)).Protocol);
         end if;
      end loop;
      return Mask;
   end Function_Mask;

   -----------------
   -- Port_Claims --
   -----------------

   procedure Port_Claims
     (O : Options; A : Assignments; Port : Port_Id; Limit : Claim_Count; Claims : out Claim_Array;
      Count : out Claim_Count)
   is
      procedure Add (Kind : Claim_Kind; Mask : Unsigned_32)
        with Pre  => Count <= Limit,
             Post => Count <= Limit
      is
      begin
         if Count < Limit then
            Count := Count + 1;
            Claims (Count) := (Kind => Kind, Mask => Mask);
         end if;
      end Add;

      MSP_Claims       : constant array (MSP_Slot) of Claim_Kind := (MSP_1, MSP_2, MSP_3);
      Telemetry_Claims : constant array (Telemetry_Slot) of Claim_Kind := (Telemetry_1, Telemetry_2, Telemetry_3);
   begin
      Claims := (others => (Kind => MSP_1, Mask => 0));
      Count := 0;
      if Port = No_Port then
         return;
      end if;
      for S in MSP_Slot loop
         pragma Loop_Invariant (Count <= Limit);
         if A.MSP_Port (S) = Port then
            Add (MSP_Claims (S), Function_MSP);
         end if;
      end loop;
      if O.GPS and then A.GPS_Port = Port then
         Add (GPS_Claim, Function_GPS);
      end if;
      if O.Receiver and then A.RX_Port = Port then
         Add (RX_Claim, Function_RX_Serial);
      end if;
      if O.Blackbox and then A.Blackbox_Port = Port then
         Add (Blackbox_Claim, Function_Blackbox);
      end if;
      if O.ESC_Sensor and then A.ESC_Sensor_Port = Port then
         Add (ESC_Sensor_Claim, Function_ESC_Sensor);
      end if;
      if O.RCDevice and then A.RCDevice_Port = Port then
         Add (RCDevice_Claim, Function_RCDevice);
      end if;
      if O.Gimbal and then A.Gimbal_Port = Port then
         Add (Gimbal_Claim, Function_Gimbal);
      end if;
      if O.VTX and then A.VTX_Port = Port then
         Add (VTX_Claim, VTX_Mask (O, A));
      end if;
      if O.Rangefinder and then A.Rangefinder_Port = Port then
         Add (Rangefinder_Claim,
              Function_Lidar or (if O.Rangefinder_MSP and then A.Rangefinder_On_MSP then Function_MSP else 0));
      end if;
      if O.Optical_Flow and then A.Optical_Flow_Port = Port then
         Add (Optical_Flow_Claim,
              Function_Lidar or (if O.Optical_Flow_MSP and then A.Optical_Flow_On_MSP then Function_MSP else 0));
      end if;
      if O.OSD then
         if A.OSD_Port = Port then
            Add (OSD_Claim, OSD_Mask (O, A));
         end if;
         if A.Custom_Text_Port = Port then
            Add (Custom_Text_Claim, Function_OSD_Custom_Text);
         end if;
      end if;
      for I in 1 .. Telemetry_Slots (O) loop
         pragma Loop_Invariant (Count <= Limit);
         if A.Telemetry (Slot (I)).Port = Port then
            Add (Telemetry_Claims (Slot (I)), Provider_Mask (O, A.Telemetry (Slot (I)).Protocol));
         end if;
      end loop;
   end Port_Claims;

   --  The claim names in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Claim_Name_Pool_Length : constant := 128;
   Claim_Name_Text : constant String (1 .. Claim_Name_Pool_Length + 15) :=
     "msp_1msp_2msp_3gpsrxblackboxesc_sensorrcdevicegimbalvtxrangefinderopticalflowosdosd_custom_texttelemetry"
     & "_1telemetry_2telemetry_3               ";
   type Claim_Name_Start is range 0 .. Claim_Name_Pool_Length;
   type Claim_Name_Length is range 2 .. 15;
   Claim_Name_Starts : constant array (Claim_Kind) of Claim_Name_Start :=
     (MSP_1 => 0, MSP_2 => 5, MSP_3 => 10, GPS_Claim => 15, RX_Claim => 18, Blackbox_Claim => 20,
      ESC_Sensor_Claim => 28, RCDevice_Claim => 38, Gimbal_Claim => 46, VTX_Claim => 52, Rangefinder_Claim => 55,
      Optical_Flow_Claim => 66, OSD_Claim => 77, Custom_Text_Claim => 80, Telemetry_1 => 95, Telemetry_2 => 106,
      Telemetry_3 => 117);
   Claim_Name_Lengths : constant array (Claim_Kind) of Claim_Name_Length :=
     (MSP_1 => 5, MSP_2 => 5, MSP_3 => 5, GPS_Claim => 3, RX_Claim => 2, Blackbox_Claim => 8,
      ESC_Sensor_Claim => 10, RCDevice_Claim => 8, Gimbal_Claim => 6, VTX_Claim => 3, Rangefinder_Claim => 11,
      Optical_Flow_Claim => 11, OSD_Claim => 3, Custom_Text_Claim => 15, Telemetry_1 => 11, Telemetry_2 => 11,
      Telemetry_3 => 11);

   function Claim_Name (K : Claim_Kind) return String is
     (Claim_Name_Text (Natural (Claim_Name_Starts (K)) + 1
                       .. Natural (Claim_Name_Starts (K)) + Natural (Claim_Name_Lengths (K))));

   function Claim_Setting (K : Claim_Kind) return String is (Claim_Name (K) & "_uart");

   function Claim_Selector (K : Claim_Kind) return String is
     (case K is
         when VTX_Claim => "vtx_type",
         when Rangefinder_Claim => "rangefinder_hardware",
         when Optical_Flow_Claim => "opticalflow_hardware",
         when OSD_Claim => "osd_displayport_device",
         when Telemetry_1 | Telemetry_2 | Telemetry_3 => Claim_Name (K) & "_protocol",
         when MSP_1 | MSP_2 | MSP_3 | GPS_Claim | RX_Claim | Blackbox_Claim | ESC_Sensor_Claim | RCDevice_Claim
            | Gimbal_Claim | Custom_Text_Claim => "");

   function Claim_Baud_Setting (K : Claim_Kind) return String is
     (case K is
         when MSP_1 | MSP_2 | MSP_3 | GPS_Claim | Blackbox_Claim | Custom_Text_Claim | Telemetry_1 | Telemetry_2
            | Telemetry_3 => Claim_Name (K) & "_baud",
         when RX_Claim | ESC_Sensor_Claim | RCDevice_Claim | Gimbal_Claim | VTX_Claim | Rangefinder_Claim
            | Optical_Flow_Claim | OSD_Claim => "");

   --  Every MSP slot naming the port set to no port.
   procedure Clear_MSP_Claims (A : in out Assignments; Port : Port_Id) is
   begin
      for S in MSP_Slot loop
         if A.MSP_Port (S) = Port then
            A.MSP_Port (S) := No_Port;
         end if;
      end loop;
   end Clear_MSP_Claims;

   --  Every feature but MSP naming the port set to no port; selections stay
   --  as they are.
   procedure Clear_Feature_Claims (O : Options; A : in out Assignments; Port : Port_Id) is
   begin
      if O.GPS and then A.GPS_Port = Port then
         A.GPS_Port := No_Port;
      end if;
      if O.Receiver and then A.RX_Port = Port then
         A.RX_Port := No_Port;
      end if;
      if O.Blackbox and then A.Blackbox_Port = Port then
         A.Blackbox_Port := No_Port;
      end if;
      if O.ESC_Sensor and then A.ESC_Sensor_Port = Port then
         A.ESC_Sensor_Port := No_Port;
      end if;
      if O.RCDevice and then A.RCDevice_Port = Port then
         A.RCDevice_Port := No_Port;
      end if;
      if O.Gimbal and then A.Gimbal_Port = Port then
         A.Gimbal_Port := No_Port;
      end if;
      if O.VTX and then A.VTX_Port = Port then
         A.VTX_Port := No_Port;
      end if;
      if O.Rangefinder and then A.Rangefinder_Port = Port then
         A.Rangefinder_Port := No_Port;
      end if;
      if O.Optical_Flow and then A.Optical_Flow_Port = Port then
         A.Optical_Flow_Port := No_Port;
      end if;
      if O.OSD then
         if A.OSD_Port = Port then
            A.OSD_Port := No_Port;
         end if;
         if A.Custom_Text_Port = Port then
            A.Custom_Text_Port := No_Port;
         end if;
      end if;
      for I in 1 .. Telemetry_Slots (O) loop
         if A.Telemetry (Slot (I)).Port = Port then
            A.Telemetry (Slot (I)).Protocol := No_Telemetry;
            A.Telemetry (Slot (I)).Port := No_Port;
         end if;
      end loop;
   end Clear_Feature_Claims;

   --  The telemetry protocols a mask names among those built.
   function Telemetry_Bits (O : Options; Mask : Unsigned_32) return Natural is
     (Boolean'Pos (O.FrSky_Hub and then Has (Mask, Function_FrSky_Hub))
      + Boolean'Pos (O.HoTT and then Has (Mask, Function_HoTT))
      + Boolean'Pos (O.LTM and then Has (Mask, Function_LTM))
      + Boolean'Pos (O.SmartPort and then Has (Mask, Function_SmartPort))
      + Boolean'Pos (O.MAVLink and then Has (Mask, Function_MAVLink))
      + Boolean'Pos (O.IBus and then Has (Mask, Function_IBus)));

   --  Whether the mask fits the free slots, counting the port's own as free.
   function Can_Apply (O : Options; A : Assignments; Port : Port_Id; Mask : Unsigned_32) return Boolean is
      VTX_Bits : constant Natural :=
        Boolean'Pos (O.SmartAudio and then Has (Mask, Function_SmartAudio))
        + Boolean'Pos (O.Tramp and then Has (Mask, Function_Tramp))
        + Boolean'Pos (O.VTX_MSP and then Has (Mask, Function_VTX_MSP));
      Needed : constant Natural := Telemetry_Bits (O, Mask);
   begin
      if O.VTX and then VTX_Bits > 1 then
         return False;
      end if;
      if Has (Mask, Function_MSP)
        and then (for all S in MSP_Slot => A.MSP_Port (S) /= No_Port and then A.MSP_Port (S) /= Port)
      then
         return False;
      end if;
      if Telemetry_Slots (O) > 0 and then Needed > 0 then
         declare
            Free : Natural := 0;
         begin
            for I in 1 .. Telemetry_Slots (O) loop
               pragma Loop_Invariant (Free < I);
               if A.Telemetry (Slot (I)).Protocol = No_Telemetry or else A.Telemetry (Slot (I)).Port = Port then
                  Free := Free + 1;
               end if;
            end loop;
            if Free < Needed then
               return False;
            end if;
         end;
      end if;
      return True;
   end Can_Apply;

   -------------------------
   -- Apply_Function_Mask --
   -------------------------

   procedure Apply_Function_Mask
     (O : Options; A : in out Assignments; Port : Port_Id; Mask : Unsigned_32; Applied : out Boolean)
   is
      procedure Assign_Telemetry (Protocol : Telemetry_Protocol) is
      begin
         for I in 1 .. Telemetry_Slots (O) loop
            if A.Telemetry (Slot (I)).Protocol = No_Telemetry then
               A.Telemetry (Slot (I)).Protocol := Protocol;
               A.Telemetry (Slot (I)).Port := Port;
               return;
            end if;
         end loop;
      end Assign_Telemetry;
   begin
      if Port = No_Port then
         Applied := Mask = 0;
         return;
      end if;
      if not Can_Apply (O, A, Port, Mask) then
         Applied := False;
         return;
      end if;
      Clear_MSP_Claims (A, Port);
      Clear_Feature_Claims (O, A, Port);
      if Has (Mask, Function_MSP) then
         for S in MSP_Slot loop
            if A.MSP_Port (S) = No_Port then
               A.MSP_Port (S) := Port;
               exit;
            end if;
         end loop;
      end if;
      if O.GPS and then Has (Mask, Function_GPS) then
         A.GPS_Port := Port;
      end if;
      if O.Receiver and then Has (Mask, Function_RX_Serial) then
         A.RX_Port := Port;
      end if;
      if O.Blackbox and then Has (Mask, Function_Blackbox) then
         A.Blackbox_Port := Port;
      end if;
      if O.ESC_Sensor and then Has (Mask, Function_ESC_Sensor) then
         A.ESC_Sensor_Port := Port;
      end if;
      if O.RCDevice and then Has (Mask, Function_RCDevice) then
         A.RCDevice_Port := Port;
      end if;
      if O.Gimbal and then Has (Mask, Function_Gimbal) then
         A.Gimbal_Port := Port;
      end if;
      if O.VTX then
         if O.SmartAudio and then Has (Mask, Function_SmartAudio) then
            A.VTX_Port := Port;
            A.VTX_Type := SmartAudio;
         end if;
         if O.Tramp and then Has (Mask, Function_Tramp) then
            A.VTX_Port := Port;
            A.VTX_Type := Tramp;
         end if;
         if O.VTX_MSP and then Has (Mask, Function_VTX_MSP) then
            A.VTX_Port := Port;
            A.VTX_Type := MSP_VTX;
         end if;
      end if;
      if O.Rangefinder and then Has (Mask, Function_Lidar) then
         A.Rangefinder_Port := Port;
      end if;
      if O.OSD then
         if Has (Mask, Function_FrSky_OSD) then
            A.OSD_Port := Port;
            A.Display_Device := Adaflight.OSD_Task.FrSky_OSD;
         end if;
         if Has (Mask, Function_OSD_Custom_Text) then
            A.Custom_Text_Port := Port;
         end if;
      end if;
      if Telemetry_Slots (O) > 0 then
         if O.FrSky_Hub and then Has (Mask, Function_FrSky_Hub) then
            Assign_Telemetry (FrSky_Hub);
         end if;
         if O.HoTT and then Has (Mask, Function_HoTT) then
            Assign_Telemetry (HoTT);
         end if;
         if O.LTM and then Has (Mask, Function_LTM) then
            Assign_Telemetry (LTM);
         end if;
         if O.SmartPort and then Has (Mask, Function_SmartPort) then
            Assign_Telemetry (SmartPort);
         end if;
         if O.MAVLink and then Has (Mask, Function_MAVLink) then
            Assign_Telemetry (MAVLink);
         end if;
         if O.IBus and then Has (Mask, Function_IBus) then
            Assign_Telemetry (IBus);
         end if;
      end if;
      Applied := True;
   end Apply_Function_Mask;

   ---------------------
   -- Apply_Port_Baud --
   ---------------------

   procedure Apply_Port_Baud
     (O : Options; A : in out Assignments; Port : Port_Id; Class : Baud_Class; Baud : Baud_Index)
   is
   begin
      if Port = No_Port then
         return;
      end if;
      case Class is
         when MSP_Baud =>
            for S in MSP_Slot loop
               if A.MSP_Port (S) = Port then
                  A.MSP_Baud (S) := Baud;
               end if;
            end loop;
         when GPS_Baud =>
            if O.GPS and then A.GPS_Port = Port then
               A.GPS_Baud := Baud;
            end if;
         when Blackbox_Baud =>
            if O.Blackbox and then A.Blackbox_Port = Port then
               A.Blackbox_Baud := Baud;
            end if;
         when Telemetry_Baud =>
            for I in 1 .. Telemetry_Slots (O) loop
               if A.Telemetry (Slot (I)).Port = Port then
                  A.Telemetry (Slot (I)).Baud := Baud;
               end if;
            end loop;
            if O.OSD and then A.Custom_Text_Port = Port then
               A.Custom_Text_Baud := Baud;
            end if;
      end case;
   end Apply_Port_Baud;

   ---------------
   -- Port_Baud --
   ---------------

   function Port_Baud (O : Options; A : Assignments; Port : Port_Id; Class : Baud_Class) return Baud_Index is
   begin
      if Port = No_Port then
         return Default_Port_Baud (Class);
      end if;
      case Class is
         when MSP_Baud =>
            for S in MSP_Slot loop
               if A.MSP_Port (S) = Port then
                  return A.MSP_Baud (S);
               end if;
            end loop;
         when GPS_Baud =>
            if O.GPS and then A.GPS_Port = Port then
               return A.GPS_Baud;
            end if;
         when Blackbox_Baud =>
            if O.Blackbox and then A.Blackbox_Port = Port then
               return A.Blackbox_Baud;
            end if;
         when Telemetry_Baud =>
            for I in 1 .. Telemetry_Slots (O) loop
               if A.Telemetry (Slot (I)).Port = Port then
                  return A.Telemetry (Slot (I)).Baud;
               end if;
            end loop;
            if O.OSD and then A.Custom_Text_Port = Port then
               return A.Custom_Text_Baud;
            end if;
      end case;
      return Default_Port_Baud (Class);
   end Port_Baud;

   -----------------------
   -- Implied_MSP_Ports --
   -----------------------

   procedure Implied_MSP_Ports
     (O : Options; A : Assignments; Limit : Natural; Ports : out Implied_Ports; Count : out Natural)
   is
      procedure Add (Port : Port_Id)
        with Pre  => Count <= Limit and then Limit <= Max_Implied_Ports,
             Post => Count <= Limit
      is
      begin
         if Port = No_Port or else Count >= Limit then
            return;
         end if;
         for I in 1 .. Count loop
            if Ports (I) = Port then
               return;
            end if;
         end loop;
         Count := Count + 1;
         Ports (Count) := Port;
      end Add;
   begin
      Ports := (others => No_Port);
      Count := 0;
      if O.Rangefinder_MSP and then A.Rangefinder_On_MSP then
         Add (A.Rangefinder_Port);
      end if;
      if O.Optical_Flow_MSP and then A.Optical_Flow_On_MSP then
         Add (A.Optical_Flow_Port);
      end if;
      if O.OSD and then O.MSP_Display_Port and then A.Display_Device = Adaflight.OSD_Task.MSP then
         Add (A.OSD_Port);
      end if;
      if O.VTX_MSP and then A.VTX_Type = MSP_VTX then
         Add (A.VTX_Port);
      end if;
   end Implied_MSP_Ports;

   function Bit_Count (Mask : Unsigned_32) return Natural
     with Post => Bit_Count'Result <= 32
   is
      Count : Natural := 0;
   begin
      for I in 0 .. 31 loop
         pragma Loop_Invariant (Count <= I);
         if Has (Interfaces.Shift_Right (Mask, I), 1) then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Bit_Count;

   --  Whether the serial receiver shares the port with telemetry it carries.
   function RX_Port_Shared (O : Options; A : Assignments; Mask : Unsigned_32) return Boolean is
     ((Has (Mask, Function_RX_Serial) and then Has (Mask, Telemetry_Shareable)
       and then A.RX_Provider in Spektrum_1024 | Spektrum_2048 | SBUS | SUMD | SUMH | XBus_Mode_B
                               | XBus_Mode_B_RJ01 | IBus_RX | MAVLink_RX)
      or else (O.IBus and then Has (Mask, Function_IBus) and then Has (Mask, Function_RX_Serial)
               and then A.RX_Provider = IBus_RX)
      or else (O.MSP_Over_Telemetry and then O.VTX_MSP and then Has (Mask, Function_RX_Serial)
               and then Has (Mask, Function_VTX_MSP)));

   ------------------------
   -- Functions_Conflict --
   ------------------------

   function Functions_Conflict (O : Options; A : Assignments; Port : Port_Id) return Boolean is
      Mask     : constant Unsigned_32 := Function_Mask (O, A, Port);
      Bits     : constant Natural := Bit_Count (Mask);
      Sharable : constant Unsigned_32 :=
        Function_MSP or Function_Blackbox or (if O.Telemetry then Telemetry_Functions else 0) or Function_VTX_MSP
        or Function_Lidar;
   begin
      if Port in Soft_Serial_1 .. Soft_Serial_1 + O.Soft_Serial_Ports - 1
        and then Has (Mask, Function_MSP or Function_RX_Serial)
      then
         return True;
      end if;
      if O.VTX_MSP and then Has (Mask, Function_VTX_MSP) and then Bits = 1 then
         return True;
      end if;
      if Bits > 1 then
         if Has (Mask, Function_MSP) and then (Mask and not Sharable) = 0 then
            return False;
         elsif O.Telemetry and then RX_Port_Shared (O, A, Mask) then
            return False;
         else
            return True;
         end if;
      end if;
      return False;
   end Functions_Conflict;

   ------------------
   -- Config_Valid --
   ------------------

   function Config_Valid (O : Options; A : Assignments; Ports : Port_List) return Boolean is
   begin
      for P of Ports loop
         if P = USB_VCP and then not Has (Function_Mask (O, A, P), Function_MSP) then
            return False;
         end if;
         if Functions_Conflict (O, A, P) then
            return False;
         end if;
      end loop;
      return (for some S in MSP_Slot => A.MSP_Port (S) /= No_Port);
   end Config_Valid;

   ----------------------------------
   -- Drop_Conflicting_Assignments --
   ----------------------------------

   procedure Drop_Conflicting_Assignments (O : Options; A : in out Assignments; Ports : Port_List) is
   begin
      for P of Ports loop
         if Functions_Conflict (O, A, P) then
            Clear_Feature_Claims (O, A, P);
         end if;
      end loop;
   end Drop_Conflicting_Assignments;

   -------------------------------
   -- Reset_Feature_Assignments --
   -------------------------------

   procedure Reset_Feature_Assignments (O : Options; A : in out Assignments; Ports : Port_List) is
   begin
      for P of Ports loop
         Clear_MSP_Claims (A, P);
         Clear_Feature_Claims (O, A, P);
      end loop;
      A.MSP_Port (1) := Ports (Ports'First);
      A.MSP_Baud (1) := Default_Port_Baud (MSP_Baud);
   end Reset_Feature_Assignments;

   ---------
   -- Fix --
   ---------

   procedure Fix (O : Options; A : in out Assignments; Ports : Port_List) is
   begin
      if not Config_Valid (O, A, Ports) then
         Drop_Conflicting_Assignments (O, A, Ports);
         if not Config_Valid (O, A, Ports) then
            Reset_Feature_Assignments (O, A, Ports);
         end if;
      end if;
   end Fix;

   ------------------
   -- Port_Sharing --
   ------------------

   function Port_Sharing (O : Options; A : Assignments; Port : Port_Id; Func : Unsigned_32) return Port_Use is
      Mask : constant Unsigned_32 := Function_Mask (O, A, Port);
   begin
      if Port = No_Port or else (Mask and Func) = 0 then
         return Unused;
      elsif Mask = Func then
         return Not_Shared;
      else
         return Shared;
      end if;
   end Port_Sharing;

   ----------------------
   -- Port_Shared_With --
   ----------------------

   function Port_Shared_With
     (O : Options; A : Assignments; Port : Port_Id; Mask : Unsigned_32; Shared_With : Unsigned_32) return Boolean
   is
      Functions : constant Unsigned_32 := Function_Mask (O, A, Port);
   begin
      return Port /= No_Port and then (Functions and Shared_With) /= 0
        and then (Functions and (Mask and 16#FFFF#)) /= 0;
   end Port_Shared_With;

   ------------------------------
   -- Telemetry_Shares_RX_Port --
   ------------------------------

   function Telemetry_Shares_RX_Port (O : Options; A : Assignments; Port : Port_Id) return Boolean is
     (RX_Port_Shared (O, A, Function_Mask (O, A, Port)));

   -------------------
   -- Provider_Port --
   -------------------

   function Provider_Port (O : Options; A : Assignments; Protocol : Telemetry_Protocol) return Port_Id is
   begin
      for I in Telemetry_Slot loop
         exit when Natural (I) > Telemetry_Slots (O);
         if A.Telemetry (I).Protocol = Protocol and then A.Telemetry (I).Port /= No_Port then
            return A.Telemetry (I).Port;
         end if;
      end loop;
      return No_Port;
   end Provider_Port;

   -------------------
   -- Provider_Baud --
   -------------------

   function Provider_Baud (O : Options; A : Assignments; Protocol : Telemetry_Protocol; Port : Port_Id)
     return Baud_Index is
   begin
      if Port = No_Port then
         return Baud_Auto;
      end if;
      for I in Telemetry_Slot loop
         exit when Natural (I) > Telemetry_Slots (O);
         if A.Telemetry (I).Protocol = Protocol and then A.Telemetry (I).Port = Port then
            return A.Telemetry (I).Baud;
         end if;
      end loop;
      return Baud_Auto;
   end Provider_Baud;

end Adaflight.Serial_Feature_Map;
