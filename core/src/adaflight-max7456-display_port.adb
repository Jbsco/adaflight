package body Adaflight.MAX7456.Display_Port with SPARK_Mode is

   use type Interfaces.Unsigned_16;

   --  A dimension with a signed adjustment, wrapping as the byte it lands in.
   function Adjusted (Base : Byte; Adjust : Interfaces.Integer_8) return Byte is
     (Base + (if Adjust >= 0 then Byte (Adjust) else Byte (256 + Integer (Adjust))))
     with Global => null;

   procedure Clear_Device (D : in out SPI_Device; S : in out State; Display : Display_Profile) is
   begin
      Invert (D, S, Display.Invert);
      Brightness (D, S, Display.Black_Brightness, Display.White_Brightness);
      Clear_Screen (S);
   end Clear_Device;

   procedure Clear_Screen (D : in out SPI_Device; S : in out State; P : in out Port; Display : Display_Profile) is
   begin
      Clear_Device (D, S, Display);
      P.Cleared := True;
      P.Cursor_Row := -1;
   end Clear_Screen;

   --  The port's rows from the video system, NTSC, PAL for PAL, HD and any
   --  other system, or the chip's count for an automatic one, and 30
   --  columns, each with the profile's adjustment.
   procedure Set_Dimensions (S : State; Video : Video_Profile; Display : Display_Profile; P : in out Port)
     with Global => null
   is
      Lines : Byte;
   begin
      if Video.Video_System = 2 then
         Lines := Lines_NTSC;
      elsif Video.Video_System = 0 then
         Lines := Rows_Count (S);
      else
         Lines := Lines_PAL;
      end if;
      P.Rows := Adjusted (Lines, Display.Row_Adjust);
      P.Cols := Adjusted (Chars_Per_Line, Display.Col_Adjust);
   end Set_Dimensions;

   procedure Init
     (D             : in out SPI_Device;
      S             : in out State;
      P             : out Port;
      C             : Config;
      Video         : Video_Profile;
      Display       : Display_Profile;
      CPU_Overclock : Boolean;
      Available     : out Boolean;
      Ready         : out Boolean)
   is
      Status : Init_Status;
   begin
      P := (others => <>);
      Init (D, S, C, Video, CPU_Overclock, Status);
      if Status = Init_Not_Configured then
         Available := False;
         Ready := False;
         return;
      end if;
      P.Grab_Count := 0;
      Clear_Screen (D, S, P, Display);
      Available := True;
      if Status = Init_Not_Found then
         Ready := False;
         return;
      end if;
      Set_Dimensions (S, Video, Display, P);
      Ready := True;
   end Init;

   procedure Grab (D : in out SPI_Device; S : in out State; P : in out Port; Display : Display_Profile) is
   begin
      Clear_Device (D, S, Display);
      P.Grab_Count := P.Grab_Count + 1;
   end Grab;

   procedure Release (P : in out Port) is
   begin
      P.Grab_Count := P.Grab_Count - 1;
   end Release;

   procedure Release_All (P : in out Port) is
   begin
      P.Grab_Count := 0;
   end Release_All;

   procedure Write_String (S : in out State; X : Byte; Y : Byte; Text : Byte_Array) is
   begin
      if Text'Length > 0 and then Text (Text'First) /= 0 then
         Write (S, X, Y, Text);
      end if;
   end Write_String;

   procedure Heartbeat (D : in out SPI_Device; S : in out State; Stalled : out Boolean) is
   begin
      Re_Init_If_Required (D, S, False, Stalled);
   end Heartbeat;

   procedure Redraw (D : in out SPI_Device; S : in out State; Armed : Boolean) is
   begin
      if not Armed then
         Refresh_All (D, S);
      end if;
   end Redraw;

   procedure Port_Layer_Copy (S : in out State; Destination : Natural; Source : Natural; Copied : out Boolean) is
   begin
      if Source /= Destination then
         Layer_Copy (S, Destination, Source, Copied);
      else
         Copied := False;
      end if;
   end Port_Layer_Copy;

   procedure Write_Font_Character
     (D       : in out SPI_Device;
      S       : State;
      Address : Interfaces.Unsigned_16;
      Data    : Character_Data;
      Written : out Boolean)
   is
   begin
      Write_NVM (D, S, Byte (Address mod 256), Data (0 .. 53), Written);
   end Write_Font_Character;

   procedure Check_Ready
     (D             : in out SPI_Device;
      S             : in out State;
      P             : in out Port;
      C             : Config;
      Video         : Video_Profile;
      Display       : Display_Profile;
      CPU_Overclock : Boolean;
      Armed         : Boolean;
      Rescan        : Boolean;
      Ready         : out Boolean)
   is
      Status : Init_Status;
   begin
      if not S.Detected then
         if not Rescan then
            Ready := False;
            return;
         end if;
         Init (D, S, C, Video, CPU_Overclock, Status);
         if Status /= Init_OK then
            Ready := False;
            return;
         end if;
         Set_Dimensions (S, Video, Display, P);
         Redraw (D, S, Armed);
      end if;
      Ready := True;
   end Check_Ready;

end Adaflight.MAX7456.Display_Port;
