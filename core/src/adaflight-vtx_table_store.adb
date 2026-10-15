with Interfaces;

package body Adaflight.VTX_Table_Store with SPARK_Mode is

   Band_Name_Length   : constant := 8;
   Power_Label_Length : constant := 3;

   --  A text into stored bytes up to a length, padded with spaces, then a
   --  zero.
   procedure Put_Padded (Dst : out Bytes; Text : String; Length : Natural)
     with Pre => Dst'First = 0 and then Dst'Last = Length and then Text'Length <= Length
   is
   begin
      Dst := (others => 0);
      for K in 0 .. Length - 1 loop
         Dst (K) := (if K < Text'Length then Character'Pos (Text (Text'First + K)) else Character'Pos (' '));
      end loop;
   end Put_Padded;

   procedure Clear_Channels (T : in out Vtx_Table_Config_Record; B : Band; From : Count) is
   begin
      for C in From .. Table_Size - 1 loop
         T.Frequency (B) (C) := 0;
      end loop;
   end Clear_Channels;

   procedure Clear_Band (T : in out Vtx_Table_Config_Record; B : Band) is
   begin
      Clear_Channels (T, B, 0);
      for C in 0 .. Table_Size - 1 loop
         T.Channel_Names (C) := (Interfaces.Unsigned_8 (Character'Pos ('1') + C), 0);
      end loop;
      Put_Padded (T.Band_Names (B), "BAND" & Character'Val (Character'Pos ('1') + B), Band_Name_Length);
      T.Band_Letters (B) := Interfaces.Unsigned_8 (Character'Pos ('1') + B);
      T.Is_Factory_Band (B) := False;
   end Clear_Band;

   procedure Clear_Power_Values (T : in out Vtx_Table_Config_Record; From : Count) is
   begin
      for L in From .. Table_Size - 1 loop
         T.Power_Values (L) := 0;
      end loop;
   end Clear_Power_Values;

   procedure Clear_Power_Labels (T : in out Vtx_Table_Config_Record; From : Count) is
   begin
      for L in From .. Table_Size - 1 loop
         Put_Padded (T.Power_Labels (L), "LV" & Character'Val (Character'Pos ('0') + L), Power_Label_Length);
      end loop;
   end Clear_Power_Labels;

   function Running (T : Vtx_Table_Config_Record) return VTX_Table.Table is
      R : VTX_Table.Table;
   begin
      R.Bands := Natural (T.Bands);
      R.Channels := Natural (T.Channels);
      for B in VTX_Table.Band_Index loop
         for C in VTX_Table.Channel_Index loop
            R.Frequency (B, C) := T.Frequency (B - 1) (C - 1);
         end loop;
         for K in 1 .. Band_Name_Length loop
            R.Names (B) (K) := Character'Val (T.Band_Names (B - 1) (K - 1));
         end loop;
         R.Letters (B) := Character'Val (T.Band_Letters (B - 1));
         R.Is_Factory (B) := T.Is_Factory_Band (B - 1);
      end loop;
      for C in VTX_Table.Channel_Index loop
         R.Channel_Name (C) := Character'Val (T.Channel_Names (C - 1) (0));
      end loop;
      R.Power_Levels := Natural (T.Power_Levels);
      for L in VTX_Table.Power_Index loop
         R.Power_Value (L) := T.Power_Values (L - 1);
         for K in 1 .. Power_Label_Length loop
            R.Label (L) (K) := Character'Val (T.Power_Labels (L - 1) (K - 1));
         end loop;
      end loop;
      return R;
   end Running;

end Adaflight.VTX_Table_Store;
