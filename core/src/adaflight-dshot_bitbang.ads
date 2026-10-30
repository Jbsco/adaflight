--  The bit-banged DShot output: a GPIO port's buffer of set and reset
--  words, three states a bit and three hold states, which a timer paced DMA
--  stream writes into the port's bit set and reset register. Every pin of
--  the port goes high at a bit's start and low at its end, and a pin whose
--  bit is a zero goes low at the bit's middle; inverted output swaps the
--  set and reset halves. The hold states keep the line at idle after the
--  frame. With bidirectional DShot the ports' samples after a frame give
--  the motors' replies.
with Interfaces; use Interfaces;
with Adaflight.DShot;

package Adaflight.DShot_Bitbang with SPARK_Mode is

   use type Adaflight.DShot.Raw_State;

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

   ---------------------------------------------------------------------------
   --  The replies read from the ports' samples after a frame
   ---------------------------------------------------------------------------

   Max_Ports : constant := 4;
   subtype Port_Index is Natural range 0 .. Max_Ports - 1;
   subtype Port_Total is Natural range 0 .. Max_Ports;
   subtype Input_Buffer is Adaflight.DShot.Samples (0 .. Adaflight.DShot.Max_Samples - 1);

   --  A port's samples of its pins, the samples its stream took, and whether
   --  the wait for them gave up.
   type Port_Input is record
      Count   : Adaflight.DShot.Sample_Count := Adaflight.DShot.Max_Samples;
      Aborted : Boolean := False;
      Buffer  : Input_Buffer := (others => 0);
   end record;
   type Port_Inputs is array (Port_Index) of Port_Input;

   type Motor_Pin is record
      Port : Port_Index := 0;
      Pin  : Pin_Number := 0;
   end record;
   type Motor_Pins is array (Adaflight.DShot.Motor_Index) of Motor_Pin;

   --  The read after a frame: nothing without telemetry. Else each motor in
   --  order whose port's wait did not give up decodes its pin's samples; a
   --  reply found counts a read, keeps the value, or marks the extended
   --  telemetry acknowledged when the value is the acknowledgement and the
   --  motor's command enables it, or counts an invalid reply, and counts the
   --  reply in the motor's quality. After every motor the raw values wait
   --  for processing and the used ports' marks clear.
   procedure Read_Replies
     (T : in out Adaflight.DShot.Telemetry; Counts : in out Adaflight.DShot.Read_Counts;
      Q : in out Adaflight.DShot.Qualities; D : in out Adaflight.DShot.Edge_Decoder; Ports : in out Port_Inputs;
      Used_Ports : Port_Total; Motors : Motor_Pins; Count : Adaflight.DShot.Motor_Total; Use_Telemetry : Boolean;
      Commands : Adaflight.DShot.Command_List; Now_Us : Adaflight.DShot.Time_Us; Now_Ms : Adaflight.DShot.Time_Ms)
     with Global => null,
          Post   => (if Use_Telemetry
                     then T.State = Adaflight.DShot.Not_Processed
                          and then (for all P in 0 .. Used_Ports - 1 => not Ports (P).Aborted));

end Adaflight.DShot_Bitbang;
