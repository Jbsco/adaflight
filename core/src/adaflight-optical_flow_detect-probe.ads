--  Optical flow detection over the configured hardware's driver alone. The MT
--  driver takes the rangefinder's configured hardware, and both drivers need
--  the build's rangefinder drivers. A found sensor reschedules the optical
--  flow task at the delay its driver reports and names the configured
--  hardware.
generic
   type Device is limited private;
   with procedure Detect_Chip
     (D           : in out Device;
      Chip        : Driver;
      Rangefinder : Byte;
      Found       : out Boolean;
      Reported    : out Delay_Ms);
   with procedure Reschedule (D : in out Device; Period_Us : Natural);
package Adaflight.Optical_Flow_Detect.Probe with SPARK_Mode is
   use type Byte;

   procedure Detect
     (D                 : in out Device;
      Rangefinder_Built : Boolean;
      Hardware          : Byte;
      Rangefinder       : Byte;
      Detected          : in out Byte;
      Found             : out Boolean)
     with Post => (if Found then Rangefinder_Built and then Hardware in Hardware_MT | Hardware_UPT1
                   and then Detected = Hardware
                   else Detected = Detected'Old);

end Adaflight.Optical_Flow_Detect.Probe;
