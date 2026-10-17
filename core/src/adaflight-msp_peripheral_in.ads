--  The MSP in messages that write the wing's tuning and the race
--  transponder's configuration. A request reads zero past its end. A wing
--  request shorter than its 45 bytes, a transponder request without a
--  provider, a provider past the three, or transponder data of other than
--  the provider's length is an error that writes and changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Peripheral_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Transponder_Config_Command : constant := 83;
   Set_Wing_Command               : constant := 203;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Transponder_Config_Command | Set_Wing_Command);

   type Result is (Ack, Error);

   --  The runtime work a write asks for: the PID settings taken in again
   --  after the wing's tuning, and the transponder's data encoded again.
   type Effects is record
      PID_Init         : Boolean := False;
      Transponder_Data : Boolean := False;
   end record;

   No_Effects : constant Effects := (others => False);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  The current PID profile is within its list.
   function Profile_Valid (C : Configuration) return Boolean is
     (Natural (C.System_Config.Pid_Profile_Index) < C.Pid_Profiles'Length);

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
     with Pre  => Handles (Command) and then Profile_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects);

end Adaflight.MSP_Peripheral_In;
