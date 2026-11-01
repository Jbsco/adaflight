--  The MSP in messages that act on the board: the flash erase, the arming
--  switch of the MSP links, the accelerometer and compass calibrations, the
--  configuration write, the restart into a mode, and DShot commands to the
--  motors. A request reads zero past its end. A configuration write or a
--  restart while armed, a restart mode past the five, and DShot commands
--  shorter than their count are errors that write and change nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Control_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Reboot_Command              : constant := 68;
   Erase_Flash_Command         : constant := 72;
   Set_Arming_Disabled_Command : constant := 99;
   Acc_Calibration_Command     : constant := 205;
   Mag_Calibration_Command     : constant := 206;
   Camera_Control_Command      : constant := 98;
   Write_Configuration_Command : constant := 250;
   DShot_Command_Command       : constant := 16#3003#;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Reboot_Command | Erase_Flash_Command | Set_Arming_Disabled_Command | Acc_Calibration_Command
        | Mag_Calibration_Command | Write_Configuration_Command | DShot_Command_Command | Camera_Control_Command);

   type Result is (Ack, Error);

   --  The MSP links, by descriptor, that have switched arming off, a bit
   --  each.
   subtype Link is Natural range 0 .. 31;
   type Link_State is record
      Disabled : Interfaces.Unsigned_32 := 0;
   end record;

   --  What the board reports to these messages: armed, the SPI receiver
   --  running, the request's link with whether it is the telemetry link, and
   --  whether the mass storage file system is ready.
   type Board is record
      Armed          : Boolean := False;
      RX_SPI_Active  : Boolean := False;
      Source         : Link := 0;
      From_Telemetry : Boolean := False;
      MSC_Ready      : Boolean := False;
   end record;

   --  The MSP arming reason set, cleared, or left alone.
   type Arming_Change is (Unchanged, Disable, Enable);

   Max_DShot_Commands : constant := 252;
   subtype DShot_Count is Natural range 0 .. Max_DShot_Commands;
   type DShot_List is array (0 .. Max_DShot_Commands - 1) of Byte;
   type Reply_Bytes is array (0 .. 1) of Byte;

   --  The runtime work a message asks for: the flash erased, a calibration
   --  started, the current task's state time ignored by the scheduler, the
   --  configuration written and read back now or after a delay, the MSP
   --  arming reason changed, a disarm, the runaway takeoff prevention's
   --  temporary disable set to a value, the restart into a mode after the
   --  reply or after a delay, the reply's bytes, and DShot commands for a
   --  motor of a type, with the motors switched off around blocking ones.
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
      Reboot           : Boolean := False;
      Deferred_Reboot  : Boolean := False;
      Reboot_Mode      : Byte := 0;
      Reply_Length     : Natural range 0 .. 2 := 0;
      Reply            : Reply_Bytes := (others => 0);
      DShot            : Boolean := False;
      DShot_Type       : Byte := 0;
      DShot_Motor      : Byte := 0;
      DShot_Commands   : DShot_Count := 0;
      DShot_Values     : DShot_List := (others => 0);
      Motors_Off       : Boolean := False;
      --  A camera key pressed, by its code.
      Camera_Press     : Boolean := False;
      Camera_Key       : Byte := 0;
   end record;

   No_Effects : constant Effects :=
     (Erase_Flash | Acc_Calibration | Mag_Calibration | Ignore_Task_Time | Save | Deferred_Save | Disarm
        | Runaway_Set | Reboot | Deferred_Reboot | DShot | Motors_Off | Camera_Press => False,
      MSP_Arming => Unchanged, Runaway_Value | Reboot_Mode | DShot_Type | DShot_Motor | Camera_Key => 0,
      Reply_Length => 0,
      Reply => (others => 0), DShot_Commands => 0, DShot_Values => (others => 0));

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process
     (C : in out Configuration; L : in out Link_State; Command : Interfaces.Unsigned_16; Request : Byte_Array;
      B : Board; R : out Result; E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then L = L'Old and then E = No_Effects);

end Adaflight.MSP_Control_In;
