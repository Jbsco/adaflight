--  The race transponder: the three infrared codings turn the configured
--  code into the sequence of carrier toggles a timer plays out, and the
--  repeat schedule spaces the transmissions by the coding's delay plus a
--  jitter stepping through a fixed table.
with Interfaces;

package Adaflight.Transponder with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Provider is (None, ILAP, Arcitimer, ERLT);

   Code_Length : constant := 9;
   type Code is array (0 .. Code_Length - 1) of Unsigned_8;

   Max_Toggles : constant := 720;
   subtype Toggle_Count is Natural range 0 .. Max_Toggles;
   type Toggles is array (0 .. Max_Toggles - 1) of Unsigned_32;

   --  The toggles of one transmission: the coding's buffer, the ILAP and
   --  Arcitimer ones of fixed length with silence after the bits, the
   --  ERLT one as long as its bits.
   type Pattern is record
      Buffer : Toggles := (others => 0);
      Length : Toggle_Count := 0;
   end record;

   --  The code's toggles, with the one-toggle value of the timer's period.
   procedure Encode (P : Provider; Data : Code; Toggle : Unsigned_16; Result : out Pattern);

   --  A coding's timer: its counting rate in megahertz and its carrier in
   --  hertz.
   function Timer_MHz (P : Provider) return Unsigned_32 is
     (case P is when ILAP | Arcitimer => 24, when ERLT => 18, when None => 0);
   function Carrier_Hz (P : Provider) return Unsigned_32 is
     (case P is when ILAP => 460_750, when Arcitimer => 41_886, when ERLT => 38_000, when None => 0);

   --  The prescaler for a coding's counting rate from a timer's clock, none
   --  when the clock is slower, and the carrier's period in the prescaled
   --  counts, in sixteen bits. The one-toggle value is half that period.
   function Prescaler (Clock : Unsigned_32; P : Provider) return Unsigned_16
     with Global => null;
   function Period (Clock : Unsigned_32; Prescale : Unsigned_16; P : Provider) return Unsigned_16 is
     (if P = None then 0 else Unsigned_16'Mod ((Clock / (Unsigned_32 (Prescale) + 1)) / Carrier_Hz (P)));
   function Toggle_Of (Period : Unsigned_16) return Unsigned_16 is (Period / 2);

   type Schedule is record
      Next_Update_Us : Unsigned_32 := 0;
      Jitter_Index   : Natural range 0 .. 14 := 0;
   end record;

   --  One task call while repeating: a transmission when the hardware is
   --  ready and the time has come, the next time set from the delay and
   --  the jitter table.
   procedure Update (S : in out Schedule; P : Provider; Now_Us : Unsigned_32; Ready : Boolean; Transmit : out Boolean);

end Adaflight.Transponder;
