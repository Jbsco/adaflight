package body Adaflight.MAVLink_Debug with SPARK_Mode is

   procedure Record_Receiver (D : in out Debug.State; R : MAVLink.State) is
   begin
      if R.Radio_Status_Taken and then Debug.Selected (D, Debug.Mavlink_Telemetry) then
         Debug.Set (D, Debug.Mavlink_Telemetry, 1, Debug.Integer_16 (R.Tx_Buffer_Free));
      end if;
   end Record_Receiver;

   procedure Record_Telemetry
     (D : in out Debug.State; T : MAVLink_Telemetry.State; Tx_Valid, Tx_Should_Send : Boolean)
   is
   begin
      if Debug.Selected (D, Debug.Mavlink_Telemetry) then
         if Tx_Valid then
            Debug.Set (D, Debug.Mavlink_Telemetry, 0, Boolean'Pos (Tx_Should_Send));
         end if;
         for Slot in MAVLink_Telemetry.Counted_Slot loop
            if T.Taps.Sent (Slot) then
               Debug.Set (D, Debug.Mavlink_Telemetry, Slot, Debug.Integer_16 (T.Taps.Counts (Slot)));
            end if;
         end loop;
      end if;
   end Record_Telemetry;

end Adaflight.MAVLink_Debug;
