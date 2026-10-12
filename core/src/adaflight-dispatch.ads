--  The dispatch queue: delayed calls kept in the order of their due times on
--  the wrapping microsecond clock, each target in the queue at most once,
--  handed back one at a time when due with the entry unlinked first so its
--  handler can queue it again. The handlers stay with the caller, who numbers
--  its targets and runs each one this unit hands back.
with Interfaces;

package Adaflight.Dispatch with SPARK_Mode is
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Capacity : constant := 8;
   type Target is range 0 .. Capacity - 1;
   subtype Count is Natural range 0 .. Capacity;
   subtype Slot is Positive range 1 .. Capacity;
   type Order is array (Slot) of Target;
   type Due_Times is array (Target) of Unsigned_32;
   type Flags is array (Target) of Boolean;

   --  The queued targets from the head, their due times and whether each is
   --  queued, and whether dispatching has been enabled.
   type Queue is record
      Enabled  : Boolean := False;
      Length   : Count := 0;
      Queued   : Order := (others => 0);
      Due_Us   : Due_Times := (others => 0);
      In_Queue : Flags := (others => False);
   end record;

   procedure Enable (Q : in out Queue)
     with Post => Q.Enabled;

   --  The target joins the queue due after the delay, before the first entry
   --  not due earlier; a target already queued is left where it is.
   procedure Add (Q : in out Queue; T : Target; Now_Us : Unsigned_32; Delay_Us : Interfaces.Integer_32);

   --  The head entry when it is due: unlinked and handed back for its
   --  handler to run; nothing when the head is not due or the queue is empty.
   procedure Take_Due (Q : in out Queue; Now_Us : Unsigned_32; T : out Target; Due : out Boolean);

end Adaflight.Dispatch;
