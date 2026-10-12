package body Adaflight.VTX_Table with SPARK_Mode is

   Digits_1 : constant String := "0123456789";

   function Digit (N : Natural) return Character is (Digits_1 (N + 1))
     with Pre => N <= 9;

   --------------------
   -- Clear_Channels --
   --------------------

   procedure Clear_Channels (T : in out Table; Band : Band_Index; From : Channel_Count) is
   begin
      for Channel in Channel_Index loop
         if Channel > From then
            T.Frequency (Band, Channel) := 0;
         end if;
      end loop;
   end Clear_Channels;

   ----------------
   -- Clear_Band --
   ----------------

   procedure Clear_Band (T : in out Table; Band : Band_Index) is
   begin
      Clear_Channels (T, Band, 0);
      for Channel in Channel_Index loop
         T.Channel_Name (Channel) := Digit (Channel);
      end loop;
      T.Names (Band) := "BAND" & Digit (Band) & "   ";
      T.Letters (Band) := Digit (Band);
      T.Is_Factory (Band) := False;
   end Clear_Band;

   ------------------------
   -- Clear_Power_Values --
   ------------------------

   procedure Clear_Power_Values (T : in out Table; From : Power_Count) is
   begin
      for Level in Power_Index loop
         if Level > From then
            T.Power_Value (Level) := 0;
         end if;
      end loop;
   end Clear_Power_Values;

   ------------------------
   -- Clear_Power_Labels --
   ------------------------

   procedure Clear_Power_Labels (T : in out Table; From : Power_Count) is
   begin
      for Level in Power_Index loop
         if Level > From then
            T.Label (Level) := "LV" & Digit (Level - 1);
         end if;
      end loop;
   end Clear_Power_Labels;

   -------------
   -- Default --
   -------------

   function Default return Table is
      T : Table;
   begin
      for Band in Band_Index loop
         Clear_Band (T, Band);
      end loop;
      Clear_Power_Values (T, 0);
      Clear_Power_Labels (T, 0);
      return T;
   end Default;

   ---------------------
   -- Band_Channel_Of --
   ---------------------

   procedure Band_Channel_Of (T : Table; Freq : Unsigned_16; Band : out Band_Count; Channel : out Channel_Count) is
   begin
      Band := 0;
      Channel := 0;
      for B in reverse 1 .. T.Bands loop
         for C in 1 .. T.Channels loop
            if T.Frequency (B, C) = Freq then
               Band := B;
               Channel := C;
               return;
            end if;
         end loop;
      end loop;
   end Band_Channel_Of;

end Adaflight.VTX_Table;
