package body Adaflight.Timer_Tables with SPARK_Mode is

   function By_Tag_And_Index (Tag : Unsigned_8; Index : Natural) return Natural is
      Seen : Natural := 0;
   begin
      if Tag = 0 or else Index = 0 then
         return 0;
      end if;
      for K in Channels'Range loop
         pragma Loop_Invariant (Seen < K);
         if Channels (K).Tag = Tag then
            Seen := Seen + 1;
            if Seen = Index then
               return K;
            end if;
         end if;
      end loop;
      return 0;
   end By_Tag_And_Index;

   function Occurrences (Tag : Unsigned_8) return Natural is
      Seen : Natural := 0;
   begin
      for K in Channels'Range loop
         pragma Loop_Invariant (Seen < K);
         if Tag /= 0 and then Channels (K).Tag = Tag then
            Seen := Seen + 1;
         end if;
      end loop;
      return Seen;
   end Occurrences;

   procedure Timer_Option
     (Timer : Timer_Number; Channel : Channel_Number; Option : Integer; Found : out Boolean; Stream : out DMA_Stream)
   is
   begin
      Found := False;
      Stream := (1, 0, 0);
      if Option not in 0 .. Max_Timer_Options - 1 then
         return;
      end if;
      for K in Timer_Streams'Range loop
         if Timer_Streams (K).Timer = Timer and then Timer_Streams (K).Channel = Channel
           and then Option < Timer_Streams (K).Count
         then
            Found := True;
            Stream := Timer_Streams (K).Options (Option + 1);
            return;
         end if;
      end loop;
   end Timer_Option;

   procedure Peripheral_Option
     (Which : Peripheral; Device : Natural; Option : Integer; Found : out Boolean; Stream : out DMA_Stream)
   is
   begin
      Found := False;
      Stream := (1, 0, 0);
      if Option not in 0 .. Max_Peripheral_Options - 1 then
         return;
      end if;
      for K in Peripheral_Streams'Range loop
         if Peripheral_Streams (K).Which = Which and then Peripheral_Streams (K).Device = Device
           and then Option < Peripheral_Streams (K).Count
         then
            Found := True;
            Stream := Peripheral_Streams (K).Options (Option + 1);
            return;
         end if;
      end loop;
   end Peripheral_Option;

   function Has_Timer_Option (Timer : Timer_Number; Channel : Channel_Number; Option : Integer) return Boolean is
   begin
      if Option not in 0 .. Max_Timer_Options - 1 then
         return False;
      end if;
      for K in Timer_Streams'Range loop
         if Timer_Streams (K).Timer = Timer and then Timer_Streams (K).Channel = Channel
           and then Option < Timer_Streams (K).Count
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Timer_Option;

   function Has_Peripheral_Option (Which : Peripheral; Device : Natural; Option : Integer) return Boolean is
   begin
      if Option not in 0 .. Max_Peripheral_Options - 1 then
         return False;
      end if;
      for K in Peripheral_Streams'Range loop
         if Peripheral_Streams (K).Which = Which and then Peripheral_Streams (K).Device = Device
           and then Option < Peripheral_Streams (K).Count
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Peripheral_Option;

end Adaflight.Timer_Tables;
