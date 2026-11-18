--  The host's PPM receiver input: a PPM train on the pin while the
--  environment variable ADAFLIGHT_PPM lists its channels' pulse widths in
--  microseconds, each from one rising edge to the next, in 22.5 ms frames.
--  The train stops ADAFLIGHT_PPM_STOP_MS milliseconds after the input starts
--  when that variable is set. A 1 MHz counter of 16 bits gives the core's
--  PPM decoder each edge's count and each of the counter's overflows, in
--  time order, an edge before an overflow at the same count.
with Ada.Environment_Variables;
with Adaflight.RX_PWM;
with Adaflight.STM32.Time;
package body Adaflight.STM32.RX_Input is
   use Interfaces;

   Frame_Us  : constant := 22_500;
   Max_Pulse : constant := 12;

   type Pulse_List is array (1 .. Max_Pulse) of Natural;

   PPM         : Adaflight.RX_PWM.PPM_State;
   Running     : Boolean := False;
   Pulses      : Pulse_List := (others => 0);
   Count       : Natural range 0 .. Max_Pulse := 0;
   Stop_Us     : Unsigned_64 := Unsigned_64'Last;
   --  Microseconds since the start: the signal's present, its next edge and
   --  the counter's next overflow; the edge's place in its frame.
   Now         : Unsigned_64 := 0;
   Last_Micros : Unsigned_32 := 0;
   Next_Edge   : Unsigned_64 := 0;
   Next_Wrap   : Unsigned_64 := 65_536;
   Edge_Index  : Natural range 0 .. Max_Pulse := 0;
   Frame_Start : Unsigned_64 := 0;

   procedure Read_Environment is
      Text  : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_PPM", "") & ",";
      Value : Natural := 0;
      Digit : Boolean := False;
   begin
      for C of Text loop
         if C in '0' .. '9' then
            Value := Value * 10 + (Character'Pos (C) - Character'Pos ('0'));
            Digit := True;
         elsif C = ',' and then Digit and then Count < Max_Pulse then
            Count := Count + 1;
            Pulses (Count) := Value;
            Value := 0;
            Digit := False;
         end if;
      end loop;
      declare
         Stop : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_PPM_STOP_MS", "");
      begin
         if Stop'Length > 0 then
            Stop_Us := Unsigned_64 (Natural'Value (Stop)) * 1_000;
         end if;
      exception
         when Constraint_Error =>
            null;
      end;
   end Read_Environment;

   --  The train's events up to the present.
   procedure Advance is
      Micros : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
   begin
      if not Running or else Count = 0 then
         return;
      end if;
      Now := Now + Unsigned_64 (Micros - Last_Micros);
      Last_Micros := Micros;
      loop
         if Next_Edge <= Now and then Next_Edge <= Next_Wrap and then Next_Edge < Stop_Us then
            Adaflight.RX_PWM.PPM_Edge (PPM, Unsigned_16 (Next_Edge mod 65_536));
            if Edge_Index < Count then
               Edge_Index := Edge_Index + 1;
               Next_Edge := Next_Edge + Unsigned_64 (Pulses (Edge_Index));
            else
               Edge_Index := 0;
               Frame_Start := Frame_Start + Frame_Us;
               Next_Edge := Frame_Start;
            end if;
         elsif Next_Wrap <= Now then
            Adaflight.RX_PWM.PPM_Overflow (PPM, 16#FFFF#);
            Next_Wrap := Next_Wrap + 65_536;
         else
            exit;
         end if;
      end loop;
   end Advance;

   procedure Start_PPM (Tag : Unsigned_8; Started : out Boolean) is
   begin
      Started := Tag /= 0;
      if not Started then
         return;
      end if;
      Read_Environment;
      Adaflight.RX_PWM.PPM_Init (PPM, 1);
      Last_Micros := Adaflight.STM32.Time.Micros;
      Next_Edge := 1_000;
      Frame_Start := 1_000;
      Running := True;
   end Start_PPM;

   procedure Take_Received (Received : out Boolean) is
   begin
      Advance;
      Received := Adaflight.RX_PWM.PPM_Receiving (PPM);
      Adaflight.RX_PWM.PPM_Reset_Received (PPM);
   end Take_Received;

   function Channel_Value (Channel : Natural) return Unsigned_16 is
     (if Channel in Adaflight.RX_PWM.Capture_Index then PPM.Captures (Channel) else 0);

end Adaflight.STM32.RX_Input;
