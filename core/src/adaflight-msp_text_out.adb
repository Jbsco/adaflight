package body Adaflight.MSP_Text_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Unsigned_8;

   --  The request's first byte, or the default without one.
   function First_Byte (Request : Byte_Array; Default : Unsigned_8) return Unsigned_8 is
     (if Request'Length > 0 then Request (Request'First) else Default);

   procedure Band_Row (B : in out Byte_Array; S : in out Stream; Band : Positive; T : VTX_Table)
     with Pre  => Band <= Band_Count and then Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 5 + Band_Name_Length + 2 * T.Channels and then S.Last = S.Last'Old
   is
      Start : constant Position := S.Next with Ghost;
   begin
      Write_U8 (B, S, Unsigned_8 (Band));
      Write_U8 (B, S, Band_Name_Length);
      Write_Data (B, S, T.Names (Band));
      Write_U8 (B, S, T.Letters (Band));
      Write_U8 (B, S, T.Factory (Band));
      Write_U8 (B, S, Unsigned_8 (T.Channels));
      for I in 1 .. T.Channels loop
         Write_U16 (B, S, T.Frequencies (Band) (I));
         pragma Loop_Invariant
           (S.Next = Start + 5 + Band_Name_Length + 2 * I and then S.Last = S.Last'Loop_Entry);
      end loop;
   end Band_Row;

   -----------
   -- Reply --
   -----------

   procedure Reply
     (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; Request : Byte_Array; V : Snapshot;
      Ok : out Boolean)
   is
   begin
      Ok := True;
      if not Handles (Command, V) then
         return;
      end if;
      case Command is
         when Name_Command =>
            Write_String (B, S, V.Craft_Name.Data (1 .. V.Craft_Name.Length));
         when Get_Text_Command =>
            declare
               Kind  : constant Unsigned_8 := First_Byte (Request, 0);
               Value : Text;
            begin
               case Kind is
                  when Pilot_Name_Text =>
                     Value := V.Pilot_Name;
                  when Craft_Name_Text =>
                     Value := V.Craft_Name;
                  when PID_Profile_Name_Text =>
                     Value := V.PID_Profile_Name;
                  when Rate_Profile_Name_Text =>
                     Value := V.Rate_Profile_Name;
                  when Build_Key_Text =>
                     Ok := V.Build_Key.Present;
                     Value := V.Build_Key.Value;
                  when Release_Name_Text =>
                     Ok := V.Release_Name.Present;
                     Value := V.Release_Name.Value;
                  when Battery_Profile_Name_Text =>
                     Value := V.Batteries (V.Active_Battery).Name;
                  when others =>
                     Ok := False;
               end case;
               if Ok then
                  Write_U8 (B, S, Kind);
                  Write_Prefixed_String (B, S, Value.Data (1 .. Value.Length));
               end if;
            end;
         when VTX_Table_Band_Command =>
            declare
               Band : constant Unsigned_8 := First_Byte (Request, 0);
            begin
               if Band in 1 .. Band_Count then
                  Band_Row (B, S, Positive (Band), V.Table);
               else
                  Ok := False;
               end if;
            end;
         when VTX_Table_Power_Command =>
            declare
               Level : constant Unsigned_8 := First_Byte (Request, 0);
            begin
               if Level in 1 .. Power_Count then
                  Write_U8 (B, S, Level);
                  Write_U16 (B, S, V.Table.Powers (Positive (Level)));
                  Write_U8 (B, S, Power_Label_Length);
                  Write_Data (B, S, V.Table.Labels (Positive (Level)));
               else
                  Ok := False;
               end if;
            end;
         when LED_Strip_Values_Command =>
            Write_U8 (B, S, V.Brightness);
            Write_U16 (B, S, V.Rainbow_Delta);
            Write_U16 (B, S, V.Rainbow_Freq);
         when Battery_Profile_Command =>
            declare
               Index : constant Unsigned_8 := First_Byte (Request, Unsigned_8 (V.Active_Battery));
            begin
               if Index < Profile_Count then
                  declare
                     P : Battery_Profile renames V.Batteries (Natural (Index));
                  begin
                     Write_U8 (B, S, Index);
                     Write_U16 (B, S, P.Min_Cell);
                     Write_U16 (B, S, P.Max_Cell);
                     Write_U16 (B, S, P.Warning_Cell);
                     Write_U16 (B, S, P.Full_Cell);
                     Write_U16 (B, S, P.Capacity);
                     Write_U8 (B, S, P.Force_Cell_Count);
                     Write_U8 (B, S, P.Consumption_Warning);
                  end;
               else
                  Ok := False;
               end if;
            end;
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Text_Out;
