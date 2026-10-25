--  MAVLink telemetry: the stream messages the flight controller sends,
--  each packed in the library's wire order, framed as MAVLink 2 with its
--  payload's trailing zeros trimmed, numbered on the link's sequence and
--  checked with the message's CRC extra; the streams' intervals from the
--  settings' rates or per message from the ground station; and the arming
--  report as a status text when the disable reasons change. The port, the
--  receiver's link and the readings stay with the target.
with Interfaces;
with Adaflight.Arming;
with Adaflight.Battery;
with Adaflight.MAVLink_Frames;

package Adaflight.MAVLink_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Integer_64 is Interfaces.Integer_64;

   --  The stream messages in the reference's table order.
   type Output_Message is
     (Sys_Status, RC_Channels_Raw, GPS_Raw_Int, Global_Position_Int, GPS_Global_Origin, Home_Position, Attitude,
      Heartbeat, VFR_HUD, Battery_Status);

   type Stream is (Extended_Status, RC_Channels, Position, Extra1, Extra2, Extra3);

   Stream_Of : constant array (Output_Message) of Stream :=
     (Sys_Status => Extended_Status, RC_Channels_Raw => RC_Channels,
      GPS_Raw_Int | Global_Position_Int | GPS_Global_Origin | Home_Position => Position, Attitude => Extra1,
      Heartbeat | VFR_HUD => Extra2, Battery_Status => Extra3);

   Id_Of : constant array (Output_Message) of Natural := (1, 35, 24, 33, 49, 242, 30, 0, 74, 147);

   Disabled        : constant Unsigned_32 := Unsigned_32'Last;
   Min_Interval_Ms : constant := 20;
   Delay_Us        : constant := 20_000;

   type Stream_Rates is array (Stream) of Unsigned_8;

   --  The streams' rates in hertz, zero off; the charge drawn shown as the
   --  heading over a divisor; the cell voltages reported one by one.
   type Settings is record
      Rates               : Stream_Rates :=
        (Extended_Status => 2, RC_Channels => 1, Position => 2, Extra1 => 2, Extra2 => 2, Extra3 => 1);
      MAh_Heading_Divisor : Unsigned_16 := 0;
      Report_Cell_Voltage : Boolean := False;
   end record;

   type Schedule is record
      Interval_Ms : Unsigned_32 := Disabled;
      Due_Ms      : Unsigned_32 := 0;
   end record;
   type Schedules is array (Output_Message) of Schedule;

   --  The streams' schedules, the link's sequence, the disable reasons last
   --  reported and the time of the last send.
   type State is record
      Streams         : Schedules;
      Tx_Seq          : Unsigned_8 := 0;
      Last_Flags      : Adaflight.Arming.Disable_Set := (others => False);
      Last_Message_Us : Unsigned_32 := 0;
   end record;

   subtype RC_Value is Float range 0.0 .. 65_535.0;
   type RC_Values is array (0 .. 7) of RC_Value;
   Altitude_Bound : constant := 214_748_364;
   subtype Altitude_Range is Integer_32 range -Altitude_Bound .. Altitude_Bound;
   RTC_Bound : constant := 2 ** 53;

   --  What the messages read: the battery, the RSSI and channels, the
   --  attitude, the sensors, the GPS solution and home, the altitude, the
   --  mixer, arming, failsafe and flight modes, the clock and the arming
   --  disable reasons.
   type Inputs is record
      Battery             : Adaflight.Battery.Battery_State := Adaflight.Battery.OK;
      Voltage_Configured  : Boolean := False;
      Amperage_Configured : Boolean := False;
      Pack_Voltage        : Unsigned_16 := 0;
      Cell_Voltage        : Unsigned_16 := 0;
      Amperage            : Integer_32 := 0;
      MAh_Drawn           : Integer_32 := 0;
      Battery_Percent     : Unsigned_8 := 0;
      Cell_Count          : Unsigned_8 := 0;
      RSSI                : Unsigned_16 := 0;
      Channel_Count       : Natural range 0 .. 18 := 0;
      RC                  : RC_Values := (others => 1500.0);
      Roll                : Integer_16 := 0;
      Pitch               : Integer_16 := 0;
      Yaw                 : Integer_16 := 0;
      GPS_Present         : Boolean := False;
      Mag_Present         : Boolean := False;
      Baro_Present        : Boolean := False;
      GPS_Fix             : Boolean := False;
      GPS_Fix_Home        : Boolean := False;
      Latitude            : Integer_32 := 0;
      Longitude           : Integer_32 := 0;
      Altitude_Cm         : Altitude_Range := 0;
      HDOP                : Unsigned_16 := 0;
      VDOP                : Unsigned_16 := 0;
      Ground_Speed        : Unsigned_16 := 0;
      Ground_Course       : Unsigned_16 := 0;
      Satellites          : Unsigned_8 := 0;
      H_Acc               : Unsigned_32 := 0;
      V_Acc               : Unsigned_32 := 0;
      S_Acc               : Unsigned_32 := 0;
      Vel_N               : Integer_16 := 0;
      Vel_E               : Integer_16 := 0;
      Vel_D               : Integer_16 := 0;
      Home_Latitude       : Integer_32 := 0;
      Home_Longitude      : Integer_32 := 0;
      Home_Altitude_Cm    : Altitude_Range := 0;
      Estimated_Alt_Cm    : Altitude_Range := 0;
      Mixer_Mode          : Unsigned_8 := 3;
      Armed               : Boolean := False;
      Failsafe_Active     : Boolean := False;
      Modes               : Unsigned_16 := 0;
      Has_Time            : Boolean := False;
      RTC_Ms              : Integer_64 range -RTC_Bound .. RTC_Bound := 0;
      Disable_Flags       : Adaflight.Arming.Disable_Set := (others => False);
   end record;

   Max_Output : constant := 640;
   subtype Output_Bytes is Adaflight.MAVLink_Frames.Byte_Buffer (1 .. Max_Output);
   type Output is record
      Data   : Output_Bytes := (others => 0);
      Length : Natural range 0 .. Max_Output := 0;
   end record;

   --  The streams' intervals from the settings, each first due one interval
   --  and three milliseconds a place from now, a stream off staying off.
   procedure Configure_Intervals (S : in out State; C : Settings; Now_Ms : Unsigned_32);

   --  A message's interval in microseconds, at most Integer_32'Last: minus one
   --  when off, zero when not a stream message.
   function Message_Interval_Us (S : State; Id : Natural) return Integer_32;

   --  A message's interval set by the ground station: zero restores the
   --  setting's, anything under twenty milliseconds takes twenty.
   procedure Set_Message_Interval
     (S : in out State; C : Settings; Id : Natural; Interval_Ms : Unsigned_32; Found : out Boolean);

   --  One telemetry pass: when the receiver's buffer report asks for it, or
   --  twenty milliseconds after the last pass without one, every stream
   --  message due and the arming report.
   procedure Handle
     (S : in out State; C : Settings; Inp : Inputs; Now_Us, Now_Ms : Unsigned_32; Tx_Valid, Tx_Should_Send : Boolean;
      O : out Output);

end Adaflight.MAVLink_Telemetry;
