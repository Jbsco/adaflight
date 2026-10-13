--  The spec prearm screen: the RPM limit, with the motor's KV and poles and
--  the limit's gains when it is on, the throttle limit, the motor output
--  limit, the battery voltage and the version, one row a call, each row
--  centred on the display from three rows above its middle. Settings and
--  readings stay with the target.
with Interfaces;
with Adaflight.Battery;
with Adaflight.OSD_Format;

package Adaflight.OSD_Spec with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;

   type Row_Kind is (RPM, Poles, Mixer, Throttle, Motor, Battery_Row, Version_Row);

   --  The row to draw next and the display row it goes to.
   type State is record
      Next : Row_Kind := RPM;
      Row  : Integer range -3 .. 131 := 0;
   end record;

   --  The display row stays within the screen's seven rows from three rows
   --  above the middle of the tallest display.
   function Valid (S : State) return Boolean is
     (S.Next = RPM or else S.Row <= 124 + Row_Kind'Pos (S.Next));

   subtype Throttle_Limit_Kind is Natural range 0 .. 2;

   type Settings is record
      RPM_Limit              : Boolean := False;
      RPM_Limit_Value        : Unsigned_16 := 18_000;
      RPM_Limit_P            : Unsigned_16 := 25;
      RPM_Limit_I            : Unsigned_16 := 10;
      RPM_Limit_D            : Unsigned_16 := 8;
      KV                     : Unsigned_16 := 1960;
      Pole_Count             : Unsigned_8 := 14;
      Throttle_Limit         : Throttle_Limit_Kind := 0;
      Throttle_Limit_Percent : Unsigned_8 := 100;
      Motor_Output_Limit     : Unsigned_8 := 100;
      Min_Cell               : Unsigned_16 := 330;
      Max_Cell               : Unsigned_16 := 430;
   end record;

   type Inputs is record
      Bidir_DShot  : Boolean := False;
      Pack_Voltage : Unsigned_16 := 0;
      Cell_Voltage : Unsigned_16 := 0;
      Battery      : Adaflight.Battery.Battery_State := Adaflight.Battery.OK;
   end record;

   --  One row: its position and text; complete after the version row,
   --  which starts the screen again.
   procedure Draw
     (S : in out State; C : Settings; Inp : Inputs; Rows, Cols : Unsigned_8; Version : String; X, Y : out Unsigned_8;
      Line : out Adaflight.OSD_Format.Text; Complete : out Boolean)
     with Pre  => Valid (S) and then C.Min_Cell /= C.Max_Cell
                  and then Version'Length in 1 .. Adaflight.OSD_Format.Max_Length,
          Post => Valid (S);

end Adaflight.OSD_Spec;
