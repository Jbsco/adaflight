package body Adaflight.Config_Runtime with SPARK_Mode is

   Last_Box : constant Natural := Modes.Box'Pos (Modes.Box'Last);

   --  A stored condition: its range held to the steps, its aux channel to
   --  the channels, its logic to the two, its link to a box or none.
   function Condition_Of (M : Mode_Activation_Condition_Record) return Modes.Condition is
     (if Natural (M.Mode_Id) > Last_Box then Modes.Empty
      else
        (Mode      => Modes.Box'Val (M.Mode_Id),
         Aux       => Held (Integer (M.Aux_Channel_Index), 0, Modes.Aux_Channel_Count - 1),
         Span      => (Start_Step => Held (Integer (M.Range_Value.Start_Step), 0, Modes.Max_Range_Step),
                       End_Step   => Held (Integer (M.Range_Value.End_Step), 0, Modes.Max_Range_Step)),
         Combine   => Modes.Logic'Val (Code (M.Mode_Logic, 1)),
         Linked_To => (if Natural (M.Linked_To) > Last_Box then Modes.Arm else Modes.Box'Val (M.Linked_To))));

   function Conditions_Of (C : Mode_Activation_Condition_Record_List_20) return Modes.Conditions is
      R : Modes.Conditions;
   begin
      for I in R'Range loop
         R (I) := Condition_Of (C (I));
      end loop;
      return R;
   end Conditions_Of;

   function Map_Of (Rcmap : Bytes_8) return Receiver.Channel_Map is
      M : Receiver.Channel_Map;
   begin
      for I in M'Range loop
         M (I) := Held (Integer (Rcmap (I)), 0, Receiver.Channel_Count - 1);
      end loop;
      return M;
   end Map_Of;

   --  A channel range, its ends held to the pulse range, an equal pair
   --  widened by one step so that the scaling has a span.
   function Range_Of (R : Rx_Channel_Range_Config_Record) return Receiver.Range_Config is
      Low  : constant Receiver.Pulse_Us := Held (Integer (R.Min), Receiver.Pulse_Min, Receiver.Pulse_Max);
      High : constant Receiver.Pulse_Us := Held (Integer (R.Max), Receiver.Pulse_Min, Receiver.Pulse_Max);
   begin
      if Low /= High then
         return (Low => Low, High => High);
      elsif High <= Receiver.Pulse_Max - 25 then
         return (Low => Low, High => High + 25);
      else
         return (Low => Low - 25, High => High);
      end if;
   end Range_Of;

   function Ranges_Of (Ranges : Rx_Channel_Range_Config_Record_List_4) return Receiver.Range_Configs is
      C : Receiver.Range_Configs;
   begin
      for I in C'Range loop
         C (I) := Range_Of (Ranges (I));
      end loop;
      return C;
   end Ranges_Of;

   function Failsafes_Of (Failsafes : Rx_Failsafe_Channel_Config_Record_List_18) return Receiver.Failsafe_Channels is
      C : Receiver.Failsafe_Channels;
   begin
      for I in C'Range loop
         C (I) := (Mode => Receiver.Failsafe_Mode'Val (Code (Failsafes (I).Mode, 3)),
                   Step => Held (Integer (Failsafes (I).Step), 0, Receiver.Max_Failsafe_Step));
      end loop;
      return C;
   end Failsafes_Of;

   function Channels_Of (Mask : Unsigned_32) return Receiver.Channel_Set is
      C : Receiver.Channel_Set;
   begin
      for I in C'Range loop
         C (I) := (Mask and Shift_Left (1, I)) /= 0;
      end loop;
      return C;
   end Channels_Of;

end Adaflight.Config_Runtime;
