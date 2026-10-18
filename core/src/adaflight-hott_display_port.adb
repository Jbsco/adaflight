package body Adaflight.HoTT_Display_Port with SPARK_Mode is

   procedure Write_Char (L : in out Link; Col, Row : Byte; C : Byte) is
   begin
      HoTT_Telemetry.Text_Write (L, Col, Row, C);
   end Write_Char;

   procedure Write_String (L : in out Link; Col, Row : Byte; Text : String) is
      At_Col : Byte := Col;
   begin
      for K in Text'Range loop
         Write_Char (L, At_Col, Row, Character'Pos (Text (K)));
         At_Col := At_Col + 1;
      end loop;
   end Write_String;

   procedure Clear (D : Display; L : in out Link) is
   begin
      for Row in 0 .. D.Rows - 1 loop
         for Col in 0 .. D.Cols - 1 loop
            Write_Char (L, Byte (Col), Byte (Row), Character'Pos (' '));
         end loop;
      end loop;
   end Clear;

   procedure Grab (D : in out Display; L : in out Link) is
   begin
      HoTT_Telemetry.Text_Grab (L);
      D.Grabbed := True;
   end Grab;

   procedure Release (D : in out Display; L : in out Link) is
   begin
      D.Grabbed := False;
      Clear (D, L);
      HoTT_Telemetry.Text_Exit (L);
   end Release;

   procedure Register (D : in out Display; L : in out Link) is
   begin
      D.Grabbed := False;
      Clear (D, L);
      D.Rows := HoTT_Telemetry.Text_Rows;
      D.Cols := HoTT_Telemetry.Text_Cols;
   end Register;

end Adaflight.HoTT_Display_Port;
