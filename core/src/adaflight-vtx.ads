--  The video transmitter settings and their update. The configured band,
--  channel, power, frequency, pit mode frequency and low power disarm
--  policy are brought to the device one parameter per task call, the
--  device state confirmed in its turn, and the device driven while disarmed
--  or while a change is pending. The band and channel follow the stick
--  commands and the switch conditions until the first arm, the power
--  follows the switch conditions always, and a Spektrum control word from
--  the receiver sets band, channel, power and pit mode. The SmartAudio,
--  Tramp and MSP devices are driven, each through its own driver.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Modes;
with Adaflight.VTX_MSP;
with Adaflight.VTX_Settings;
with Adaflight.VTX_Table;
with Adaflight.SmartAudio;
with Adaflight.Tramp;

package Adaflight.VTX with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   subtype Low_Power_Disarm is VTX_Settings.Low_Power_Disarm;
   subtype Settings is VTX_Settings.Settings;

   --  A switch condition: within the range of the aux channel, a band, a
   --  channel and a power above zero are applied.
   Max_Conditions : constant := 10;
   subtype Condition_Index is Positive range 1 .. Max_Conditions;

   type Condition is record
      Aux     : Modes.Aux_Channel := 0;
      Band    : Unsigned_8 := 0;
      Channel : Unsigned_8 := 0;
      Power   : Unsigned_8 := 0;
      Span    : Modes.Channel_Range := (0, 0);
   end record;

   type Conditions is array (Condition_Index) of Condition;

   type Parameter is (Power_Param, Band_Channel_Param, Pit_Mode_Param, Confirm_Param);

   Spektrum_Frame_Mask : constant Unsigned_32 := 16#F000_F000#;
   Spektrum_Frame      : constant Unsigned_32 := 16#E000_E000#;

   type Device_Kind is (No_Device, SmartAudio_Device, Tramp_Device, MSP_Device);

   type State is record
      Kind             : Device_Kind := No_Device;
      SA               : SmartAudio.Driver;
      TR               : Tramp.Driver;
      MD               : VTX_MSP.Driver;
      Device_Present   : Boolean := False;
      Prepend_Zero     : Boolean := False;
      Schedule         : Parameter := Power_Param;
      Prev_Pit_Switch  : Boolean := False;
      Locked           : Boolean := False;
      Selected_Band    : Unsigned_8 := 0;
      Selected_Channel : Unsigned_8 := 0;
      Spektrum_Word    : Unsigned_32 := not Spektrum_Frame;
      Prev_Spektrum    : Unsigned_32 := 0;
   end record;

   type Inputs is record
      Now_Ms           : Unsigned_32 := 0;
      Now_Us           : Unsigned_32 := 0;
      Armed            : Boolean := False;
      Was_Ever_Armed   : Boolean := False;
      Failsafe         : Boolean := False;
      Cli_Mode         : Boolean := False;
      Pit_Switch       : Boolean := False;
      Control_Disabled : Boolean := False;
   end record;

   --  The device events of the kind in use; Consumed counts the received
   --  bytes taken, the rest to be offered again. MSP_Send reports the MSP
   --  driver's configuration frame to push, and MSP_Status_Due the MSP
   --  menu's status line due an update.
   type Events is record
      Device         : SmartAudio.Events;
      Tramp_Tx       : Tramp.Events;
      MSP_Frame      : VTX_MSP.Config_Frame := (others => 0);
      MSP_Send       : Boolean := False;
      MSP_Status_Due : Boolean := False;
      Consumed       : Natural := 0;
      Save           : Boolean := False;
   end record;

   --  The driver starts with the port, and the settings are made whole: the
   --  frequency of a configured band and channel, and the pit mode
   --  frequency raised to the user range. Save asks for the settings to be
   --  stored when one changed.
   procedure Init (V : out State; S : in out Settings; T : VTX_Table.Table; Kind : Device_Kind;
                   Port_Opened, Softserial : Boolean; Save : out Boolean);

   --  One task call with the bytes received from the device.
   procedure Update (V : in out State; S : in out Settings; T : VTX_Table.Table; Inp : Inputs; Rx : Byte_Array;
                     E : out Events)
     with Post => E.Consumed <= Rx'Length;

   --  A control word from the Spektrum receiver, taken at the next call.
   procedure Offer_Spektrum_Control (V : in out State; Word : Unsigned_32);

   --  The stick commands, locked from the first arm on.
   procedure Increment_Band (V : in out State; S : in out Settings; Armed : Boolean);
   procedure Decrement_Band (V : in out State; S : in out Settings; Armed : Boolean);
   procedure Increment_Channel (V : in out State; S : in out Settings; Armed : Boolean);
   procedure Decrement_Channel (V : in out State; S : in out Settings; Armed : Boolean);

   --  Every active condition applies in order, the later one winning a
   --  field; band and channel only until the first arm.
   procedure Update_Activated_Channel (V : in out State; S : in out Settings; C : Conditions; Aux : Modes.Aux_Values;
                                       Armed : Boolean);

   --  The next band or channel from the device's, wrapping within the
   --  table; the next power index, wrapping below the level count.
   procedure Cycle_Band_Or_Channel (V : State; S : in out Settings; T : VTX_Table.Table;
                                    Band_Step, Channel_Step : Unsigned_8);
   procedure Cycle_Power (V : State; S : in out Settings; T : VTX_Table.Table; Power_Step : Unsigned_8);

end Adaflight.VTX;
