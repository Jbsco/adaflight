package body Adaflight.Compass_Detect.Scan with SPARK_Mode is

   procedure Detect
     (D               : in out Bus_Device;
      B               : Build;
      C               : Config;
      Gyro_Is_MPU9250 : Boolean;
      Detected        : in out Byte;
      Alignment       : out Byte;
      Found           : out Boolean)
   is
      OK         : Boolean;
      Started    : Boolean := C.Hardware = Hardware_Default;
      Chip_Found : Boolean;
      Result     : Byte := Hardware_None;
   begin
      Found := False;
      if B.Simulator then
         Alignment := 0;
         if C.Hardware /= Hardware_None then
            Detect_Chip (D, Virtual, Chip_Found);
            if Chip_Found then
               Detected := Hardware_Default;
               Found := True;
            end if;
         end if;
         return;
      end if;
      Alignment := B.Mag_Align;
      if B.DroneCAN and then C.Hardware = Hardware_DroneCAN then
         Detect_DroneCAN (D, Chip_Found);
         if Chip_Found then
            Detected := Hardware_DroneCAN;
            Found := True;
         end if;
         return;
      end if;
      Set_Interrupt_Pin (D, C.Interrupt_Tag);
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
      elsif C.Bus_Type = Bus_MPU_Slave and then B.MPU_Slave then
         if not Gyro_Is_MPU9250 then
            return;
         end if;
         Set_MPU_Slave (D, C.I2C_Address);
      else
         return;
      end if;
      for Chip in Scanned loop
         pragma Loop_Invariant (Result = Hardware_None);
         pragma Loop_Invariant (if Started then C.Hardware /= Hardware_None);
         Started := Started or else Starts_At (Chip, C.Hardware);
         if Started then
            if Bus_Type (D) = Bus_I2C then
               Set_I2C_Address (D, C.I2C_Address);
            end if;
            if Chip = AK8963 and then Gyro_Is_MPU9250 then
               declare
                  Saved : constant Byte := Bus_Type (D);
               begin
                  Set_MPU_Slave (D, C.I2C_Address);
                  Detect_Chip (D, Chip, Chip_Found);
                  if not Chip_Found then
                     Set_Bus_Type (D, Saved);
                  end if;
               end;
            else
               Detect_Chip (D, Chip, Chip_Found);
            end if;
            if Chip_Found then
               Result := Named (Chip);
               exit;
            end if;
         end if;
      end loop;
      if C.Hardware = Hardware_MPU925X then
         Detect_Chip (D, MPU925X, Chip_Found);
         if not Chip_Found then
            return;
         end if;
         Result := Hardware_MPU925X;
      end if;
      if Result /= Hardware_None then
         Detected := Result;
         Found := True;
      end if;
   end Detect;

end Adaflight.Compass_Detect.Scan;
