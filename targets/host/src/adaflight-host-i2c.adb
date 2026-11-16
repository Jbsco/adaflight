with Interfaces;
--  The host's I2C buses: the first carries a model of a BMP280 at the
--  address 16#76#, answering its identity, the calibration and the raw
--  readings of its datasheet's worked example, whose compensation gives
--  2508 hundredths of a degree and 100653 pascal, and keeping the control
--  registers written to it, and the OLED display's model when one is on.
--  With the environment variable ADAFLIGHT_BARO_CHIP set to DPS310 or SPL07
--  that address carries a DPS310 or an SPL07-003 in the BMP280's place, the
--  two alike but for the identity: its identity, a status
--  with its coefficients and sensor ready, coefficients and raw readings
--  whose compensation gives 2600 hundredths of a degree and 101015 pascal,
--  and a register store that its soft reset clears. With MS5611 the address
--  16#77# carries an MS5611: the PROM of its datasheet's worked example with
--  its check, and the ADC result of the conversion a command asked for last,
--  whose compensation gives 2007 hundredths of a degree and 100009 pascal.
--  Every other address and bus answers nothing.
with Ada.Environment_Variables;
with Adaflight.Board;
with Adaflight.Host_OLED;
package body Adaflight.STM32.I2C is
   use type Interfaces.Unsigned_8;
   Running : array (Bus) of Boolean := (others => False);
   Chip_Address : constant Byte := 16#76#;
   --  An MS4525 pitot at its default address: a fresh frame at 10 to 90 percent of its pressure range plus a
   --  quarter, and a temperature count of 1023. When ADAFLIGHT_PITOT_STEP names a count, the frames after that
   --  many reads show a higher pressure, so a sensor zeroed at rest then reads an airspeed.
   Pitot_Address : constant Byte := 16#28#;
   Pitot_Frame   : constant Byte_Array (0 .. 3) := (16#26#, 16#66#, 16#7F#, 16#E0#);
   Pitot_Moving  : constant Byte_Array (0 .. 3) := (16#28#, 16#66#, 16#7F#, 16#E0#);
   Pitot_Step    : constant Natural := Natural'Value (Ada.Environment_Variables.Value ("ADAFLIGHT_PITOT_STEP", "0"));
   Pitot_Reads   : Natural := 0;
   Chip_Id      : constant Byte := 16#58#;
   --  The calibration of the datasheet's example, little-endian words:
   --  T1 27504, T2 26435, T3 -1000, P1 36477, P2 -10685, P3 3024, P4 2855,
   --  P5 140, P6 -7, P7 15500, P8 -14600, P9 6000.
   Calibration : constant Byte_Array (0 .. 23) :=
     (16#70#, 16#6B#, 16#43#, 16#67#, 16#18#, 16#FC#, 16#7D#, 16#8E#, 16#43#, 16#D6#, 16#D0#, 16#0B#,
      16#27#, 16#0B#, 16#8C#, 16#00#, 16#F9#, 16#FF#, 16#8C#, 16#3C#, 16#F8#, 16#C6#, 16#70#, 16#17#);
   --  The raw pressure 415148 and temperature 519888 as the chip stores
   --  them, twenty bits in three bytes each.
   Readings : constant Byte_Array (0 .. 5) := (16#65#, 16#5A#, 16#C0#, 16#7E#, 16#ED#, 16#00#);
   Control  : Byte := 0;
   Config   : Byte := 0;
   --  The DPS310 model: C0 50, C1 100, C00 100000, C10 -20000, C01 1000 and
   --  C20 2000 in the chip's packing, the rest zero, and the raw pressure
   --  -12698 and temperature 2540, 24 bits each with the high byte first.
   Baro_Chip        : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_BARO_CHIP", "");
   DPS_Model        : constant Boolean := Baro_Chip = "DPS310" or else Baro_Chip = "SPL07";
   DPS_Id           : constant Byte := (if Baro_Chip = "SPL07" then 16#11# else 16#10#);
   DPS_Coefficients : constant Byte_Array (0 .. 17) :=
     (16#03#, 16#20#, 16#64#, 16#18#, 16#6A#, 16#0F#, 16#B1#, 16#E0#, 16#03#, 16#E8#, 16#00#, 16#00#,
      16#07#, 16#D0#, 16#00#, 16#00#, 16#00#, 16#00#);
   DPS_Readings     : constant Byte_Array (0 .. 5) := (16#FF#, 16#CE#, 16#66#, 16#00#, 16#09#, 16#EC#);
   DPS_Ready        : constant Byte := 16#C0#;
   DPS_Registers    : Byte_Array (0 .. 16#3F#) := (others => 0);
   --  The MS5611 model: PROM words 1, 40127, 36924, 23317, 23282, 33464, 28312
   --  and the check 8, the pressure reading 9085466 and the temperature
   --  reading 8569150, each with the high byte first.
   MS_Model         : constant Boolean := Baro_Chip = "MS5611";
   MS_Address       : constant Byte := 16#77#;
   MS_PROM          : constant Byte_Array (0 .. 15) :=
     (16#00#, 16#01#, 16#9C#, 16#BF#, 16#90#, 16#3C#, 16#5B#, 16#15#, 16#5A#, 16#F2#, 16#82#, 16#B8#,
      16#6E#, 16#98#, 16#00#, 16#08#);
   MS_Pressure      : constant Byte_Array (0 .. 2) := (16#8A#, 16#A2#, 16#1A#);
   MS_Temperature   : constant Byte_Array (0 .. 2) := (16#82#, 16#C1#, 16#3E#);
   MS_Result        : Byte_Array (0 .. 2) := (others => 0);

   procedure Init (B : Bus; SCL, SDA : Adaflight.Pins.Pin) is
   begin
      Running (B) := True;
   end Init;

   function Started (B : Bus) return Boolean is (Running (B));

   function Answers (B : Bus; Address : Byte) return Boolean is
     (B = I2C1 and then Running (B)
      and then ((Address = Chip_Address and then (if DPS_Model then Adaflight.Board.Baro_DPS310
                                                  else Adaflight.Board.Baro_BMP280))
                or else (Address = MS_Address and then MS_Model and then Adaflight.Board.Baro_MS5611)
                or else Address = Pitot_Address
                or else (Address = Adaflight.Host_OLED.Address and then Adaflight.Host_OLED.On)));

   procedure Read (B : Bus; Address : Byte; Register : Byte; Data : out Byte_Array; OK : out Boolean) is
   begin
      Data := (others => 0);
      OK := Answers (B, Address);
      if not OK then
         return;
      end if;
      if Address = Pitot_Address then
         if Pitot_Reads < Natural'Last then
            Pitot_Reads := Pitot_Reads + 1;
         end if;
         for I in Data'Range loop
            Data (I) :=
              (if Pitot_Step > 0 and then Pitot_Reads > Pitot_Step then Pitot_Moving ((I - Data'First) mod 4)
               else Pitot_Frame ((I - Data'First) mod 4));
         end loop;
         return;
      end if;
      if Address = MS_Address then
         for I in Data'Range loop
            declare
               R : constant Natural := Natural (Register) + (I - Data'First);
            begin
               Data (I) :=
                 (if R in 16#A0# .. 16#AF# then MS_PROM (R - 16#A0#)
                  elsif R in 0 .. 2 then MS_Result (R)
                  else 0);
            end;
         end loop;
         return;
      end if;
      if Address = Chip_Address and then DPS_Model then
         for I in Data'Range loop
            declare
               R : constant Natural := Natural (Register) + (I - Data'First);
            begin
               Data (I) :=
                 (if R in 0 .. 5 then DPS_Readings (R)
                  elsif R = 16#08# then DPS_Registers (R) or DPS_Ready
                  elsif R = 16#0D# then DPS_Id
                  elsif R in 16#10# .. 16#21# then DPS_Coefficients (R - 16#10#)
                  elsif R <= DPS_Registers'Last then DPS_Registers (R)
                  else 0);
            end;
         end loop;
         return;
      end if;
      for I in Data'Range loop
         declare
            R : constant Natural := Natural (Register) + (I - Data'First);
         begin
            Data (I) :=
              (if R = 16#D0# then Chip_Id
               elsif R in 16#88# .. 16#9F# then Calibration (R - 16#88#)
               elsif R = 16#F4# then Control
               elsif R = 16#F5# then Config
               elsif R in 16#F7# .. 16#FC# then Readings (R - 16#F7#)
               else 0);
         end;
      end loop;
   end Read;

   procedure Write (B : Bus; Address : Byte; Register : Byte; Value : Byte; OK : out Boolean) is
   begin
      OK := Answers (B, Address);
      if OK and then Address = Adaflight.Host_OLED.Address then
         Adaflight.Host_OLED.Write (Register, Value);
      elsif OK and then Address = MS_Address then
         if Register = 16#1E# then
            MS_Result := (others => 0);
         elsif (Register and 16#F0#) = 16#40# then
            MS_Result := MS_Pressure;
         elsif (Register and 16#F0#) = 16#50# then
            MS_Result := MS_Temperature;
         end if;
      elsif OK and then Address = Chip_Address and then DPS_Model then
         if Register = 16#0C# and then (Value and 16#0F#) = 16#09# then
            DPS_Registers := (others => 0);
         elsif Natural (Register) <= DPS_Registers'Last then
            DPS_Registers (Natural (Register)) := Value;
         end if;
      elsif OK then
         if Register = 16#F4# then
            Control := Value;
         elsif Register = 16#F5# then
            Config := Value;
         end if;
      end if;
   end Write;
end Adaflight.STM32.I2C;
