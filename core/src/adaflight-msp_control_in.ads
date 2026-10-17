--  The MSP in messages that act on the board: the flash erase, the arming
--  switch of the MSP links, the accelerometer and compass calibrations, and
--  the configuration write. A request reads zero past its end. A
--  configuration write while armed is an error that writes and changes
--  nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Control_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Erase_Flash_Command         : constant := 72;
   Set_Arming_Disabled_Command : constant := 99;
   Acc_Calibration_Command     : constant := 205;
   Mag_Calibration_Command     : constant := 206;
   Write_Configuration_Command : constant := 250;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Erase_Flash_Command | Set_Arming_Disabled_Command | Acc_Calibration_Command
        | Mag_Calibration_Command | Write_Configuration_Command);

   type Result is (Ack, Error);

   --  The MSP links, by descriptor, that have switched arming off, a bit
   --  each.
   subtype Link is Natural range 0 .. 31;
   type Link_State is record
      Disabled : Interfaces.Unsigned_32 := 0;
   end record;

   --  What the board reports to these messages: armed, the SPI receiver
   --  running, and the request's link with whether it is the telemetry link.
   type Board is record
      Armed          : Boolean := False;
      RX_SPI_Active  : Boolean := False;
      Source         : Link := 0;
      From_Telemetry : Boolean := False;
   end record;

   --  The MSP arming reason set, cleared, or left alone.
   type Arming_Change is (Unchanged, Disable, Enable);

   --  The runtime work a message asks for: the flash erased, a calibration
   --  started, the current task's state time ignored by the scheduler, the
   --  configuration written and read back now or after a delay, the MSP
   --  arming reason changed, a disarm, and the runaway takeoff prevention's
   --  temporary disable set to a value.
   type Effects is record
      Erase_Flash      : Boolean := False;
      Acc_Calibration  : Boolean := False;
      Mag_Calibration  : Boolean := False;
      Ignore_Task_Time : Boolean := False;
      Save             : Boolean := False;
      Deferred_Save    : Boolean := False;
      MSP_Arming       : Arming_Change := Unchanged;
      Disarm           : Boolean := False;
      Runaway_Set      : Boolean := False;
      Runaway_Value    : Byte := 0;
   end record;

   No_Effects : constant Effects :=
     (Erase_Flash | Acc_Calibration | Mag_Calibration | Ignore_Task_Time | Save | Deferred_Save | Disarm
        | Runaway_Set => False,
      MSP_Arming => Unchanged, Runaway_Value => 0);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process
     (C : in out Configuration; L : in out Link_State; Command : Interfaces.Unsigned_16; Request : Byte_Array;
      B : Board; R : out Result; E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then L = L'Old and then E = No_Effects);

end Adaflight.MSP_Control_In;
