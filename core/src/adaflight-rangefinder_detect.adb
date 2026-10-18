package body Adaflight.Rangefinder_Detect with SPARK_Mode is

   HCSR04_Period_Ms : constant Delay_Ms := 70;
   UPT1_Period_Ms   : constant Delay_Ms := 20;

   function Driver_Of (Hardware : Byte) return Driver is
     (case Hardware is
         when 1           => HCSR04,
         when 2 | 3 | 8   => TF,
         when 4 .. 7      => MT,
         when 9 .. 14     => Nooploop,
         when others      => UPT1);

   function Period_Ms (Chip : Driver; Reported : Delay_Ms) return Delay_Ms is
     (case Chip is
         when HCSR04            => HCSR04_Period_Ms,
         when UPT1              => UPT1_Period_Ms,
         when TF | MT | Nooploop => Reported);

end Adaflight.Rangefinder_Detect;
