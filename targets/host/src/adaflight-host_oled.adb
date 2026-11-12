with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Wide_Text_IO;
with Adaflight.OLED_Font;
package body Adaflight.Host_OLED is
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Interfaces.Unsigned_8;

   Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_OLED_SCREEN", "");

   subtype Page_Number is Natural range 0 .. 7;
   subtype Column_Number is Natural range 0 .. 127;
   Memory       : array (Page_Number, Column_Number) of Interfaces.Unsigned_8 := (others => (others => 0));
   Page         : Page_Number := 0;
   Column       : Column_Number := 0;
   Skip_Value   : Boolean := False;
   Changed      : Boolean := False;
   First_Change : Ada.Real_Time.Time := Ada.Real_Time.Clock;
   Last_Change  : Ada.Real_Time.Time := Ada.Real_Time.Clock;
   Written      : Ada.Real_Time.Time := Ada.Real_Time.Clock;

   function On return Boolean is (Name'Length > 0);

   procedure Command (Value : Interfaces.Unsigned_8) is
   begin
      if Skip_Value then
         Skip_Value := False;
      elsif Value in 16#20# | 16#81# | 16#8D# | 16#A8# | 16#D3# | 16#D4# | 16#D5# | 16#D9# | 16#DA# | 16#DB# then
         Skip_Value := True;
      elsif Value in 16#B0# .. 16#B7# then
         Page := Natural (Value - 16#B0#);
      elsif Value in 16#00# .. 16#0F# then
         Column := Column / 16 * 16 + Natural (Value);
      elsif Value in 16#10# .. 16#17# then
         Column := Natural (Value - 16#10#) * 16 + Column mod 16;
      end if;
   end Command;

   procedure Data (Value : Interfaces.Unsigned_8) is
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      if Memory (Page, Column) /= Value then
         Memory (Page, Column) := Value;
         if not Changed then
            First_Change := Now;
         end if;
         Changed := True;
         Last_Change := Now;
      end if;
      if Column = Column_Number'Last then
         Column := 0;
         Page := (Page + 1) mod 8;
      else
         Column := Column + 1;
      end if;
   end Data;

   procedure Write (Control : Interfaces.Unsigned_8; Value : Interfaces.Unsigned_8) is
   begin
      if Control = 16#40# then
         Data (Value);
      else
         Command (Value);
      end if;
   end Write;

   --  The character a cell's five columns show, in the normal format or
   --  the inverse one. A level of the vertical bar graph, the font's last
   --  seven glyphs, reads as the block element of that height.
   function Shown (Row : Page_Number; Cell : Natural) return Wide_Character is
      Inverse   : constant Interfaces.Unsigned_8 := 16#7F#;
      Bar_First : constant := Adaflight.OLED_Font.Font'Last - 6;
   begin
      for Flip in Boolean loop
         for G in Adaflight.OLED_Font.Font'Range loop
            if (for all K in 0 .. 4 =>
                  (Memory (Row, 6 * Cell + K) xor (if Flip then Inverse else 0)) = Adaflight.OLED_Font.Font (G) (K))
            then
               return (if G <= 94 then Wide_Character'Val (Adaflight.OLED_Font.First + G)
                       elsif G >= Bar_First then Wide_Character'Val (16#2581# + G - Bar_First)
                       else '#');
            end if;
         end loop;
      end loop;
      return '?';
   end Shown;

   procedure Dump is
      File : Ada.Wide_Text_IO.File_Type;
   begin
      Ada.Wide_Text_IO.Create (File, Ada.Wide_Text_IO.Out_File, Name, Form => "WCEM=8");
      for Row in Page_Number loop
         for Cell in 0 .. 20 loop
            Ada.Wide_Text_IO.Put (File, Shown (Row, Cell));
         end loop;
         Ada.Wide_Text_IO.New_Line (File);
      end loop;
      Ada.Wide_Text_IO.Close (File);
   exception
      when others =>
         null;
   end Dump;

   procedure Poll is
   begin
      if On and then Changed then
         declare
            Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         begin
            if Now - Written >= Ada.Real_Time.Milliseconds (100)
              and then (Now - Last_Change >= Ada.Real_Time.Milliseconds (5)
                        or else Now - First_Change >= Ada.Real_Time.Milliseconds (200))
            then
               Dump;
               Changed := False;
               Written := Now;
            end if;
         end;
      end if;
   end Poll;
end Adaflight.Host_OLED;
