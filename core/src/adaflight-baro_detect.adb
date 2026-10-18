package body Adaflight.Baro_Detect with SPARK_Mode is

   Baro_BMP085    : constant Byte := 2;
   Baro_MS5611    : constant Byte := 3;
   Baro_BMP280    : constant Byte := 4;
   Baro_LPS       : constant Byte := 5;
   Baro_QMP6988   : constant Byte := 6;
   Baro_BMP388    : constant Byte := 7;
   Baro_DPS310    : constant Byte := 8;
   Baro_2SMPB_02B : constant Byte := 9;
   Baro_LPS22DF   : constant Byte := 10;
   Baro_BMP580    : constant Byte := 11;
   Baro_BMP581    : constant Byte := 12;
   Baro_Virtual   : constant Byte := 13;
   Baro_SPA06_003 : constant Byte := 14;

   Chip_BMP580 : constant Byte := 16#50#;
   Chip_BMP581 : constant Byte := 16#51#;
   SPL07_003   : constant Byte := 1;

   function Starts_At (Chip : Driver; Hardware : Byte) return Boolean is
     (case Chip is
         when BMP085   => Hardware = Baro_BMP085,
         when MS5611   => Hardware = Baro_MS5611,
         when LPS      => Hardware = Baro_LPS,
         when DPS310   => Hardware in Baro_DPS310 | Baro_SPA06_003,
         when BMP388   => Hardware = Baro_BMP388,
         when BMP280   => Hardware = Baro_BMP280,
         when QMP6988  => Hardware = Baro_QMP6988,
         when SMPB_02B => Hardware = Baro_2SMPB_02B,
         when LPS22DF  => Hardware = Baro_LPS22DF,
         when BMP5xx   => Hardware in Baro_BMP580 | Baro_BMP581,
         when Virtual  => Hardware = Baro_Virtual);

   function Named (Chip : Driver; Variant : Byte; SPA06 : Boolean) return Byte is
   begin
      case Chip is
         when BMP085 =>
            return Baro_BMP085;
         when MS5611 =>
            return Baro_MS5611;
         when LPS =>
            return Baro_LPS;
         when DPS310 =>
            if SPA06 and then Variant = SPL07_003 then
               return Baro_SPA06_003;
            end if;
            return Baro_DPS310;
         when BMP388 =>
            return Baro_BMP388;
         when BMP280 =>
            return Baro_BMP280;
         when QMP6988 =>
            return Baro_QMP6988;
         when SMPB_02B =>
            return Baro_2SMPB_02B;
         when LPS22DF =>
            return Baro_LPS22DF;
         when BMP5xx =>
            if Variant = Chip_BMP580 then
               return Baro_BMP580;
            elsif Variant = Chip_BMP581 then
               return Baro_BMP581;
            end if;
            return Hardware_None;
         when Virtual =>
            return Baro_Virtual;
      end case;
   end Named;

end Adaflight.Baro_Detect;
