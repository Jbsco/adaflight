with Interfaces;

package body Adaflight.OSD_Custom_Text with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   Carriage_Return : constant := 16#0D#;

   ----------
   -- Init --
   ----------

   procedure Init (T : out State; Port_Configured : Boolean) is
   begin
      T := (others => <>);
      T.Open := Port_Configured;
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (T : in out State; Ends : Terminator; Input : Byte_Array) is
      End_Byte : constant Byte := (if Ends = Null_Byte then 0 else 16#0A#);
   begin
      if not T.Open then
         return;
      end if;
      for K in Input'Range loop
         if Input (K) = End_Byte then
            if T.Position > 0 then
               T.Display_Length := Natural'Min (T.Position, Display_Size - 1);
               for I in 0 .. T.Display_Length - 1 loop
                  T.Display (I) := T.Input (I);
               end loop;
            else
               T.Display_Length := 0;
            end if;
            T.Position := 0;
         elsif Input (K) = Carriage_Return then
            null;
         elsif Input (K) /= 0 and then T.Position < Input_Size - 1 then
            T.Input (T.Position) := Input (K);
            T.Position := T.Position + 1;
         end if;
      end loop;
   end Update;

end Adaflight.OSD_Custom_Text;
