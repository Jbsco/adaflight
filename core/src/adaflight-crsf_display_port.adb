package body Adaflight.CRSF_Display_Port with SPARK_Mode is

   procedure Clear (S : in out Screen; Now_Ms : Interfaces.Unsigned_32) is
   begin
      S.Buffer := (others => Character'Pos (' '));
      S.Updated := False;
      S.Reset := True;
      S.Delay_Until_Ms := Now_Ms + Clear_Delay_Ms;
   end Clear;

   procedure Init (S : in out Screen; Now_Ms : Interfaces.Unsigned_32) is
   begin
      Set_Dimensions (S, Rows_Max, Cols_Max);
      S.Grabbed := False;
      Clear (S, Now_Ms);
   end Init;

   procedure Grab (S : in out Screen) is
   begin
      S.Grabbed := True;
   end Grab;

   procedure Release (S : in out Screen; Now_Ms : Interfaces.Unsigned_32) is
   begin
      S.Grabbed := False;
      Clear (S, Now_Ms);
   end Release;

   procedure Set_Dimensions (S : in out Screen; Rows, Cols : Byte) is
   begin
      S.Rows := Natural'Min (Natural (Rows), Rows_Max);
      S.Cols := Natural'Min (Natural (Cols), Cols_Max);
   end Set_Dimensions;

   procedure Write_String (S : in out Screen; Col, Row : Byte; Text : String) is
   begin
      if Natural (Row) >= S.Rows or else Natural (Col) >= S.Cols then
         return;
      end if;
      declare
         Length : constant Natural := Natural'Min (Text'Length, S.Cols - Natural (Col));
         Start  : constant Natural := Natural (Row) * S.Cols + Natural (Col);
      begin
         for K in 0 .. Length - 1 loop
            if S.Buffer (Start + K) /= Character'Pos (Text (Text'First + K)) then
               S.Updated := True;
            end if;
         end loop;
         if S.Updated then
            for K in 0 .. Length - 1 loop
               S.Buffer (Start + K) := Character'Pos (Text (Text'First + K));
            end loop;
         end if;
      end;
   end Write_String;

   procedure Write_Char (S : in out Screen; Col, Row : Byte; C : Byte) is
   begin
      if C /= 0 then
         Write_String (S, Col, Row, (1 => Character'Val (C)));
      end if;
   end Write_Char;

   procedure Opened (S : in out Screen; Now_Ms : Interfaces.Unsigned_32) is
   begin
      S.Delay_Until_Ms := Now_Ms + Open_Delay_Ms;
   end Opened;

   procedure Command (S : in out Screen; Payload : Byte_Array; Now_Ms : Interfaces.Unsigned_32;
                      Armed, In_Menu, Registered : Boolean; Request : out Menu_Request)
   is
      F : constant Natural := Payload'First;
   begin
      Request := None;
      case Payload (F) is
         when Command_Open =>
            Set_Dimensions (S, Payload (F + 1), Payload (F + 2));
            if Can_Open (Armed, In_Menu, Registered) then
               Request := Open;
            end if;
         when Command_Close =>
            if In_Menu then
               Request := Leave;
            end if;
         when Command_Poll =>
            if not In_Menu then
               if Can_Open (Armed, In_Menu, Registered) then
                  Request := Open;
               end if;
            else
               S.Updated := True;
               S.Reset := True;
               S.Delay_Until_Ms := Now_Ms + Clear_Delay_Ms;
            end if;
         when others =>
            null;
      end case;
   end Command;

end Adaflight.CRSF_Display_Port;
