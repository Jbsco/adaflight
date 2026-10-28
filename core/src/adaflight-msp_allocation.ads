with Interfaces;
with Adaflight.Serial_Feature_Map;

--  The MSP serial ports a board opens: the three MSP slots in order, then the
--  ports the features that talk MSP imply, each opened once, on a port the
--  board has and no other function holds. Also the slots a fresh
--  configuration claims for the board's first port and its MSP UARTs.
package Adaflight.MSP_Allocation
  with SPARK_Mode
is
   package SFM renames Adaflight.Serial_Feature_Map;
   subtype Port_Id is SFM.Port_Id;
   use type Interfaces.Unsigned_32;

   --  The serial hardware behind an identifier: the USB port, a soft serial
   --  port, a UART of either kind, or none.
   type Port_Kind is (No_Kind, USB_VCP, Soft_Serial, UART);
   function Kind_Of (Port : Port_Id) return Port_Kind is
     (case Port is
         when 20 => USB_VCP,
         when 30 .. 31 => Soft_Serial,
         when 40 .. 79 => UART,
         when others => No_Kind);

   --  The fastest rate a soft serial port opens at.
   Soft_Serial_Max_Rate : constant := 19_200;

   --  Per identifier: whether the board offers the port, or whether another
   --  function opened it before MSP.
   type Port_Flags is array (Port_Id) of Boolean;

   Max_Ports : constant := 3 + SFM.Max_Implied_Ports;
   subtype Port_Count is Natural range 0 .. Max_Ports;

   --  An opened port with the rate and options asked of its driver, and
   --  whether its functions share it with telemetry.
   type Opened_Port is record
      Port          : Port_Id := SFM.No_Port;
      Rate          : Interfaces.Unsigned_32 := 0;
      Bidirectional : Boolean := False;
      Check_TX      : Boolean := False;
      Shared        : Boolean := False;
   end record;
   type Opened_Ports is array (1 .. Max_Ports) of Opened_Port;

   --  The telemetry functions a port shared with MSP carries.
   Telemetry_Functions : constant Interfaces.Unsigned_32 :=
     SFM.Function_FrSky_Hub or SFM.Function_LTM or SFM.Function_MAVLink or SFM.Function_HoTT or SFM.Function_SmartPort;

   --  The implied ports the build has room for: one per feature built that
   --  talks MSP over a port of its own.
   function Implied_Limit (O : SFM.Options) return Natural is
     (Boolean'Pos (O.Rangefinder_MSP) + Boolean'Pos (O.Optical_Flow_MSP)
      + Boolean'Pos (O.OSD and then O.MSP_Display_Port) + Boolean'Pos (O.VTX_MSP))
     with Post => Implied_Limit'Result <= SFM.Max_Implied_Ports;

   procedure Allocate
     (O           : SFM.Options;
      A           : SFM.Assignments;
      Half_Duplex : Boolean;
      Present     : Port_Flags;
      Busy        : Port_Flags;
      Ports       : out Opened_Ports;
      Count       : out Port_Count)
     with Global => null,
          Post   => (for all I in 1 .. Count => Present (Ports (I).Port) and then not Busy (Ports (I).Port));

   --  The slots a fresh configuration names: the board's first port, then
   --  the target's MSP UART, its other MSP UART and its MSP display port
   --  UART, each once, none past three.
   function Default_Slots (First, MSP_UART, Other_MSP_UART, Display_Port_UART : Port_Id) return SFM.MSP_Ports
     with Global => null;

end Adaflight.MSP_Allocation;
