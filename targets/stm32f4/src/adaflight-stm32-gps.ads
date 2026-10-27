--  The GPS module on a UART: the link on the serial port with the GPS
--  function, run by the GPS task with the bytes received and the bytes and
--  rate changes it asks for carried out, and its readings for the flight,
--  the OSD, the replies and the status.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.GPS_Frames;
with Adaflight.GPS_Link;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.USART;
package Adaflight.STM32.GPS is
   --  The link's settings and its port, which opens at the link's rate
   --  when the GPS feature is on and a serial port has the GPS function.
   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Now_Ms : Interfaces.Unsigned_32);

   --  Whether the GPS feature runs with a port.
   function Enabled return Boolean;
   --  Whether the GPS link holds a UART.
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;

   --  What a run of the task asks of the flight: the ready beep, the task
   --  rate and the solutions the run took in.
   type Report is record
      Ready_Beep : Boolean := False;
      Rate       : Adaflight.GPS_Link.Task_Rate := Adaflight.GPS_Link.Unchanged;
      Solutions  : Natural := 0;
   end record;

   --  One run of the GPS task: the bytes received through the link, its
   --  bytes sent and its rate change made.
   procedure Run (Now_Ms, Now_Us : Interfaces.Unsigned_32; Armed : Boolean; R : out Report);

   --  The readings: the module present with a fix, the home fix, a fix ever
   --  held and a healthy link, the satellites, the position, the speeds and
   --  the course, the dilutions, the home vector and the distance flown,
   --  the time of week, the home position and the channels in view, and for
   --  the position estimate the solutions' stamp, their rate, the cosine of
   --  the home latitude and the solution's accuracies.
   type Readings is record
      Present             : Boolean := False;
      Fix                 : Boolean := False;
      Fix_Home            : Boolean := False;
      Fix_Ever            : Boolean := False;
      Healthy             : Boolean := False;
      Satellites          : Interfaces.Unsigned_8 := 0;
      Latitude            : Interfaces.Integer_32 := 0;
      Longitude           : Interfaces.Integer_32 := 0;
      Altitude_Cm         : Interfaces.Integer_32 := 0;
      Ground_Speed        : Interfaces.Unsigned_16 := 0;
      Speed_3D            : Interfaces.Unsigned_16 := 0;
      Ground_Course       : Interfaces.Unsigned_16 := 0;
      Velocity            : Adaflight.GPS_Frames.Velocity;
      PDOP                : Interfaces.Unsigned_16 := 0;
      HDOP                : Interfaces.Unsigned_16 := 0;
      VDOP                : Interfaces.Unsigned_16 := 0;
      Distance_To_Home_M  : Interfaces.Unsigned_16 := 0;
      Distance_To_Home_Cm : Interfaces.Unsigned_32 := 0;
      Direction_To_Home   : Interfaces.Integer_16 := 0;
      Distance_Flown_Cm   : Interfaces.Unsigned_32 := 0;
      Time_Ms             : Interfaces.Unsigned_32 := 0;
      --  The clock at the last solution, which the telemetry reads as the
      --  solution's time.
      Solution_Ms         : Interfaces.Unsigned_32 := 0;
      Use_3D_Speed        : Boolean := False;
      Home                : Adaflight.GPS_Frames.Location;
      In_View             : Interfaces.Unsigned_8 := 0;
      Tick                : Boolean := False;
      Stamp               : Interfaces.Unsigned_16 := 0;
      Rate_Hz             : Float range 0.38 .. 25.0 := 10.0;
      Cos_Lat             : Float range -1.0 .. 1.0 := 1.0;
      Accuracy            : Adaflight.GPS_Frames.Accuracy;
   end record;

   function Current return Readings;
   --  The home position from the current fix with enough satellites, unless
   --  it is kept once set, with a u-blox module's satellite reports turned
   --  off.
   procedure Reset_Home;
   function Link_State return Adaflight.GPS_Link.Link_State;
   function Platform return Adaflight.GPS_Frames.Platform;
   --  The port's rate as the status command's index.
   function Port_Baud return Adaflight.Serial_Feature_Map.Baud_Index;
   function Satellite (I : Adaflight.GPS_Frames.Satellite_Index) return Adaflight.GPS_Frames.Satellite;
   function Time return Adaflight.GPS_Frames.Date_Time;
end Adaflight.STM32.GPS;
