package body Adaflight.MSP_VTX_Status_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  What the device reports, each value zero where it is not known.
   type Report is record
      Type_Code      : Unsigned_8 := 0;
      Ready          : Boolean := False;
      Band_Known     : Boolean := False;
      Band, Channel  : Unsigned_8 := 0;
      Power_Known    : Boolean := False;
      Power_Index    : Unsigned_8 := 0;
      Freq_Known     : Boolean := False;
      Freq           : Unsigned_16 := 0;
      Status_Known   : Boolean := False;
      Status         : Unsigned_32 := 0;
      Level_Count    : Natural range 0 .. Max_Levels := 0;
      Levels, Powers : Adaflight.VTX_MSP.Level_Values := (others => 0);
   end record;

   function Device_Report (V : Snapshot) return Report
     with Pre => V.Kind /= No_Device
   is
      R : Report;
   begin
      case V.Kind is
         when SmartAudio_Device =>
            declare
               package SA renames Adaflight.SmartAudio;
               Pit    : Boolean;
               Count  : SA.Level_Count;
               L, P   : SA.Level_Values;
            begin
               R.Type_Code := SmartAudio_Type;
               R.Ready := SA.Ready (V.SA);
               SA.Get_Band_Channel (V.SA, V.Table, R.Band, R.Channel, R.Band_Known);
               SA.Get_Power_Index (V.SA, R.Power_Index, R.Power_Known);
               SA.Get_Frequency (V.SA, V.Table, R.Freq, R.Freq_Known);
               SA.Get_Status (V.SA, Pit, R.Status_Known);
               R.Status := (if R.Status_Known and then Pit then Pit_Mode_Status else 0);
               SA.Get_Power_Levels (V.SA, Count, L, P);
               R.Level_Count := Count;
               for I in 1 .. Count loop
                  R.Levels (I) := L (I - 1);
                  R.Powers (I) := P (I - 1);
               end loop;
            end;
         when Tramp_Device =>
            declare
               package TR renames Adaflight.Tramp;
               Pit, Locked : Boolean;
            begin
               R.Type_Code := Tramp_Type;
               R.Ready := TR.Ready (V.TR);
               TR.Get_Band_Channel (V.TR, R.Band, R.Channel, R.Band_Known);
               TR.Get_Power_Index (V.TR, V.Table, R.Power_Index, R.Power_Known);
               TR.Get_Frequency (V.TR, R.Freq, R.Freq_Known);
               TR.Get_Status (V.TR, Pit, Locked, R.Status_Known);
               if R.Status_Known then
                  R.Status := (if Pit then Pit_Mode_Status else 0) + (if Locked then Locked_Status else 0);
               end if;
            end;
         when MSP_Device =>
            declare
               package MD renames Adaflight.VTX_MSP;
               Pit   : Boolean;
               Count : Adaflight.VTX_Table.Power_Count;
            begin
               R.Type_Code := MSP_Type;
               R.Ready := MD.Is_Ready (V.MD);
               MD.Get_Band_Channel (V.MD, R.Band, R.Channel, R.Band_Known);
               MD.Get_Power_Index (V.MD, V.Table, R.Power_Index, R.Power_Known);
               MD.Get_Frequency (V.MD, V.Table, R.Freq, R.Freq_Known);
               MD.Get_Status (V.MD, Pit, R.Status_Known);
               R.Status := (if R.Status_Known and then Pit then Pit_Mode_Status else 0);
               MD.Get_Power_Levels (V.MD, V.Table, Count, R.Levels, R.Powers);
               R.Level_Count := Count;
            end;
         when No_Device =>
            null;
      end case;
      if not R.Band_Known then
         R.Band := 0;
         R.Channel := 0;
      end if;
      if not R.Power_Known then
         R.Power_Index := 0;
      end if;
      if not R.Freq_Known then
         R.Freq := 0;
      end if;
      return R;
   end Device_Report;

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
   begin
      if not Handles (Command, V) or else V.Kind = No_Device then
         return;
      end if;
      declare
         R     : constant Report := Device_Report (V);
         Start : constant Position := S.Next with Ghost;
      begin
         Write_U8 (B, S, R.Type_Code);
         Write_U8 (B, S, Boolean'Pos (R.Ready));
         Write_U8 (B, S, Boolean'Pos (R.Band_Known));
         Write_U8 (B, S, R.Band);
         Write_U8 (B, S, R.Channel);
         Write_U8 (B, S, Boolean'Pos (R.Power_Known));
         Write_U8 (B, S, R.Power_Index);
         Write_U8 (B, S, Boolean'Pos (R.Freq_Known));
         Write_U16 (B, S, R.Freq);
         Write_U8 (B, S, Boolean'Pos (R.Status_Known));
         Write_U32 (B, S, R.Status);
         Write_U8 (B, S, Unsigned_8 (R.Level_Count));
         for I in 1 .. R.Level_Count loop
            pragma Loop_Invariant (S.Next = Start + 16 + 4 * (I - 1) and then S.Last = S.Last'Loop_Entry);
            Write_U16 (B, S, R.Levels (I));
            Write_U16 (B, S, R.Powers (I));
         end loop;
         if V.Kind = SmartAudio_Device then
            Write_Data (B, S, Adaflight.SmartAudio.Custom_Status (V.SA));
         else
            Write_U8 (B, S, 0);
         end if;
      end;
   end Reply;

end Adaflight.MSP_VTX_Status_Out;
