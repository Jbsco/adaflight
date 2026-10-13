--  The OSD task: the update check that wakes it at the frame rate, and the
--  update that steps its state machine one state a call through the boot
--  screen, the three statistics steps and the page, the alarms, the canvas,
--  the element draw cycle, the spec prearm screen, the commit and the
--  transfer. The display port's answers come in with each call and its
--  operations go back in order; the scheduler takes each state's timing.
--  Settings, readings and the display stay with the target.
with Interfaces;
with Adaflight.OSD_Draw;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Format;
with Adaflight.OSD_Page;
with Adaflight.OSD_Render;
with Adaflight.OSD_Spec;
with Adaflight.OSD_Stats;
with Adaflight.OSD_Warnings;
with Adaflight.RTC;
with Adaflight.Scheduler;

package Adaflight.OSD_Task with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Task_State is
     (Init, Idle, Check, Process_Stats_1, Refresh_Stats, Process_Stats_2, Process_Stats_3, Update_Alarms,
      Refresh_Prearm, Update_Canvas, Draw_Element, Display_Element, Update_Heartbeat, Commit, Transfer);

   type Device_Kind is (None, Auto, MAX7456, MSP, FrSky_OSD, Framebuffer);

   --  The display port's answers for this call: ready, a transfer under
   --  way, a heartbeat that took extra action, more of the screen to draw,
   --  grabbed by the menu.
   type Display_Answers is record
      Ready                : Boolean := True;
      Transfer_In_Progress : Boolean := False;
      Heartbeat_Taken      : Boolean := False;
      More_To_Draw         : Boolean := False;
      Grabbed              : Boolean := False;
   end record;

   --  A display operation; Attr holds the write's attribute or font, the
   --  clear's wait, the system element, the layer or the transaction's
   --  option.
   type Op_Kind is
     (Clear, Write, Write_Char, Write_Logo, Write_Sys, Select_Layer, Layer_Copy, Redraw_Background, Redraw,
      Begin_Transaction, Commit_Transaction, Heartbeat, Draw_Screen);
   type Op is record
      Kind : Op_Kind := Write;
      X, Y : Unsigned_8 := 0;
      Attr : Unsigned_8 := 0;
      Line : Adaflight.OSD_Format.Text;
   end record;

   Max_Ops : constant := 128;
   type Op_Array is array (1 .. Max_Ops) of Op;
   type Ops is record
      List  : Op_Array;
      Count : Natural range 0 .. Max_Ops := 0;
   end record;

   subtype Frame_Rate is Unsigned_16 range 1 .. 60;
   Max_Version : constant := 20;

   --  What the task reads: the display's kind, layer and blink, the frame
   --  rate, the spec screen's setting, the version, and the settings and
   --  readings of the page, alarms, elements, renderers and spec screen,
   --  with the clock for the boot screen.
   type Context is record
      Device           : Device_Kind := MAX7456;
      Background_Layer : Boolean := False;
      Device_Blink     : Boolean := False;
      Rate_Hz          : Frame_Rate := 12;
      Show_Spec        : Boolean := False;
      Version          : String (1 .. Max_Version) := (others => ' ');
      Version_Length   : Natural range 1 .. Max_Version := 1;
      Page_Settings    : Adaflight.OSD_Page.Settings;
      Page_Inputs      : Adaflight.OSD_Page.Inputs;
      Readings         : Adaflight.OSD_Stats.Readings;
      Page             : Adaflight.OSD_Stats.Page;
      Alarm_Settings   : Adaflight.OSD_Elements.Alarm_Settings;
      Alarm_Inputs     : Adaflight.OSD_Elements.Alarm_Inputs;
      Element_Inputs   : Adaflight.OSD_Elements.Element_Inputs;
      Positions        : Adaflight.OSD_Elements.Positions := (others => 0);
      Draw             : Adaflight.OSD_Draw.Context;
      Spec_Settings    : Adaflight.OSD_Spec.Settings;
      Spec_Inputs      : Adaflight.OSD_Spec.Inputs;
      RTC_Variant      : Adaflight.OSD_Format.Element_Type := Adaflight.OSD_Format.Type_1;
      Has_Time         : Boolean := False;
      Date             : Adaflight.RTC.Date_Time;
      Zone             : Adaflight.RTC.Settings;
   end record;

   function Context_Valid (C : Context) return Boolean is
     (Adaflight.OSD_Draw.Context_Valid (C.Draw) and then C.Spec_Settings.Min_Cell /= C.Spec_Settings.Max_Cell
      and then C.Date.Month in 1 .. 12);

   type State_Times is array (Task_State) of Unsigned_16;
   type Element_Times is array (0 .. Adaflight.OSD_Elements.Max_Active) of Unsigned_32;

   --  The task's state: the state on turn, the next frame's due time, the
   --  draw cycle's progress, the GPS sensor last seen, the states' and
   --  elements' running peak times, and the page, statistics, blink, active
   --  list, draw cycle, renderer, warnings and spec screen states with the
   --  craft name.
   type OSD is record
      State            : Task_State := Init;
      Due_Us           : Unsigned_32 := 0;
      More_Elements    : Boolean := False;
      Last_GPS         : Boolean := False;
      Background_Layer : Boolean := False;
      State_Time       : State_Times := (others => 0);
      Element_Time     : Element_Times := (others => 0);
      Page             : Adaflight.OSD_Page.State;
      Stats            : Adaflight.OSD_Stats.Statistics;
      Blink            : Adaflight.OSD_Elements.Blink;
      Active           : Adaflight.OSD_Elements.Active_List;
      Cycle            : Adaflight.OSD_Draw.Cycle;
      Render           : Adaflight.OSD_Render.State;
      Warnings         : Adaflight.OSD_Warnings.State;
      Spec             : Adaflight.OSD_Spec.State;
      Craft            : Adaflight.OSD_Render.Craft_Name_Buffer := (others => Character'Val (0));
   end record;

   --  The scheduler's check: an idle task wakes once the frame is due, the
   --  due time stepping past the clock by whole frames; a check or transfer
   --  waits while the display transfers.
   procedure Update_Check
     (O : in out OSD; C : Context; Now_Us : Unsigned_32; Transfer_In_Progress : Boolean; Due : out Boolean);

   --  One state of the update. The clock reads Clock_Us during the call and
   --  Draw_End_Us after an element draw.
   procedure Update
     (O : in out OSD; C : Context; Now_Us, Clock_Us, Draw_End_Us : Unsigned_32; Answers : Display_Answers;
      Sched : in out Adaflight.Scheduler.State; Result : out Ops)
     with Pre => Context_Valid (C) and then Adaflight.OSD_Spec.Valid (O.Spec)
                 and then O.Render.ESC_Motor < Unsigned_8 (C.Draw.Inputs.Motors);

end Adaflight.OSD_Task;
