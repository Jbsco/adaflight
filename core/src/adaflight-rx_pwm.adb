package body Adaflight.RX_PWM with SPARK_Mode is

   Timer_Period    : constant := 16#1_0000#;
   Min_Sync_Us     : constant := 2_700;
   Min_Pulse_Us    : constant := 750;
   Max_Pulse_Us    : constant := 2_250;
   Stable_Required : constant := 25;
   Min_Channels    : constant := 4;
   Max_Missed      : constant := 10;

   --------------
   -- PPM_Init --
   --------------

   procedure PPM_Init (S : out PPM_State; Divisor : Count_Divisor) is
   begin
      S := (Divisor => Divisor, others => <>);
   end PPM_Init;

   ------------------
   -- PPM_Overflow --
   ------------------

   procedure PPM_Overflow (S : in out PPM_State; Capture : Unsigned_16) is
   begin
      S.Large_Counter := S.Large_Counter + Unsigned_32 (Capture) + 1;
      if Unsigned_32 (Capture) = Timer_Period - 1 then
         S.Overflowed := True;
      end if;
   end PPM_Overflow;

   --------------
   -- PPM_Edge --
   --------------

   procedure PPM_Edge (S : in out PPM_State; Capture : Unsigned_16) is
      Previous_Time    : constant Unsigned_32 := S.Current_Time;
      Previous_Capture : constant Unsigned_32 := S.Current_Capture;
      Period           : constant Unsigned_32 := Timer_Period / Unsigned_32 (S.Divisor);
      Now              : Unsigned_32 := Unsigned_32 (Capture) + S.Large_Counter;
   begin
      if Unsigned_32 (Capture) < Previous_Capture and then S.Overflowed then
         Now := Now + Timer_Period;
      end if;
      Now := Now / Unsigned_32 (S.Divisor);
      if Now > Previous_Time then
         S.Delta_Time := Now - (Previous_Time + (if S.Overflowed then Period else 0));
      else
         S.Delta_Time := Period + Now - Previous_Time;
      end if;
      S.Overflowed := False;
      S.Current_Time := Now;
      S.Current_Capture := Unsigned_32 (Capture);
      if S.Delta_Time > Min_Sync_Us then
         if S.Pulse_Index = S.Previous_Channels and then S.Pulse_Index >= Min_Channels then
            if S.Stable_Frames < Stable_Required then
               S.Stable_Frames := S.Stable_Frames + 1;
            else
               S.Channels := S.Pulse_Index;
            end if;
         else
            S.Stable_Frames := 0;
         end if;
         if S.Pulse_Index = S.Channels and then S.Tracking then
            for I in Capture_Index loop
               S.Captures (I) := (if I < S.Channels then Unsigned_16'Mod (S.Pulses (I)) else Timeout);
            end loop;
            S.Frame_Count := S.Frame_Count + 1;
         end if;
         S.Tracking := True;
         S.Previous_Channels := S.Pulse_Index;
         S.Pulse_Index := 0;
      elsif S.Tracking then
         if S.Delta_Time > Min_Pulse_Us and then S.Delta_Time < Max_Pulse_Us and then S.Pulse_Index < Capture_Count
         then
            S.Pulses (S.Pulse_Index) := S.Delta_Time;
            S.Pulse_Index := S.Pulse_Index + 1;
         else
            S.Tracking := False;
            S.Pulses := (others => Timeout);
         end if;
      end if;
   end PPM_Edge;

   ------------------------
   -- PPM_Reset_Received --
   ------------------------

   procedure PPM_Reset_Received (S : in out PPM_State) is
   begin
      S.Last_Frame_Count := S.Frame_Count;
   end PPM_Reset_Received;

   --------------
   -- PWM_Init --
   --------------

   procedure PWM_Init (S : out PWM_State) is
   begin
      S := (Ports => (others => (Waiting_Fall => False, Missed => 0, Rise => 0, Fall => 0, Capture => 0)),
            Captures => (others => 0));
   end PWM_Init;

   --------------
   -- PWM_Edge --
   --------------

   procedure PWM_Edge (S : in out PWM_State; Port : Port_Index; Capture : Unsigned_16; Next : out Polarity) is
      P : Port_State renames S.Ports (Port);
   begin
      if not P.Waiting_Fall then
         P.Rise := Capture;
         P.Waiting_Fall := True;
         Next := Falling;
      else
         P.Fall := Capture;
         P.Capture := P.Fall - P.Rise;
         S.Captures (Port) := P.Capture;
         P.Waiting_Fall := False;
         Next := Rising;
         P.Missed := 0;
      end if;
   end PWM_Edge;

   ------------------
   -- PWM_Overflow --
   ------------------

   procedure PWM_Overflow (S : in out PWM_State; Port : Port_Index) is
      P : Port_State renames S.Ports (Port);
   begin
      if P.Missed + 1 > Max_Missed then
         S.Captures (Port) := Timeout;
         P.Missed := 0;
      else
         P.Missed := P.Missed + 1;
      end if;
   end PWM_Overflow;

end Adaflight.RX_PWM;
