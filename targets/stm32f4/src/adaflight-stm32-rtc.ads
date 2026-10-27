--  The real time clock of the board: the core's clock over the millisecond
--  clock, set by the configurator over MSP or by the GPS fix, the time zone
--  the stored configuration names, and the readings the log header, the
--  OSD, the MSP reply and the card's file dates take.
with Interfaces;
with Adaflight.FAT;
with Adaflight.MSP_Out;
with Adaflight.RTC;
package Adaflight.STM32.RTC is
   procedure Set_Zone (Minutes : Interfaces.Integer_16);
   function Zone return Adaflight.RTC.Zone_Minutes;
   function Has_Time return Boolean;
   --  The time in milliseconds since 1970, meaningful once the clock has time.
   function Now_Ms return Interfaces.Integer_64;
   --  The clock set to milliseconds since 1970, or to a calendar date.
   procedure Set_Ms (T : Interfaces.Integer_64);
   procedure Set_Date (D : Adaflight.RTC.Date_Time);
   --  The date now, valid once a time was set.
   procedure Date_Now (Valid : out Boolean; D : out Adaflight.RTC.Date_Time);
   --  The local date now for the card's file dates.
   procedure Local_Now (Valid : out Boolean; Local : out Adaflight.FAT.Clock_Reading);
   --  The local time formatted for the log header, the default date without
   --  a time.
   function Start_Text return String;
   --  The MSP clock reply.
   function Clock_Values return Adaflight.MSP_Out.Clock_Values;
end Adaflight.STM32.RTC;
