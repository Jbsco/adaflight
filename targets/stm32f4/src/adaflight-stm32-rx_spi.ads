--  The SPI receiver as the receiver core's provider: the device and the
--  protocol's family started from the configuration, the frame check, the
--  frame processing and the channel reads.
with Interfaces;
with Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.FrSky_Hub_Telemetry;
with Adaflight.Receiver;
with Adaflight.SmartPort_Telemetry;
package Adaflight.STM32.RX_SPI is
   --  The readings a receiver's telemetry sends: the hub stream's inputs, the
   --  external and RSSI analog samples and the battery voltage in hundredths
   --  and in tenths of a volt.
   type Telemetry_Readings is record
      Hub          : Adaflight.FrSky_Hub_Telemetry.Inputs;
      ADC_External : Interfaces.Unsigned_16 := 0;
      ADC_RSSI     : Interfaces.Unsigned_16 := 0;
      Centivolts   : Interfaces.Unsigned_16 := 0;
      Decivolts    : Interfaces.Unsigned_16 := 0;
   end record;

   --  The receiver's select pin, before the buses start.
   procedure Preinit (C : Adaflight.Config_Groups.Configuration);
   --  The device and the protocol's family, with its telemetry when the
   --  telemetry feature is on; when either fails to start, the frame check
   --  reports nothing and the channels read zero.
   procedure Init (C : Adaflight.Config_Groups.Configuration; Telemetry : Boolean);
   procedure Frame_Status (Report : out Adaflight.Receiver.Frame_Report);
   --  The processing a frame status asked for, with the SmartPort values a
   --  receiver's telemetry sends, and an MSP request completed over its link
   --  answered through Answer.
   generic
      with procedure Answer (Command : Interfaces.Unsigned_16; Request : Adaflight.Bytes.Byte_Array;
                             Reply : out Adaflight.Bytes.Byte_Array; Length : out Natural; Failed : out Boolean);
      with function SmartPort_Values return Adaflight.SmartPort_Telemetry.Inputs;
   procedure Process_Frame;
   --  The channels the protocol carries.
   function Channel_Count return Natural;
   procedure Read_Raw (Ch : Natural; Value : out Float);
   procedure Stop;
   --  A bind request from the bind command.
   procedure Bind;
   --  The time of the last frame, the interrupt edge that announced it.
   function Last_Frame_Us return Adaflight.Receiver.Time_Us;
   --  Whether the protocol takes the RSSI when no other source is set.
   function Claims_RSSI return Boolean;
   --  Whether the protocol takes the link quality, as CRSF reports it, when
   --  no other source is set.
   function Claims_Link_Quality return Boolean;
   --  Whether the receiver sends telemetry readings, and whether it took the
   --  hub stream or the SmartPort stream, which the serial telemetry then
   --  leaves alone.
   function Takes_Readings return Boolean;
   function Hub_Taken return Boolean;
   function SmartPort_Taken return Boolean;
   procedure Set_Readings (R : Telemetry_Readings);
   procedure Set_Hub_Settings (S : Adaflight.FrSky_Hub_Telemetry.Settings);
   --  The SmartPort stream's value tables from the sensors.
   procedure Set_SmartPort_Build (B : Adaflight.SmartPort_Telemetry.Build_Inputs);
   --  Whether the craft is armed, which a receiver's status frames read.
   procedure Set_Armed (Armed : Boolean);
   --  The bind data into the configuration when a completed bind asked to
   --  save it, or the VTX settings a status frame asked for, once; Notify for
   --  a save the pilot hears confirmed.
   procedure Take_Save
     (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean; Notify : out Boolean);
end Adaflight.STM32.RX_SPI;
