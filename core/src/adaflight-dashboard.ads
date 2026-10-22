--  The OLED dashboard: one page of the board's state at a time on a 21 by
--  8 character display, cycled every five seconds while disarmed, the armed
--  page while armed, and a corner with the failsafe phase, the receiver's
--  state and a ticker. An update draws through display operations that the
--  board performs: a start of the display, which tells whether it is
--  there, a quick clear, a position, a line, a character and a text.
with Interfaces;
with Adaflight.Failsafe;
with Adaflight.Scheduler;

package Adaflight.Dashboard with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   Columns : constant := 21;
   Rows    : constant := 8;

   --  The pages by the identifiers the board's other units name them with.
   type Page_Id is (Welcome, Armed, Battery, Sensors, Receiver, Profile, Rate_Profile, Tasks, GPS, Debug, Blackbox);

   --  A display operation, its text up to 40 characters.
   Max_Text : constant := 40;
   type Operation_Kind is (Start, Clear, Position, Line, Char, Text);
   type Operation is record
      Kind   : Operation_Kind := Start;
      Column : Unsigned_8 := 0;
      Row    : Unsigned_8 := 0;
      Glyph  : Character := ' ';
      Data   : String (1 .. Max_Text) := (others => ' ');
      Length : Natural range 0 .. Max_Text := 0;
   end record;
   Max_Operations : constant := 256;
   type Operation_List is array (1 .. Max_Operations) of Operation;
   type Output is record
      Operations : Operation_List;
      Count      : Natural range 0 .. Max_Operations := 0;
   end record;

   --  An identity text up to 32 characters.
   type Identity is record
      Data   : String (1 .. 32) := (others => ' ');
      Length : Natural range 0 .. 32 := 0;
   end record;

   Max_Channels : constant := 18;
   type Channel_Values is array (0 .. Max_Channels - 1) of Float;
   type Axis_Values is array (0 .. 2) of Unsigned_8;
   type Vector is array (0 .. 2) of Float;
   Satellite_Slots : constant := 32;
   type Signal_Levels is array (0 .. Satellite_Slots - 1) of Unsigned_8;
   Log_Length : constant := 21;
   subtype Packet_Log is String (1 .. Log_Length);
   type Debug_Values is array (0 .. 3) of Integer_16;

   --  A task's statistics as the tasks page prints them.
   type Task_Row is record
      Enabled           : Boolean := False;
      Max_Exec_Us       : Unsigned_32 := 0;
      Average_Exec_10th : Unsigned_32 := 0;
      Max_Load_10th     : Unsigned_32 := 0;
      Average_Load_10th : Unsigned_32 := 0;
   end record;
   type Task_Rows is array (Scheduler.Task_Id) of Task_Row;

   --  What an update reads: whether the board is armed, whether the menu
   --  system holds the display, whether the display answers a start, the
   --  failsafe phase, whether the receiver gets a signal and whether its
   --  flight channels are valid, whether the GPS feature runs, which sensors
   --  run, the receiver's channels, the current PID profile with its gains,
   --  the current rate profile with its rates, the GPS receiver's solution,
   --  counters, packet log and satellite signals, the battery's meters and
   --  readings, the sensors' readings and the attitude, the tasks'
   --  statistics, the flight log device, the first four debug values, and
   --  the firmware's name, version and revision with the target's name.
   type Readings is record
      Armed            : Boolean := False;
      Grabbed          : Boolean := False;
      Present          : Boolean := False;
      Phase            : Failsafe.Phase := Failsafe.Idle;
      Rx_Signal        : Boolean := False;
      Rx_Valid         : Boolean := False;
      GPS_Enabled      : Boolean := False;
      Acc_On           : Boolean := False;
      Gyro_On          : Boolean := False;
      Mag_On           : Boolean := False;
      Channel_Count    : Natural range 0 .. Max_Channels := 0;
      Channels         : Channel_Values := (others => 0.0);
      PID_Index        : Unsigned_8 := 0;
      P_Gains          : Axis_Values := (others => 0);
      I_Gains          : Axis_Values := (others => 0);
      D_Gains          : Axis_Values := (others => 0);
      Rate_Index       : Unsigned_8 := 0;
      RC_Rates         : Axis_Values := (others => 0);
      Super_Rates      : Axis_Values := (others => 0);
      Expos            : Axis_Values := (others => 0);
      Satellites       : Unsigned_8 := 0;
      Fix              : Boolean := False;
      Latitude         : Integer_32 := 0;
      Longitude        : Integer_32 := 0;
      Ground_Speed     : Unsigned_16 := 0;
      Ground_Course    : Unsigned_16 := 0;
      Packets          : Unsigned_32 := 0;
      Sat_Info_Count   : Unsigned_32 := 0;
      Errors           : Unsigned_32 := 0;
      Timeouts         : Unsigned_32 := 0;
      Nav_Interval_Ms  : Unsigned_32 := 0;
      Log              : Packet_Log := (others => ASCII.NUL);
      Signals          : Signal_Levels := (others => 0);
      Voltage_Meter    : Boolean := False;
      Current_Meter    : Boolean := False;
      Voltage          : Unsigned_16 := 0;
      Cells            : Unsigned_8 := 0;
      Percentage       : Unsigned_8 := 0;
      Amperage         : Integer_32 := 0;
      MAh_Drawn        : Integer_32 := 0;
      Acc              : Vector := (others => 0.0);
      Gyro             : Vector := (others => 0.0);
      Mag              : Vector := (others => 0.0);
      Roll             : Integer_16 := 0;
      Pitch            : Integer_16 := 0;
      Yaw              : Integer_16 := 0;
      Tasks            : Task_Rows;
      Blackbox_Working : Boolean := False;
      Blackbox_Device  : Unsigned_8 := 0;
      Log_File         : Integer_8 := 0;
      Debug_Values_In  : Debug_Values := (others => 0);
      Firmware         : Identity;
      Version          : Identity;
      Revision         : Identity;
      Target           : Identity;
   end record;

   Page_Count   : constant := 11;
   Ticker_Count : constant := 5;
   subtype Page_Index is Natural range 0 .. Page_Count - 1;

   --  The page shown with whether it changes this update, whether pages
   --  cycle, whether a change is due, the cycle's position and the time of
   --  the next change, the time of the next update, whether the display
   --  answered its last start, the armed state of the last update, and the
   --  corner and GPS tickers with the satellite information count the GPS
   --  ticker last moved at.
   type State is record
      Page           : Page_Index := 0;
      Changing       : Boolean := False;
      Cycle_Enabled  : Boolean := False;
      Force_Change   : Boolean := False;
      Cycle_Index    : Page_Index := 0;
      Next_Page_At   : Unsigned_32 := 0;
      Next_Update_At : Unsigned_32 := 0;
      Present        : Boolean := False;
      Previous_Armed : Boolean := False;
      Ticker         : Natural range 0 .. Ticker_Count - 1 := 0;
      GPS_Ticker     : Natural range 0 .. Ticker_Count - 1 := 0;
      Last_Sat_Info  : Unsigned_32 := 0;
   end record;

   --  The start: the display started, the welcome page set and drawn, and
   --  the next page change five seconds on.
   procedure Init (S : in out State; Now_Us : Unsigned_32; R : Readings; O : out Output)
     with Global => null;

   --  An update every 200 milliseconds while the menu system leaves the
   --  display alone.
   procedure Update (S : in out State; Now_Us : Unsigned_32; R : Readings; O : in out Output)
     with Global => null;

   --  A page shown with cycling stopped, cycling started or stopped, and the
   --  cycle sent back to its first page.
   procedure Show_Fixed_Page (S : in out State; Page : Page_Id)
     with Global => null;
   procedure Enable_Cycling (S : in out State)
     with Global => null;
   procedure Disable_Cycling (S : in out State)
     with Global => null;
   procedure Reset_Cycling (S : in out State)
     with Global => null;

end Adaflight.Dashboard;
