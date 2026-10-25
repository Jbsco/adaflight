--  The transmitter driver over MSP: a transmitter that answers on the MSP
--  link is ready once the table is set, the configuration it is sent
--  gathers the settings' band, channel, power and frequencies with the
--  pit mode and the table's counts, and goes out as an MSP reply every two
--  hundred milliseconds while something changed, over the serial link or
--  wrapped for the CRSF telemetry buffer. The link, the port sharing and
--  the command processor stay with the target.
with Interfaces;
with Adaflight.Bytes;
with Adaflight.VTX_Settings;
with Adaflight.VTX_Table;

package Adaflight.VTX_MSP with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Adaflight.VTX_Settings.Low_Power_Disarm;
   use Adaflight.Bytes;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Settings is Adaflight.VTX_Settings.Settings;

   Request_Period_Us : constant := 200_000;
   Config_Command    : constant := 88;
   Device_Type       : constant := 5;
   Frame_Length      : constant := 15;
   Max_Payload       : constant := 50;
   Max_Frame         : constant := 64;

   subtype Config_Frame is Byte_Array (0 .. Frame_Length - 1);
   subtype CRSF_Frame is Byte_Array (0 .. Max_Frame - 1);
   type Level_Values is array (Adaflight.VTX_Table.Power_Index) of Unsigned_16;

   type Status is (Offline, Ready);

   --  The configuration the driver was given, whether it has gone out, the
   --  time it last went out, the low power state it last saw, the link's
   --  readiness and the count of frames sent.
   type Driver is record
      Conf_Freq      : Unsigned_16 := 0;
      Conf_Band      : Unsigned_8 := 0;
      Conf_Channel   : Unsigned_8 := 0;
      Conf_Power     : Unsigned_16 := 0;
      Conf_Pit_Mode  : Unsigned_8 := 0;
      Config_Changed : Boolean := False;
      Last_Time_Us   : Unsigned_32 := 0;
      Prev_Low_Power : Boolean := False;
      Current        : Status := Offline;
      Packets        : Unsigned_16 := 0;
   end record;

   type Inputs is record
      Now_Us         : Unsigned_32 := 0;
      Armed          : Boolean := False;
      Was_Ever_Armed : Boolean := False;
      Failsafe       : Boolean := False;
   end record;

   --  The lowest power while disarmed and not in failsafe, always or until
   --  the first arming, by the setting.
   function Low_Power_Disarmed (S : Settings; Armed, Was_Ever_Armed, Failsafe : Boolean) return Boolean is
     (not Armed and then not Failsafe
      and then (S.Low_Power = Adaflight.VTX_Settings.Always
                or else (S.Low_Power = Adaflight.VTX_Settings.Until_First_Arm and then not Was_Ever_Armed)));

   function Is_Ready (D : Driver) return Boolean is (D.Current = Ready);

   --  The transmitter answered on the driver's link: ready once the table
   --  has bands, channels and power levels.
   procedure Set_Ready (D : in out Driver; T : Adaflight.VTX_Table.Table; On_Link : Boolean);

   --  The configuration frame: the device type, the band, channel and power
   --  of the settings with the lowest power while low power disarmed, the
   --  pit mode, the frequency, the readiness, the low power setting, the pit
   --  mode frequency, and the table's counts behind a table flag.
   procedure Prepare_Frame (D : Driver; S : Settings; T : Adaflight.VTX_Table.Table; Low_Power : Boolean;
                            Frame : out Config_Frame);

   --  One cycle: a low power change marks the configuration changed, and a
   --  changed configuration goes out once the period has passed; Send
   --  reports the frame to push as an MSP reply.
   procedure Process (D : in out Driver; S : Settings; T : Adaflight.VTX_Table.Table; Inp : Inputs;
                      Frame : out Config_Frame; Send : out Boolean);

   --  The MSP reply wrapped for the CRSF telemetry buffer: the sync byte,
   --  the length, the MSP response type, the receiver and flight controller
   --  addresses, the MSP header of a first chunk in version 2, the payload,
   --  the MSP checksum and the frame's checksum.
   procedure CRSF_Push (Command : Unsigned_16; Payload : Byte_Array; Frame : out CRSF_Frame; Length : out Natural)
     with Pre  => Payload'Length <= Max_Payload,
          Post => Length = Payload'Length + 13;

   procedure Set_Band_Channel (D : in out Driver; Band, Channel : Unsigned_8);
   procedure Set_Power_Index (D : in out Driver; T : Adaflight.VTX_Table.Table; Index : Unsigned_8);
   procedure Set_Pit_Mode (D : in out Driver; Value : Unsigned_8);
   procedure Set_Frequency (D : in out Driver; Freq : Unsigned_16);

   --  The configuration read back once ready; Known says the driver is. The
   --  frequency is the one given while no band is set, else the table's.
   procedure Get_Band_Channel (D : Driver; Band, Channel : out Unsigned_8; Known : out Boolean);
   procedure Get_Power_Index (D : Driver; T : Adaflight.VTX_Table.Table; Index : in out Unsigned_8;
                              Known : out Boolean);
   procedure Get_Frequency (D : Driver; T : Adaflight.VTX_Table.Table; Freq : out Unsigned_16; Known : out Boolean);
   procedure Get_Status (D : Driver; Pit_Mode : out Boolean; Known : out Boolean);

   --  The table's power levels in decibel-milliwatts and in milliwatts
   --  through the C library's power function, none until ready.
   procedure Get_Power_Levels (D : Driver; T : Adaflight.VTX_Table.Table; Count : out Adaflight.VTX_Table.Power_Count;
                               Levels, Powers : out Level_Values);

end Adaflight.VTX_MSP;
