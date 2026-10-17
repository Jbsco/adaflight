--  The pulse receivers' inputs. The PPM decoder rebuilds each edge's time
--  from the 16-bit capture and the timer's overflows, takes a gap longer than
--  2.7 ms as the frame sync, settles the frame size after 25 frames alike,
--  and hands over each well-formed frame's pulses. The parallel PWM decoder
--  times each channel's pulse from its rising to its falling edge and drops
--  a channel after ten overflows without an edge.
with Interfaces;

package Adaflight.RX_PWM with SPARK_Mode, Pure is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Capture_Count : constant := 12;
   Input_Ports   : constant := 8;
   subtype Capture_Index is Natural range 0 .. Capture_Count - 1;
   subtype Port_Index is Natural range 0 .. Input_Ports - 1;
   type Capture_Values is array (Capture_Index) of Unsigned_16;
   type Pulse_Times is array (Capture_Index) of Unsigned_32;

   --  The capture of a channel without a pulse.
   Timeout : constant := 0;

   subtype Count_Divisor is Positive range 1 .. 255;

   type PPM_State is record
      Current_Capture   : Unsigned_32 := 0;
      Current_Time      : Unsigned_32 := 0;
      Delta_Time        : Unsigned_32 := 0;
      Pulses            : Pulse_Times := (others => 0);
      Large_Counter     : Unsigned_32 := 0;
      Pulse_Index       : Natural range 0 .. Capture_Count := 0;
      Channels          : Integer range -1 .. Capture_Count := -1;
      Previous_Channels : Integer range -1 .. Capture_Count := -1;
      Stable_Frames     : Natural range 0 .. 25 := 0;
      Tracking          : Boolean := False;
      Overflowed        : Boolean := False;
      Frame_Count       : Unsigned_8 := 0;
      Last_Frame_Count  : Unsigned_8 := 0;
      Divisor           : Count_Divisor := 1;
      Captures          : Capture_Values := (others => 0);
   end record;

   --  The divisor scales the timer down where a motor output shares it.
   procedure PPM_Init (S : out PPM_State; Divisor : Count_Divisor);

   procedure PPM_Overflow (S : in out PPM_State; Capture : Unsigned_16);

   procedure PPM_Edge (S : in out PPM_State; Capture : Unsigned_16);

   --  Whether a frame arrived since the last reset of this check.
   function PPM_Receiving (S : PPM_State) return Boolean is (S.Frame_Count /= S.Last_Frame_Count);

   procedure PPM_Reset_Received (S : in out PPM_State);

   --  The edge each PWM channel's timer looks for next.
   type Polarity is (Rising, Falling);

   type Port_State is record
      Waiting_Fall : Boolean := False;
      Missed       : Natural range 0 .. 10 := 0;
      Rise         : Unsigned_16 := 0;
      Fall         : Unsigned_16 := 0;
      Capture      : Unsigned_16 := 0;
   end record;
   type Port_States is array (Port_Index) of Port_State;

   type PWM_State is record
      Ports    : Port_States;
      Captures : Capture_Values := (others => 0);
   end record;

   procedure PWM_Init (S : out PWM_State);

   procedure PWM_Edge (S : in out PWM_State; Port : Port_Index; Capture : Unsigned_16; Next : out Polarity);

   procedure PWM_Overflow (S : in out PWM_State; Port : Port_Index);

   --  Whether any channel holds a pulse.
   function PWM_Receiving (S : PWM_State) return Boolean is
     (for some C in Capture_Index => S.Captures (C) /= Timeout);

end Adaflight.RX_PWM;
