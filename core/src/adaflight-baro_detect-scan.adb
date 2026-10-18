package body Adaflight.Baro_Detect.Scan with SPARK_Mode is

   procedure Detect
     (D        : in out Bus_Device;
      B        : Build;
      C        : Bus_Config;
      Hardware : Byte;
      Detected : in out Byte;
      Found    : out Boolean)
   is
      OK         : Boolean;
      Started    : Boolean := Hardware = Hardware_Default;
      Chip_Found : Boolean;
      Variant    : Byte;
      Result     : Byte := Hardware_None;
   begin
      Found := False;
      if not B.Drivers (Virtual) then
         if C.Bus_Type = Bus_I2C and then B.I2C then
            Set_I2C_Instance (D, C.I2C_Device, OK);
            if not OK then
               return;
            end if;
            Set_I2C_Address (D, C.I2C_Address);
         elsif C.Bus_Type = Bus_SPI and then B.SPI then
            Set_SPI_Instance (D, C.SPI_Device, OK);
            if not OK then
               return;
            end if;
            Set_CS_Pin (D, C.SPI_CS);
         else
            return;
         end if;
      end if;
      for Chip in Driver loop
         pragma Loop_Invariant (Result = Hardware_None);
         pragma Loop_Invariant (if Started then Hardware /= Hardware_None);
         Started := Started or else Starts_At (Chip, Hardware);
         if Started and then B.Drivers (Chip) then
            Detect_Chip (D, Chip, C.EOC_Tag, C.XCLR_Tag, Chip_Found, Variant);
            if Chip_Found then
               Result := Named (Chip, Variant, B.SPA06);
               exit;
            end if;
         end if;
      end loop;
      if Result /= Hardware_None then
         Detected := Result;
         Found := True;
      end if;
   end Detect;

end Adaflight.Baro_Detect.Scan;
