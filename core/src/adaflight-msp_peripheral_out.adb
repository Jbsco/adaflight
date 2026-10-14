package body Adaflight.MSP_Peripheral_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Integer_32;

   function Word (V : Integer_16) return Unsigned_16 is (Unsigned_16 (Interfaces.Integer_32 (V) mod 65_536));

   function Byte_Of (V : Integer_8) return Unsigned_8 is (Unsigned_8 (Interfaces.Integer_32 (V) mod 256));

   procedure Servo_Configurations (B : in out Byte_Array; S : in out Stream; V : Snapshot)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 12 * V.Servo_Count and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      for I in 1 .. V.Servo_Count loop
         Write_U16 (B, S, Word (V.Params (I).Min));
         Write_U16 (B, S, Word (V.Params (I).Max));
         Write_U16 (B, S, Word (V.Params (I).Middle));
         Write_U8 (B, S, Byte_Of (V.Params (I).Rate));
         Write_U8 (B, S, Byte_Of (V.Params (I).Forward_From_Channel));
         Write_U32 (B, S, V.Params (I).Reversed_Sources);
         pragma Loop_Invariant (S.Next = Start + 12 * I and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Servo_Configurations;

   procedure Servo_Mix_Rules (B : in out Byte_Array; S : in out Stream; V : Snapshot)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 14 * V.Servo_Count and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      for I in 1 .. 2 * V.Servo_Count loop
         Write_U8 (B, S, V.Rules (I).Target_Channel);
         Write_U8 (B, S, V.Rules (I).Input_Source);
         Write_U8 (B, S, Byte_Of (V.Rules (I).Rate));
         Write_U8 (B, S, V.Rules (I).Speed);
         Write_U8 (B, S, Byte_Of (V.Rules (I).Min));
         Write_U8 (B, S, Byte_Of (V.Rules (I).Max));
         Write_U8 (B, S, V.Rules (I).Box);
         pragma Loop_Invariant (S.Next = Start + 7 * I and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Servo_Mix_Rules;

   procedure LED_Strip_Config (B : in out Byte_Array; S : in out Stream; L : LED_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 4 * L.Length + 2 and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      for I in 1 .. L.Length loop
         Write_U32 (B, S, (if L.Status_Mode then L.Configs (I) else 0));
         pragma Loop_Invariant (S.Next = Start + 4 * I and then S.Last = S.Last'Loop_Entry);
      end loop;
      Write_U8 (B, S, (if L.Status_Mode then 1 else 0));
      Write_U8 (B, S, L.Profile);
   end LED_Strip_Config;

   procedure LED_Mode_Colors (B : in out Byte_Array; S : in out Stream; L : LED_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 3 * (Mode_Count * Direction_Count + Special_Color_Count + 1)
                  and then S.Last = S.Last'Old
   is
      Aux_Channel_Mode : constant := 7;
      Start : constant Position := S.Next with Ghost;
   begin
      for Mode in 1 .. Mode_Count loop
         for Direction in 1 .. Direction_Count loop
            Write_U8 (B, S, Unsigned_8 (Mode - 1));
            Write_U8 (B, S, Unsigned_8 (Direction - 1));
            Write_U8 (B, S, L.Modes (Mode) (Direction));
            pragma Loop_Invariant
              (S.Next = Start + 3 * (Direction_Count * (Mode - 1) + Direction) and then S.Last = S.Last'Loop_Entry);
         end loop;
         pragma Loop_Invariant (S.Next = Start + 3 * Direction_Count * Mode and then S.Last = S.Last'Loop_Entry);
      end loop;
      for Special in 1 .. Special_Color_Count loop
         Write_U8 (B, S, Mode_Count);
         Write_U8 (B, S, Unsigned_8 (Special - 1));
         Write_U8 (B, S, L.Specials (Special));
         pragma Loop_Invariant
           (S.Next = Start + 3 * (Mode_Count * Direction_Count + Special) and then S.Last = S.Last'Loop_Entry);
      end loop;
      Write_U8 (B, S, Aux_Channel_Mode);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, L.Aux_Channel);
   end LED_Mode_Colors;

   procedure VTX_Config (B : in out Byte_Array; S : in out Stream; X : VTX_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 15 and then S.Last = S.Last'Old
   is
   begin
      Write_U8 (B, S, (if X.Device then X.Device_Type else 16#FF#));
      Write_U8 (B, S, X.Band);
      Write_U8 (B, S, X.Channel);
      Write_U8 (B, S, X.Power);
      Write_U8 (B, S, (if X.Device and then X.Pit_Mode then 1 else 0));
      Write_U16 (B, S, X.Frequency);
      Write_U8 (B, S, (if X.Device and then X.Ready then 1 else 0));
      Write_U8 (B, S, X.Low_Power_Disarm);
      Write_U16 (B, S, X.Pit_Frequency);
      if X.Table then
         Write_U8 (B, S, 1);
         Write_U8 (B, S, X.Table_Bands);
         Write_U8 (B, S, X.Table_Channels);
         Write_U8 (B, S, X.Table_Powers);
      else
         Fill (B, S, 0, 4);
      end if;
   end VTX_Config;

   procedure Wing (B : in out Byte_Array; S : in out Stream; W : Wing_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 45 and then S.Last = S.Last'Old
   is
   begin
      for G of W.S_Gains loop
         Write_U8 (B, S, G);
      end loop;
      for C of W.SPA_Center loop
         Write_U16 (B, S, C);
      end loop;
      for Width of W.SPA_Width loop
         Write_U16 (B, S, Width);
      end loop;
      for M of W.SPA_Mode loop
         Write_U8 (B, S, M);
      end loop;
      Write_U8 (B, S, W.TPA_Curve_Type);
      Write_U8 (B, S, W.TPA_Curve_Stall);
      Write_U16 (B, S, W.TPA_Curve_PID_Thr0);
      Write_U16 (B, S, W.TPA_Curve_PID_Thr100);
      Write_U8 (B, S, Byte_Of (W.TPA_Curve_Expo));
      Write_U8 (B, S, W.TPA_Speed_Type);
      Write_U16 (B, S, W.TPA_Speed_Delay);
      Write_U16 (B, S, W.TPA_Speed_Gravity);
      Write_U16 (B, S, W.TPA_Speed_Prop_Pitch);
      Write_U16 (B, S, W.TPA_Speed_Mass);
      Write_U16 (B, S, W.TPA_Speed_Drag_K);
      Write_U16 (B, S, W.TPA_Speed_Thrust);
      Write_U16 (B, S, W.TPA_Speed_Max_Voltage);
      Write_U16 (B, S, Word (W.TPA_Speed_Pitch_Offset));
      Write_U8 (B, S, W.Yaw_Type);
      Write_U16 (B, S, Word (W.Angle_Pitch_Offset));
   end Wing;

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
   begin
      if not Supported (Command, V) then
         return;
      end if;
      case Command is
         when Servo_Command =>
            for I in 1 .. V.Servo_Count loop
               Write_U16 (B, S, Word (V.Outputs (I)));
            end loop;
         when Servo_Configurations_Command =>
            Servo_Configurations (B, S, V);
         when Servo_Mix_Rules_Command =>
            Servo_Mix_Rules (B, S, V);
         when Motor_Output_Reordering_Command =>
            Write_U8 (B, S, Max_Motors);
            for Output of V.Motors loop
               Write_U8 (B, S, Output);
            end loop;
         when LED_Colors_Command =>
            for C of V.LED.Colors loop
               Write_U16 (B, S, C.H);
               Write_U8 (B, S, C.S);
               Write_U8 (B, S, C.V);
            end loop;
         when LED_Strip_Config_Command =>
            LED_Strip_Config (B, S, V.LED);
         when LED_Strip_Mode_Color_Command =>
            LED_Mode_Colors (B, S, V.LED);
         when VTX_Config_Command =>
            VTX_Config (B, S, V.VTX);
         when Wing_Command =>
            Wing (B, S, V.Wing);
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Peripheral_Out;
