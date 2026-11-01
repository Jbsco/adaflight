--  The link to the GPS module over its serial port. The baud rate is found
--  by polling the version three times at each rate of the sweep, the module
--  is moved to the configured rate through its own sentence, the
--  configuration runs step by step on the acknowledgements with a timeout
--  for each, a data timeout restarts the detection, the dynamic model
--  switches to the flight model once a fix is held, and every solution with
--  a fix updates the distance and the direction home and the distance
--  flown. The home position is set on request from a fix with enough
--  satellites. The caller owns the port: it hands over the bytes received
--  since the last call and carries out the bytes and the rate change a call
--  asks for.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Maths;
with Adaflight.GPS_Frames;
with Adaflight.UBX_Config;

package Adaflight.GPS_Link with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Cosine is Adaflight.Maths.Cosine;

   type Provider is (NMEA, UBlox, MSP, Virtual);

   --  The rates of the detection sweep, fastest first.
   type Baud_Rate is (B_230400, B_115200, B_57600, B_38400, B_19200, B_9600);

   function Rate_Of (B : Baud_Rate) return Unsigned_32 is
     (case B is
         when B_230400 => 230_400,
         when B_115200 => 115_200,
         when B_57600  => 57_600,
         when B_38400  => 38_400,
         when B_19200  => 19_200,
         when B_9600   => 9_600);

   subtype Update_Rate_Hz is Unsigned_8 range 1 .. 20;
   subtype Satellite_Minimum is Unsigned_8 range 5 .. 50;

   --  The NMEA commands sent after the rate change, separated by spaces.
   Max_Command : constant := 64;
   subtype Command_Length is Natural range 0 .. Max_Command;
   subtype Command_Text is String (1 .. Max_Command);

   type Settings is record
      Source            : Provider := UBlox;
      Port_Assigned     : Boolean := True;
      Baud              : Baud_Rate := B_57600;
      Auto_Config       : Boolean := True;
      Sbas              : UBX_Config.Sbas_Mode := UBX_Config.None;
      Sbas_Integrity    : Boolean := False;
      Use_Galileo       : Boolean := False;
      Acquire_Model     : UBX_Config.Dynamic_Model := UBX_Config.Stationary;
      Flight_Model      : UBX_Config.Dynamic_Model := UBX_Config.Airborne_4G;
      Update_Rate       : Update_Rate_Hz := 10;
      UTC               : UBX_Config.UTC_Standard := UBX_Config.Auto;
      Enable_Assistance : Boolean := False;
      Set_Home_Once     : Boolean := False;
      Use_3D_Speed      : Boolean := False;
      Commands          : Command_Text := (others => ' ');
      Commands_Length   : Command_Length := 0;
      Min_Sats          : Satellite_Minimum := 8;
   end record;

   type Link_State is (Unknown, Detect_Baud, Initialized, Change_Baud, Configure, Receiving_Data,
                       Lost_Communication);

   --  The task rate asked for: fast while bytes are waiting, normal one
   --  call after the last byte.
   type Task_Rate is (Unchanged, Fast, Normal);

   --  The bytes a call sends, in order. A call sends at most a reply to the
   --  module and one configuration message; a frame past the room is
   --  dropped and flagged.
   Max_Tx : constant := 2 * UBX_Config.Max_Frame;
   subtype Tx_Length is Natural range 0 .. Max_Tx;
   subtype Tx_Index is Natural range 0 .. Max_Tx - 1;
   type Tx_Bytes is array (Tx_Index) of Byte;

   type Transmission is record
      Data     : Tx_Bytes := (others => 0);
      Length   : Tx_Length := 0;
      Overflow : Boolean := False;
   end record;

   --  What one call asks of the caller: the bytes to send, the port rate to
   --  set, the indicator toggle, the ready beep, the clock to set and the
   --  task rate, with the count of solutions completed.
   type Events is record
      Tx           : Transmission;
      Baud_Changed : Boolean := False;
      New_Baud     : Baud_Rate := B_230400;
      Indicator    : Boolean := False;
      Ready_Beep   : Boolean := False;
      Clock        : GPS_Frames.Clock_Request;
      Clock_Sets   : Natural := 0;
      Rate         : Task_Rate := Unchanged;
      Solutions    : Natural := 0;
   end record;

   subtype Interval_S is Float range 0.04 .. 2.6;
   subtype Frequency_Hz is Float range 0.38 .. 25.0;
   subtype Sweep_Count is Natural range 0 .. 12;
   subtype Wait_Count is Natural range 0 .. 2;
   subtype Centidegrees is Natural range 0 .. 35_999;

   --  What the debug values read of the link: whether an update ran, the
   --  bytes waiting when the port was read, the navigation interval at a
   --  completed frame, the connection values the reference logs in its second
   --  and third slots (baud detection progress or the navigation message age,
   --  and the baud rate in hundreds or that age), and the dynamic model last
   --  sent. Each tap holds what its site last wrote.
   type Debug_Taps is record
      Updated   : Boolean := False;
      Rx_Set    : Boolean := False;
      Rx_Count  : Natural := 0;
      Conn1_Set : Boolean := False;
      Conn1     : Unsigned_32 := 0;
      Conn2_Set : Boolean := False;
      Conn2     : Unsigned_32 := 0;
      Conn3_Set : Boolean := False;
      Conn3     : Unsigned_32 := 0;
      Model_Set : Boolean := False;
      Model     : Natural range 0 .. 7 := 0;
   end record;

   type Link is record
      State               : Link_State := Unknown;
      Position            : Unsigned_32 := 0;
      Now                 : Unsigned_32 := 0;
      State_Ts            : Unsigned_32 := 0;
      Last_Nav_Message    : Unsigned_32 := 0;
      Last_Message_Sent   : Unsigned_32 := 0;
      Timeouts            : Unsigned_32 := 0;
      User_Baud           : Baud_Rate := B_230400;
      Temp_Baud           : Baud_Rate := B_230400;
      Port_Baud           : Baud_Rate := B_230400;
      Port_Open           : Boolean := False;
      Update_Rate         : Unsigned_8 := 10;
      Using_Flight_Model  : Boolean := False;
      Sensor_Present      : Boolean := False;
      Fix_Home            : Boolean := False;
      Home                : GPS_Frames.Location;
      Cos_Lat             : Cosine := 1.0;
      Distance_To_Home_M  : Unsigned_16 := 0;
      Distance_To_Home_Cm : Unsigned_32 := 0;
      Direction_To_Home   : Integer_16 := 0;
      Distance_Flown_Cm   : Unsigned_32 := 0;
      Last_Llh            : GPS_Frames.Location;
      Data_Interval_S     : Interval_S := 0.1;
      Data_Frequency_Hz   : Frequency_Hz := 10.0;
      Stamp               : Unsigned_16 := 0;
      Tick                : Boolean := False;
      Solution_Offered    : Boolean := False;
      Message_Sent        : Boolean := False;
      Message_Counter     : Unsigned_8 := 0;
      Sweep_Steps         : Sweep_Count := 0;
      Last_Sweep_Step     : Unsigned_32 := 0;
      Last_Step_Time      : Unsigned_32 := 0;
      Command_Offset      : Command_Length := 0;
      Indicator_Time_Us   : Unsigned_32 := 0;
      Has_Beeped          : Boolean := False;
      Wait                : Wait_Count := 0;
      Is_Fast             : Boolean := False;
      --  The virtual provider: the solution a simulator offered, its offer
      --  count with the count and the time last seen, and the next update.
      Virtual_Sol         : GPS_Frames.Solution;
      Virtual_Count       : Unsigned_32 := 0;
      Virtual_Last_Count  : Unsigned_32 := 0;
      Virtual_Last_Change : Unsigned_32 := 0;
      Virtual_Next_Update : Unsigned_32 := 0;
      Taps                : Debug_Taps;
   end record;

   --  The start: the rate sweep begins at the configured rate once the port
   --  is open. A source without a port starts initialized.
   procedure Init (L : out Link; R : in out GPS_Frames.Receiver; C : Settings; Now_Ms : Unsigned_32;
                   Port_Opened : Boolean);

   --  One task call at the millisecond and microsecond clocks with the
   --  bytes received since the last one, whether the transmit buffer has
   --  drained and whether the craft is armed. The clock flag is raised when
   --  a solution sets the clock.
   procedure Update (L : in out Link; R : in out GPS_Frames.Receiver; C : Settings; Now_Ms, Now_Us : Unsigned_32;
                     Rx : Byte_Array; Tx_Empty, Armed : Boolean; Clock_Has_Time : in out Boolean; E : out Events);

   --  A solution from the ground link: the fix, the satellite count, the
   --  position with the altitude in metres and the ground speed, taken at
   --  the next call.
   procedure Offer_Solution (L : in out Link; R : in out GPS_Frames.Receiver; Fix : Boolean; Num_Sat : Unsigned_8;
                             Lat, Lon : Integer_32; Alt_M : Unsigned_16; Ground_Speed : Unsigned_16);

   --  A solution from a simulator for the virtual provider: the position,
   --  the speeds and the course as a solution carries them, taken at the
   --  next update step with twelve satellites and fixed accuracies.
   procedure Offer_Virtual (L : in out Link; Lat, Lon, Alt_Cm : Integer_32;
                            Ground_Speed, Speed_3D, Course : Unsigned_16; Vel_North, Vel_East, Vel_Down : Integer_16);
   --  The home position from the current fix with enough satellites, unless
   --  it is kept once set. The satellite information is turned off on a
   --  u-blox module and the distance flown restarts.
   procedure Reset_Home (L : in out Link; R : in out GPS_Frames.Receiver; C : Settings; Tx : out Transmission);

   function Healthy (L : Link) return Boolean is (L.State = Receiving_Data);

   --  Whether a solution arrived since the caller's stamp, which moves on.
   procedure Take_New_Data (L : Link; Stamp : in out Unsigned_16; Fresh : out Boolean);

end Adaflight.GPS_Link;
