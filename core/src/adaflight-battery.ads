--  The battery: the pack voltage from the analog meter or the ESC sensor, the
--  current from the analog, virtual, ESC sensor or MSP meter, the presence
--  and cell count detection on a stable voltage, the warning and critical
--  states with their hysteresis and durations, the consumption state from
--  the capacity, the low voltage cutoff ramp, and the energy drawn.
with Interfaces;
with Adaflight.Filters;

package Adaflight.Battery with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Time_Us is Unsigned_32;
   subtype Time_Ms is Unsigned_32;

   --  Voltages in hundredths of a volt, currents in hundredths of an ampere.
   subtype Centivolts is Natural range 0 .. 65_535;
   subtype ADC_Count is Natural range 0 .. 4_095;
   subtype Percent is Natural range 0 .. 100;
   subtype Cell_Count is Natural range 0 .. 255;

   type Voltage_Source is (None, Analog, ESC);
   type Current_Source is (None, Analog, Virtual, ESC, MSP);

   --  The battery configuration, the active profile, and the analog meters'
   --  scaling, within the configuration interface's ranges.
   type Settings is record
      Voltage_Meter                  : Voltage_Source := Analog;
      Current_Meter                  : Current_Source := Analog;
      Not_Present_Cell_Voltage       : Centivolts := 300;
      LVC_Percentage                 : Percent := 100;
      Voltage_Alerts                 : Boolean := True;
      Consumption_Alerts             : Boolean := False;
      Hysteresis                     : Natural range 0 .. 255 := 1;
      Display_Filter_Period          : Positive range 1 .. 255 := 30;
      Current_Filter_Period          : Positive range 1 .. 255 := 10;
      Duration_For_Warning           : Natural range 0 .. 255 := 0;
      Duration_For_Critical          : Natural range 0 .. 255 := 0;
      Max_Cell_Voltage               : Positive range 1 .. 65_535 := 430;
      Min_Cell_Voltage               : Centivolts := 330;
      Warning_Cell_Voltage           : Centivolts := 350;
      Full_Cell_Voltage              : Centivolts := 410;
      Capacity_mAh                   : Natural range 0 .. 65_535 := 0;
      Force_Cell_Count               : Cell_Count := 0;
      Consumption_Warning_Percentage : Percent := 10;
      Voltage_Scale                  : Natural range 0 .. 255 := 110;
      Voltage_Divider                : Positive range 1 .. 255 := 10;
      Voltage_Multiplier             : Positive range 1 .. 255 := 1;
      Current_Scale                  : Integer range -32_768 .. 32_767 := 400;
      Current_Offset                 : Integer range -32_768 .. 32_767 := 0;
      Virtual_Scale                  : Integer range -16_000 .. 16_000 := 0;
      Virtual_Offset                 : Natural range 0 .. 16_000 := 0;
      ESC_Current_Offset             : Natural range 0 .. 16_000 := 0;
      --  The sag compensation, which a PID profile asks for with the RPM
      --  limit off: the voltage task at 200 Hz, and the sag filter's period
      --  in tenths of a second.
      Sag_Compensation               : Boolean := False;
      Sag_Filter_Period              : Positive range 1 .. 255 := 2;
   end record;

   --  In the order the overall state takes its maximum over.
   type Battery_State is (OK, Warning, Critical, Not_Present, Init);
   type Alert is (Silence, Low, Critical_Low);

   type Voltage_Meter is record
      Display_Filtered     : Centivolts := 0;
      Stable_Prev_Filtered : Centivolts := 0;
      Stable_Last_Update   : Time_Ms := 0;
      Stable_Bits          : Unsigned_16 := 0;
      Unfiltered           : Centivolts := 0;
      Sag_Filtered         : Centivolts := 0;
   end record;

   subtype Centiamps is Integer_32 range -2 ** 24 .. 2 ** 24;
   subtype Charge_mAh is Integer_32 range -2 ** 30 .. 2 ** 30;

   --  The ESC sensor's combined reading: its age in sensor periods, the
   --  voltage, the current, and the consumption in milliampere hours.
   type ESC_Reading is record
      Data_Age    : Natural range 0 .. 255 := 0;
      Voltage     : Centivolts := 0;
      Current     : Integer_32 range -2 ** 23 .. 2 ** 23 := 0;
      Consumption : Integer_32 range -2 ** 23 .. 2 ** 23 := 0;
   end record;

   --  What the other meters read: the ESC sensor while its feature is on,
   --  and for the virtual meter the arming flag, the low throttle status,
   --  the motor stop feature and the mixer throttle. Now_Ms is the
   --  millisecond clock the ESC meter reads.
   type Meter_Inputs is record
      ESC_Sensor   : Boolean := False;
      ESC          : ESC_Reading;
      Armed        : Boolean := False;
      Throttle_Low : Boolean := False;
      Motor_Stop   : Boolean := False;
      Throttle     : Float range 0.0 .. 1.0 := 0.0;
      Now_Ms       : Time_Ms := 0;
   end record;

   No_Meters : constant Meter_Inputs := (others => <>);

   type Current_Meter is record
      Amperage        : Centiamps := 0;
      Amperage_Latest : Centiamps := 0;
      mAh_Drawn       : Charge_mAh := 0;
      mAh_Drawn_F     : Float range -2.0 ** 30 .. 2.0 ** 30 := 0.0;
   end record;

   type State is record
      Voltage                : Voltage_Meter;
      Display_Filter         : Filters.PT1;
      Sag_Filter             : Filters.PT1;
      Current                : Current_Meter;
      Current_Filter         : Filters.PT1;
      Cells                  : Cell_Count := 0;
      Warning_Voltage        : Centivolts := 0;
      Critical_Voltage       : Centivolts := 0;
      Warning_Hysteresis     : Centivolts := 0;
      Critical_Hysteresis    : Centivolts := 0;
      Voltage_State          : Battery_State := Init;
      Consumption_State      : Battery_State := OK;
      Overall                : Battery_State := Init;
      LVC_Enabled            : Boolean := False;
      LVC_Percentage         : Percent := 100;
      LVC_Start_Us           : Time_Us := 0;
      Last_Voltage_Change_Ms : Time_Ms := 0;
      Current_Serviced_Us    : Time_Us := 0;
      mAh_Previous           : Charge_mAh := 0;
      Watt_Hours             : Float range -1.0e9 .. 1.0e9 := 0.0;
      MSP_Amperage           : Unsigned_16 := 0;
      MSP_mAh                : Unsigned_16 := 0;
      MSP_Request_At         : Time_Us := 0;
      MSP_Request            : Boolean := False;
   end record;

   procedure Init (S : out State; C : Settings);

   --  The voltage task: the analog sample through the display filter and the
   --  divider, and with the sag compensation through the sag filter, or the
   --  ESC sensor's voltage through the display filter while its feature is
   --  on, and the stability record at the millisecond clock.
   procedure Update_Voltage (S : in out State; C : Settings; Raw : ADC_Count; Now_Ms : Time_Ms;
                             Meters : Meter_Inputs := No_Meters);

   --  The current task: the analog sample through its filter and scale, the
   --  virtual meter's estimate from the throttle, the ESC sensor's current
   --  and consumption with the offset, or the MSP values, and the charge
   --  drawn since the last call for the analog and virtual meters. The MSP
   --  meter asks for an analog reply every 100 ms through MSP_Request.
   procedure Update_Current (S : in out State; C : Settings; Raw : ADC_Count; Now_Us : Time_Us;
                             Meters : Meter_Inputs := No_Meters);

   --  The current and the capacity drawn from an MSP analog reply, for the
   --  MSP meter.
   procedure Set_MSP_Current (S : in out State; Amperage : Unsigned_16; mAh : Unsigned_16);

   --  Presence and cell count from a stable voltage, while disarmed.
   procedure Update_Presence (S : in out State; C : Settings);

   --  The voltage, consumption, and overall states, the cutoff ramp, and
   --  the energy drawn.
   procedure Update_States (S : in out State; C : Settings; Now_Us : Time_Us; Now_Ms : Time_Ms);

   function Alarm (S : State; C : Settings) return Alert;

   function Percentage_Remaining (S : State; C : Settings) return Percent;

   function Voltage_Is_Stable (S : State) return Boolean;

   --  The sag-filtered voltage per cell, or 0 before the cell count is known.
   function Sag_Cell_Voltage (S : State) return Centivolts is
     (if S.Cells > 0 then S.Voltage.Sag_Filtered / S.Cells else 0);

end Adaflight.Battery;
