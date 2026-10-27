package body Adaflight.USB_VCP with SPARK_Mode is

   --  The device descriptor at startup, the configuration descriptor with the
   --  class's two interfaces and three endpoints, and the language list.
   Device_Descriptor : constant Descriptor_Bytes :=
     (16#12#, 16#01#, 16#00#, 16#02#, 16#02#, 16#02#, 16#00#, 16#40#, 16#83#, 16#04#, 16#40#, 16#57#,
      16#00#, 16#02#, 16#01#, 16#02#, 16#03#, 16#01#);

   Configuration_Descriptor : constant Byte_Array (0 .. 66) :=
     (16#09#, 16#02#, 16#43#, 16#00#, 16#02#, 16#01#, 16#00#, 16#C0#, 16#32#,
      16#09#, 16#04#, 16#00#, 16#00#, 16#01#, 16#02#, 16#02#, 16#01#, 16#00#,
      16#05#, 16#24#, 16#00#, 16#10#, 16#01#,
      16#05#, 16#24#, 16#01#, 16#00#, 16#01#,
      16#04#, 16#24#, 16#02#, 16#02#,
      16#05#, 16#24#, 16#06#, 16#00#, 16#01#,
      16#07#, 16#05#, 16#82#, 16#03#, 16#08#, 16#00#, 16#FF#,
      16#09#, 16#04#, 16#01#, 16#00#, 16#02#, 16#0A#, 16#00#, 16#00#, 16#00#,
      16#07#, 16#05#, 16#01#, 16#02#, 16#40#, 16#00#, 16#00#,
      16#07#, 16#05#, 16#81#, 16#02#, 16#40#, 16#00#, 16#00#);

   Language_Descriptor : constant Byte_Array (0 .. 3) := (16#04#, 16#03#, 16#09#, 16#04#);

   Manufacturer_Name  : constant String := "Adaflight";
   Serial_Name        : constant String := "0x8000000";
   Configuration_Name : constant String := "VCP Config";
   Interface_Name     : constant String := "VCP Interface";

   Get_Status_Code        : constant Unsigned_8 := 16#00#;
   Clear_Feature_Code     : constant Unsigned_8 := 16#01#;
   Set_Feature_Code       : constant Unsigned_8 := 16#03#;
   Set_Address_Code       : constant Unsigned_8 := 16#05#;
   Get_Descriptor_Code    : constant Unsigned_8 := 16#06#;
   Get_Configuration_Code : constant Unsigned_8 := 16#08#;
   Set_Configuration_Code : constant Unsigned_8 := 16#09#;
   Get_Interface_Code     : constant Unsigned_8 := 16#0A#;
   Set_Interface_Code     : constant Unsigned_8 := 16#0B#;

   Set_Line_Coding_Code : constant Unsigned_32 := 16#20#;
   Get_Line_Coding_Code : constant Unsigned_32 := 16#21#;
   No_Command           : constant Unsigned_32 := 16#FF#;

   type Request is record
      Request_Type : Unsigned_8 := 0;
      Code         : Unsigned_8 := 0;
      Value        : Unsigned_16 := 0;
      Index        : Unsigned_16 := 0;
      Length       : Unsigned_16 := 0;
   end record;

   function Word (Low, High : Byte) return Unsigned_16 is (Unsigned_16 (Low) + Unsigned_16 (High) * 256);

   --  An endpoint address the controller has, and its number.
   function Valid (Address : Unsigned_8) return Boolean is ((Address and 16#7F#) < Endpoint_Count);
   function Number (Address : Unsigned_8) return Endpoint_Number is (Natural (Address and 16#7F#))
     with Pre => Valid (Address);
   function Is_In (Address : Unsigned_8) return Boolean is ((Address and 16#80#) /= 0);

   procedure Add (A : in out Actions; X : Action) is
   begin
      if A.Count < Max_Actions then
         A.Count := A.Count + 1;
         A.List (A.Count) := X;
      end if;
   end Add;

   procedure Open (D : in out Device; A : in out Actions; Address : Unsigned_8; Max : Packet_Limit;
                   Kind : Endpoint_Kind)
     with Pre => Valid (Address)
   is
   begin
      if Is_In (Address) then
         D.In_EP (Number (Address)).Max_Packet := Max;
      else
         D.Out_EP (Number (Address)).Max_Packet := Max;
      end if;
      Add (A, (Kind => Open_Endpoint, Address => Address, Length => Max, EP_Kind => Kind, others => <>));
   end Open;

   procedure Close (A : in out Actions; Address : Unsigned_8) is
   begin
      Add (A, (Kind => Close_Endpoint, Address => Address, others => <>));
   end Close;

   procedure Prepare (D : in out Device; A : in out Actions; Address : Unsigned_8; Length : Transfer_Length)
     with Pre => Valid (Address)
   is
   begin
      D.Out_EP (Number (Address)).Prepared := Length;
      D.Out_EP (Number (Address)).Received := 0;
      Add (A, (Kind => Prepare_Receive, Address => Address, Length => Length, others => <>));
   end Prepare;

   --  The control endpoint armed for a zero-length packet with no buffer.
   procedure Prepare_Status (D : in out Device; A : in out Actions) is
   begin
      Prepare (D, A, 0, 0);
      D.Receiving := False;
   end Prepare_Status;

   procedure Stall (D : in out Device; A : in out Actions; Address : Unsigned_8)
     with Pre => Valid (Address)
   is
   begin
      if Is_In (Address) then
         D.In_EP (Number (Address)).Halted := True;
      else
         D.Out_EP (Number (Address)).Halted := True;
      end if;
      Add (A, (Kind => Stall_Endpoint, Address => Address, others => <>));
   end Stall;

   procedure Clear (D : in out Device; A : in out Actions; Address : Unsigned_8)
     with Pre => Valid (Address)
   is
   begin
      if Is_In (Address) then
         D.In_EP (Number (Address)).Halted := False;
      else
         D.Out_EP (Number (Address)).Halted := False;
      end if;
      Add (A, (Kind => Clear_Stall, Address => Address, others => <>));
   end Clear;

   procedure Arm (A : in out Actions) is
   begin
      Add (A, (Kind => Arm_Setup, others => <>));
   end Arm;

   --  One packet of a control transfer from the reply's next byte, which
   --  moves past the packet the controller sends.
   procedure Send_Control (D : in out Device; A : in out Actions; Length : Transfer_Length) is
      X     : Action := (Kind => Transmit, Address => 0, Length => Length, others => <>);
      Count : constant Natural :=
        Natural'Min (Natural'Min (Length, D.In_EP (0).Max_Packet), Natural'Min (Packet_Size, Max_Reply - D.Reply_Next));
   begin
      for K in 0 .. Count - 1 loop
         X.Data (K) := D.Reply (D.Reply_Next + K);
      end loop;
      X.Count := Count;
      D.Reply_Next := D.Reply_Next + Count;
      Add (A, X);
   end Send_Control;

   --  One packet toward the host from the buffer's next byte.
   procedure Send_Data (D : Device; A : in out Actions; Length : Packet_Count) is
      X     : Action := (Kind => Transmit, Address => Data_In_Address, Length => Length, others => <>);
      Count : constant Natural :=
        Natural'Min (Natural'Min (Length, D.In_EP (1).Max_Packet), Buffer_Size - D.To_Host_Out);
   begin
      for K in 0 .. Count - 1 loop
         X.Data (K) := D.To_Host (D.To_Host_Out + K);
      end loop;
      X.Count := Count;
      Add (A, X);
   end Send_Data;

   procedure Control_Send (D : in out Device; A : in out Actions; Source : Byte_Array)
     with Pre => Source'Length <= Max_Reply
   is
   begin
      for K in 0 .. Source'Length - 1 loop
         D.Reply (K) := Source (Source'First + K);
      end loop;
      D.In_EP (0).Total := Source'Length;
      D.In_EP (0).Remaining := Source'Length;
      D.Stage := Stage_Data_In;
      D.Reply_Next := 0;
      Send_Control (D, A, Source'Length);
   end Control_Send;

   procedure Control_Prepare (D : in out Device; A : in out Actions; Length : Transfer_Length) is
   begin
      D.Out_EP (0).Total := Length;
      D.Out_EP (0).Remaining := Length;
      D.Stage := Stage_Data_Out;
      D.Receiving := True;
      D.Command_Next := 0;
      Prepare (D, A, 0, Length);
   end Control_Prepare;

   procedure Control_Send_Status (D : in out Device; A : in out Actions) is
   begin
      D.Stage := Stage_Status_In;
      Send_Control (D, A, 0);
      Arm (A);
   end Control_Send_Status;

   procedure Control_Receive_Status (D : in out Device; A : in out Actions) is
   begin
      D.Stage := Stage_Status_Out;
      Prepare_Status (D, A);
      Arm (A);
   end Control_Receive_Status;

   procedure Control_Error (D : in out Device; A : in out Actions) is
   begin
      Stall (D, A, 16#80#);
      Stall (D, A, 16#00#);
      Arm (A);
   end Control_Error;

   --  The port's control: the line coding set from the command's seven bytes,
   --  or read into them.
   procedure Line_Control (D : in out Device; Code : Unsigned_32; Length : Unsigned_32) is
   begin
      if Code = Set_Line_Coding_Code and then Length = 7 then
         D.Line :=
           (Bit_Rate  => Unsigned_32 (D.Command (0)) + Unsigned_32 (D.Command (1)) * 2 ** 8
                         + Unsigned_32 (D.Command (2)) * 2 ** 16 + Unsigned_32 (D.Command (3)) * 2 ** 24,
            Format    => D.Command (4),
            Parity    => D.Command (5),
            Data_Bits => D.Command (6));
      elsif Code = Get_Line_Coding_Code and then Length = 7 then
         D.Command (0) := Byte (D.Line.Bit_Rate and 16#FF#);
         D.Command (1) := Byte (Interfaces.Shift_Right (D.Line.Bit_Rate, 8) and 16#FF#);
         D.Command (2) := Byte (Interfaces.Shift_Right (D.Line.Bit_Rate, 16) and 16#FF#);
         D.Command (3) := Byte (Interfaces.Shift_Right (D.Line.Bit_Rate, 24));
         D.Command (4) := D.Line.Format;
         D.Command (5) := D.Line.Parity;
         D.Command (6) := D.Line.Data_Bits;
      end if;
   end Line_Control;

   --  The class's start on a configuration: the three endpoints opened, the
   --  device descriptor's class bytes, the port configured, and the data
   --  endpoint armed for a packet.
   procedure Class_Init (D : in out Device; A : in out Actions) is
   begin
      Open (D, A, Data_In_Address, Packet_Size, Bulk);
      Open (D, A, Data_Out_Address, Packet_Size, Bulk);
      Open (D, A, Command_Address, Command_Size, Interrupt);
      D.Descriptor (4) := 16#02#;
      D.Descriptor (5) := 16#00#;
      D.Port_Configured := True;
      Prepare (D, A, Data_Out_Address, Packet_Size);
   end Class_Init;

   procedure Class_Deinit (D : in out Device; A : in out Actions) is
   begin
      Close (A, Data_In_Address);
      Close (A, Data_Out_Address);
      Close (A, Command_Address);
      D.Port_Configured := False;
   end Class_Deinit;

   --  The class's requests: a class request's data stage through the command
   --  buffer, which it cannot pass, the alternate setting, and an error for
   --  the rest.
   procedure Class_Setup (D : in out Device; A : in out Actions; R : Request) is
   begin
      case R.Request_Type and 16#60# is
         when 16#20# =>
            if R.Length /= 0 then
               declare
                  L : constant Natural := Natural'Min (Natural (R.Length), Command_Size);
               begin
                  if (R.Request_Type and 16#80#) /= 0 then
                     Line_Control (D, Unsigned_32 (R.Code), Unsigned_32 (L));
                     declare
                        Copy : constant Byte_Array (0 .. L - 1) := D.Command (0 .. L - 1);
                     begin
                        Control_Send (D, A, Copy);
                     end;
                  else
                     D.Command_Code := Unsigned_32 (R.Code);
                     D.Command_Length := Unsigned_32 (L);
                     Control_Prepare (D, A, L);
                  end if;
               end;
            else
               Line_Control (D, Unsigned_32 (R.Code), 2);
            end if;
         when 16#00# =>
            case R.Code is
               when Get_Descriptor_Code =>
                  Control_Error (D, A);
               when Get_Interface_Code =>
                  Control_Send (D, A, (0 => Byte (D.Alt_Setting and 16#FF#)));
               when Set_Interface_Code =>
                  if (R.Value and 16#FF#) < 1 then
                     D.Alt_Setting := Unsigned_32 (R.Value and 16#FF#);
                  else
                     Control_Error (D, A);
                  end if;
               when others =>
                  null;
            end case;
         when others =>
            Control_Error (D, A);
      end case;
   end Class_Setup;

   --  A command's data received: the line control it names.
   procedure Class_Rx_Ready (D : in out Device) is
   begin
      if D.Command_Code /= No_Command then
         Line_Control (D, D.Command_Code, D.Command_Length);
         D.Command_Code := No_Command;
      end if;
   end Class_Rx_Ready;

   --  A packet from the host into the buffer when it fits short of filling
   --  it, and the data endpoint armed again.
   procedure Class_Data_Out (D : in out Device; A : in out Actions; EP : Endpoint_Number) is
      Count : constant Natural := Natural'Min (D.Out_EP (EP).Received, Packet_Size);
   begin
      if Receive_Available (D) + Count <= Buffer_Size - 1 then
         for K in 0 .. Count - 1 loop
            D.From_Host (D.From_Host_In) := D.Out_Packet (K);
            D.From_Host_In := (D.From_Host_In + 1) mod Buffer_Size;
         end loop;
      end if;
      Prepare (D, A, Data_Out_Address, Packet_Size);
   end Class_Data_Out;

   --  A packet toward the host done: the block's next packet, a zero-length
   --  packet after a block that ended on a full packet, or idle.
   procedure Class_Data_In (D : in out Device; A : in out Actions) is
      Length : Packet_Count;
   begin
      if D.Sending = Transmit_Busy then
         if D.Block_Length = 0 then
            D.Sending := Transmit_Idle;
         else
            if D.Block_Length > Packet_Size then
               Length := Packet_Size;
            else
               Length := D.Block_Length;
               if Length = Packet_Size then
                  D.Sending := Transmit_Zero_Length;
               end if;
            end if;
            Send_Data (D, A, Length);
            D.To_Host_Out := (D.To_Host_Out + Length) mod Buffer_Size;
            D.Block_Length := D.Block_Length - Natural'Min (Length, D.Block_Length);
            return;
         end if;
      end if;
      if D.Sending = Transmit_Zero_Length then
         Send_Data (D, A, 0);
         D.Sending := Transmit_Idle;
      end if;
   end Class_Data_In;

   --  The buffer's next block toward the host, up to its end, started while
   --  no transfer runs.
   procedure Start_Transmit (D : in out Device; A : in out Actions) is
      Length : Packet_Count;
   begin
      if D.Sending = Transmit_Idle then
         if D.To_Host_Out = D.To_Host_In then
            return;
         end if;
         if D.To_Host_Out > D.To_Host_In then
            D.Block_Length := Buffer_Size - D.To_Host_Out;
         else
            D.Block_Length := D.To_Host_In - D.To_Host_Out;
         end if;
         if D.Block_Length > Packet_Size then
            Length := Packet_Size;
            D.Sending := Transmit_Busy;
         else
            Length := D.Block_Length;
            if Length = Packet_Size then
               D.Sending := Transmit_Zero_Length;
            else
               D.Sending := Transmit_Busy;
            end if;
         end if;
         Send_Data (D, A, Length);
         D.To_Host_Out := (D.To_Host_Out + Length) mod Buffer_Size;
         D.Block_Length := D.Block_Length - Natural'Min (Length, D.Block_Length);
      end if;
   end Start_Transmit;

   --  A string descriptor: its length and type, then each character as a
   --  16-bit code.
   procedure String_Descriptor (Text : String; Reply : in out Byte_Array; Length : out Natural)
     with Pre  => Text'Length <= Max_Product and then Reply'First = 0 and then Reply'Length = Max_Reply,
          Post => Length = 2 * Text'Length + 2
   is
   begin
      Length := 2 * Text'Length + 2;
      Reply (0) := Byte (Length mod 256);
      Reply (1) := 3;
      for K in 0 .. Text'Length - 1 loop
         Reply (2 + 2 * K) := Character'Pos (Text (Text'First + K));
         Reply (3 + 2 * K) := 0;
      end loop;
   end String_Descriptor;

   procedure Get_Descriptor (D : in out Device; A : in out Actions; R : Request) is
      Reply  : Byte_Array (0 .. Max_Reply - 1) := (others => 0);
      Length : Natural;
   begin
      case R.Value / 256 is
         when 1 =>
            Reply (0 .. 17) := D.Descriptor;
            Length := 18;
         when 2 =>
            Reply (0 .. 66) := Configuration_Descriptor;
            Length := 67;
         when 3 =>
            case R.Value and 16#FF# is
               when 0 =>
                  Reply (0 .. 3) := Language_Descriptor;
                  Length := 4;
               when 1 =>
                  String_Descriptor (Manufacturer_Name, Reply, Length);
               when 2 =>
                  String_Descriptor (D.Product (1 .. D.Product_Used), Reply, Length);
               when 3 =>
                  String_Descriptor (Serial_Name, Reply, Length);
               when 4 =>
                  String_Descriptor (Configuration_Name, Reply, Length);
               when 5 =>
                  String_Descriptor (Interface_Name, Reply, Length);
               when others =>
                  Control_Error (D, A);
                  return;
            end case;
         when others =>
            Control_Error (D, A);
            return;
      end case;
      if Length /= 0 and then R.Length /= 0 then
         Length := Natural'Min (Length, Natural (R.Length));
         Control_Send (D, A, Reply (0 .. Length - 1));
      end if;
   end Get_Descriptor;

   procedure Set_Device_Address (D : in out Device; A : in out Actions; R : Request) is
      Address : constant Unsigned_8 := Unsigned_8 (R.Value and 16#7F#);
   begin
      if R.Index = 0 and then R.Length = 0 then
         if D.Status = Configured then
            Control_Error (D, A);
         else
            D.Address := Address;
            Add (A, (Kind => Set_Address, Address => Address, others => <>));
            Control_Send_Status (D, A);
            D.Status := (if Address /= 0 then Addressed else Default);
         end if;
      else
         Control_Error (D, A);
      end if;
   end Set_Device_Address;

   procedure Set_Configuration (D : in out Device; A : in out Actions; R : Request) is
      Index : constant Unsigned_8 := Unsigned_8 (R.Value and 16#FF#);
   begin
      if Index > 1 then
         Control_Error (D, A);
      else
         case D.Status is
            when Addressed =>
               if Index /= 0 then
                  D.Config := Index;
                  D.Status := Configured;
                  Class_Init (D, A);
               end if;
               Control_Send_Status (D, A);
            when Configured =>
               if Index = 0 then
                  D.Status := Addressed;
                  D.Config := 0;
                  Class_Deinit (D, A);
               elsif Index /= D.Config then
                  Class_Deinit (D, A);
                  D.Config := Index;
                  Class_Init (D, A);
               end if;
               Control_Send_Status (D, A);
            when others =>
               Control_Error (D, A);
         end case;
      end if;
   end Set_Configuration;

   procedure Device_Request (D : in out Device; A : in out Actions; R : Request) is
   begin
      case R.Code is
         when Get_Descriptor_Code =>
            Get_Descriptor (D, A, R);
         when Set_Address_Code =>
            Set_Device_Address (D, A, R);
         when Set_Configuration_Code =>
            Set_Configuration (D, A, R);
         when Get_Configuration_Code =>
            if R.Length /= 1 then
               Control_Error (D, A);
            else
               case D.Status is
                  when Addressed =>
                     Control_Send (D, A, (0 => 0));
                  when Configured =>
                     Control_Send (D, A, (0 => D.Config));
                  when others =>
                     Control_Error (D, A);
               end case;
            end if;
         when Get_Status_Code =>
            case D.Status is
               when Addressed | Configured =>
                  Control_Send (D, A, (0 => (if D.Remote_Wakeup then 2 else 0), 1 => 0));
               when others =>
                  Control_Error (D, A);
            end case;
         when Set_Feature_Code =>
            if R.Value = 1 then
               D.Remote_Wakeup := True;
               Class_Setup (D, A, R);
               Control_Send_Status (D, A);
            elsif R.Value = 2 and then (R.Index and 16#FF#) = 0 then
               declare
                  Selector : constant Unsigned_8 := Unsigned_8 (R.Index / 256);
               begin
                  D.Test_Selector := (if Selector in 1 .. 5 then Selector else 1);
               end;
               D.Test_Pending := True;
               Control_Send_Status (D, A);
            end if;
         when Clear_Feature_Code =>
            case D.Status is
               when Addressed | Configured =>
                  if R.Value = 1 then
                     D.Remote_Wakeup := False;
                     Class_Setup (D, A, R);
                     Control_Send_Status (D, A);
                  end if;
               when others =>
                  Control_Error (D, A);
            end case;
         when others =>
            Control_Error (D, A);
      end case;
   end Device_Request;

   procedure Interface_Request (D : in out Device; A : in out Actions; R : Request) is
   begin
      if D.Status = Configured and then (R.Index and 16#FF#) <= 1 then
         Class_Setup (D, A, R);
         if R.Length = 0 then
            Control_Send_Status (D, A);
         end if;
      else
         Control_Error (D, A);
      end if;
   end Interface_Request;

   --  An endpoint's requests; one that names an endpoint the controller lacks
   --  is an error.
   procedure Endpoint_Request (D : in out Device; A : in out Actions; R : Request) is
      Address : constant Unsigned_8 := Unsigned_8 (R.Index and 16#FF#);
      Halted  : Boolean;
   begin
      if (R.Request_Type and 16#60#) = 16#20# then
         Class_Setup (D, A, R);
         return;
      end if;
      case R.Code is
         when Set_Feature_Code | Clear_Feature_Code | Get_Status_Code =>
            if not Valid (Address) then
               Control_Error (D, A);
               return;
            end if;
         when others =>
            return;
      end case;
      case D.Status is
         when Addressed =>
            if Address /= 16#00# and then Address /= 16#80# then
               Stall (D, A, Address);
            end if;
         when Configured =>
            if R.Code = Set_Feature_Code then
               if R.Value = 0 and then Address /= 16#00# and then Address /= 16#80# then
                  Stall (D, A, Address);
               end if;
               Class_Setup (D, A, R);
               Control_Send_Status (D, A);
            elsif R.Code = Clear_Feature_Code then
               if R.Value = 0 then
                  if Address /= 16#00# and then Address /= 16#80# then
                     Clear (D, A, Address);
                     Class_Setup (D, A, R);
                  end if;
                  Control_Send_Status (D, A);
               end if;
            else
               Halted :=
                 (if Is_In (Address) then D.In_EP (Number (Address)).Halted
                  else D.Out_EP (Number (Address)).Halted);
               Control_Send (D, A, (0 => (if Halted then 1 else 0), 1 => 0));
            end if;
         when others =>
            Control_Error (D, A);
      end case;
   end Endpoint_Request;

   procedure Init (D : out Device; Product : String) is
   begin
      D := (others => <>);
      D.Descriptor := Device_Descriptor;
      for K in 0 .. Product'Length - 1 loop
         D.Product (K + 1) := Product (Product'First + K);
      end loop;
      D.Product_Used := Product'Length;
   end Init;

   procedure Reset (D : in out Device; A : out Actions) is
   begin
      A := (others => <>);
      Open (D, A, 16#00#, Packet_Size, Control);
      Open (D, A, 16#80#, Packet_Size, Control);
      D.Status := Default;
   end Reset;

   --  A setup packet: the request read from it, the control endpoint's halt
   --  ended, and the request handed to its recipient.
   procedure Setup (D : in out Device; Packet : Setup_Packet; A : out Actions) is
      R : constant Request :=
        (Request_Type => Packet (0), Code => Packet (1), Value => Word (Packet (2), Packet (3)),
         Index => Word (Packet (4), Packet (5)), Length => Word (Packet (6), Packet (7)));
   begin
      A := (others => <>);
      D.Control_Length := Natural (R.Length);
      D.Stage := Stage_Setup;
      D.In_EP (0).Halted := False;
      D.Out_EP (0).Halted := False;
      case R.Request_Type and 16#1F# is
         when 0 =>
            Device_Request (D, A, R);
         when 1 =>
            Interface_Request (D, A, R);
         when 2 =>
            Endpoint_Request (D, A, R);
         when others =>
            Stall (D, A, R.Request_Type and 16#80#);
      end case;
   end Setup;

   procedure Data_Out (D : in out Device; EP : Endpoint_Number; Packet : Byte_Array; A : out Actions) is
      Room  : constant Natural :=
        (if D.Out_EP (EP).Received < D.Out_EP (EP).Prepared
         then D.Out_EP (EP).Prepared - D.Out_EP (EP).Received else 0);
      Taken : Natural := Natural'Min (Packet'Length, Room);
   begin
      A := (others => <>);
      if EP = 0 then
         if D.Receiving then
            Taken := Natural'Min (Taken, Command_Size - D.Command_Next);
            for K in 0 .. Taken - 1 loop
               D.Command (D.Command_Next + K) := Packet (Packet'First + K);
            end loop;
            D.Command_Next := D.Command_Next + Taken;
         else
            Taken := 0;
         end if;
      else
         Taken := Natural'Min (Taken, Packet_Size - Natural'Min (D.Out_EP (EP).Received, Packet_Size));
         for K in 0 .. Taken - 1 loop
            D.Out_Packet (Natural'Min (D.Out_EP (EP).Received, Packet_Size) + K) := Packet (Packet'First + K);
         end loop;
      end if;
      D.Out_EP (EP).Received := D.Out_EP (EP).Received + Taken;
      if EP = 0 then
         if D.Stage = Stage_Data_Out then
            if D.Out_EP (0).Remaining > D.Out_EP (0).Max_Packet then
               D.Out_EP (0).Remaining := D.Out_EP (0).Remaining - D.Out_EP (0).Max_Packet;
               Prepare (D, A, 0, Natural'Min (D.Out_EP (0).Remaining, D.Out_EP (0).Max_Packet));
            else
               if D.Status = Configured then
                  Class_Rx_Ready (D);
               end if;
               Control_Send_Status (D, A);
            end if;
         end if;
      elsif D.Status = Configured then
         Class_Data_Out (D, A, EP);
      end if;
   end Data_Out;

   procedure Data_In (D : in out Device; EP : Endpoint_Number; A : out Actions) is
   begin
      A := (others => <>);
      if EP = 0 then
         if D.Stage = Stage_Data_In then
            if D.In_EP (0).Remaining > D.In_EP (0).Max_Packet then
               D.In_EP (0).Remaining := D.In_EP (0).Remaining - D.In_EP (0).Max_Packet;
               Send_Control (D, A, D.In_EP (0).Remaining);
               Prepare_Status (D, A);
            elsif D.In_EP (0).Total mod D.In_EP (0).Max_Packet = 0
              and then D.In_EP (0).Total >= D.In_EP (0).Max_Packet
              and then D.In_EP (0).Total < D.Control_Length
            then
               Send_Control (D, A, 0);
               D.Control_Length := 0;
               Prepare_Status (D, A);
            else
               Control_Receive_Status (D, A);
            end if;
         end if;
         if D.Test_Pending then
            Add (A, (Kind => Enter_Test_Mode, Address => D.Test_Selector, others => <>));
            D.Test_Pending := False;
         end if;
      elsif D.Status = Configured then
         Class_Data_In (D, A);
      end if;
   end Data_In;

   procedure Start_Of_Frame (D : in out Device; A : out Actions) is
   begin
      A := (others => <>);
      if D.Frame_Count = Frame_Interval then
         D.Frame_Count := 0;
         Start_Transmit (D, A);
      else
         D.Frame_Count := D.Frame_Count + 1;
      end if;
   end Start_Of_Frame;

   procedure Suspend (D : in out Device) is
   begin
      if D.Status /= Suspended then
         D.Old_Status := D.Status;
      end if;
      D.Status := Suspended;
   end Suspend;

   procedure Resume (D : in out Device) is
   begin
      if D.Status = Suspended then
         D.Status := D.Old_Status;
      end if;
   end Resume;

   procedure Send (D : in out Device; Data : Byte_Array; Accepted : out Natural) is
   begin
      Accepted := 0;
      if D.Sending /= Transmit_Idle then
         return;
      end if;
      for K in Data'Range loop
         exit when (D.To_Host_In + 1) mod Buffer_Size = D.To_Host_Out;
         D.To_Host (D.To_Host_In) := Data (K);
         D.To_Host_In := (D.To_Host_In + 1) mod Buffer_Size;
         Accepted := Accepted + 1;
         pragma Loop_Invariant (Accepted = K - Data'First + 1);
      end loop;
   end Send;

   procedure Receive (D : in out Device; Into : out Byte_Array; Count : out Natural) is
   begin
      Into := (others => 0);
      Count := 0;
      for K in Into'Range loop
         exit when D.From_Host_Out = D.From_Host_In;
         Into (K) := D.From_Host (D.From_Host_Out);
         D.From_Host_Out := (D.From_Host_Out + 1) mod Buffer_Size;
         Count := Count + 1;
         pragma Loop_Invariant (Count = K - Into'First + 1);
      end loop;
   end Receive;

   function Receive_Available (D : Device) return Natural is
     ((D.From_Host_In + Buffer_Size - D.From_Host_Out) mod Buffer_Size);

   function Send_Pending (D : Device) return Natural is
     ((D.To_Host_In + Buffer_Size - D.To_Host_Out) mod Buffer_Size);

end Adaflight.USB_VCP;
