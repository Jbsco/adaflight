--  The MSP in messages that write the receiver's configuration: the mode
--  ranges, the receiver settings, the RSSI channel, the adjustment ranges,
--  the channel map, the failsafe settings and a channel's failsafe value. A
--  request reads zero past its end. A request with a field outside its
--  setting's range is an error that writes and changes nothing; a field no
--  setting names takes the bounds of the command line command that writes
--  it.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Receiver_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Mode_Range_Command       : constant := 35;
   Set_Rx_Config_Command        : constant := 45;
   Set_RSSI_Config_Command      : constant := 51;
   Set_Adjustment_Range_Command : constant := 53;
   Set_Rx_Map_Command           : constant := 65;
   Set_Failsafe_Config_Command  : constant := 76;
   Set_Rxfail_Config_Command    : constant := 78;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Mode_Range_Command | Set_Rx_Config_Command | Set_RSSI_Config_Command
        | Set_Adjustment_Range_Command | Set_Rx_Map_Command | Set_Failsafe_Config_Command
        | Set_Rxfail_Config_Command);

   type Result is (Ack, Error);

   --  The runtime work a write asks for: the mode conditions taken in again,
   --  the active adjustment ranges cleared, or a restart before a changed
   --  stick smoothing setting takes effect.
   type Effects is record
      Modes_Init        : Boolean := False;
      Adjustments_Reset : Boolean := False;
      Reboot_Required   : Boolean := False;
   end record;

   No_Effects : constant Effects := (others => False);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects);

end Adaflight.MSP_Receiver_In;
