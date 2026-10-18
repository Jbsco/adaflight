package body Adaflight.Gyro_Start with SPARK_Mode is

   Sensor_ICM20649  : constant Byte := 10;
   Sensor_BMI160    : constant Byte := 18;
   Sensor_BMI270    : constant Byte := 19;
   Sensor_BMI423    : constant Byte := 20;
   Sensor_LSM6DSO   : constant Byte := 21;
   Sensor_ICM45605  : constant Byte := 25;
   Sensor_ICM45686  : constant Byte := 26;
   Sensor_ICM56686  : constant Byte := 27;
   LPF_Experimental : constant Byte := 3;

   function Sample_Rates (Sensor : Byte; Hardware_LPF : Byte) return Rates is
   begin
      case Sensor is
         when Sensor_BMI160 =>
            return (Rate_Code => Rate_3200_Hz, Gyro_Hz => 3_200, Acc_Hz => 800);
         when Sensor_BMI270 =>
            if Hardware_LPF = LPF_Experimental then
               return (Rate_Code => Rate_6400_Hz, Gyro_Hz => 6_400, Acc_Hz => 800);
            end if;
            return (Rate_Code => Rate_3200_Hz, Gyro_Hz => 3_200, Acc_Hz => 800);
         when Sensor_BMI423 =>
            return (Rate_Code => Rate_6400_Hz, Gyro_Hz => 6_400, Acc_Hz => 800);
         when Sensor_ICM20649 =>
            return (Rate_Code => Rate_9_kHz, Gyro_Hz => 9_000, Acc_Hz => 1_125);
         when Sensor_LSM6DSO =>
            return (Rate_Code => Rate_6664_Hz, Gyro_Hz => 6_664, Acc_Hz => 833);
         when Sensor_ICM45686 | Sensor_ICM45605 | Sensor_ICM56686 =>
            return (Rate_Code => Rate_6400_Hz, Gyro_Hz => 6_400, Acc_Hz => 1_600);
         when others =>
            return (Rate_Code => Rate_8_kHz, Gyro_Hz => 8_000, Acc_Hz => 1_000);
      end case;
   end Sample_Rates;

   --  The ICM-20601, ICM-20602, ICM-20608-G, ICM-20649, ICM-20689 and
   --  ICM-40609-D lack it, as does any hardware past the list.
   function Overflow_Protected (Hardware : Byte) return Boolean is
     (case Hardware is
         when 0 .. 6 | 12 .. 20 | 22 .. 29 => True,
         when others => False);

   procedure Check_Update (Data_Ready : in out Boolean; Updated : out Boolean) is
   begin
      Updated := Data_Ready;
      Data_Ready := False;
   end Check_Update;

end Adaflight.Gyro_Start;
