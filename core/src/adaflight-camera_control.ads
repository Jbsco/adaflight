--  The camera control: a camera's OSD menu takes its keys over one pin as
--  the voltage of a resistor ladder, made by a hardware PWM duty or a
--  software PWM hi time, held for the key delay and the hold, then idle.
--  The hardware PWM idles at the full period and returns to it from the
--  process call once the end time has passed; the software PWM blocks its
--  caller for the wait, a hi time of zero as a low level, then idles high.
--  An unknown output mode or the DAC, which has no implementation, leaves
--  the control off.
with Interfaces;
package Adaflight.Camera_Control with SPARK_Mode is
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Key is (Enter, Left, Up, Right, Down);
   type Mode is (Hardware_PWM, Software_PWM, DAC, Unknown);

   PWM_Resolution      : constant := 128;
   Soft_PWM_Resolution : constant := 448;
   Supply_Volts        : constant Float := 3.3;

   subtype Setting_Value is Natural range 0 .. 65_535;
   type Key_Resistances is array (Key) of Setting_Value;

   --  The configured output mode, the reference voltage in 10 mV steps, the
   --  key delay, the internal and the key resistances in 100 ohm steps and
   --  the output inversion.
   type Settings is record
      Output              : Mode := Hardware_PWM;
      Ref_Voltage         : Setting_Value := 330;
      Key_Delay_Ms        : Setting_Value := 180;
      Internal_Resistance : Setting_Value := 470;
      Inverted            : Boolean := False;
      Buttons             : Key_Resistances := (450, 270, 150, 68, 0);
   end record;

   function Mode_Of (Code : Interfaces.Unsigned_8) return Mode is
     (case Code is when 0 => Hardware_PWM, when 1 => Software_PWM, when 2 => DAC, when others => Unknown);

   --  A duty count: a key voltage above the supply gives a count past the
   --  period, as the reference computes it.
   subtype Count is Natural range 0 .. 2 ** 17;
   subtype Hold_Time is Natural range 0 .. 2 ** 20;
   subtype Wait_Time is Natural range 0 .. 2 ** 21;

   type State is record
      Enabled  : Boolean := False;
      Output   : Mode := Hardware_PWM;
      Inverted : Boolean := False;
      Period   : Natural range 0 .. Soft_PWM_Resolution := 0;
      --  The hardware PWM compare value, the period when idle.
      Pulse    : Count := 0;
      --  The hardware key press end in milliseconds, zero when idle.
      End_Ms   : Unsigned_32 := 0;
   end record;

   --  What one key press asks of the pin: the OSD refresh reset, and for
   --  the software PWM its hi time over the period and the wait, with the
   --  pin low for the wait when the hi time is zero.
   type Press is record
      Taken     : Boolean := False;
      OSD_Reset : Boolean := False;
      Hi_Time   : Count := 0;
      Wait_Ms   : Wait_Time := 0;
      Low_Only  : Boolean := False;
   end record;

   --  The control on when the pin exists: a hardware PWM needs its timer
   --  channel and idles at the full period, a software PWM idles high.
   procedure Init (S : out State; C : Settings; Has_Pin : Boolean; Timer_Found : Boolean)
     with Post => S.Pulse <= Soft_PWM_Resolution;

   --  The key's voltage from the ladder, its duty of the supply, and the
   --  press: nothing while off or for a key code past the keys; else the OSD
   --  refresh reset, then the hardware compare value and end time, or the
   --  software hi time and wait.
   procedure Key_Press
     (S : in out State; C : Settings; Code : Interfaces.Unsigned_8; Hold_Ms : Hold_Time; Now_Ms : Unsigned_32;
      P : out Press);

   --  Once the hardware press has ended, the compare value back at the
   --  period; Idle says so.
   procedure Process (S : in out State; Now_Us : Unsigned_32; Idle : out Boolean);

   --  The level the software PWM pin idles at.
   function Idle_High (S : State) return Boolean is (not S.Inverted);

end Adaflight.Camera_Control;
