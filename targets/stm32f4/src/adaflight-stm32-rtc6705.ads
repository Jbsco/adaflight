--  The RTC6705 video transmitter's pins on the board: its select pin, a
--  power pin where the board has one, and either an SPI bus or a clock and
--  a data pin driven as a software SPI. The core's driver lists register
--  writes, power changes and waits. This unit keeps them in their order and
--  carries out those that are due, so a wait takes no time from the flight
--  loop.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.VTX_RTC6705;
package Adaflight.STM32.RTC6705 is
   --  The pins as the stored configuration names them. The power pin goes
   --  high first, which keeps the transmitter off. OK when there is a select
   --  pin and either a started SPI bus or both software SPI pins.
   procedure Init (C : Adaflight.Config_Groups.Configuration; OK : out Boolean);
   --  Operations placed behind those not yet carried out.
   procedure Submit (Ops : Adaflight.VTX_RTC6705.Operations);
   --  The operations that are due, in their order, up to a wait that has
   --  not passed. A wait starts at the call that reaches it.
   procedure Run (Now_Ms : Interfaces.Unsigned_32);
end Adaflight.STM32.RTC6705;
