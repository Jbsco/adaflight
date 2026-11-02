with Interfaces;

package body Adaflight.Receiver_Debug with SPARK_Mode is
   use type Interfaces.Integer_32;

   --  A value held within the conversion bound.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   function Flag (B : Boolean) return Debug.Integer_16 is (if B then 1 else 0);

   --  The frame status bit upstream logs for a failsafe frame.
   Frame_Failsafe_Bit : constant := 2;

   procedure Record_Frame_Check (D : in out Debug.State; S : Receiver.State; Delta_Us : Receiver.Time_Delta) is
   begin
      Debug.Set (D, Debug.RX_Signal_Loss, 2, Debug.Wrapped (Interfaces.Integer_32'Min (2000, Delta_Us / 100)));
      if S.Taps.Checked then
         if S.Taps.Status_Read then
            Debug.Set (D, Debug.RX_Signal_Loss, 1, (if S.Taps.Frame_Failsafe then Frame_Failsafe_Bit else 0));
         end if;
         Debug.Set (D, Debug.Failsafe, 1, Flag (S.Signal_Received));
         Debug.Set (D, Debug.RX_Signal_Loss, 0, Flag (S.Signal_Received));
      end if;
   end Record_Frame_Check;

   procedure Record_Channels (D : in out Debug.State; S : Receiver.State) is
   begin
      if S.Taps.Loss_Applied then
         Debug.Set (D, Debug.RX_Signal_Loss, 3, Debug.Truncated (Held (S.Data (Receiver.Throttle))));
      end if;
   end Record_Channels;

   procedure Record_Failsafe (D : in out Debug.State; F : Failsafe.State) is
   begin
      if F.Taps.Updated then
         Debug.Set (D, Debug.Failsafe, 2, Flag (F.Taps.Receiving_At_Entry));
         Debug.Set (D, Debug.Failsafe, 0, Flag (F.Switch_Was_On));
         Debug.Set (D, Debug.Failsafe, 3, Debug.Integer_16 (Failsafe.Phase'Pos (F.Current)));
      end if;
   end Record_Failsafe;

   procedure Record_State_Time (D : in out Debug.State; T : RX_Task.State; Left : RX_Task.Step) is
      Estimate : constant RX_Task.Estimate := T.Duration (Left);
   begin
      Debug.Set (D, Debug.RX_State_Time, RX_Task.Step'Pos (Left),
                 Debug.Wrapped (if Estimate < 0 then -1 else Estimate / 64));
   end Record_State_Time;

end Adaflight.Receiver_Debug;
