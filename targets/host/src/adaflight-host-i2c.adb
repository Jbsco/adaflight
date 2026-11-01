with Interfaces;
--  The host's I2C buses: the first carries a model of a BMP280 at the
--  address 16#76#, answering its identity, the calibration and the raw
--  readings of its datasheet's worked example, whose compensation gives
--  2508 hundredths of a degree and 100653 pascal, and keeping the control
--  registers written to it. Every other address and bus answers nothing.
with Adaflight.Board;
package body Adaflight.STM32.I2C is
   use type Interfaces.Unsigned_8;
   Running : array (Bus) of Boolean := (others => False);
   Chip_Address : constant Byte := 16#76#;
   --  An MS4525 pitot at its default address: a fresh frame at 10 to 90 percent of its pressure range plus a
   --  quarter, and a temperature count of 1023.
   Pitot_Address : constant Byte := 16#28#;
   Pitot_Frame   : constant Byte_Array (0 .. 3) := (16#26#, 16#66#, 16#7F#, 16#E0#);
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

   procedure Init (B : Bus; SCL, SDA : Adaflight.Pins.Pin) is
   begin
      Running (B) := True;
   end Init;

   function Started (B : Bus) return Boolean is (Running (B));

   function Answers (B : Bus; Address : Byte) return Boolean is
     (B = I2C1 and then Running (B)
      and then ((Address = Chip_Address and then Adaflight.Board.Baro_BMP280) or else Address = Pitot_Address));

   procedure Read (B : Bus; Address : Byte; Register : Byte; Data : out Byte_Array; OK : out Boolean) is
   begin
      Data := (others => 0);
      OK := Answers (B, Address);
      if not OK then
         return;
      end if;
      if Address = Pitot_Address then
         for I in Data'Range loop
            Data (I) := Pitot_Frame ((I - Data'First) mod 4);
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
      if OK then
         if Register = 16#F4# then
            Control := Value;
         elsif Register = 16#F5# then
            Config := Value;
         end if;
      end if;
   end Write;
end Adaflight.STM32.I2C;
