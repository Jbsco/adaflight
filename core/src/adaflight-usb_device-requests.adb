package body Adaflight.USB_Device.Requests with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Language_Descriptor : constant Byte_Array (0 .. 3) := (16#04#, 16#03#, 16#09#, 16#04#);

   Get_Status_Code        : constant Unsigned_8 := 16#00#;
   Clear_Feature_Code     : constant Unsigned_8 := 16#01#;
   Set_Feature_Code       : constant Unsigned_8 := 16#03#;
   Set_Address_Code       : constant Unsigned_8 := 16#05#;
   Get_Descriptor_Code    : constant Unsigned_8 := 16#06#;
   Get_Configuration_Code : constant Unsigned_8 := 16#08#;
   Set_Configuration_Code : constant Unsigned_8 := 16#09#;

   function Word (Low, High : Byte) return Unsigned_16 is (Unsigned_16 (Low) + Unsigned_16 (High) * 256);

   --  A string descriptor: its length and type, then each character as a
   --  16-bit code. A text past the longest one is cut.
   procedure String_Descriptor (Text : String; Reply : in out Byte_Array; Length : out Natural)
     with Pre  => Reply'First = 0 and then Reply'Length = Max_Reply,
          Post => Length in 2 .. 2 * Max_Text + 2
   is
      Used : constant Natural := Natural'Min (Text'Length, Max_Text);
   begin
      Length := 2 * Used + 2;
      Reply (0) := Byte (Length);
      Reply (1) := 3;
      for K in 0 .. Used - 1 loop
         Reply (2 + 2 * K) := Character'Pos (Text (Text'First + K));
         Reply (3 + 2 * K) := 0;
      end loop;
   end String_Descriptor;

   procedure Get_Descriptor (C : in out Core; A : in out Actions; R : Request) is
      Reply  : Byte_Array (0 .. Max_Reply - 1) := (others => 0);
      Length : Natural;
   begin
      case R.Value / 256 is
         when 1 =>
            Reply (0 .. 17) := C.Descriptor;
            Length := 18;
         when 2 =>
            Length := Natural'Min (Configuration_Descriptor'Length, Max_Reply);
            for K in 0 .. Length - 1 loop
               Reply (K) := Configuration_Descriptor (Configuration_Descriptor'First + K);
            end loop;
         when 3 =>
            case R.Value and 16#FF# is
               when 0 =>
                  Reply (0 .. 3) := Language_Descriptor;
                  Length := 4;
               when 1 =>
                  String_Descriptor (Manufacturer_Name, Reply, Length);
               when 2 =>
                  String_Descriptor (C.Product (1 .. C.Product_Used), Reply, Length);
               when 3 =>
                  String_Descriptor (C.Serial (1 .. C.Serial_Used), Reply, Length);
               when 4 =>
                  String_Descriptor (Configuration_Name, Reply, Length);
               when 5 =>
                  String_Descriptor (Interface_Name, Reply, Length);
               when others =>
                  Control_Error (C, A);
                  return;
            end case;
         when others =>
            Control_Error (C, A);
            return;
      end case;
      if Length /= 0 and then R.Length /= 0 then
         Length := Natural'Min (Length, Natural (R.Length));
         Control_Send (C, A, Reply (0 .. Length - 1));
      end if;
   end Get_Descriptor;

   procedure Set_Device_Address (C : in out Core; A : in out Actions; R : Request) is
      Address : constant Unsigned_8 := Unsigned_8 (R.Value and 16#7F#);
   begin
      if R.Index = 0 and then R.Length = 0 then
         if C.Status = Configured then
            Control_Error (C, A);
         else
            C.Address := Address;
            Add (A, (Kind => Set_Address, Address => Address, others => <>));
            Control_Send_Status (C, A);
            C.Status := (if Address /= 0 then Addressed else Default);
         end if;
      else
         Control_Error (C, A);
      end if;
   end Set_Device_Address;

   procedure Set_Configuration (C : in out Core; S : in out Class_State; A : in out Actions; R : Request) is
      Index : constant Unsigned_8 := Unsigned_8 (R.Value and 16#FF#);
   begin
      if Index > 1 then
         Control_Error (C, A);
      else
         case C.Status is
            when Addressed =>
               if Index /= 0 then
                  C.Config := Index;
                  C.Status := Configured;
                  Class_Init (C, S, A);
               end if;
               Control_Send_Status (C, A);
            when Configured =>
               if Index = 0 then
                  C.Status := Addressed;
                  C.Config := 0;
                  Class_Deinit (C, S, A);
               elsif Index /= C.Config then
                  Class_Deinit (C, S, A);
                  C.Config := Index;
                  Class_Init (C, S, A);
               end if;
               Control_Send_Status (C, A);
            when others =>
               Control_Error (C, A);
         end case;
      end if;
   end Set_Configuration;

   procedure Device_Request (C : in out Core; S : in out Class_State; A : in out Actions; R : Request) is
   begin
      case R.Code is
         when Get_Descriptor_Code =>
            Get_Descriptor (C, A, R);
         when Set_Address_Code =>
            Set_Device_Address (C, A, R);
         when Set_Configuration_Code =>
            Set_Configuration (C, S, A, R);
         when Get_Configuration_Code =>
            if R.Length /= 1 then
               Control_Error (C, A);
            else
               case C.Status is
                  when Addressed =>
                     Control_Send (C, A, (0 => 0));
                  when Configured =>
                     Control_Send (C, A, (0 => C.Config));
                  when others =>
                     Control_Error (C, A);
               end case;
            end if;
         when Get_Status_Code =>
            case C.Status is
               when Addressed | Configured =>
                  Control_Send (C, A, (0 => (if C.Remote_Wakeup then 2 else 0), 1 => 0));
               when others =>
                  Control_Error (C, A);
            end case;
         when Set_Feature_Code =>
            if R.Value = 1 then
               C.Remote_Wakeup := True;
               Class_Setup (C, S, A, R);
               Control_Send_Status (C, A);
            elsif R.Value = 2 and then (R.Index and 16#FF#) = 0 then
               declare
                  Selector : constant Unsigned_8 := Unsigned_8 (R.Index / 256);
               begin
                  C.Test_Selector := (if Selector in 1 .. 5 then Selector else 1);
               end;
               C.Test_Pending := True;
               Control_Send_Status (C, A);
            end if;
         when Clear_Feature_Code =>
            case C.Status is
               when Addressed | Configured =>
                  if R.Value = 1 then
                     C.Remote_Wakeup := False;
                     Class_Setup (C, S, A, R);
                     Control_Send_Status (C, A);
                  end if;
               when others =>
                  Control_Error (C, A);
            end case;
         when others =>
            Control_Error (C, A);
      end case;
   end Device_Request;

   procedure Interface_Request (C : in out Core; S : in out Class_State; A : in out Actions; R : Request) is
   begin
      if C.Status = Configured and then (R.Index and 16#FF#) <= 1 then
         Class_Setup (C, S, A, R);
         if R.Length = 0 then
            Control_Send_Status (C, A);
         end if;
      else
         Control_Error (C, A);
      end if;
   end Interface_Request;

   --  An endpoint's requests; one that names an endpoint the controller lacks
   --  is an error.
   procedure Endpoint_Request (C : in out Core; S : in out Class_State; A : in out Actions; R : Request) is
      Address : constant Unsigned_8 := Unsigned_8 (R.Index and 16#FF#);
      Halted  : Boolean;
   begin
      if (R.Request_Type and 16#60#) = 16#20# then
         Class_Setup (C, S, A, R);
         return;
      end if;
      case R.Code is
         when Set_Feature_Code | Clear_Feature_Code | Get_Status_Code =>
            if not Valid (Address) then
               Control_Error (C, A);
               return;
            end if;
         when others =>
            return;
      end case;
      case C.Status is
         when Addressed =>
            if Address /= 16#00# and then Address /= 16#80# then
               Stall (C, A, Address);
            end if;
         when Configured =>
            if R.Code = Set_Feature_Code then
               if R.Value = 0 and then Address /= 16#00# and then Address /= 16#80# then
                  Stall (C, A, Address);
               end if;
               Class_Setup (C, S, A, R);
               Control_Send_Status (C, A);
            elsif R.Code = Clear_Feature_Code then
               if R.Value = 0 then
                  if Address /= 16#00# and then Address /= 16#80# then
                     Clear_Stall (C, A, Address);
                     Class_Setup (C, S, A, R);
                  end if;
                  Control_Send_Status (C, A);
               end if;
            else
               Halted :=
                 (if Is_In (Address) then C.In_EP (Number (Address)).Halted
                  else C.Out_EP (Number (Address)).Halted);
               Control_Send (C, A, (0 => (if Halted then 1 else 0), 1 => 0));
            end if;
         when others =>
            Control_Error (C, A);
      end case;
   end Endpoint_Request;

   --  A setup packet: the request read from it, the control endpoint's halt
   --  ended, and the request handed to its recipient.
   procedure Setup (C : in out Core; S : in out Class_State; Packet : Setup_Packet; A : out Actions) is
      R : constant Request :=
        (Request_Type => Packet (0), Code => Packet (1), Value => Word (Packet (2), Packet (3)),
         Index => Word (Packet (4), Packet (5)), Length => Word (Packet (6), Packet (7)));
   begin
      Clear (A);
      C.Control_Length := Natural (R.Length);
      C.Stage := Stage_Setup;
      C.In_EP (0).Halted := False;
      C.Out_EP (0).Halted := False;
      case R.Request_Type and 16#1F# is
         when 0 =>
            Device_Request (C, S, A, R);
         when 1 =>
            Interface_Request (C, S, A, R);
         when 2 =>
            Endpoint_Request (C, S, A, R);
         when others =>
            Stall (C, A, R.Request_Type and 16#80#);
      end case;
   end Setup;

   procedure Data_Out
     (C : in out Core; S : in out Class_State; EP : Endpoint_Number; Packet : Byte_Array; A : out Actions) is
   begin
      Clear (A);
      if EP /= 0 and then C.Status = Configured then
         Class_Data_Out (C, S, A, EP, Packet);
      end if;
   end Data_Out;

   procedure Data_In (C : in out Core; S : in out Class_State; EP : Endpoint_Number; A : out Actions) is
   begin
      Clear (A);
      if EP = 0 then
         if C.Stage = Stage_Data_In then
            if C.In_EP (0).Remaining > C.In_EP (0).Max_Packet then
               C.In_EP (0).Remaining := C.In_EP (0).Remaining - C.In_EP (0).Max_Packet;
               Send_Control (C, A, C.In_EP (0).Remaining);
               Prepare (C, A, 0, 0);
            elsif C.In_EP (0).Total mod C.In_EP (0).Max_Packet = 0
              and then C.In_EP (0).Total >= C.In_EP (0).Max_Packet
              and then C.In_EP (0).Total < C.Control_Length
            then
               Send_Control (C, A, 0);
               C.Control_Length := 0;
               Prepare (C, A, 0, 0);
            else
               Control_Receive_Status (C, A);
            end if;
         end if;
         if C.Test_Pending then
            Add (A, (Kind => Enter_Test_Mode, Address => C.Test_Selector, others => <>));
            C.Test_Pending := False;
         end if;
      elsif C.Status = Configured then
         Class_Data_In (C, S, A, EP);
      end if;
   end Data_In;

end Adaflight.USB_Device.Requests;
