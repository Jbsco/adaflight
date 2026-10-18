--  Rangefinder detection over the configured hardware's driver alone. A found
--  rangefinder reschedules the rangefinder task and names the configured
--  hardware. Hardware without a driver finds nothing.
generic
   type Device is limited private;
   with procedure Detect_Chip
     (D        : in out Device;
      Chip     : Driver;
      Hardware : Byte;
      Found    : out Boolean;
      Reported : out Delay_Ms);
   with procedure Reschedule (D : in out Device; Period_Us : Natural);
package Adaflight.Rangefinder_Detect.Probe with SPARK_Mode is
   use type Byte;

   procedure Detect (D : in out Device; Hardware : Byte; Detected : in out Byte; Found : out Boolean)
     with Post => (if Found then Has_Driver (Hardware) and then Detected = Hardware else Detected = Detected'Old);

end Adaflight.Rangefinder_Detect.Probe;
