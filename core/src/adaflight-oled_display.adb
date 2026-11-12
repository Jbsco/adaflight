with Interfaces;
with Adaflight.OLED_Font;

package body Adaflight.OLED_Display with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   Command_Control : constant Byte := 16#80#;
   Data_Control    : constant Byte := 16#40#;
   Display_Off     : constant Byte := 16#AE#;
   Char_Width      : constant := 6;
   Screen_Bytes    : constant := 1024;

   procedure Send_Command (D : in out I2C_Device; Command : Byte; OK : out Boolean) is
   begin
      Write (D, Command_Control, Command, OK);
   end Send_Command;

   procedure Send_Commands (D : in out I2C_Device; Commands : Byte_Array; OK : out Boolean) is
   begin
      OK := True;
      for C of Commands loop
         Send_Command (D, C, OK);
         exit when not OK;
      end loop;
   end Send_Commands;

   procedure Send_Byte (D : in out I2C_Device; Value : Byte) is
      Unused_OK : Boolean;
   begin
      Write (D, Data_Control, Value, Unused_OK);
   end Send_Byte;

   procedure Clear_Quick (D : in out I2C_Device) is
      Unused_OK : Boolean;
   begin
      Send_Commands (D, (16#B0#, 16#40#, 0, 16#10#), Unused_OK);
      for I in 1 .. Screen_Bytes loop
         Send_Byte (D, 0);
      end loop;
   end Clear_Quick;

   procedure Clear (D : in out I2C_Device) is
      Unused_OK : Boolean;
   begin
      Send_Commands (D, (16#A6#, 16#AE#, 16#20#, 16#00#), Unused_OK);
      Clear_Quick (D);
      Send_Commands (D, (16#81#, 200, 16#AF#), Unused_OK);
   end Clear;

   procedure Set_XY (D : in out I2C_Device; Col : Byte; Row : Byte) is
      Address   : constant Natural := Char_Width * Natural (Col);
      Unused_OK : Boolean;
   begin
      Send_Commands
        (D, (16#B0# + Row, Byte (Address mod 16), 16#10# + Byte (Address / 16 mod 16)), Unused_OK);
   end Set_XY;

   procedure Set_Line (D : in out I2C_Device; Row : Byte) is
   begin
      Set_XY (D, 0, Row);
   end Set_Line;

   procedure Send_Char (D : in out I2C_Device; S : Display; Ascii : Byte) is
      Index : constant Natural :=
        (if Ascii >= OLED_Font.First and then Natural (Ascii) - OLED_Font.First <= OLED_Font.Table'Last
         then Natural (Ascii) - OLED_Font.First else 0);
   begin
      for Column of OLED_Font.Font (Index) loop
         Send_Byte (D, Column xor S.Format);
      end loop;
      Send_Byte (D, S.Format);
   end Send_Char;

   procedure Send_String (D : in out I2C_Device; S : Display; Text : String) is
   begin
      for C of Text loop
         Send_Char (D, S, Character'Pos (C));
      end loop;
   end Send_String;

   procedure Init (D : in out I2C_Device; S : Display; OK : out Boolean) is
      pragma Unreferenced (S);
      Setup : constant Byte_Array :=
        (16#D4#, 16#80#, 16#A8#, 16#3F#, 16#D3#, 16#00#, 16#40#, 16#8D#, 16#14#, 16#A1#, 16#C8#, 16#DA#, 16#12#,
         16#81#, 16#CF#, 16#D9#, 16#F1#, 16#DB#, 16#40#, 16#A4#, 16#A6#, 16#AF#);
      Unused_OK : Boolean;
   begin
      Send_Command (D, Display_Off, OK);
      if not OK then
         return;
      end if;
      Send_Commands (D, Setup, Unused_OK);
      Clear (D);
      OK := True;
   end Init;

end Adaflight.OLED_Display;
