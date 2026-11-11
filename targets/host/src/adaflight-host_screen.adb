with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Text_IO;
package body Adaflight.Host_Screen is
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Interfaces.Unsigned_8;

   Display      : array (Address) of Interfaces.Unsigned_8 := (others => 0);
   Changed      : Boolean := False;
   First_Change : Ada.Real_Time.Time := Ada.Real_Time.Clock;
   Last_Change  : Ada.Real_Time.Time := Ada.Real_Time.Clock;
   Written      : Ada.Real_Time.Time := Ada.Real_Time.Clock;

   procedure Note_Change is
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      if not Changed then
         First_Change := Now;
      end if;
      Changed := True;
      Last_Change := Now;
   end Note_Change;

   procedure Clear is
   begin
      Display := (others => 0);
      Note_Change;
   end Clear;

   procedure Put (At_Address : Address; Code : Interfaces.Unsigned_8) is
   begin
      if Display (At_Address) /= Code then
         Display (At_Address) := Code;
         Note_Change;
      end if;
   end Put;

   procedure Dump is
      File : Ada.Text_IO.File_Type;
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_OSD_SCREEN", "adaflight-osd.txt");
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
      for Row in 0 .. 15 loop
         for Col in 0 .. 29 loop
            declare
               Code : constant Interfaces.Unsigned_8 := Display (Row * 30 + Col);
            begin
               Ada.Text_IO.Put (File, (if Code in 16#20# .. 16#7E# then Character'Val (Code) else '.'));
            end;
         end loop;
         Ada.Text_IO.New_Line (File);
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others =>
         null;
   end Dump;

   procedure Poll is
   begin
      if Changed then
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
end Adaflight.Host_Screen;
