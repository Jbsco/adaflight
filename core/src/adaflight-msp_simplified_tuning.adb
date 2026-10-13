with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Simplified_Tuning;

package body Adaflight.MSP_Simplified_Tuning with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use Adaflight.PID_Profile;

   --  The gain sliders from the request at an offset.
   procedure Read_PID_Sliders (Request : Byte_Array; Base : Request_Offset; P : in out Profile)
     with Pre => Base <= Request_Offset'Last - PID_Sliders_Length and then PID_Sliders_Valid (Request, Base)
   is
   begin
      P.Simplified_PIDs_Mode := Simplified_Mode'Val (Byte_At (Request, Base));
      P.Simplified_Master_Multiplier := Natural (Byte_At (Request, Base + 1));
      P.Simplified_Roll_Pitch_Ratio := Natural (Byte_At (Request, Base + 2));
      P.Simplified_I_Gain := Natural (Byte_At (Request, Base + 3));
      P.Simplified_D_Gain := Natural (Byte_At (Request, Base + 4));
      P.Simplified_PI_Gain := Natural (Byte_At (Request, Base + 5));
      P.Simplified_D_Max_Gain := Natural (Byte_At (Request, Base + 6));
      P.Simplified_Feedforward_Gain := Natural (Byte_At (Request, Base + 7));
      P.Simplified_Pitch_PI_Gain := Natural (Byte_At (Request, Base + 8));
   end Read_PID_Sliders;

   --  The D term filter sliders and cutoffs from the request at an offset.
   --  The dynamic range's ends are written in the order that keeps the lower
   --  end off or at most the upper end at every step.
   procedure Read_Dterm_Filters (Request : Byte_Array; Base : Request_Offset; P : in out Profile)
     with Pre => Base <= Request_Offset'Last - Filter_Sliders_Length and then Filter_Sliders_Valid (Request, Base)
   is
      New_Min : constant Hertz := U16_At (Request, Base + 6);
      New_Max : constant Hertz := U16_At (Request, Base + 8);
   begin
      P.Simplified_Dterm_Filter := Byte_At (Request, Base) = 1;
      P.Simplified_Dterm_Filter_Multiplier := Natural (Byte_At (Request, Base + 1));
      P.Dterm_LPF1_Static_Hz := U16_At (Request, Base + 2);
      P.Dterm_LPF2_Static_Hz := U16_At (Request, Base + 4);
      if P.Dterm_LPF1_Dyn_Min_Hz <= New_Max then
         P.Dterm_LPF1_Dyn_Max_Hz := New_Max;
         P.Dterm_LPF1_Dyn_Min_Hz := New_Min;
      else
         P.Dterm_LPF1_Dyn_Min_Hz := New_Min;
         P.Dterm_LPF1_Dyn_Max_Hz := New_Max;
      end if;
   end Read_Dterm_Filters;

   --  The gyro filter sliders and cutoffs from the request at an offset, the
   --  dynamic range written the same way.
   procedure Read_Gyro_Filters (Request : Byte_Array; Base : Request_Offset; G : in out Gyro_Filters.Settings)
     with Pre => Base <= Request_Offset'Last - Filter_Sliders_Length and then Filter_Sliders_Valid (Request, Base)
   is
      New_Min : constant Hertz := U16_At (Request, Base + 6);
      New_Max : constant Hertz := U16_At (Request, Base + 8);
   begin
      G.Simplified_Filter := Byte_At (Request, Base) = 1;
      G.Simplified_Filter_Multiplier := Natural (Byte_At (Request, Base + 1));
      G.LPF1_Static_Hz := U16_At (Request, Base + 2);
      G.LPF2_Static_Hz := U16_At (Request, Base + 4);
      if G.LPF1_Dyn_Min_Hz <= New_Max then
         G.LPF1_Dyn_Max_Hz := New_Max;
         G.LPF1_Dyn_Min_Hz := New_Min;
      else
         G.LPF1_Dyn_Min_Hz := New_Min;
         G.LPF1_Dyn_Max_Hz := New_Max;
      end if;
   end Read_Gyro_Filters;

   procedure Write_PID_Sliders (B : in out Byte_Array; S : in out Stream; P : Profile)
     with Pre  => Fits (S, B) and then Remaining (S) >= PID_Sliders_Length,
          Post => S.Next = S.Next'Old + PID_Sliders_Length and then S.Last = S.Last'Old
   is
   begin
      Write_U8 (B, S, Simplified_Mode'Pos (P.Simplified_PIDs_Mode));
      Write_U8 (B, S, Byte (P.Simplified_Master_Multiplier));
      Write_U8 (B, S, Byte (P.Simplified_Roll_Pitch_Ratio));
      Write_U8 (B, S, Byte (P.Simplified_I_Gain));
      Write_U8 (B, S, Byte (P.Simplified_D_Gain));
      Write_U8 (B, S, Byte (P.Simplified_PI_Gain));
      Write_U8 (B, S, Byte (P.Simplified_D_Max_Gain));
      Write_U8 (B, S, Byte (P.Simplified_Feedforward_Gain));
      Write_U8 (B, S, Byte (P.Simplified_Pitch_PI_Gain));
      Write_U32 (B, S, 0);
      Write_U32 (B, S, 0);
   end Write_PID_Sliders;

   --  A filter slider's switch and multiplier, the static cutoffs and the
   --  dynamic range.
   procedure Write_Filters
     (B : in out Byte_Array; S : in out Stream; On : Boolean; Multiplier : Natural;
      Static_1, Static_2, Dyn_Min, Dyn_Max : Hertz)
     with Pre  => Multiplier <= 200 and then Fits (S, B) and then Remaining (S) >= Filter_Sliders_Length,
          Post => S.Next = S.Next'Old + Filter_Sliders_Length and then S.Last = S.Last'Old
   is
   begin
      Write_U8 (B, S, Boolean'Pos (On));
      Write_U8 (B, S, Byte (Multiplier));
      Write_U16 (B, S, Unsigned_16 (Static_1));
      Write_U16 (B, S, Unsigned_16 (Static_2));
      Write_U16 (B, S, Unsigned_16 (Dyn_Min));
      Write_U16 (B, S, Unsigned_16 (Dyn_Max));
      Write_U32 (B, S, 0);
      Write_U32 (B, S, 0);
   end Write_Filters;

   procedure Write_Dterm_Filters (B : in out Byte_Array; S : in out Stream; P : Profile)
     with Pre  => Fits (S, B) and then Remaining (S) >= Filter_Sliders_Length,
          Post => S.Next = S.Next'Old + Filter_Sliders_Length and then S.Last = S.Last'Old
   is
   begin
      Write_Filters
        (B, S, P.Simplified_Dterm_Filter, P.Simplified_Dterm_Filter_Multiplier, P.Dterm_LPF1_Static_Hz,
         P.Dterm_LPF2_Static_Hz, P.Dterm_LPF1_Dyn_Min_Hz, P.Dterm_LPF1_Dyn_Max_Hz);
   end Write_Dterm_Filters;

   procedure Write_Gyro_Filters (B : in out Byte_Array; S : in out Stream; G : Gyro_Filters.Settings)
     with Pre  => Fits (S, B) and then Remaining (S) >= Filter_Sliders_Length,
          Post => S.Next = S.Next'Old + Filter_Sliders_Length and then S.Last = S.Last'Old
   is
   begin
      Write_Filters
        (B, S, G.Simplified_Filter, G.Simplified_Filter_Multiplier, G.LPF1_Static_Hz, G.LPF2_Static_Hz,
         G.LPF1_Dyn_Min_Hz, G.LPF1_Dyn_Max_Hz);
   end Write_Gyro_Filters;

   --  Each axis's P, I and D gains and D max, then its feedforward gain.
   procedure Write_Gains (B : in out Byte_Array; S : in out Stream; P : Profile)
     with Pre  => Fits (S, B) and then Remaining (S) >= 18,
          Post => S.Next = S.Next'Old + 18 and then S.Last = S.Last'Old
   is
      procedure Write_Axis (A : Axis)
        with Pre  => Fits (S, B) and then Remaining (S) >= 6,
             Post => S.Next = S.Next'Old + 6 and then S.Last = S.Last'Old
      is
      begin
         Write_U8 (B, S, Byte (P.Gains (A).P));
         Write_U8 (B, S, Byte (P.Gains (A).I));
         Write_U8 (B, S, Byte (P.Gains (A).D));
         Write_U8 (B, S, Byte (P.D_Max (A)));
         Write_U16 (B, S, Unsigned_16 (P.Gains (A).F));
      end Write_Axis;
   begin
      Write_Axis (Roll);
      Write_Axis (Pitch);
      Write_Axis (Yaw);
   end Write_Gains;

   function Same_Gains (X, Y : Profile) return Boolean is
     (for all A in Axis =>
        X.Gains (A).P = Y.Gains (A).P and then X.Gains (A).I = Y.Gains (A).I
        and then X.Gains (A).D = Y.Gains (A).D and then X.D_Max (A) = Y.D_Max (A)
        and then X.Gains (A).F = Y.Gains (A).F);

   -----------
   -- Reply --
   -----------

   procedure Reply
     (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; Request : Byte_Array;
      P : PID_Profile.Profile; G : Gyro_Filters.Settings; Ok : out Boolean)
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
               Result : Profile := P;
            begin
               Read_PID_Sliders (Request, 0, Result);
               Simplified_Tuning.Apply_PIDs (Result);
               Write_Gains (B, S, Result);
            end;
         when Calculate_Gyro_Command =>
            declare
               Result : Gyro_Filters.Settings := G;
            begin
               Read_Gyro_Filters (Request, 0, Result);
               Simplified_Tuning.Apply_Gyro_Filters (Result);
               Write_Gyro_Filters (B, S, Result);
            end;
         when Calculate_Dterm_Command =>
            declare
               Result : Profile := P;
            begin
               Read_Dterm_Filters (Request, 0, Result);
               Simplified_Tuning.Apply_Dterm_Filters (Result);
               Write_Dterm_Filters (B, S, Result);
            end;
         when Validate_Command =>
            declare
               Gains   : Profile := P;
               Filters : Gyro_Filters.Settings := G;
            begin
               Simplified_Tuning.Apply_PIDs (Gains);
               Write_U8 (B, S, Boolean'Pos (Same_Gains (Gains, P)));
               Simplified_Tuning.Apply_Gyro_Filters (Filters);
               Write_U8
                 (B, S,
                  Boolean'Pos
                    (Filters.LPF1_Static_Hz = G.LPF1_Static_Hz and then Filters.LPF2_Static_Hz = G.LPF2_Static_Hz
                     and then Filters.LPF1_Dyn_Min_Hz = G.LPF1_Dyn_Min_Hz
                     and then Filters.LPF1_Dyn_Max_Hz = G.LPF1_Dyn_Max_Hz));
               Simplified_Tuning.Apply_Dterm_Filters (Gains);
               Write_U8
                 (B, S,
                  Boolean'Pos
                    (Gains.Dterm_LPF1_Static_Hz = P.Dterm_LPF1_Static_Hz
                     and then Gains.Dterm_LPF2_Static_Hz = P.Dterm_LPF2_Static_Hz
                     and then Gains.Dterm_LPF1_Dyn_Min_Hz = P.Dterm_LPF1_Dyn_Min_Hz
                     and then Gains.Dterm_LPF1_Dyn_Max_Hz = P.Dterm_LPF1_Dyn_Max_Hz));
            end;
         when others =>
            null;
      end case;
   end Reply;

   ---------
   -- Set --
   ---------

   procedure Set
     (Request : Byte_Array; P : in out PID_Profile.Profile; G : in out Gyro_Filters.Settings; Ok : out Boolean)
   is
   begin
      Ok := Valid (Set_Simplified_Tuning_Command, Request);
      if not Ok then
         return;
      end if;
      Read_PID_Sliders (Request, 0, P);
      Read_Dterm_Filters (Request, PID_Sliders_Length, P);
      Read_Gyro_Filters (Request, PID_Sliders_Length + Filter_Sliders_Length, G);
      Simplified_Tuning.Apply (P, G);
   end Set;

end Adaflight.MSP_Simplified_Tuning;
