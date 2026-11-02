with Interfaces;

package body Adaflight.VTX_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   function Bit (B : Boolean; V : Interfaces.Unsigned_32) return Interfaces.Unsigned_32 is (if B then V else 0);

   procedure Record_Tramp (D : in out Debug.State; T : Tramp.Driver) is
      Packed : Interfaces.Unsigned_32;
   begin
      if T.Taps.Ran and then Debug.Selected (D, Debug.VTX_Tramp) then
         Packed := (Interfaces.Shift_Left (Interfaces.Unsigned_32 (T.Conf_Pit_Mode), 14) and 16#C000#)
           or (Interfaces.Shift_Left (Interfaces.Unsigned_32 (T.Cur_Pit_Mode), 12) and 16#3000#)
           or (Interfaces.Shift_Left (Interfaces.Unsigned_32 (T.Conf_Power), 8) and 16#0F00#)
           or (Interfaces.Shift_Left (Interfaces.Unsigned_32 (T.Cur_Conf_Power), 4) and 16#00F0#)
           or Bit (T.Conf_Freq /= T.Cur_Freq, 16#0008#)
           or Bit (T.Conf_Power /= T.Cur_Conf_Power, 16#0004#)
           or Bit (T.Conf_Pit_Mode /= T.Cur_Pit_Mode, 16#0002#)
           or Bit (T.Taps.Update_Required, 16#0001#);
         Debug.Set (D, Debug.VTX_Tramp, 0, Debug.Integer_16 (Tramp.Status'Pos (T.Current)));
         Debug.Set (D, Debug.VTX_Tramp, 1, Debug.Integer_16 (T.Taps.Reply));
         Debug.Set (D, Debug.VTX_Tramp, 2, Debug.Wrapped (Interfaces.Integer_32 (Packed)));
         Debug.Set (D, Debug.VTX_Tramp, 3, Debug.Integer_16 (T.Retry_Count));
      end if;
   end Record_Tramp;

   procedure Record_SmartAudio (D : in out Debug.State; A : SmartAudio.Driver) is
   begin
      if A.Taps.Settings_Taken and then Debug.Selected (D, Debug.Smartaudio) then
         Debug.Set (D, Debug.Smartaudio, 0, A.Taps.Version_Mode);
         Debug.Set (D, Debug.Smartaudio, 1, Debug.Integer_16 (A.Taps.Channel));
         Debug.Set (D, Debug.Smartaudio, 2, Debug.Wrapped (Interfaces.Integer_32 (A.Taps.Freq)));
         Debug.Set (D, Debug.Smartaudio, 3, Debug.Integer_16 (A.Taps.Power));
      end if;
   end Record_SmartAudio;

end Adaflight.VTX_Debug;
