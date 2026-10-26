--  The waypoint capture gesture: a press of the capture switch samples the
--  GPS position, a release within 1.5 s appends it to the flight plan, and a
--  hold of 1.5 s deletes the last waypoint instead. Edits are refused while
--  the executor flies the plan, and a signal loss freezes the gesture. Each
--  edit leaves a message for the OSD for 2.5 s.
with Interfaces;
with Adaflight.Flight_Plan;

package Adaflight.Flight_Plan_Capture with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   Hold_Delete_Us  : constant := 1_500_000;
   Message_Time_Us : constant := 2_500_000;
   Message_Size    : constant := 16;

   type Capture is record
      Switch_Was        : Boolean := False;
      Press_Time_Us     : Unsigned_32 := 0;
      Delete_Fired      : Boolean := False;
      Pending           : Flight_Plan.Waypoint;
      Pending_Valid     : Boolean := False;
      Press_Accepted    : Boolean := False;
      Message           : String (1 .. Message_Size) := (others => ' ');
      Message_Length    : Natural range 0 .. Message_Size := 0;
      Message_Expire_Us : Unsigned_32 := 0;
      Message_Valid     : Boolean := False;
   end record;

   --  The GPS fix and the position a press samples.
   type Position is record
      Fix         : Boolean := False;
      Latitude    : Integer_32 := 0;
      Longitude   : Integer_32 := 0;
      Altitude_Cm : Integer_32 := 0;
   end record;

   --  One step of the gesture with the switch, the channels' validity and
   --  whether the executor flies the plan. An expired message is cleared
   --  first.
   procedure Update (C : in out Capture; P : in out Flight_Plan.Plan; Now_Us : Unsigned_32;
                     Switch_Active, Channels_Valid, Plan_Active : Boolean; Where : Position)
     with Global => null;

   --  The OSD's read of the message: valid until it expires, and cleared
   --  then.
   procedure Read_Message (C : in out Capture; Now_Us : Unsigned_32; Valid : out Boolean)
     with Global => null;

   function Message_Text (C : Capture) return String is (C.Message (1 .. C.Message_Length));

end Adaflight.Flight_Plan_Capture;
