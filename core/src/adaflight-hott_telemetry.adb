package body Adaflight.HoTT_Telemetry with SPARK_Mode is

   Start_Byte        : constant Byte := 16#7C#;
   Stop_Byte         : constant Byte := 16#7D#;
   EAM_Sensor_Id     : constant Byte := 16#8E#;
   EAM_Text_Id       : constant Byte := 16#E0#;
   GPS_Sensor_Id     : constant Byte := 16#8A#;
   GPS_Text_Id       : constant Byte := 16#A0#;
   No_Sensor_Id      : constant Byte := 16#80#;
   Binary_Request_Id : constant Byte := 16#80#;
   Text_Request_Id   : constant Byte := 16#7F#;
   Text_Start        : constant Byte := 16#7B#;
   Text_Stop         : constant Byte := 16#7D#;

   Button_Dec  : constant := 16#B#;
   Button_Inc  : constant := 16#D#;
   Button_Set  : constant := 16#9#;
   Button_Next : constant := 16#E#;
   Button_Prev : constant := 16#7#;

   Preparation_Us        : constant := 200_000;
   Binary_Request_Wait   : constant := 4000;
   Binary_Byte_Delay     : constant := 3000;
   Text_Task_Period_Us   : constant := 1000;
   Text_Request_Wait     : constant := 5000;
   Text_Byte_Delay       : constant := 1000;
   Height_Offset   : constant := 500;
   Climb_Offset    : constant := 30000;
   Climb_3s_Offset : constant := 120;
   Degrees_Divider : constant := 10_000_000;
   Min_Sat_Count   : constant := 4;

   Alarm_Flag_Mah     : constant Byte := 1;
   Alarm_Flag_Battery : constant Byte := 2;

   function Low (V : Integer) return Byte is (Byte (V mod 256));
   function High (V : Integer) return Byte is (Byte ((V / 256) mod 256));

   --  The low two bytes of a value that may be negative, as the
   --  reference's shifts of a signed value give them.
   function Low_Signed (V : Integer) return Byte is (Byte (V mod 256));
   function High_Signed (V : Integer) return Byte is
     (Byte ((V / 256 - (if V < 0 and then V rem 256 /= 0 then 1 else 0)) mod 256));

   --  The voltage into the main and first battery fields, with the alarm
   --  once per interval from the battery states.
   procedure Prepare_EAM (L : in out Link; C : Settings; Inp : Inputs) is
      Amp     : constant Integer := Integer (Inp.Amperage_Ca / 10);
      Mah     : constant Integer := Integer (Inp.Mah_Drawn / 10);
      Height  : constant Integer := Integer (Inp.Altitude_Cm / 100) + Height_Offset;
      Climb   : constant Integer := Climb_Offset + Integer (Inp.Vario_Cms);
      Climb3  : constant Integer := Climb_3s_Offset + Integer (Inp.Vario_Cms / 100);
   begin
      L.EAM (2) := 0;
      L.EAM (4) := 0;
      L.EAM (30) := Byte (Inp.Voltage_Dv and 16#FF#);
      L.EAM (31) := Byte (Interfaces.Shift_Right (Inp.Voltage_Dv, 8));
      L.EAM (20) := L.EAM (30);
      L.EAM (21) := L.EAM (31);
      if Inp.Now_Ms - L.Last_Alarm_Ms >= Unsigned_32 (C.Alarm_Interval_S) * 1000 then
         L.Last_Alarm_Ms := Inp.Now_Ms;
         if Inp.Voltage_State in Warning | Critical then
            L.EAM (2) := 16#10#;
            L.EAM (4) := Alarm_Flag_Battery;
         elsif Inp.Consumption_State in Warning | Critical then
            L.EAM (2) := 16#16#;
            L.EAM (4) := Alarm_Flag_Mah;
         end if;
      end if;
      L.EAM (28) := Low_Signed (Amp);
      L.EAM (29) := High_Signed (Amp);
      L.EAM (32) := Low_Signed (Mah);
      L.EAM (33) := High_Signed (Mah);
      L.EAM (26) := Low_Signed (Height);
      L.EAM (27) := High_Signed (Height);
      L.EAM (34) := Low_Signed (Climb);
      L.EAM (35) := High_Signed (Climb);
      L.EAM (36) := Low_Signed (Climb3);
   end Prepare_EAM;

   --  A coordinate as degrees and minutes, then the hundredths of a
   --  second of arc, each wrapped as the reference stores them.
   procedure Put_Coordinate (M : in out Message; Value : Integer_32; At_Pos : Natural)
     with Pre => At_Pos <= Message_Length - 5
   is
      Deg     : constant Integer_32 := Value / Degrees_Divider;
      Sec     : constant Integer_32 := (Value - Deg * Degrees_Divider) * 6;
      Min     : constant Integer_32 := Sec / 1_000_000;
      Hundred : constant Integer_32 := (Sec rem 1_000_000) / 100;
      Deg_Min : constant Integer := Integer (Deg) * 100 + Integer (Min);
   begin
      M (At_Pos) := (if Value < 0 then 1 else 0);
      M (At_Pos + 1) := Low_Signed (Deg_Min);
      M (At_Pos + 2) := High_Signed (Deg_Min);
      M (At_Pos + 3) := Low_Signed (Integer (Hundred));
      M (At_Pos + 4) := High_Signed (Integer (Hundred));
   end Put_Coordinate;

   --  The satellites and the fix character always, the rest with a fix.
   procedure Prepare_GPS (L : in out Link; Inp : Inputs) is
      Speed    : constant Integer := Integer (Inp.Ground_Speed) * 36 / 1000;
      Height   : constant Integer := Integer (Inp.Altitude_Cm / 100) + Height_Offset;
      Altitude : constant Integer := Integer'Max (0, Integer'Min (65535, Height));
   begin
      L.GPS (26) := Inp.Num_Sat;
      if not Inp.Fix then
         L.GPS (27) := Character'Pos ('-');
         return;
      end if;
      L.GPS (27) := (if Inp.Num_Sat >= Min_Sat_Count then Character'Pos ('3') else Character'Pos ('2'));
      Put_Coordinate (L.GPS, Inp.Lat, 9);
      Put_Coordinate (L.GPS, Inp.Lon, 14);
      L.GPS (7) := Low (Speed);
      L.GPS (8) := High (Speed);
      L.GPS (19) := Byte (Inp.Distance_Home and 16#FF#);
      L.GPS (20) := Byte (Interfaces.Shift_Right (Inp.Distance_Home, 8));
      L.GPS (21) := Low (Altitude);
      L.GPS (22) := High (Altitude);
      L.GPS (28) := Low_Signed (Integer (Inp.Direction_Home / 10));
   end Prepare_GPS;

   --  A request: two bytes waiting, seen twice at least four milliseconds
   --  apart, their count read as a byte (finding F81); more than two bytes
   --  are flushed.
   --  A text mode request: the first one starts the text mode, a request
   --  for the text sensor opens the menu unless the transmitter left it,
   --  takes the button as a menu key and answers with the screen.
   procedure Text_Request (L : in out Link; Inp : Inputs; Address : Byte; O : in out Output) is
      Button : constant Byte := Address and 16#0F#;
   begin
      if not L.Text_Alive then
         L.Saved_Period_Us := Inp.Task_Period_Us;
         O.Reschedule := True;
         O.Period_Us := Text_Task_Period_Us;
         L.Request_Wait_Us := Text_Request_Wait;
         L.Byte_Delay_Us := Text_Byte_Delay;
         L.Text_Alive := True;
      end if;
      if (Address and 16#F0#) /= Text_Sensor_Id then
         return;
      end if;
      if L.Escape_Back then
         L.Text (1) := Text_Sensor_Id;
         L.Escape_Back := False;
      end if;
      if L.Text (1) /= Text_Escape then
         O.Open_Menu := not Inp.In_Menu;
      else
         L.Escape_Back := True;
      end if;
      O.Key_Set := True;
      case Button is
         when Button_Dec =>
            O.Key := Up;
         when Button_Inc =>
            O.Key := Down;
         when Button_Set =>
            O.Exit_Menu := Inp.In_Menu or else O.Open_Menu;
            O.Key := None;
         when Button_Next =>
            O.Key := Right;
         when Button_Prev =>
            O.Key := Left;
            O.Reopen := L.Text (1) = Text_Escape;
         when others =>
            O.Key := None;
      end case;
      L.Pending := Text_Mode_Message;
      L.Position := 0;
      L.Remaining := Text_Length + 1;
   end Text_Request;

   procedure Check_Request
     (L : in out Link; C : Settings; Inp : Inputs; Rx : Byte_Array; Consumed : out Natural; O : in out Output)
     with Post => Consumed <= Rx'Length
   is
      Waiting : constant Natural := Rx'Length mod 256;
   begin
      Consumed := 0;
      if Waiting <= 1 then
         return;
      end if;
      if Waiting /= 2 then
         Consumed := Rx'Length;
         L.Looking := True;
         return;
      end if;
      if L.Looking then
         L.Last_Request_Us := Inp.Now_Us;
         L.Looking := False;
         return;
      end if;
      if Inp.Now_Us - L.Last_Request_Us < L.Request_Wait_Us then
         return;
      end if;
      L.Looking := True;
      Consumed := 2;
      declare
         Request_Id : constant Byte := Rx (Rx'First);
         Address    : constant Byte := Rx (Rx'First + 1);
      begin
         if Request_Id = 0 or else Request_Id = Binary_Request_Id or else Address = No_Sensor_Id then
            if L.Text_Alive then
               if L.Saved_Period_Us > 0 then
                  O.Reschedule := True;
                  O.Period_Us := L.Saved_Period_Us;
                  L.Saved_Period_Us := 0;
               end if;
               L.Request_Wait_Us := Binary_Request_Wait;
               L.Byte_Delay_Us := Binary_Byte_Delay;
               L.Text_Alive := False;
            end if;
            if Address = GPS_Sensor_Id then
               if C.GPS_Present then
                  L.Pending := GPS_Message;
                  L.Position := 0;
                  L.Remaining := Message_Length + 1;
               end if;
            elsif Address = EAM_Sensor_Id then
               L.Pending := EAM_Message;
               L.Position := 0;
               L.Remaining := Message_Length + 1;
            end if;
         elsif Request_Id = Text_Request_Id then
            Text_Request (L, Inp, Address, O);
         end if;
      end;
   end Check_Request;

   --  One step of the answer: the line turned to send, then a byte per
   --  call with the checksum after the last, then the line turned back
   --  and the bytes waiting flushed. The sum steps once more after it is
   --  sent, as the reference's post-increment leaves it.
   procedure Send_Step (L : in out Link; Rx : Byte_Array; O : in out Output) is
      B : Byte;
   begin
      if not L.Sending then
         L.Sending := True;
         L.Crc := 0;
         return;
      end if;
      if L.Remaining = 0 then
         L.Pending := No_Message;
         L.Sending := False;
         O.Consumed := Rx'Length;
         return;
      end if;
      L.Remaining := L.Remaining - 1;
      if L.Remaining = 0 then
         O.Sent := True;
         O.B := L.Crc;
         L.Crc := L.Crc + 1;
         return;
      end if;
      if L.Pending = Text_Mode_Message and then L.Position < Text_Length then
         B := L.Text (L.Position);
         L.Position := L.Position + 1;
      elsif L.Pending /= Text_Mode_Message and then L.Position < Message_Length then
         B := (if L.Pending = GPS_Message then L.GPS (L.Position) else L.EAM (L.Position));
         L.Position := L.Position + 1;
      else
         B := 0;
      end if;
      L.Crc := L.Crc + B;
      O.Sent := True;
      O.B := B;
   end Send_Step;

   ----------
   -- Init --
   ----------

   procedure Init (L : out Link) is
   begin
      L := (others => <>);
      L.EAM (0) := Start_Byte;
      L.EAM (1) := EAM_Sensor_Id;
      L.EAM (3) := EAM_Text_Id;
      L.EAM (Message_Length - 1) := Stop_Byte;
      L.GPS (0) := Start_Byte;
      L.GPS (1) := GPS_Sensor_Id;
      L.GPS (3) := GPS_Text_Id;
      L.GPS (Message_Length - 1) := Stop_Byte;
      L.Text (0) := Text_Start;
      L.Text (1) := Text_Sensor_Id;
      L.Text (Text_Length - 1) := Text_Stop;
   end Init;

   procedure Text_Write (L : in out Link; Col, Row : Byte; C : Byte) is
   begin
      if Natural (Col) < Text_Cols and then Natural (Row) < Text_Rows then
         L.Text (3 + Natural (Row) * Text_Cols + Natural (Col)) := C;
      end if;
   end Text_Write;

   procedure Text_Grab (L : in out Link) is
   begin
      L.Text (1) := Text_Sensor_Id;
   end Text_Grab;

   procedure Text_Exit (L : in out Link) is
   begin
      L.Text (1) := Text_Escape;
   end Text_Exit;

   ------------
   -- Update --
   ------------

   procedure Update (L : in out Link; C : Settings; Inp : Inputs; Rx : Byte_Array; O : out Output) is
      Consumed : Natural;
   begin
      O := (others => <>);
      if Inp.Now_Us - L.Last_Prepared_Us >= Preparation_Us then
         Prepare_EAM (L, C, Inp);
         Prepare_GPS (L, Inp);
         L.Last_Prepared_Us := Inp.Now_Us;
      end if;
      if not L.Sending then
         Check_Request (L, C, Inp, Rx, Consumed, O);
         O.Consumed := Consumed;
      end if;
      if L.Pending = No_Message then
         return;
      end if;
      if L.Sending and then Inp.Now_Us - L.Serial_Timer_Us < L.Byte_Delay_Us then
         return;
      end if;
      Send_Step (L, Rx, O);
      L.Serial_Timer_Us := Inp.Now_Us;
   end Update;

end Adaflight.HoTT_Telemetry;
