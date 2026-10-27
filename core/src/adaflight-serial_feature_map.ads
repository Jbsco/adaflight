--  Serial feature map: the features that name a serial port in their own
--  settings, and the per-port view of function bits and baud rates over
--  them that the configurator and the command line read and write. A port's
--  function bits and its baud rate of a class come from the features naming
--  it, and its claims list those features with their settings. Applying a
--  function mask moves features onto a port only when every slot the mask
--  needs is free; applying a baud rate sets it on the port's features of that
--  class. A port's functions conflict when they cannot run together, and a
--  fix drops the claims on conflicting ports, then resets every claim when
--  the assignment is still invalid.
with Interfaces;
with Adaflight.OSD_Task;

package Adaflight.Serial_Feature_Map with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  Port identifiers: none, the USB port at 20, soft serial from 30, low
   --  power UARTs from 40, UARTs from 50 and PIO UARTs from 70.
   subtype Port_Id is Integer range -1 .. 79;
   No_Port       : constant Port_Id := -1;
   USB_VCP       : constant Port_Id := 20;
   Soft_Serial_1 : constant Port_Id := 30;

   --  Baud rate indices from automatic to 2470000 baud.
   subtype Baud_Index is Natural range 0 .. 15;
   Baud_Auto   : constant Baud_Index := 0;
   Baud_57600  : constant Baud_Index := 4;
   Baud_115200 : constant Baud_Index := 5;

   --  A baud index's rate, zero for the automatic one.
   function Rate_Of (B : Baud_Index) return Unsigned_32 is
     (case B is
         when 0 => 0, when 1 => 9_600, when 2 => 19_200, when 3 => 38_400, when 4 => 57_600, when 5 => 115_200,
         when 6 => 230_400, when 7 => 250_000, when 8 => 400_000, when 9 => 460_800, when 10 => 500_000,
         when 11 => 921_600, when 12 => 1_000_000, when 13 => 1_500_000, when 14 => 2_000_000, when 15 => 2_470_000);

   Function_MSP             : constant Unsigned_32 := 16#0000_0001#;
   Function_GPS             : constant Unsigned_32 := 16#0000_0002#;
   Function_FrSky_Hub       : constant Unsigned_32 := 16#0000_0004#;
   Function_HoTT            : constant Unsigned_32 := 16#0000_0008#;
   Function_LTM             : constant Unsigned_32 := 16#0000_0010#;
   Function_SmartPort       : constant Unsigned_32 := 16#0000_0020#;
   Function_RX_Serial       : constant Unsigned_32 := 16#0000_0040#;
   Function_Blackbox        : constant Unsigned_32 := 16#0000_0080#;
   Function_MAVLink         : constant Unsigned_32 := 16#0000_0200#;
   Function_ESC_Sensor      : constant Unsigned_32 := 16#0000_0400#;
   Function_SmartAudio      : constant Unsigned_32 := 16#0000_0800#;
   Function_IBus            : constant Unsigned_32 := 16#0000_1000#;
   Function_Tramp           : constant Unsigned_32 := 16#0000_2000#;
   Function_RCDevice        : constant Unsigned_32 := 16#0000_4000#;
   Function_Lidar           : constant Unsigned_32 := 16#0000_8000#;
   Function_FrSky_OSD       : constant Unsigned_32 := 16#0001_0000#;
   Function_VTX_MSP         : constant Unsigned_32 := 16#0002_0000#;
   Function_Gimbal          : constant Unsigned_32 := 16#0004_0000#;
   Function_OSD_Custom_Text : constant Unsigned_32 := 16#0008_0000#;

   type Baud_Class is (MSP_Baud, GPS_Baud, Telemetry_Baud, Blackbox_Baud);
   type Telemetry_Protocol is (No_Telemetry, FrSky_Hub, HoTT, LTM, SmartPort, MAVLink, IBus);
   type VTX_Device is (Unsupported, RTC6705, SmartAudio, Tramp, MSP_VTX, Unknown);
   type Serial_RX is
     (No_Serial_RX, Spektrum_2048, SBUS, SUMD, SUMH, XBus_Mode_B, XBus_Mode_B_RJ01, IBus_RX, Jeti_ExBus, CRSF,
      SRXL, Target_Custom, FPort, SRXL2, Ghost, Spektrum_1024, MAVLink_RX);

   --  The build's features, its telemetry protocols, and the target's soft
   --  serial ports.
   type Options is record
      GPS                 : Boolean := True;
      Receiver            : Boolean := True;
      Blackbox            : Boolean := True;
      ESC_Sensor          : Boolean := True;
      RCDevice            : Boolean := True;
      Gimbal              : Boolean := True;
      VTX                 : Boolean := True;
      SmartAudio          : Boolean := True;
      Tramp               : Boolean := True;
      VTX_MSP             : Boolean := True;
      Rangefinder         : Boolean := True;
      Rangefinder_MSP     : Boolean := True;
      Optical_Flow        : Boolean := True;
      Optical_Flow_MSP    : Boolean := True;
      OSD                 : Boolean := True;
      MSP_Display_Port    : Boolean := True;
      Telemetry           : Boolean := True;
      FrSky_Hub           : Boolean := True;
      HoTT                : Boolean := True;
      LTM                 : Boolean := True;
      SmartPort           : Boolean := True;
      MAVLink             : Boolean := True;
      IBus                : Boolean := True;
      MSP_Over_Telemetry  : Boolean := True;
      Soft_Serial_Ports   : Natural range 0 .. 2 := 2;
   end record;

   Max_Telemetry_Slots : constant := 3;
   subtype Telemetry_Slot_Count is Natural range 0 .. Max_Telemetry_Slots;

   --  The telemetry slots: one per protocol built, at most three.
   function Telemetry_Slots (O : Options) return Telemetry_Slot_Count is
     (Natural'Min
        (Max_Telemetry_Slots,
         Boolean'Pos (O.FrSky_Hub) + Boolean'Pos (O.HoTT) + Boolean'Pos (O.LTM) + Boolean'Pos (O.SmartPort)
         + Boolean'Pos (O.MAVLink) + Boolean'Pos (O.IBus)));

   type MSP_Slot is range 1 .. 3;
   type MSP_Ports is array (MSP_Slot) of Port_Id;
   type MSP_Bauds is array (MSP_Slot) of Baud_Index;
   type Telemetry_Slot is range 1 .. Max_Telemetry_Slots;

   type Telemetry_Provider is record
      Protocol : Telemetry_Protocol := No_Telemetry;
      Port     : Port_Id := No_Port;
      Baud     : Baud_Index := Baud_Auto;
   end record;
   type Telemetry_Providers is array (Telemetry_Slot) of Telemetry_Provider;

   --  The port and the baud rate each feature names, with the selections that
   --  decide what a port opens as: the serial receiver's protocol, the VTX
   --  device, whether the rangefinder's and the optical flow's hardware talk
   --  MSP, and the OSD's display device.
   type Assignments is record
      MSP_Port            : MSP_Ports := (others => No_Port);
      MSP_Baud            : MSP_Bauds := (others => Baud_115200);
      GPS_Port            : Port_Id := No_Port;
      GPS_Baud            : Baud_Index := Baud_57600;
      RX_Port             : Port_Id := No_Port;
      RX_Provider         : Serial_RX := No_Serial_RX;
      Blackbox_Port       : Port_Id := No_Port;
      Blackbox_Baud       : Baud_Index := Baud_115200;
      ESC_Sensor_Port     : Port_Id := No_Port;
      RCDevice_Port       : Port_Id := No_Port;
      Gimbal_Port         : Port_Id := No_Port;
      VTX_Port            : Port_Id := No_Port;
      VTX_Type            : VTX_Device := Unknown;
      Rangefinder_Port    : Port_Id := No_Port;
      Rangefinder_On_MSP  : Boolean := False;
      Optical_Flow_Port   : Port_Id := No_Port;
      Optical_Flow_On_MSP : Boolean := False;
      OSD_Port            : Port_Id := No_Port;
      Display_Device      : Adaflight.OSD_Task.Device_Kind := Adaflight.OSD_Task.Auto;
      Custom_Text_Port    : Port_Id := No_Port;
      Custom_Text_Baud    : Baud_Index := Baud_Auto;
      Telemetry           : Telemetry_Providers;
   end record;

   --  A port's function bits from the features naming it; none for no port.
   function Function_Mask (O : Options; A : Assignments; Port : Port_Id) return Unsigned_32;

   type Claim_Kind is
     (MSP_1, MSP_2, MSP_3, GPS_Claim, RX_Claim, Blackbox_Claim, ESC_Sensor_Claim, RCDevice_Claim, Gimbal_Claim,
      VTX_Claim, Rangefinder_Claim, Optical_Flow_Claim, OSD_Claim, Custom_Text_Claim, Telemetry_1, Telemetry_2,
      Telemetry_3);

   --  A feature's claim on a port with the functions the port opens with.
   type Claim is record
      Kind : Claim_Kind := MSP_1;
      Mask : Unsigned_32 := 0;
   end record;
   Max_Claims : constant := 17;
   subtype Claim_Count is Natural range 0 .. Max_Claims;
   type Claim_Array is array (1 .. Max_Claims) of Claim;

   --  The claims on a port in the features' order, up to a count.
   procedure Port_Claims
     (O : Options; A : Assignments; Port : Port_Id; Limit : Claim_Count; Claims : out Claim_Array;
      Count : out Claim_Count)
     with Post => Count <= Limit;

   --  The claim's name, its port setting, the setting that selects what the
   --  port opens as and the claim's baud setting, empty where there is none.
   function Claim_Name (K : Claim_Kind) return String;
   function Claim_Setting (K : Claim_Kind) return String;
   function Claim_Selector (K : Claim_Kind) return String;
   function Claim_Baud_Setting (K : Claim_Kind) return String;

   --  The features a mask names moved onto a port after every claim on it is
   --  cleared, or nothing changed when the mask asks for two VTX protocols or
   --  for more MSP or telemetry slots than are free. No port takes only an
   --  empty mask.
   procedure Apply_Function_Mask
     (O : Options; A : in out Assignments; Port : Port_Id; Mask : Unsigned_32; Applied : out Boolean)
     with Post => (if not Applied then A = A'Old);

   --  A baud rate set on the port's features of a class.
   procedure Apply_Port_Baud
     (O : Options; A : in out Assignments; Port : Port_Id; Class : Baud_Class; Baud : Baud_Index);

   --  A class's baud rate where no feature names the port.
   function Default_Port_Baud (Class : Baud_Class) return Baud_Index is
     (case Class is
         when MSP_Baud | Blackbox_Baud => Baud_115200,
         when GPS_Baud => Baud_57600,
         when Telemetry_Baud => Baud_Auto);

   --  A port's baud rate of a class from the first feature of the class
   --  naming it, or the class default.
   function Port_Baud (O : Options; A : Assignments; Port : Port_Id; Class : Baud_Class) return Baud_Index;

   Max_Implied_Ports : constant := 4;
   type Implied_Ports is array (1 .. Max_Implied_Ports) of Port_Id;

   --  The distinct ports a feature talks MSP over without an MSP claim, up to
   --  a count.
   procedure Implied_MSP_Ports
     (O : Options; A : Assignments; Limit : Natural; Ports : out Implied_Ports; Count : out Natural)
     with Pre  => Limit <= Max_Implied_Ports,
          Post => Count <= Limit;

   --  Whether a port's functions cannot run together.
   function Functions_Conflict (O : Options; A : Assignments; Port : Port_Id) return Boolean;

   Max_Ports : constant := 24;
   type Port_List is array (Positive range <>) of Port_Id;

   --  Whether the assignment has an MSP slot in use, MSP on the USB port and
   --  no conflicting port among the target's.
   function Config_Valid (O : Options; A : Assignments; Ports : Port_List) return Boolean
     with Pre => Ports'Length <= Max_Ports;

   --  Every claim but MSP cleared on each conflicting port.
   procedure Drop_Conflicting_Assignments (O : Options; A : in out Assignments; Ports : Port_List)
     with Pre => Ports'Length <= Max_Ports;

   --  Every claim cleared, then MSP on the target's first port at its
   --  default baud rate.
   procedure Reset_Feature_Assignments (O : Options; A : in out Assignments; Ports : Port_List)
     with Pre => Ports'Length in 1 .. Max_Ports;

   --  The configuration check: an invalid assignment loses its conflicting
   --  claims, then every claim when it is still invalid.
   procedure Fix (O : Options; A : in out Assignments; Ports : Port_List)
     with Pre => Ports'Length in 1 .. Max_Ports;

   --  Whether a port has a function, alone or with others.
   type Port_Use is (Unused, Not_Shared, Shared);
   function Port_Sharing (O : Options; A : Assignments; Port : Port_Id; Func : Unsigned_32) return Port_Use;

   --  Whether a port has the shared function and one of a mask's
   --  functions, the mask taken to 16 bits.
   function Port_Shared_With
     (O : Options; A : Assignments; Port : Port_Id; Mask : Unsigned_32; Shared_With : Unsigned_32) return Boolean;

   --  Whether the serial receiver on a port leaves room for telemetry on it.
   function Telemetry_Shares_RX_Port (O : Options; A : Assignments; Port : Port_Id) return Boolean;

   --  The port of the first telemetry slot with the protocol and a port, or
   --  none.
   function Provider_Port (O : Options; A : Assignments; Protocol : Telemetry_Protocol) return Port_Id;

   --  The baud rate of the first slot with the protocol on the port, or
   --  automatic.
   function Provider_Baud (O : Options; A : Assignments; Protocol : Telemetry_Protocol; Port : Port_Id)
     return Baud_Index;

   --  Telemetry runs on a port of its own, and on a shared one while the
   --  telemetry mode is on, or while armed where no telemetry mode is set up.
   function Telemetry_Enabled (Use_Of_Port : Port_Use; Mode_Present, Mode_Active, Armed : Boolean) return Boolean is
     (case Use_Of_Port is
         when Unused     => False,
         when Not_Shared => True,
         when Shared     => (if Mode_Present then Mode_Active else Armed));

   --  Whether telemetry reports a sensor the disabled mask leaves on.
   function Sensor_Enabled (Disabled : Unsigned_32; Sensor : Unsigned_32) return Boolean is
     (((not Disabled) and Sensor) /= 0);

end Adaflight.Serial_Feature_Map;
