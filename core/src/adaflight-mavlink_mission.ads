--  The MAVLink mission protocol: a ground station uploads and downloads the
--  flight plan and a fence of up to 16 points kept in memory, sets the
--  current item and clears the stores. An upload asks for each item in turn,
--  asks again after 1.5 s up to five times, and replaces the plan once its
--  last item arrives. A download answers each item request and ends at the
--  station's acknowledgement or after 5 s without a request. The unit
--  reports the current item every second and each waypoint the executor
--  reaches. A set-current request goes to the executor, whose answer the
--  caller hands back.
with Interfaces;
with Adaflight.MAVLink;
with Adaflight.MAVLink_Frames;
with Adaflight.Flight_Plan;
with Adaflight.Flight_Plan_Nav;

package Adaflight.MAVLink_Mission with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   Upload_Retry_Ms   : constant := 1_500;
   Upload_Max_Retry  : constant := 5;
   Download_Idle_Ms  : constant := 5_000;
   Current_Period_Ms : constant := 1_000;
   Max_Fence_Points  : constant := 16;

   type Transfer_State is (Idle, Receiving, Sending);

   --  A fence item as the station sent it, its first parameter kept as bits.
   type Fence_Point is record
      Command     : Unsigned_16 := 0;
      Latitude    : Integer_32 := 0;
      Longitude   : Integer_32 := 0;
      Param1_Bits : Unsigned_32 := 0;
   end record;
   type Fence_List is array (0 .. Max_Fence_Points - 1) of Fence_Point;

   type State is record
      Transfer           : Transfer_State := Idle;
      Mission_Type       : Unsigned_8 := 0;
      Next_Seq           : Unsigned_16 := 0;
      Total_Count        : Unsigned_16 := 0;
      Partner_Sys        : Unsigned_8 := 0;
      Partner_Comp       : Unsigned_8 := 0;
      Last_Activity_Ms   : Unsigned_32 := 0;
      Retries            : Unsigned_8 := 0;
      Last_Current_Tx_Ms : Unsigned_32 := 0;
      Pending_Reached    : Integer range -1 .. 255 := -1;
      RTL_Terminator     : Boolean := False;
      Fence_Count        : Natural range 0 .. Max_Fence_Points := 0;
      Fence              : Fence_List;
      Set_Sys            : Unsigned_8 := 0;
      Set_Comp           : Unsigned_8 := 0;
   end record;

   --  The executor's state as the protocol reports it.
   type Executor_Status is record
      Active        : Boolean := False;
      Injected      : Boolean := False;
      Current_Index : Unsigned_8 := 0;
      Complete      : Boolean := False;
   end record;

   --  What the handlers read: the executor, the autopilot mode, the home
   --  with its fix, the hold radius and maximum velocity, and the clock.
   type Inputs is record
      Executor         : Executor_Status;
      Autopilot_Mode   : Boolean := False;
      Home_Fix         : Boolean := False;
      Home_Altitude_Cm : Integer_32 := 0;
      Radius           : Flight_Plan_Nav.Hold_Radius := 200;
      Max_Speed        : Flight_Plan_Nav.Max_Velocity := 500;
      Now_Ms           : Unsigned_32 := 0;
   end record;

   Max_Output : constant := 512;
   subtype Output_Bytes is MAVLink_Frames.Byte_Buffer (1 .. Max_Output);

   --  The frames written, whether the configuration is to be saved, and a
   --  set-current request for the executor.
   type Output is record
      Data              : Output_Bytes := (others => 0);
      Length            : Natural range 0 .. Max_Output := 0;
      Save_Config       : Boolean := False;
      Set_Current       : Boolean := False;
      Set_Current_Index : Unsigned_8 := 0;
   end record;

   procedure Init (M : out State)
     with Global => null;

   --  A message from the link; Handled says it was a mission message.
   procedure Handle
     (M       : in out State;
      P       : in out Flight_Plan.Plan;
      Msg     : MAVLink.Message;
      I       : Inputs;
      Seq     : in out Unsigned_8;
      O       : in out Output;
      Handled : out Boolean)
     with Global => null;

   --  The executor's answer to a set-current request: the current item
   --  report when it took the index, an error acknowledgement when not.
   procedure Complete_Set_Current
     (M        : State;
      P        : Flight_Plan.Plan;
      Accepted : Boolean;
      I        : Inputs;
      Seq      : in out Unsigned_8;
      O        : in out Output)
     with Global => null;

   --  A waypoint the executor reached, reported at the next update.
   procedure Waypoint_Reached (M : in out State; Index : Unsigned_8)
     with Global => null;

   --  The retries and timeouts, the reached waypoint and the current item
   --  report.
   procedure Update
     (M   : in out State;
      P   : Flight_Plan.Plan;
      I   : Inputs;
      Seq : in out Unsigned_8;
      O   : in out Output)
     with Global => null;

end Adaflight.MAVLink_Mission;
