--  The video transmitter's configured settings, which the VTX control layer
--  and the MSP driver both read: band, channel, power, frequency, pit mode
--  frequency, low power disarm policy and the soft serial variant.
with Interfaces;

package Adaflight.VTX_Settings with SPARK_Mode, Pure is

   type Low_Power_Disarm is (Off, Always, Until_First_Arm);

   Default_Power : constant Interfaces.Unsigned_8 := 1;

   --  The configured transmitter settings, changed at run time by the
   --  sticks, the switches and the receiver, so held by the caller.
   type Settings is record
      Band           : Interfaces.Unsigned_8 := 0;
      Channel        : Interfaces.Unsigned_8 := 0;
      Power          : Interfaces.Unsigned_8 := 0;
      Freq           : Interfaces.Unsigned_16 := 0;
      Pit_Mode_Freq  : Interfaces.Unsigned_16 := 0;
      Low_Power      : Low_Power_Disarm := Off;
      Softserial_Alt : Boolean := False;
   end record;

end Adaflight.VTX_Settings;
