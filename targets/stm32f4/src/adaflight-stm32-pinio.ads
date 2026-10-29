--  The PINIO outputs of the board: each configured pin a push-pull output at
--  its idle level, high when its configuration inverts it, and the PINIO box
--  task, which sets each output from the box its setting names and runs
--  while one of those boxes has a mode condition.
with Adaflight.Config_Groups;
package Adaflight.STM32.PINIO is
   --  The pins from the configuration.
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   --  The boxes from the configuration's permanent ids, after the modes.
   procedure Init_Boxes (C : Adaflight.Config_Groups.Configuration);
   --  Whether the task runs: a named box with a mode condition.
   function Task_Enabled return Boolean;
   --  The task: each assigned output set from its box.
   procedure Update;
   --  An output switched on or off: the level its inversion gives, written
   --  when it changes.
   procedure Set (Index : Natural; On : Boolean);
end Adaflight.STM32.PINIO;
