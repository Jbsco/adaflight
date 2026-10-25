package body Adaflight.RunCam_Device with SPARK_Mode is

   Polynomial     : constant Byte := 16#D5#;
   Request_Reset  : constant := 200;
   Key_Timeout_Ms : constant := 400;
   Key_Retries    : constant := 2;

   Op_Wifi        : constant Unsigned_8 := 0;
   Op_Power       : constant Unsigned_8 := 1;
   Op_Change_Mode : constant Unsigned_8 := 2;
   Op_Unknown     : constant Unsigned_8 := 16#FF#;

   Key_None  : constant Unsigned_8 := 0;
   Key_Set   : constant Unsigned_8 := 1;
   Key_Left  : constant Unsigned_8 := 2;
   Key_Right : constant Unsigned_8 := 3;
   Key_Up    : constant Unsigned_8 := 4;
   Key_Down  : constant Unsigned_8 := 5;

   Connection_Open_Op  : constant Unsigned_8 := 1;
   Connection_Close_Op : constant Unsigned_8 := 2;

   Stick_Min       : constant := 1080.0;
   Stick_Max       : constant := 1920.0;
   Stick_Mid_Start : constant := 1350.0;
   Stick_Mid_End   : constant := 1650.0;

   No_Data : constant Byte_Array (1 .. 0) := (others => 0);

   function Expected_Reply (Cmd : Unsigned_8) return Reply_Length is
     (if Cmd = Cmd_Device_Info then 5
      elsif Cmd = Cmd_Key_Press or else Cmd = Cmd_Key_Release then 2
      elsif Cmd = Cmd_Connection then 3
      else 0);

   --  The checksum of the older cameras, the polynomial 16#31# high first.
   function Split_Crc (Data : Byte_Array) return Byte is
      Crc : Byte := 0;
   begin
      for I in Data'Range loop
         Crc := Crc xor Data (I);
         for B in 1 .. 8 loop
            Crc := (if (Crc and 16#80#) /= 0 then Interfaces.Shift_Left (Crc, 1) xor 16#31#
                    else Interfaces.Shift_Left (Crc, 1));
         end loop;
      end loop;
      return Crc;
   end Split_Crc;

   procedure Append (T : in out Transmission; Data : Byte_Array)
     with Pre => Data'Length <= Max_Packet
   is
   begin
      if T.Count + Data'Length <= Max_Tx then
         for I in 0 .. Data'Length - 1 loop
            T.Tx (T.Count + I) := Data (Data'First + I);
         end loop;
         T.Count := T.Count + Data'Length;
      end if;
   end Append;

   --  A packet: the header, the command, the data and the checksum over
   --  all of them.
   procedure Send_Packet (D : Device; Cmd : Unsigned_8; Data : Byte_Array; T : in out Transmission)
     with Pre => Data'Length <= Max_Data
   is
      P : Byte_Array (0 .. Data'Length + 2) := (others => 0);
   begin
      if not D.Port_Open then
         return;
      end if;
      P (0) := Header;
      P (1) := Cmd;
      for I in 0 .. Data'Length - 1 loop
         P (2 + I) := Data (Data'First + I);
      end loop;
      P (P'Last) := CRC8_Update (0, P (0 .. P'Last - 1), Polynomial);
      Append (T, P);
   end Send_Packet;

   --  The older command: the header, the control command, the argument,
   --  the checksum computed with the tail in its place, and the tail.
   procedure Send_Split (D : Device; Argument : Unsigned_8; T : in out Transmission) is
      P : Byte_Array (0 .. 4) := (Split_Header, Split_Control, Argument, Split_Tail, 0);
   begin
      if not D.Port_Open then
         return;
      end if;
      P (3) := Split_Crc (P (0 .. 3));
      P (4) := Split_Tail;
      Append (T, P);
   end Send_Split;

   --  A request that waits for its reply: the receive buffer is flushed
   --  first, then the request goes out when the one slot is free.
   procedure Send_Request (D : in out Device; Cmd : Unsigned_8; Data : Byte_Array; Timeout_Ms : Unsigned_32;
                           Retries : Integer; Parse_With : Parser; Now_Ms : Unsigned_32; E : in out Events) is
   begin
      E.Flushed := True;
      if D.Wait.Active then
         return;
      end if;
      D.Wait := (Active       => True,
                 Command      => Cmd,
                 Expected     => Expected_Reply (Cmd),
                 Received     => 0,
                 Reply        => (others => 0),
                 Timeout_Ms   => Timeout_Ms,
                 Timeout_At   => Now_Ms + Timeout_Ms,
                 Parse_With   => Parse_With,
                 Param        => (if Data'Length = 1 then Data (Data'First) else 0),
                 Param_Length => Data'Length,
                 Retries      => Retries,
                 Outcome      => Success);
      Send_Packet (D, Cmd, Data, E.Line);
   end Send_Request;

   procedure Send_Waiting (D : Device; T : in out Transmission) is
   begin
      if D.Wait.Param_Length = 1 then
         Send_Packet (D, D.Wait.Command, Byte_Array'(0 => D.Wait.Param), T);
      else
         Send_Packet (D, D.Wait.Command, No_Data, T);
      end if;
   end Send_Waiting;

   --  The device information reply; a failure flushes the receive buffer
   --  and asks the older cameras once, without waiting for their reply
   --  (finding F78).
   procedure Parse_Info (D : in out Device; E : in out Events) is
   begin
      if D.Wait.Outcome /= Success then
         E.Flushed := True;
         Send_Split (D, 16#FF#, E.Line);
         return;
      end if;
      D.Device_Info.Version := (case D.Wait.Reply (1) is
                                  when 0 => Split,
                                  when 1 => V1_0,
                                  when others => Unknown);
      D.Device_Info.Features := Unsigned_16 (D.Wait.Reply (2))
        or Interfaces.Shift_Left (Unsigned_16 (D.Wait.Reply (3)), 8);
      D.Ready := True;
   end Parse_Info;

   --  A key simulation reply: the connection result in the low bits of
   --  the second byte, with the beep of the outcome.
   procedure Parse_Simulation (D : in out Device; E : in out Events) is
   begin
      if D.Wait.Outcome /= Success then
         D.Waiting_Response := False;
         return;
      end if;
      if D.Wait.Command = Cmd_Key_Release then
         D.Button_Pressed := False;
      elsif D.Wait.Command = Cmd_Connection then
         D.Button_Pressed := True;
         declare
            Ok : constant Boolean := (D.Wait.Reply (1) and 16#0F#) /= 0;
         begin
            if D.Wait.Param = Connection_Open_Op then
               if Ok then
                  D.In_Menu := True;
                  E.Sound := Connection_Open;
               else
                  E.Sound := Connection_Close;
               end if;
            elsif D.Wait.Param = Connection_Close_Op then
               if Ok then
                  D.In_Menu := False;
                  E.Sound := Connection_Close;
               end if;
            end if;
         end;
      elsif D.Wait.Command = Cmd_Key_Press then
         D.Button_Pressed := True;
      end if;
      D.Waiting_Response := False;
   end Parse_Simulation;

   procedure Run_Parser (D : in out Device; E : in out Events) is
   begin
      case D.Wait.Parse_With is
         when Info_Reply => Parse_Info (D, E);
         when Simulation => Parse_Simulation (D, E);
         when No_Parser  => null;
      end case;
   end Run_Parser;

   --  The waiting request past its timeout is sent again while retries
   --  remain, else counted timed out and dropped. Pending says a request
   --  still waits for bytes after this.
   procedure Check_Timeout (D : in out Device; Now_Ms : Unsigned_32; E : in out Events; Pending : out Boolean)
     with Post => (if Pending then D.Wait.Active)
   is
   begin
      Pending := False;
      while D.Wait.Active and then D.Wait.Timeout_At /= 0 and then Now_Ms > D.Wait.Timeout_At loop
         if D.Wait.Retries > 0 then
            Send_Waiting (D, E.Line);
            D.Wait.Received := 0;
            D.Wait.Timeout_At := Now_Ms + D.Wait.Timeout_Ms;
            D.Wait.Retries := D.Wait.Retries - 1;
            return;
         else
            D.Wait.Outcome := Timeout;
            Run_Parser (D, E);
            D.Wait.Active := False;
         end if;
      end loop;
      Pending := D.Wait.Active;
   end Check_Timeout;

   --  A reply byte: the header starts the reply, the expected length ends
   --  it with its checksum, and the parser of the request runs. A reply
   --  failing its checksum leaves the request waiting with its count
   --  full, so only the retry takes bytes again (finding F79).
   procedure Reply_Byte (D : in out Device; B : Byte; E : in out Events) is
      W : Waiting renames D.Wait;
   begin
      if W.Received = 0 and then B /= Header then
         return;
      end if;
      if W.Received < Max_Packet then
         W.Reply (W.Received) := B;
         W.Received := W.Received + 1;
      end if;
      if W.Received = W.Expected then
         W.Outcome := (if CRC8_Update (0, W.Reply (0 .. W.Received - 1), Polynomial) = 0 then Success
                       else Incorrect_Crc);
         Run_Parser (D, E);
         if D.Wait.Outcome = Success then
            D.Wait.Active := False;
         end if;
      end if;
   end Reply_Byte;

   --  A byte of the camera's own request. A command other than the
   --  attitude request and the 200 ms reset both return the parser to
   --  the header state (finding F77).
   procedure Request_Byte (D : in out Device; Now_Ms : Unsigned_32; B : Byte) is
      R : Request renames D.Req;
   begin
      if R.State /= State_Header and then Now_Ms - R.Last_Byte_Ms > Request_Reset then
         R := (others => <>);
      end if;
      if R.State = State_Header then
         if B = Header then
            R := (others => <>);
            R.State := State_Command;
         end if;
      elsif R.State = State_Command then
         R.Command := B;
         R.State := (if B = Cmd_Attitude then State_Crc else State_Header);
      elsif R.State = State_Data_Length then
         R.Expected_Length := B;
         R.State := State_Data;
      elsif R.State = State_Data then
         if R.Length < Natural (R.Expected_Length) and then R.Length < Max_Data then
            R.Data (R.Length) := B;
            R.Length := R.Length + 1;
         end if;
         if R.Length = Natural (R.Expected_Length) then
            R.State := State_Crc;
         end if;
      elsif R.State = State_Crc then
         declare
            Crc : Byte := CRC8_Update (0, Byte_Array'(0 => Header), Polynomial);
         begin
            Crc := CRC8_Update (Crc, Byte_Array'(0 => R.Command), Polynomial);
            Crc := CRC8_Update (Crc, R.Data (0 .. R.Length - 1), Polynomial);
            if Crc = B then
               R.Done := True;
            end if;
            R.State := State_Header;
         end;
      end if;
      R.Last_Byte_Ms := Now_Ms;
   end Request_Byte;

   --  The bytes: to the waiting request first, the rest to the camera's
   --  request parser until a request is done.
   procedure Receive (D : in out Device; Now_Ms : Unsigned_32; Rx : Byte_Array; E : in out Events) is
      Pending : Boolean;
      Pos     : Natural := 0;
   begin
      loop
         pragma Loop_Invariant (Pos <= Rx'Length);
         Check_Timeout (D, Now_Ms, E, Pending);
         exit when not Pending or else E.Flushed or else Pos >= Rx'Length;
         Reply_Byte (D, Rx (Rx'First + Pos), E);
         Pos := Pos + 1;
      end loop;
      if E.Flushed then
         E.Consumed := Rx'Length;
         return;
      end if;
      while Pos < Rx'Length and then not D.Req.Done loop
         pragma Loop_Invariant (Pos < Rx'Length);
         Request_Byte (D, Now_Ms, Rx (Rx'First + Pos));
         Pos := Pos + 1;
      end loop;
      E.Consumed := Pos;
   end Receive;

   function Supported (D : Device; C : Settings; Feature : Unsigned_16) return Boolean is
     ((D.Device_Info.Features and Feature) /= 0 or else (C.Feature and Feature) /= 0);

   --  The camera buttons: one press per switch activation, the wifi and
   --  mode buttons held back while armed or blocked.
   procedure Camera_Buttons (D : in out Device; C : Settings; Inp : Inputs; E : in out Events) is
      Behaviour : Unsigned_8;
   begin
      for I in 1 .. 3 loop
         if Inp.Camera (I) then
            if not D.Switch_Active (I) then
               Behaviour := Op_Unknown;
               case I is
                  when 1 =>
                     if Supported (D, C, Feature_Wifi_Button) and then not Inp.Armed and then not Inp.Blocked then
                        Behaviour := Op_Wifi;
                     end if;
                  when 2 =>
                     if Supported (D, C, Feature_Power_Button) then
                        Behaviour := Op_Power;
                     end if;
                  when 3 =>
                     if Supported (D, C, Feature_Change_Mode) and then not Inp.Armed and then not Inp.Blocked then
                        Behaviour := Op_Change_Mode;
                     end if;
               end case;
               if Behaviour /= Op_Unknown then
                  if D.Device_Info.Version = V1_0 then
                     Send_Packet (D, Cmd_Camera, Byte_Array'(0 => Behaviour), E.Line);
                  elsif D.Device_Info.Version = Split then
                     Send_Split (D, Behaviour + 1, E.Line);
                  end if;
                  D.Switch_Active (I) := True;
               end if;
            end if;
         else
            D.Switch_Active (I) := False;
         end if;
      end loop;
   end Camera_Buttons;

   function Hi (V : Float) return Boolean is (V > Stick_Max);
   function Lo (V : Float) return Boolean is (V < Stick_Min);
   function Mid (V : Float) return Boolean is (V > Stick_Mid_Start and then V < Stick_Mid_End);

   --  The five key cable: a connection opened and closed with the yaw
   --  stick, the keys from the sticks in the menu, and the release when
   --  the sticks return to centre.
   procedure Five_Keys (D : in out Device; Inp : Inputs; E : in out Events) is
      Key : Unsigned_8 := Key_None;
   begin
      if Inp.Menu_Open or else Inp.Armed or else Inp.Sticks_Disabled or else Inp.Blocked then
         return;
      end if;
      if D.Button_Pressed then
         if Mid (Inp.Yaw) and then Mid (Inp.Pitch) and then Mid (Inp.Roll) then
            Send_Request (D, Cmd_Key_Release, No_Data, Key_Timeout_Ms, Key_Retries, Simulation, Inp.Now_Ms, E);
            D.Waiting_Response := True;
         end if;
         return;
      end if;
      if D.Waiting_Response then
         return;
      end if;
      if Mid (Inp.Throttle) and then Mid (Inp.Roll) and then Mid (Inp.Pitch) and then Lo (Inp.Yaw) then
         if D.In_Menu then
            Send_Request (D, Cmd_Connection, Byte_Array'(0 => Connection_Close_Op), Key_Timeout_Ms, Key_Retries,
                          Simulation, Inp.Now_Ms, E);
            D.Button_Pressed := True;
            D.Waiting_Response := True;
         end if;
         return;
      end if;
      if D.In_Menu then
         if Lo (Inp.Roll) then
            Key := Key_Left;
         elsif Hi (Inp.Pitch) then
            Key := Key_Up;
         elsif Hi (Inp.Roll) then
            Key := Key_Right;
         elsif Lo (Inp.Pitch) then
            Key := Key_Down;
         elsif Mid (Inp.Throttle) and then Mid (Inp.Roll) and then Mid (Inp.Pitch) and then Hi (Inp.Yaw) then
            Key := Key_Set;
         end if;
         if Key /= Key_None then
            Send_Request (D, Cmd_Key_Press, Byte_Array'(0 => Key), Key_Timeout_Ms, Key_Retries, Simulation,
                          Inp.Now_Ms, E);
            D.Button_Pressed := True;
            D.Waiting_Response := True;
         end if;
      elsif Mid (Inp.Throttle) and then Mid (Inp.Roll) and then Mid (Inp.Pitch) and then Hi (Inp.Yaw) then
         Send_Request (D, Cmd_Connection, Byte_Array'(0 => Connection_Open_Op), Key_Timeout_Ms, Key_Retries,
                       Simulation, Inp.Now_Ms, E);
         D.Button_Pressed := True;
         D.Waiting_Response := True;
      end if;
   end Five_Keys;

   function To_U16 (I : Integer_16) return Unsigned_16 is
     (if I < 0 then Unsigned_16 (Integer (I) + 2 ** 16) else Unsigned_16 (I));

   --  The attitude the camera asked for: roll, pitch and the yaw in whole
   --  degrees, each little-endian.
   procedure Send_Attitude (D : Device; Inp : Inputs; T : in out Transmission) is
      R : constant Unsigned_16 := To_U16 (Inp.Att_Roll);
      P : constant Unsigned_16 := To_U16 (Inp.Att_Pitch);
      Y : constant Unsigned_16 := To_U16 (Inp.Att_Yaw / 10);
      Data : constant Byte_Array (0 .. 5) :=
        (Byte (R and 16#FF#), Byte (Interfaces.Shift_Right (R, 8)),
         Byte (P and 16#FF#), Byte (Interfaces.Shift_Right (P, 8)),
         Byte (Y and 16#FF#), Byte (Interfaces.Shift_Right (Y, 8)));
   begin
      Send_Packet (D, Cmd_Attitude, Data, T);
   end Send_Attitude;

   ----------
   -- Init --
   ----------

   procedure Init (D : out Device; C : Settings; Port_Opened : Boolean; Now_Ms : Unsigned_32; E : out Events) is
   begin
      D := (others => <>);
      E := (others => <>);
      D.Port_Open := Port_Opened;
      if Port_Opened then
         D.Device_Info.Version := C.Protocol_Setting;
         Send_Request (D, Cmd_Device_Info, No_Data, C.Init_Interval_Ms, C.Init_Attempts, Info_Reply, Now_Ms, E);
      end if;
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (D : in out Device; C : Settings; Inp : Inputs; Rx : Byte_Array; E : out Events) is
   begin
      E := (others => <>);
      if not D.Port_Open then
         return;
      end if;
      Receive (D, Inp.Now_Ms, Rx, E);
      Camera_Buttons (D, C, Inp, E);
      Five_Keys (D, Inp, E);
      if E.Flushed then
         E.Consumed := Rx'Length;
      end if;
      if Supported (D, C, Feature_Attitude) and then D.Req.Done then
         D.Req.Done := False;
         if D.Req.Command = Cmd_Attitude then
            Send_Attitude (D, Inp, E.Line);
         end if;
      end if;
   end Update;

end Adaflight.RunCam_Device;
