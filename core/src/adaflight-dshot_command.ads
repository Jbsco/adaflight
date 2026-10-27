--  The DShot command queue: three commands at most in a ring of four, each
--  with its state, the motor output cycles it still waits, the delay after
--  it, its repeats and a command for each motor. An inline command enters
--  the queue while the motors stream, waits for them to idle, waits the
--  start delay, goes out its repeats one millisecond apart in place of the
--  motor values, and waits the delay after it before the next one. A
--  blocking command, while the motors are disabled, stands in the queue's
--  current entry and goes out at once through the caller's motor table. The
--  first streaming command waits three seconds after the motors enable, for
--  the protocol detection of the ESCs.
with Interfaces;

package Adaflight.DShot_Command with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Max_Commands       : constant := 3;
   Max_Motors         : constant := 8;
   All_Motors         : constant Unsigned_8 := 255;
   Max_Command        : constant Unsigned_8 := 47;
   Motor_Stop         : constant Unsigned_8 := 0;
   Initial_Delay_Us   : constant := 10_000;
   Command_Delay_Us   : constant := 1_000;
   Beep_Delay_Us      : constant := 100_000;
   Detection_Delay_Ms : constant := 3_000;

   type Command_Type is (Inline, Blocking);
   type State_Kind is (Idle_Wait, Start_Delay, Active, Post_Delay);

   subtype Motor_Index is Natural range 0 .. Max_Motors - 1;
   subtype Motor_Count is Natural range 0 .. Max_Motors;
   type Command_Bytes is array (Motor_Index) of Unsigned_8;

   type Control is record
      State          : State_Kind := Idle_Wait;
      Cycle_Delay    : Unsigned_32 := 0;
      Delay_After_Us : Unsigned_32 := 0;
      Repeats        : Unsigned_8 := 0;
      Command        : Command_Bytes := (others => 0);
   end record;

   subtype Slot is Natural range 0 .. Max_Commands;
   type Entries is array (Slot) of Control;
   subtype Loop_Time_Us is Unsigned_32 range 1 .. Unsigned_32'Last;

   type Queue is record
      Items         : Entries;
      Head          : Slot := 0;
      Tail          : Slot := 0;
      Loop_Us       : Loop_Time_Us := 125;
      First_Command : Boolean := True;
   end record;

   --  What the queue reads from the motor layer: whether the protocol is
   --  DShot, whether the motors are enabled and since when, the clock, the
   --  motor count, and each motor's idle state, its last value zero.
   type Idle_Flags is array (Motor_Index) of Boolean;
   type Motor_Facts is record
      DShot          : Boolean := True;
      Enabled        : Boolean := False;
      Enable_Time_Ms : Unsigned_32 := 0;
      Now_Ms         : Unsigned_32 := 0;
      Count          : Motor_Count := 0;
      Idle           : Idle_Flags := (others => False);
   end record;

   function Next (S : Slot) return Slot is ((S + 1) mod (Max_Commands + 1));

   function Queue_Empty (Q : Queue) return Boolean is (Q.Head = Q.Tail);

   function Queue_Full (Q : Queue) return Boolean is (Next (Q.Head) = Q.Tail);

   function Is_Last (Q : Queue) return Boolean is (Next (Q.Tail) = Q.Head);

   --  A command goes out in place of the motor values: the current entry
   --  waits its start delay or goes out, or waits the delay after it with
   --  another command behind it.
   function Is_Processing (Q : Queue) return Boolean is
     (not Queue_Empty (Q)
      and then (Q.Items (Q.Tail).State in Start_Delay | Active
                or else (Q.Items (Q.Tail).State = Post_Delay and then not Is_Last (Q))));

   function Get_Current (Q : Queue; Index : Motor_Index) return Unsigned_8 is (Q.Items (Q.Tail).Command (Index));

   procedure Set_Loop_Time (Q : in out Queue; Us : Loop_Time_Us)
     with Global => null, Post => Q.Loop_Us = Us;

   --  The motor output cycles that give at least the delay.
   function Cycles_From_Time (Q : Queue; Delay_Us : Unsigned_32) return Unsigned_32 is
     ((Delay_Us + Q.Loop_Us - 1) / Q.Loop_Us);

   --  The signed difference of two millisecond clocks.
   function Elapsed_Ms (Now, Since : Unsigned_32) return Interfaces.Integer_32 is
     (if Now - Since <= Unsigned_32 (Interfaces.Integer_32'Last) then Interfaces.Integer_32 (Now - Since)
      else -Interfaces.Integer_32 (Unsigned_32'Last - (Now - Since)) - 1);

   --  Streaming commands run once the motors are enabled, the first one only
   --  past the protocol detection delay after the enable.
   procedure Streaming_Enabled (Q : in out Queue; F : Motor_Facts; Enabled : out Boolean)
     with Global => null;

   function All_Idle (F : Motor_Facts) return Boolean is (for all I in 0 .. F.Count - 1 => F.Idle (I));

   --  What a blocking command asks of the caller: whether it runs, its
   --  repeats, the delay after it, the motor it goes to or all of them, the
   --  command and the motor count.
   type Blocking_Plan is record
      Run            : Boolean := False;
      Repeats        : Unsigned_8 := 0;
      Delay_After_Us : Unsigned_32 := 0;
      Index          : Unsigned_8 := 0;
      Command        : Unsigned_8 := 0;
      Count          : Motor_Count := 0;
   end record;

   --  A command to one motor, or all of them with the all-motors index: an
   --  inline one enters the queue, a blocking one stands in the queue's
   --  current entry and returns its plan. Nothing happens without DShot,
   --  with commands disabled for its type, past the last command, or with
   --  the queue full.
   procedure Write
     (Q           : in out Queue;
      F           : Motor_Facts;
      Index       : Unsigned_8;
      Motors      : Motor_Count;
      Command     : Unsigned_8;
      Kind        : Command_Type;
      Plan        : out Blocking_Plan)
     with Global => null, Post => Plan.Count <= Max_Motors;

   --  The motor output's gate: whether this motor update goes out, the
   --  current command stepping through its states.
   procedure Output_Is_Enabled (Q : in out Queue; F : Motor_Facts; Enabled : out Boolean)
     with Global => null;

   --  A motor's value as the timer layer writes it: the current command
   --  while one is processing, which requests telemetry when it is not the
   --  stop.
   procedure Command_Value (Q : Queue; Index : Motor_Index; Value : in out Unsigned_16; Request : in out Boolean)
     with Global => null;

   --  The blocking command's entry back to the stop for each motor.
   procedure Finish_Blocking (Q : in out Queue; Count : Motor_Count)
     with Global => null;

end Adaflight.DShot_Command;
