--  The host's PPM and parallel PWM receiver inputs. While the environment
--  variable ADAFLIGHT_PPM lists pulse widths in microseconds, each from one
--  rising edge to the next, the PPM pin gets that train in 22.5 ms frames.
--  While ADAFLIGHT_PWM_INPUT lists pulse widths in microseconds, each PWM pin
--  in port order gets a pulse of its width every 20 ms, and a width of 0
--  gives its pin no pulses. A train stops ADAFLIGHT_PPM_STOP_MS or
--  ADAFLIGHT_PWM_STOP_MS milliseconds after its input starts when that
--  variable is set. A 1 MHz counter of 16 bits gives the core's decoders
--  each edge's count and each of the counter's overflows, in time order, an
--  edge before an overflow at the same count.
with Ada.Environment_Variables;
with Adaflight.RX_PWM;
with Adaflight.STM32.Time;
package body Adaflight.STM32.RX_Input is
   use Interfaces;
   use type Adaflight.RX_PWM.Polarity;

   package RX_PWM renames Adaflight.RX_PWM;

   Frame_Us  : constant := 22_500;
   Period_Us : constant := 20_000;
   Max_Pulse : constant := 12;

   type Input_Mode is (Off, PPM_Input, PWM_Input);
   type Pulse_List is array (1 .. Max_Pulse) of Natural;
   type Port_Times is array (RX_PWM.Port_Index) of Unsigned_64;
   type Port_Flags is array (RX_PWM.Port_Index) of Boolean;

   PPM         : RX_PWM.PPM_State;
   PWM         : RX_PWM.PWM_State;
   Mode        : Input_Mode := Off;
   Pulses      : Pulse_List := (others => 0);
   Count       : Natural range 0 .. Max_Pulse := 0;
   Stop_Us     : Unsigned_64 := Unsigned_64'Last;
   --  Microseconds since the start: the signal's present, the PPM train's
   --  next edge and the counter's next overflow; the PPM edge's place in its
   --  frame. Each PWM port's pin, and its next edge of the polarity its
   --  decoder asks for.
   Now         : Unsigned_64 := 0;
   Last_Micros : Unsigned_32 := 0;
   Next_Edge   : Unsigned_64 := 0;
   Next_Wrap   : Unsigned_64 := 65_536;
   Edge_Index  : Natural range 0 .. Max_Pulse := 0;
   Frame_Start : Unsigned_64 := 0;
   Has_Pin     : Port_Flags := (others => False);
   Port_Edge   : Port_Times := (others => Unsigned_64'Last);

   procedure Read_Environment (Name : String; Stop_Name : String) is
      Text  : constant String := Ada.Environment_Variables.Value (Name, "") & ",";
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
         Stop : constant String := Ada.Environment_Variables.Value (Stop_Name, "");
      begin
         if Stop'Length > 0 then
            Stop_Us := Unsigned_64 (Natural'Value (Stop)) * 1_000;
         end if;
      exception
         when Constraint_Error =>
            null;
      end;
   end Read_Environment;

   --  The PPM train's events up to the present.
   procedure Advance_PPM is
   begin
      if Count = 0 then
         return;
      end if;
      loop
         if Next_Edge <= Now and then Next_Edge <= Next_Wrap and then Next_Edge < Stop_Us then
            RX_PWM.PPM_Edge (PPM, Unsigned_16 (Next_Edge mod 65_536));
            if Edge_Index < Count then
               Edge_Index := Edge_Index + 1;
               Next_Edge := Next_Edge + Unsigned_64 (Pulses (Edge_Index));
            else
               Edge_Index := 0;
               Frame_Start := Frame_Start + Frame_Us;
               Next_Edge := Frame_Start;
            end if;
         elsif Next_Wrap <= Now then
            RX_PWM.PPM_Overflow (PPM, 16#FFFF#);
            Next_Wrap := Next_Wrap + 65_536;
         else
            exit;
         end if;
      end loop;
   end Advance_PPM;

   --  A PWM port's first edge after a time of the polarity its decoder asks
   --  for: its pulses rise at 1 ms and every 20 ms after, and fall their
   --  width later.
   function Edge_After (P : RX_PWM.Port_Index; After : Unsigned_64; Next : RX_PWM.Polarity) return Unsigned_64 is
      Phase : Unsigned_64;
   begin
      if P >= Count or else Pulses (P + 1) = 0 then
         return Unsigned_64'Last;
      end if;
      Phase := 1_000 + (if Next = RX_PWM.Falling then Unsigned_64 (Pulses (P + 1)) else 0);
      return (if After < Phase then Phase else Phase + ((After - Phase) / Period_Us + 1) * Period_Us);
   end Edge_After;

   --  The PWM pulses' events up to the present.
   procedure Advance_PWM is
      First : RX_PWM.Port_Index;
      At_Us : Unsigned_64;
      Next  : RX_PWM.Polarity;
   begin
      loop
         First := RX_PWM.Port_Index'First;
         At_Us := Unsigned_64'Last;
         for P in RX_PWM.Port_Index loop
            if Has_Pin (P) and then Port_Edge (P) < At_Us then
               First := P;
               At_Us := Port_Edge (P);
            end if;
         end loop;
         if At_Us <= Now and then At_Us <= Next_Wrap and then At_Us < Stop_Us then
            RX_PWM.PWM_Edge (PWM, First, Unsigned_16 (At_Us mod 65_536), Next);
            Port_Edge (First) := Edge_After (First, At_Us, Next);
         elsif Next_Wrap <= Now then
            for P in RX_PWM.Port_Index loop
               if Has_Pin (P) then
                  RX_PWM.PWM_Overflow (PWM, P);
               end if;
            end loop;
            Next_Wrap := Next_Wrap + 65_536;
         else
            exit;
         end if;
      end loop;
   end Advance_PWM;

   procedure Advance is
      Micros : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
   begin
      if Mode = Off then
         return;
      end if;
      Now := Now + Unsigned_64 (Micros - Last_Micros);
      Last_Micros := Micros;
      case Mode is
         when Off =>
            null;
         when PPM_Input =>
            Advance_PPM;
         when PWM_Input =>
            Advance_PWM;
      end case;
   end Advance;

   procedure Start_PPM (Tag : Unsigned_8; Started : out Boolean) is
   begin
      Started := Tag /= 0;
      if not Started then
         return;
      end if;
      Read_Environment ("ADAFLIGHT_PPM", "ADAFLIGHT_PPM_STOP_MS");
      RX_PWM.PPM_Init (PPM, 1);
      Last_Micros := Adaflight.STM32.Time.Micros;
      Next_Edge := 1_000;
      Frame_Start := 1_000;
      Mode := PPM_Input;
   end Start_PPM;

   procedure Start_PWM (Tags : Adaflight.Config_Groups.Bytes_8; Filtering : Boolean) is
      pragma Unreferenced (Filtering);
   begin
      Read_Environment ("ADAFLIGHT_PWM_INPUT", "ADAFLIGHT_PWM_STOP_MS");
      RX_PWM.PWM_Init (PWM);
      for P in RX_PWM.Port_Index loop
         Has_Pin (P) := Tags (P) /= 0;
         Port_Edge (P) := Edge_After (P, 0, RX_PWM.Rising);
      end loop;
      Last_Micros := Adaflight.STM32.Time.Micros;
      Mode := PWM_Input;
   end Start_PWM;

   procedure Take_Received (Received : out Boolean) is
   begin
      Advance;
      case Mode is
         when Off =>
            Received := False;
         when PPM_Input =>
            Received := RX_PWM.PPM_Receiving (PPM);
            RX_PWM.PPM_Reset_Received (PPM);
         when PWM_Input =>
            Received := RX_PWM.PWM_Receiving (PWM);
      end case;
   end Take_Received;

   function Channel_Value (Channel : Natural) return Unsigned_16 is
     (if Channel not in RX_PWM.Capture_Index then 0
      else
        (case Mode is
           when Off       => 0,
           when PPM_Input => PPM.Captures (Channel),
           when PWM_Input => PWM.Captures (Channel)));

end Adaflight.STM32.RX_Input;
