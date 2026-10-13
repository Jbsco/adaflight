--  The OSD's statistics page and arming screen, and the steps the OSD runs
--  around them each cycle: the arming and disarming transitions with the
--  reset and the end voltage, the flight and launch times, the statistics
--  refresh and their hiding by the switch, the pause after arming or
--  booting that the sticks end, the auxiliary value, and the acceleration
--  the page reads. The page itself is laid out row by row from the enabled
--  statistics, centred vertically with its heading when the rows fit, the
--  armed screen shows the logo, the armed word and the crash flip warning,
--  and the boot screen the logo, the version, the menu help and the clock.
--  The display, the sticks, the switches and the readings stay with the
--  target.
with Interfaces;
with Adaflight.OSD_Format;
with Adaflight.OSD_Stats;
with Adaflight.RTC;

package Adaflight.OSD_Page with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   Refresh_1S    : constant := 1_000_000;
   Logo_Rows     : constant := 4;
   Logo_Cols     : constant := 24;
   Logo_Start    : constant := 16#A0#;
   End_Of_Font   : constant := 16#FF#;
   Stick_High    : constant := 1_750.0;
   Max_Writes    : constant := 104;
   Heading       : constant String := "--- STATS ---";
   Armed_Word    : constant String := "ARMED";
   Crash_Warning : constant String := ">CRASH FLIP<";
   Help_1        : constant String := "MENU:THR MID";
   Help_2        : constant String := "+ YAW LEFT";
   Help_3        : constant String := "+ PITCH UP";

   subtype Font is Natural range 0 .. 3;

   --  A request to the display: a clear, text at a column and row, one
   --  character there in a font, or the logo as a whole when the display
   --  draws it itself.
   type Write_Kind is (Clear, Text_Write, Char_Write, Logo_Write);
   type Write is record
      Kind     : Write_Kind := Clear;
      Wait     : Boolean := False;
      X        : Unsigned_8 := 0;
      Y        : Unsigned_8 := 0;
      Text     : Adaflight.OSD_Format.Text;
      Char     : Character := ' ';
      Font_Sel : Font := 0;
   end record;
   type Write_List is array (1 .. Max_Writes) of Write;
   type Writes is record
      List  : Write_List;
      Count : Natural range 0 .. Max_Writes := 0;
   end record;

   --  The page's progress: the row being written, the next statistic in
   --  the order, and the row count found by the counting pass.
   type Render_State is record
      Row       : Unsigned_8 := 0;
      Index     : Unsigned_8 := 0;
      Row_Count : Unsigned_8 := 0;
   end record;

   type Refresh_Phase is (Initial_Clear, Count_Stats, Clear_Between, Render_Stats);

   --  What the OSD keeps between cycles: the page's progress and phase, the
   --  arming state it last saw, the statistics shown and visible, the
   --  times of the last cycle, the next refresh, the next auxiliary value
   --  and the pause's end, the flight and launch times, the auxiliary
   --  value, the acceleration and the stats suppression.
   type State is record
      Render                : Render_State;
      Phase                 : Refresh_Phase := Initial_Clear;
      Arm_State             : Boolean := False;
      Stats_Enabled         : Boolean := False;
      Stats_Visible         : Boolean := False;
      Last_Time_Us          : Unsigned_32 := 0;
      Stats_Refresh_Time_Us : Unsigned_32 := 0;
      Aux_Refresh_Time_Us   : Unsigned_32 := 0;
      Resume_Refresh_At     : Unsigned_32 := 0;
      Fly_Time_Us           : Unsigned_32 := 0;
      Launch_Time_Us        : Unsigned_32 := 0;
      Aux_Value             : Unsigned_16 := 0;
      G_Force               : Adaflight.OSD_Stats.G_Force := 0.0;
      Suppress_Stats        : Boolean := False;
   end record;

   --  The screen and the settings the page and the screens read.
   type Settings is record
      Rows                 : Unsigned_8 := 16;
      Cols                 : Unsigned_8 := 30;
      Enabled              : Adaflight.OSD_Stats.Stat_Set := (others => False);
      Logo_On_Arming       : Natural range 0 .. 2 := 0;
      Logo_Duration_Tenths : Unsigned_8 := 5;
      Arming_Logo          : Font := 0;
      Logo_Supported       : Boolean := False;
      Aux_Scale            : Unsigned_16 := 200;
      Aux_Visible          : Boolean := False;
      G_Force_Visible      : Boolean := False;
      Warnings_Visible     : Boolean := False;
   end record;

   --  What one cycle reads from the target.
   type Inputs is record
      Now_Us                   : Unsigned_32 := 0;
      Armed                    : Boolean := False;
      Was_Ever_Armed           : Boolean := False;
      Has_Link_Quality_Source  : Boolean := False;
      Failsafe_Active          : Boolean := False;
      Runaway_Or_Crash_Disable : Boolean := False;
      Display_Grabbed          : Boolean := False;
      OSD_Switch               : Boolean := False;
      Launch_Control_Active    : Boolean := False;
      Aux_Rc                   : Float range 0.0 .. 5_000.0 := 1_500.0;
      Throttle_High            : Boolean := False;
      Pitch_High               : Boolean := False;
      Crash_Flip_Box           : Boolean := False;
      Crash_Flip_Active        : Boolean := False;
      Acc_Present              : Boolean := False;
      Acc_Magnitude            : Adaflight.OSD_Stats.G_Force := 0.0;
   end record;

   procedure Clear_Writes (W : out Writes)
     with Post => W.Count = 0;

   --  The page's inputs within the statistics' bounds.
   function Page_Ready (S : Adaflight.OSD_Stats.Statistics; P : Adaflight.OSD_Stats.Page) return Boolean is
     (P.Date.Month in 1 .. 12
      and then Adaflight.OSD_Format.Timer_Source_Of (P.Timer_1) <= 4
      and then Adaflight.OSD_Format.Timer_Source_Of (P.Timer_2) <= 4
      and then S.Max_Altitude in -Adaflight.OSD_Stats.Altitude_Bound .. Adaflight.OSD_Stats.Altitude_Bound
      and then (not P.Blackbox_Working
                or else P.Blackbox_Device not in Adaflight.OSD_Stats.Device_Flash | Adaflight.OSD_Stats.Device_SDCard
                or else Adaflight.OSD_Stats.Storage_Total (P) > 0));

   --  The pause after arming: the logo's duration when it shows, else half
   --  a second.
   function Armed_Delay_Us (C : Settings; Was_Ever_Armed : Boolean) return Unsigned_32 is
     (if C.Logo_On_Arming = 1 or else (C.Logo_On_Arming = 2 and then not Was_Ever_Armed)
      then Unsigned_32 (C.Logo_Duration_Tenths) * 100_000 else Refresh_1S / 2);

   --  The logo at a column and row: drawn by the display when it can, else
   --  the font's logo characters row by row.
   procedure Draw_Logo (C : Settings; X, Y : Unsigned_8; Font_Sel : Font; W : in out Writes)
     with Pre  => W.Count <= Max_Writes - Logo_Rows * Logo_Cols,
          Post => W.Count <= W.Count'Old + Logo_Rows * Logo_Cols;

   --  The armed screen: a cleared screen, the logo when the setting shows
   --  it, the armed word, and the crash flip warning when that mode is on.
   procedure Show_Armed (C : Settings; Inp : Inputs; W : out Writes);

   --  The boot screen: a cleared screen, the logo, the version in capitals,
   --  the menu help and the clock when there is one.
   procedure Boot_Screen (C : Settings; Version : String; RTC_Variant : Adaflight.OSD_Format.Element_Type;
                          Has_Time : Boolean; Date : Adaflight.RTC.Date_Time; Zone : Adaflight.RTC.Settings;
                          W : out Writes)
     with Pre => Version'Length <= 20 and then Date.Month in 1 .. 12;

   --  One step of the page: the heading or one statistic's row, Done when
   --  the page is complete or the rows ran out.
   procedure Render_Continue (R : in out Render_State; C : Settings; S : Adaflight.OSD_Stats.Statistics;
                              P : Adaflight.OSD_Stats.Page; W : out Writes; Done : out Boolean)
     with Pre => Page_Ready (S, P);

   --  One step of the refresh: the counting pass, the clear and the page,
   --  Completed when the page is done.
   procedure Refresh_Stats (ST : in out State; C : Settings; S : Adaflight.OSD_Stats.Statistics;
                            P : Adaflight.OSD_Stats.Page; W : out Writes; Completed : out Boolean)
     with Pre => Page_Ready (S, P);

   --  The first step of a cycle: the transitions, the times while armed,
   --  the statistics' refresh and hiding while disarmed, and the auxiliary
   --  value. Show_Armed reports the arming screen to draw, Clear_Now the
   --  screen hidden by the switch, Refresh the page due.
   procedure Process_Stats_1 (ST : in out State; S : in out Adaflight.OSD_Stats.Statistics; C : Settings; Inp : Inputs;
                              R : Adaflight.OSD_Stats.Readings; Show_Armed : out Boolean; Clear_Now : out Boolean;
                              Refresh : out Boolean);

   --  The second step: the pause after arming or booting, ended early by
   --  the sticks or the crash flip switch while disarmed; Skip says the
   --  cycle draws nothing, Clear_Now that the pause ended.
   procedure Process_Stats_2 (ST : in out State; S : in out Adaflight.OSD_Stats.Statistics; Inp : Inputs;
                              Skip : out Boolean; Clear_Now : out Boolean);

   --  The third step: the acceleration when something shows it.
   procedure Process_Stats_3 (ST : in out State; C : Settings; Inp : Inputs);

   --  The auxiliary value: the channel's share of its range scaled.
   function Aux_Value_Of (Rc : Float; Scale : Unsigned_16) return Unsigned_16
     with Pre => Rc in 0.0 .. 5_000.0;

end Adaflight.OSD_Page;
