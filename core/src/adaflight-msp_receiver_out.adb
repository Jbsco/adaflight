with Adaflight.MSP_Box;

package body Adaflight.MSP_Receiver_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;

   function Built (On : Boolean; V : Unsigned_8) return Unsigned_8 is (if On then V else 0);

   procedure RX_Config (B : in out Byte_Array; S : in out Stream; R : RX_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 39 and then S.Last = S.Last'Old
   is
      Smooth : constant Boolean := R.RC_Smoothing;
   begin
      Write_U8 (B, S, R.Provider);
      Write_U16 (B, S, R.Max_Check);
      Write_U16 (B, S, R.Mid_RC);
      Write_U16 (B, S, R.Min_Check);
      Write_U8 (B, S, R.Spektrum_Sat_Bind);
      Write_U16 (B, S, R.Min_Usec);
      Write_U16 (B, S, R.Max_Usec);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U16 (B, S, Unsigned_16 (R.Airmode_Threshold) * 10 + 1_000);
      Write_U8 (B, S, Built (R.RX_SPI, R.SPI_Protocol));
      Write_U32 (B, S, (if R.RX_SPI then R.SPI_Id else 0));
      Write_U8 (B, S, Built (R.RX_SPI, R.SPI_Channel_Count));
      Write_U8 (B, S, R.FPV_Cam_Angle);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, Built (Smooth, R.Setpoint_Cutoff));
      Write_U8 (B, S, Built (Smooth, R.Throttle_Cutoff));
      Write_U8 (B, S, Built (Smooth, R.Auto_Factor_Throttle));
      Write_U8 (B, S, 0);
      Write_U8 (B, S, Built (R.USB_HID, R.USB_Type));
      Write_U8 (B, S, Built (Smooth, R.Auto_Factor_RPY));
      Write_U8 (B, S, Built (Smooth, R.Smoothing));
      Write_Data (B, S, (if R.ExpressLRS then R.UID else (1 .. 6 => 0)));
      Write_U8 (B, S, Built (R.ExpressLRS, R.Model_Id));
   end RX_Config;

   procedure Mode_Ranges (B : in out Byte_Array; S : in out Stream; Conditions : Adaflight.Modes.Conditions)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 4 * Adaflight.Modes.Max_Conditions and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      for I in Conditions'Range loop
         Write_U8 (B, S, MSP_Box.Permanent_Id (Conditions (I).Mode));
         Write_U8 (B, S, Unsigned_8 (Conditions (I).Aux));
         Write_U8 (B, S, Unsigned_8 (Conditions (I).Span.Start_Step));
         Write_U8 (B, S, Unsigned_8 (Conditions (I).Span.End_Step));
         pragma Loop_Invariant (S.Next = Start + 4 * (I + 1) and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Mode_Ranges;

   procedure Mode_Ranges_Extra (B : in out Byte_Array; S : in out Stream; Conditions : Adaflight.Modes.Conditions)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 1 + 3 * Adaflight.Modes.Max_Conditions and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      Write_U8 (B, S, Adaflight.Modes.Max_Conditions);
      for I in Conditions'Range loop
         Write_U8 (B, S, MSP_Box.Permanent_Id (Conditions (I).Mode));
         Write_U8 (B, S, Adaflight.Modes.Logic'Pos (Conditions (I).Combine));
         Write_U8 (B, S, MSP_Box.Permanent_Id (Conditions (I).Linked_To));
         pragma Loop_Invariant (S.Next = Start + 1 + 3 * (I + 1) and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Mode_Ranges_Extra;

   procedure Adjustment_Ranges (B : in out Byte_Array; S : in out Stream; Ranges : Adaflight.Adjustments.Ranges)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 10 * Adaflight.Adjustments.Max_Ranges and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      for I in Ranges'Range loop
         Write_U8 (B, S, 0);
         Write_U8 (B, S, Unsigned_8 (Ranges (I).Aux));
         Write_U8 (B, S, Unsigned_8 (Ranges (I).Span.Start_Step));
         Write_U8 (B, S, Unsigned_8 (Ranges (I).Span.End_Step));
         Write_U8 (B, S, Adaflight.Adjustments.Function_Kind'Pos (Ranges (I).Kind));
         Write_U8 (B, S, Unsigned_8 (Ranges (I).Switch_Aux));
         Write_U16 (B, S, Unsigned_16 (Ranges (I).Center));
         Write_U16 (B, S, Unsigned_16 (Ranges (I).Scale));
         pragma Loop_Invariant (S.Next = Start + 10 * (I + 1) and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Adjustment_Ranges;

   procedure RXFail_Config (B : in out Byte_Array; S : in out Stream; V : Snapshot)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 3 * V.Channel_Count and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      for I in 0 .. V.Channel_Count - 1 loop
         Write_U8 (B, S, Adaflight.Receiver.Failsafe_Mode'Pos (V.Channels (I).Mode));
         Write_U16 (B, S, Unsigned_16 (Adaflight.Receiver.Pulse_Min + 25 * V.Channels (I).Step));
         pragma Loop_Invariant (S.Next = Start + 3 * (I + 1) and then S.Last = S.Last'Loop_Entry);
      end loop;
   end RXFail_Config;

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
   begin
      case Command is
         when Mode_Ranges_Command =>
            Mode_Ranges (B, S, V.Conditions);
         when Mode_Ranges_Extra_Command =>
            Mode_Ranges_Extra (B, S, V.Conditions);
         when Adjustment_Ranges_Command =>
            Adjustment_Ranges (B, S, V.Adjustments);
         when RX_Config_Command =>
            RX_Config (B, S, V.RX);
         when Failsafe_Config_Command =>
            Write_U8 (B, S, V.Failsafe.Failsafe_Delay);
            Write_U8 (B, S, V.Failsafe.Landing_Time);
            Write_U16 (B, S, V.Failsafe.Throttle);
            Write_U8 (B, S, V.Failsafe.Switch_Mode);
            Write_U16 (B, S, V.Failsafe.Throttle_Low_Delay);
            Write_U8 (B, S, V.Failsafe.Procedure_Kind);
         when RXFail_Config_Command =>
            RXFail_Config (B, S, V);
         when RSSI_Config_Command =>
            Write_U8 (B, S, V.RX.RSSI_Channel);
         when RX_Map_Command =>
            for Target of V.Map loop
               Write_U8 (B, S, Unsigned_8 (Target));
            end loop;
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Receiver_Out;
