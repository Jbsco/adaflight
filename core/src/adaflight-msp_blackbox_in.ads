--  The MSP in message that writes the flight log's configuration: the
--  device, the sample rate, given or from the legacy rate or the intra to
--  delta frame ratio, and the fields left out. A log that has started takes
--  no change and the message still succeeds. A request reads zero past its
--  end. A request with a field outside its setting's range is an error that
--  writes and changes nothing; the fields left out take the bits the
--  disable settings name.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;
with Adaflight.Blackbox;

package Adaflight.MSP_Blackbox_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Blackbox_Config_Command : constant := 81;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is (Command = Set_Blackbox_Config_Command);

   --  The log fields the disable settings name.
   Field_Bits : constant Interfaces.Unsigned_32 := 16#1_FFFF#;

   type Result is (Ack, Error);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  Log is the flight log's recorder, whose state and intra frame interval
   --  the message reads, and Loop_Time the PID loop's time.
   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; Log : Blackbox.Recorder;
      Loop_Time : Blackbox.Loop_Time_Us; R : out Result)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old);

end Adaflight.MSP_Blackbox_In;
