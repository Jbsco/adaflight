--  The receiver task's state machine: one call checks the receiver, the
--  next updates the modes when the check found data, and the next updates
--  the RC commands and the arming status. Every step but the last tells the
--  scheduler to ignore the task's rate. The task keeps an estimate of each
--  step's time, which follows the scheduler's anticipated time when that
--  changed, rises to a longer execution and otherwise decays by a 64th of a
--  microsecond a call, and it names the next step's estimate to the
--  scheduler.
with Interfaces;

package Adaflight.RX_Task with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_32;

   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Step is (Check, Modes, Update);

   Max_Execution_Us : constant := 2 ** 25 - 1;
   subtype Execution_Us is Integer_32 range 0 .. Max_Execution_Us;
   subtype Estimate is Integer_32 range -1 .. Max_Execution_Us * 64;
   type Estimates is array (Step) of Estimate;

   type State is record
      Current  : Step := Check;
      Duration : Estimates := (others => 0);
   end record;

   --  The step this call runs.
   function Current_Step (T : State) return Step is (T.Current);

   --  Whether the receiver task is past its check, which the frame check
   --  reads.
   function In_Progress (T : State) return Boolean is (T.Current /= Check);

   --  Whether the scheduler ignores the task's rate for this call.
   function Ignore_Rate (T : State) return Boolean is (T.Current /= Update);

   --  After the step: the check moves on only when the receiver found data.
   --  Unless the scheduler ignores this call's time, the step's estimate
   --  takes the scheduler's anticipated time when that differs and then the
   --  execution time with a microsecond's margin when longer, or decays.
   --  An execution past Max_Execution_Us counts as that much. Next_State_Us
   --  is the next step's estimate for the scheduler.
   procedure Finish
     (T                : in out State;
      Rx_Ready         : Boolean;
      Ignore_Exec_Time : Boolean;
      Anticipated_Us   : Execution_Us;
      Elapsed_Us       : Unsigned_32;
      Next_State_Us    : out Integer_32)
     with Global => null;

end Adaflight.RX_Task;
