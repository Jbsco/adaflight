--  PID audio: while its mode box is on, the PID sum of roll, pitch or both
--  as a tone on the audio output, from 63 for no sum down to 0 at 500 or
--  more. The output starts with white noise when the box turns on and goes
--  silent when it turns off; the off mode holds the middle tone.
with Adaflight.Adjustments;

package Adaflight.PID_Audio with SPARK_Mode is
   use type Adaflight.Adjustments.Audio_Mode;

   subtype Audio_Mode is Adaflight.Adjustments.Audio_Mode;

   Tone_Count : constant := 64;
   subtype Tone is Natural range 0 .. Tone_Count - 1;
   Tone_Mid : constant := Tone_Count / 2;

   subtype PID_Sum is Float range -2.0 ** 32 .. 2.0 ** 32;

   type State is record
      Enabled : Boolean := False;
      Mode    : Audio_Mode := Adaflight.Adjustments.PID_Sum_XY;
   end record;

   --  The audio calls of one update, in this order.
   type Calls is record
      Start_Noise : Boolean := False;
      Silence     : Boolean := False;
      Play        : Boolean := False;
      Played      : Tone := Tone_Mid;
   end record;

   procedure Set_Mode (S : in out State; M : Audio_Mode)
     with Post => S.Mode = M and then S.Enabled = S.Enabled'Old;

   procedure Update (S : in out State; Box_Active : Boolean; Roll_Sum, Pitch_Sum : PID_Sum; C : out Calls)
     with Post => S.Enabled = Box_Active and then C.Play = Box_Active
                  and then C.Start_Noise = (Box_Active and then not S.Enabled'Old)
                  and then C.Silence = (S.Enabled'Old and then not Box_Active);

end Adaflight.PID_Audio;
