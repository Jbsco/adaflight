--  Mixer setup: each mixer mode's motor count, whether it drives servos and
--  its motor table in the build; the motors in use and their mix, from the
--  mode or, for the custom modes, from the custom table up to its first
--  entry without throttle; the launch control mix, which holds the front
--  motors at zero; a mode's table loaded into the custom table; and whether
--  the motors run or saturate. A mode whose table the build leaves out
--  keeps the previous mix for its motor count.
with Adaflight.Mixer;

package Adaflight.Mixer_Init with SPARK_Mode is

   subtype Mix_Table is Adaflight.Mixer.Mix_Table;
   subtype Motor_Outputs is Adaflight.Mixer.Motor_Outputs;

   --  The modes in their configuration order, from one.
   type Mixer_Mode is
     (Tri, Quad_P, Quad_X, Bicopter, Gimbal, Y6, Hex6, Flying_Wing, Y4, Hex6X, Octo_X8, Octo_Flat_P, Octo_Flat_X,
      Airplane, Heli_120_CCPM, Heli_90_Deg, Vtail4, Hex6H, PPM_To_Servo, Dualcopter, Singlecopter, Atail4, Custom,
      Custom_Airplane, Custom_Tri, Quad_X_1234, Octo_X8P);

   subtype Supported_Motors is Natural range 4 .. Adaflight.Mixer.Max_Motors;

   --  The build's mixers: quad X only, the uncommon frames, the motors the
   --  target drives, and launch control.
   type Options is record
      Quad_Only      : Boolean := False;
      Uncommon       : Boolean := True;
      Max_Motors     : Supported_Motors := Adaflight.Mixer.Max_Motors;
      Launch_Control : Boolean := True;
   end record;

   function Motor_Count_Of (Mode : Mixer_Mode) return Natural
     with Post => Motor_Count_Of'Result <= Adaflight.Mixer.Max_Motors;

   function Uses_Servos (Mode : Mixer_Mode) return Boolean is
     (Mode in Tri | Bicopter | Gimbal | Flying_Wing | Airplane | Heli_120_CCPM | Heli_90_Deg | PPM_To_Servo
             | Dualcopter | Singlecopter | Custom_Airplane | Custom_Tri);

   function Is_Fixed_Wing (Mode : Mixer_Mode) return Boolean is
     (Mode in Flying_Wing | Airplane | Custom_Airplane);

   --  Whether the build has the mode's motor table.
   function Has_Table (O : Options; Mode : Mixer_Mode) return Boolean;

   --  The motors in use and their mix; the custom modes take the custom
   --  table, the others their own table at most the build's motors long.
   --  Launch is the mix with every motor that pitches the nose up held at
   --  zero, unchanged without launch control. Every disarmed output of the
   --  build's motors is reset to the disarm value.
   procedure Configure_Output
     (O : Options; Mode : Mixer_Mode; Custom_Mix : Mix_Table; Disarm_Output : Adaflight.Mixer.Motor_Value;
      Current : in out Mix_Table; Count : out Natural; Launch : in out Mix_Table; Disarmed : in out Motor_Outputs)
     with Post => Count <= O.Max_Motors;

   --  The custom table cleared of throttle, then given the mode's table.
   procedure Load_Mix (O : Options; Mode : Mixer_Mode; Custom_Mix : in out Mix_Table)
     with Pre => not O.Quad_Only;

   --  Whether the motors run: armed, or a disarmed output differing from the
   --  disarm value among the motors in use.
   function Motors_Running
     (Armed : Boolean; Disarmed : Motor_Outputs; Count : Natural; Disarm_Output : Float) return Boolean
     with Pre => Count <= Adaflight.Mixer.Max_Motors;

   --  Whether a motor in use is at or above the maximum throttle.
   function Motors_Saturated (Motors : Motor_Outputs; Count : Natural; Max_Throttle : Float) return Boolean
     with Pre => Count <= Adaflight.Mixer.Max_Motors;

end Adaflight.Mixer_Init;
