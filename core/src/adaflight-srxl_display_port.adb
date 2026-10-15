package body Adaflight.SRXL_Display_Port with SPARK_Mode is

   procedure Write_Char (S : in out Stream; Col, Row : Byte; C : Byte) is
   begin
      SRXL_Telemetry.Put_Char (S, Natural (Col), Natural (Row), C);
   end Write_Char;

   procedure Write_String (S : in out Stream; Col, Row : Byte; Text : String) is
      At_Col : Byte := Col;
   begin
      for K in Text'Range loop
         Write_Char (S, At_Col, Row, Character'Pos (Text (K)));
         At_Col := At_Col + 1;
      end loop;
   end Write_String;

   procedure Clear (D : Display; S : in out Stream; Title : String) is
   begin
      for Row in 0 .. SRXL_Telemetry.Rows - 1 loop
         for Col in 0 .. SRXL_Telemetry.Input_Columns - 1 loop
            Write_Char (S, Byte (Col), Byte (Row), Character'Pos (' '));
         end loop;
      end loop;
      Write_String (S, 1, 0, Title);
      if not D.Grabbed then
         Write_String (S, 0, 2, Help_Line_1);
         Write_String (S, 2, 3, Help_Line_2);
         Write_String (S, 2, 4, Help_Line_3);
      end if;
   end Clear;

   procedure Grab (D : out Display) is
   begin
      D.Grabbed := True;
   end Grab;

   procedure Release (D : out Display; S : in out Stream; Title : String) is
   begin
      D.Grabbed := False;
      Clear (D, S, Title);
   end Release;

   procedure Register (D : out Display; S : in out Stream; Title : String) is
   begin
      D.Grabbed := False;
      Clear (D, S, Title);
   end Register;

end Adaflight.SRXL_Display_Port;
