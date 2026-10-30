--  The bit-banged DShot output: a GPIO port's buffer of set and reset
--  words, three states a bit and three hold states, which a timer paced DMA
--  stream writes into the port's bit set and reset register. Every pin of
--  the port goes high at a bit's start and low at its end, and a pin whose
--  bit is a zero goes low at the bit's middle; inverted output swaps the
--  set and reset halves. The hold states keep the line at idle after the
--  frame.
with Interfaces; use Interfaces;

package Adaflight.DShot_Bitbang with SPARK_Mode is

   Frame_Bits      : constant := 16;
   States_Per_Bit  : constant := 3;
   Buffer_Length   : constant := Frame_Bits * States_Per_Bit + 3;
   subtype Pin_Number is Natural range 0 .. 15;
   type Port_Buffer is array (0 .. Buffer_Length - 1) of Unsigned_32;

   --  A pin's set and reset states added to its port's buffer, the middles
   --  and the hold states after the first cleared.
   procedure Init (B : in out Port_Buffer; Port_Mask : Unsigned_16; Inverted : Boolean)
     with Global => null;

   --  A motor's frame in its pin's middles, most significant bit first.
   procedure Set (B : in out Port_Buffer; Pin : Pin_Number; Value : Unsigned_16; Inverted : Boolean)
     with Global => null;

   --  Every frame's middles cleared for the next update.
   procedure Clear (B : in out Port_Buffer)
     with Global => null;

end Adaflight.DShot_Bitbang;
