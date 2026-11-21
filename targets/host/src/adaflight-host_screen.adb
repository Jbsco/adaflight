with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Text_IO;
with GNAT.OS_Lib;
package body Adaflight.Host_Screen is
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Interfaces.Unsigned_8;

   Display : array (Address) of Interfaces.Unsigned_8 := (others => 0);
   Changed : Boolean := False;
   Written : Ada.Real_Time.Time := Ada.Real_Time.Clock;

   procedure Clear is
   begin
      Display := (others => 0);
      Changed := True;
   end Clear;

   procedure Put (At_Address : Address; Code : Interfaces.Unsigned_8) is
   begin
      if Display (At_Address) /= Code then
         Display (At_Address) := Code;
         Changed := True;
      end if;
   end Put;

   procedure Dump is
      File           : Ada.Text_IO.File_Type;
      Name           : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_OSD_SCREEN", "adaflight-osd.txt");
      Unused_Renamed : Boolean;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name & ".part");
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
      GNAT.OS_Lib.Rename_File (Name & ".part", Name, Unused_Renamed);
   exception
      when others =>
         null;
   end Dump;

   procedure Poll (Synced : Boolean) is
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      if Changed and then Synced and then Now - Written >= Ada.Real_Time.Milliseconds (100) then
         Dump;
         Changed := False;
         Written := Now;
      end if;
   end Poll;
end Adaflight.Host_Screen;
