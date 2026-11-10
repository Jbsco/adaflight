with Adaflight.Simplified_Tuning.Stored;

package body Adaflight.MSP_Simplified_Tuning with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use Adaflight.Config_Groups;

   --  The gain sliders from the request at an offset.
   procedure Read_PID_Sliders (Request : Byte_Array; Base : Request_Offset; P : in out Pid_Profile_Record)
     with Pre => Base <= Request_Offset'Last - PID_Sliders_Length
   is
   begin
      P.Simplified_Pids_Mode := Byte_At (Request, Base);
      P.Simplified_Master_Multiplier := Byte_At (Request, Base + 1);
      P.Simplified_Roll_Pitch_Ratio := Byte_At (Request, Base + 2);
      P.Simplified_I_Gain := Byte_At (Request, Base + 3);
      P.Simplified_D_Gain := Byte_At (Request, Base + 4);
      P.Simplified_Pi_Gain := Byte_At (Request, Base + 5);
      P.Simplified_D_Max_Gain := Byte_At (Request, Base + 6);
      P.Simplified_Feedforward_Gain := Byte_At (Request, Base + 7);
      P.Simplified_Pitch_Pi_Gain := Byte_At (Request, Base + 8);
   end Read_PID_Sliders;

   --  The D term filter sliders and cutoffs from the request at an offset.
   procedure Read_Dterm_Filters (Request : Byte_Array; Base : Request_Offset; P : in out Pid_Profile_Record)
     with Pre => Base <= Request_Offset'Last - Filter_Sliders_Length
   is
   begin
      P.Simplified_Dterm_Filter := Byte_At (Request, Base);
      P.Simplified_Dterm_Filter_Multiplier := Byte_At (Request, Base + 1);
      P.Dterm_Lpf1_Static_Hz := Unsigned_16 (U16_At (Request, Base + 2));
      P.Dterm_Lpf2_Static_Hz := Unsigned_16 (U16_At (Request, Base + 4));
      P.Dterm_Lpf1_Dyn_Min_Hz := Unsigned_16 (U16_At (Request, Base + 6));
      P.Dterm_Lpf1_Dyn_Max_Hz := Unsigned_16 (U16_At (Request, Base + 8));
   end Read_Dterm_Filters;

   --  The gyro filter sliders and cutoffs from the request at an offset.
   procedure Read_Gyro_Filters (Request : Byte_Array; Base : Request_Offset; G : in out Gyro_Config_Record)
     with Pre => Base <= Request_Offset'Last - Filter_Sliders_Length
   is
   begin
      G.Simplified_Gyro_Filter := Byte_At (Request, Base);
      G.Simplified_Gyro_Filter_Multiplier := Byte_At (Request, Base + 1);
      G.Gyro_Lpf1_Static_Hz := Unsigned_16 (U16_At (Request, Base + 2));
      G.Gyro_Lpf2_Static_Hz := Unsigned_16 (U16_At (Request, Base + 4));
      G.Gyro_Lpf1_Dyn_Min_Hz := Unsigned_16 (U16_At (Request, Base + 6));
      G.Gyro_Lpf1_Dyn_Max_Hz := Unsigned_16 (U16_At (Request, Base + 8));
   end Read_Gyro_Filters;

   procedure Write_PID_Sliders (B : in out Byte_Array; S : in out Stream; P : Pid_Profile_Record)
     with Pre  => Fits (S, B) and then Remaining (S) >= PID_Sliders_Length,
          Post => S.Next = S.Next'Old + PID_Sliders_Length and then S.Last = S.Last'Old
   is
   begin
      Write_U8 (B, S, P.Simplified_Pids_Mode);
      Write_U8 (B, S, P.Simplified_Master_Multiplier);
      Write_U8 (B, S, P.Simplified_Roll_Pitch_Ratio);
      Write_U8 (B, S, P.Simplified_I_Gain);
      Write_U8 (B, S, P.Simplified_D_Gain);
      Write_U8 (B, S, P.Simplified_Pi_Gain);
      Write_U8 (B, S, P.Simplified_D_Max_Gain);
      Write_U8 (B, S, P.Simplified_Feedforward_Gain);
      Write_U8 (B, S, P.Simplified_Pitch_Pi_Gain);
      Write_U32 (B, S, 0);
      Write_U32 (B, S, 0);
   end Write_PID_Sliders;

   --  A filter slider's switch and multiplier, the static cutoffs and the
   --  dynamic range.
   procedure Write_Filters
     (B : in out Byte_Array; S : in out Stream; On, Multiplier : Byte;
      Static_1, Static_2, Dyn_Min, Dyn_Max : Unsigned_16)
     with Pre  => Fits (S, B) and then Remaining (S) >= Filter_Sliders_Length,
          Post => S.Next = S.Next'Old + Filter_Sliders_Length and then S.Last = S.Last'Old
   is
   begin
      Write_U8 (B, S, On);
      Write_U8 (B, S, Multiplier);
      Write_U16 (B, S, Static_1);
      Write_U16 (B, S, Static_2);
      Write_U16 (B, S, Dyn_Min);
      Write_U16 (B, S, Dyn_Max);
      Write_U32 (B, S, 0);
      Write_U32 (B, S, 0);
   end Write_Filters;

   procedure Write_Dterm_Filters (B : in out Byte_Array; S : in out Stream; P : Pid_Profile_Record)
     with Pre  => Fits (S, B) and then Remaining (S) >= Filter_Sliders_Length,
          Post => S.Next = S.Next'Old + Filter_Sliders_Length and then S.Last = S.Last'Old
   is
   begin
      Write_Filters
        (B, S, P.Simplified_Dterm_Filter, P.Simplified_Dterm_Filter_Multiplier, P.Dterm_Lpf1_Static_Hz,
         P.Dterm_Lpf2_Static_Hz, P.Dterm_Lpf1_Dyn_Min_Hz, P.Dterm_Lpf1_Dyn_Max_Hz);
   end Write_Dterm_Filters;

   procedure Write_Gyro_Filters (B : in out Byte_Array; S : in out Stream; G : Gyro_Config_Record)
     with Pre  => Fits (S, B) and then Remaining (S) >= Filter_Sliders_Length,
          Post => S.Next = S.Next'Old + Filter_Sliders_Length and then S.Last = S.Last'Old
   is
   begin
      Write_Filters
        (B, S, G.Simplified_Gyro_Filter, G.Simplified_Gyro_Filter_Multiplier, G.Gyro_Lpf1_Static_Hz,
         G.Gyro_Lpf2_Static_Hz, G.Gyro_Lpf1_Dyn_Min_Hz, G.Gyro_Lpf1_Dyn_Max_Hz);
   end Write_Gyro_Filters;

   --  Each axis's P, I and D gains and D max, then its feedforward gain.
   procedure Write_Gains (B : in out Byte_Array; S : in out Stream; P : Pid_Profile_Record)
     with Pre  => Fits (S, B) and then Remaining (S) >= 18,
          Post => S.Next = S.Next'Old + 18 and then S.Last = S.Last'Old
   is
      procedure Write_Axis (I : Natural)
        with Pre  => I <= 2 and then Fits (S, B) and then Remaining (S) >= 6,
             Post => S.Next = S.Next'Old + 6 and then S.Last = S.Last'Old
      is
      begin
         Write_U8 (B, S, P.Pid (I).P);
         Write_U8 (B, S, P.Pid (I).I);
         Write_U8 (B, S, P.Pid (I).D);
         Write_U8 (B, S, P.D_Max (I));
         Write_U16 (B, S, P.Pid (I).F);
      end Write_Axis;
   begin
      Write_Axis (0);
      Write_Axis (1);
      Write_Axis (2);
   end Write_Gains;

   function Same_Gains (X, Y : Pid_Profile_Record) return Boolean is
     (for all I in 0 .. 2 =>
        X.Pid (I).P = Y.Pid (I).P and then X.Pid (I).I = Y.Pid (I).I
        and then X.Pid (I).D = Y.Pid (I).D and then X.D_Max (I) = Y.D_Max (I)
        and then X.Pid (I).F = Y.Pid (I).F);

   -----------
   -- Reply --
   -----------

   procedure Reply
     (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; Request : Byte_Array;
      P : Config_Groups.Pid_Profile_Record; G : Config_Groups.Gyro_Config_Record; Ok : out Boolean)
   is
   begin
      Ok := not Handles (Command) or else Valid (Command, Request);
      if not Ok or else not Handles (Command) then
         return;
      end if;
      case Command is
         when Simplified_Tuning_Command =>
            Write_PID_Sliders (B, S, P);
            Write_Dterm_Filters (B, S, P);
            Write_Gyro_Filters (B, S, G);
         when Calculate_PID_Command =>
            declare
               Result : Pid_Profile_Record := P;
            begin
               Read_PID_Sliders (Request, 0, Result);
               Simplified_Tuning.Stored.Apply_PIDs (Result);
               Write_Gains (B, S, Result);
            end;
         when Calculate_Gyro_Command =>
            declare
               Result : Gyro_Config_Record := G;
            begin
               Read_Gyro_Filters (Request, 0, Result);
               Simplified_Tuning.Stored.Apply_Gyro_Filters (Result);
               Write_Gyro_Filters (B, S, Result);
            end;
         when Calculate_Dterm_Command =>
            declare
               Result : Pid_Profile_Record := P;
            begin
               Read_Dterm_Filters (Request, 0, Result);
               Simplified_Tuning.Stored.Apply_Dterm_Filters (Result);
               Write_Dterm_Filters (B, S, Result);
            end;
         when Validate_Command =>
            declare
               Gains   : Pid_Profile_Record := P;
               Filters : Gyro_Config_Record := G;
            begin
               Simplified_Tuning.Stored.Apply_PIDs (Gains);
               Write_U8 (B, S, Boolean'Pos (Same_Gains (Gains, P)));
               Simplified_Tuning.Stored.Apply_Gyro_Filters (Filters);
               Write_U8
                 (B, S,
                  Boolean'Pos
                    (Filters.Gyro_Lpf1_Static_Hz = G.Gyro_Lpf1_Static_Hz
                     and then Filters.Gyro_Lpf2_Static_Hz = G.Gyro_Lpf2_Static_Hz
                     and then Filters.Gyro_Lpf1_Dyn_Min_Hz = G.Gyro_Lpf1_Dyn_Min_Hz
                     and then Filters.Gyro_Lpf1_Dyn_Max_Hz = G.Gyro_Lpf1_Dyn_Max_Hz));
               Simplified_Tuning.Stored.Apply_Dterm_Filters (Gains);
               Write_U8
                 (B, S,
                  Boolean'Pos
                    (Gains.Dterm_Lpf1_Static_Hz = P.Dterm_Lpf1_Static_Hz
                     and then Gains.Dterm_Lpf2_Static_Hz = P.Dterm_Lpf2_Static_Hz
                     and then Gains.Dterm_Lpf1_Dyn_Min_Hz = P.Dterm_Lpf1_Dyn_Min_Hz
                     and then Gains.Dterm_Lpf1_Dyn_Max_Hz = P.Dterm_Lpf1_Dyn_Max_Hz));
            end;
         when others =>
            null;
      end case;
   end Reply;

   ---------
   -- Set --
   ---------

   procedure Set
     (Request : Byte_Array; P : in out Config_Groups.Pid_Profile_Record;
      G : in out Config_Groups.Gyro_Config_Record; Ok : out Boolean)
   is
   begin
      Ok := Valid (Set_Simplified_Tuning_Command, Request);
      if not Ok then
         return;
      end if;
      Read_PID_Sliders (Request, 0, P);
      Read_Dterm_Filters (Request, PID_Sliders_Length, P);
      Read_Gyro_Filters (Request, PID_Sliders_Length + Filter_Sliders_Length, G);
      Simplified_Tuning.Stored.Apply (P, G);
   end Set;

end Adaflight.MSP_Simplified_Tuning;
