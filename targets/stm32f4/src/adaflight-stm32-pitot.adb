with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Runtime;
with Adaflight.MS4525;
with Adaflight.Pitot;
with Adaflight.STM32.I2C;
with Adaflight.STM32.Pilot;
package body Adaflight.STM32.Pitot is
   use type Interfaces.Unsigned_8;
   package Core renames Adaflight.Pitot;
   package I2C renames Adaflight.STM32.I2C;
   use type Core.Source;

   Period_Us : constant := 50_000;
   Bus_I2C   : constant Interfaces.Unsigned_8 := 1;

   Settings  : Core.Settings;
   Sensor    : Core.Sensor;
   Bus       : I2C.Bus := I2C.I2C1;
   Address   : Byte := 0;
   I2C_Found : Boolean := False;

   procedure Read_Frame (F : out Adaflight.MS4525.Frame; OK : out Boolean) is
   begin
      I2C.Read (Bus, Address, 16#FF#, F, OK);
   end Read_Frame;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      P  : Adaflight.Config_Groups.Pitot_Config_Record renames C.Pitot_Config;
      F  : Adaflight.MS4525.Frame := (others => 0);
      OK : Boolean := False;
   begin
      Settings := Adaflight.Config_Runtime.Pitot_Settings_Of (P);
      I2C_Found := False;
      if Core.Is_Configured (Settings) and then Settings.Hardware in Core.Default | Core.MS4525
        and then P.Pitot_Bus_Type = Bus_I2C and then P.Pitot_I2c_Device in 1 .. 4
        and then I2C.Started (I2C.Bus'Val (P.Pitot_I2c_Device - 1))
      then
         Bus := I2C.Bus'Val (P.Pitot_I2c_Device - 1);
         Address := (if P.Pitot_I2c_Address = 0 then Adaflight.MS4525.Default_Address else P.Pitot_I2c_Address);
         Read_Frame (F, OK);
         I2C_Found := OK;
      end if;
      Core.Init (Sensor, Settings, I2C_Detected => I2C_Found);
   end Init;

   function Configured return Boolean is (Core.Is_Configured (Settings));
   function Detected return Boolean is (Sensor.Active /= Core.None);

   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta) is
      F           : Adaflight.MS4525.Frame := (others => 0);
      OK          : Boolean := False;
      Valid       : Boolean := False;
      Pressure    : Adaflight.MS4525.Pressure_Pa := 0.0;
      Temperature : Adaflight.MS4525.Kelvin := 273.15;
   begin
      Next_Period_Us := Period_Us;
      if not Core.Is_Configured (Settings) then
         return;
      end if;
      if I2C_Found then
         Read_Frame (F, OK);
         if OK then
            Adaflight.MS4525.Decode (F, Valid, Pressure, Temperature);
         end if;
      end if;
      Core.Update
        (Sensor, Settings,
         (Now_Us          => Now_Us,
          Armed           => Adaflight.STM32.Pilot.Armed,
          I2C_Read        => OK and then Valid,
          I2C_Pressure    => Pressure,
          I2C_Temperature => Temperature,
          Can_Frame       => False,
          Can_Pressure    => 0.0,
          Can_Temperature => 0.0,
          Can_Update_Us   => 0));
   end Update;

   procedure Start_Calibration is
   begin
      Core.Start_Calibration (Sensor);
   end Start_Calibration;

   function Calibrated return Boolean is (Core.Is_Calibrated (Sensor));
   function Airspeed_Cm_S return Float is (Sensor.Airspeed);
   function Diff_Pressure_Pa return Float is (Sensor.Diff_Pressure);
   function Temperature_K return Float is (Sensor.Temperature);

end Adaflight.STM32.Pitot;
