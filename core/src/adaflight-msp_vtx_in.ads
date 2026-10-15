--  The MSP in message that writes the video transmitter's settings: band
--  and channel or frequency, power and pit mode, low power while disarmed,
--  pit mode frequency, band, channel and frequency again in their own
--  fields, and the table's counts with an optional clearing. A request
--  reads zero past its end. A field outside its setting's range, or a table
--  count past eight, is an error that writes and changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;
with Adaflight.VTX_Table;

package Adaflight.MSP_VTX_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_VTX_Config_Command : constant := 89;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is (Command = Set_VTX_Config_Command);

   type Result is (Ack, Error);

   --  The transmitter the board drives: present, of a known type, and in
   --  pit mode.
   type Device is record
      Present    : Boolean := False;
      Known_Type : Boolean := False;
      Pit_Mode   : Boolean := False;
   end record;

   --  The runtime work a write asks for: the transmitter's pit mode set to
   --  the request's byte, and the MSP transmitter marked ready for the
   --  requesting link.
   type Effects is record
      Pit_Mode_Set   : Boolean := False;
      Pit_Mode_Value : Byte := 0;
      VTX_Ready      : Boolean := False;
   end record;

   No_Effects : constant Effects := (Pit_Mode_Set | VTX_Ready => False, Pit_Mode_Value => 0);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  The running table gives the frequency of a band and channel when a
   --  transmitter is present.
   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; D : Device;
      T : VTX_Table.Table; R : out Result; E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects);

end Adaflight.MSP_VTX_In;
