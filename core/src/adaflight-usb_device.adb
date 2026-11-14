package body Adaflight.USB_Device with SPARK_Mode is

   procedure Init (C : out Core; Descriptor : Descriptor_Bytes; Product : String; Serial : String) is
   begin
      C := (others => <>);
      C.Descriptor := Descriptor;
      for K in 0 .. Product'Length - 1 loop
         C.Product (K + 1) := Product (Product'First + K);
      end loop;
      C.Product_Used := Product'Length;
      for K in 0 .. Serial'Length - 1 loop
         C.Serial (K + 1) := Serial (Serial'First + K);
      end loop;
      C.Serial_Used := Serial'Length;
   end Init;

   procedure Add (A : in out Actions; X : Action) is
   begin
      if A.Count < Max_Actions then
         A.Count := A.Count + 1;
         A.List (A.Count) := X;
      end if;
   end Add;

   procedure Clear (A : out Actions) is
   begin
      A.Count := 0;
      for I in A.List'Range loop
         A.List (I) := (others => <>);
      end loop;
   end Clear;

   procedure Open (C : in out Core; A : in out Actions; Address : Unsigned_8; Max : Packet_Limit; Kind : Endpoint_Kind)
   is
   begin
      if Is_In (Address) then
         C.In_EP (Number (Address)).Max_Packet := Max;
      else
         C.Out_EP (Number (Address)).Max_Packet := Max;
      end if;
      Add (A, (Kind => Open_Endpoint, Address => Address, Length => Max, EP_Kind => Kind, others => <>));
   end Open;

   procedure Close (A : in out Actions; Address : Unsigned_8) is
   begin
      Add (A, (Kind => Close_Endpoint, Address => Address, others => <>));
   end Close;

   procedure Flush (A : in out Actions; Address : Unsigned_8) is
   begin
      Add (A, (Kind => Flush_Endpoint, Address => Address, others => <>));
   end Flush;

   procedure Prepare (C : in out Core; A : in out Actions; Address : Unsigned_8; Length : Transfer_Length) is
   begin
      C.Out_EP (Number (Address)).Prepared := Length;
      Add (A, (Kind => Prepare_Receive, Address => Address, Length => Length, others => <>));
   end Prepare;

   procedure Stall (C : in out Core; A : in out Actions; Address : Unsigned_8) is
   begin
      if Is_In (Address) then
         C.In_EP (Number (Address)).Halted := True;
      else
         C.Out_EP (Number (Address)).Halted := True;
      end if;
      Add (A, (Kind => Stall_Endpoint, Address => Address, others => <>));
   end Stall;

   procedure Clear_Stall (C : in out Core; A : in out Actions; Address : Unsigned_8) is
   begin
      if Is_In (Address) then
         C.In_EP (Number (Address)).Halted := False;
      else
         C.Out_EP (Number (Address)).Halted := False;
      end if;
      Add (A, (Kind => Clear_Stall, Address => Address, others => <>));
   end Clear_Stall;

   procedure Arm (A : in out Actions) is
   begin
      Add (A, (Kind => Arm_Setup, others => <>));
   end Arm;

   procedure Send_Packet (A : in out Actions; Address : Unsigned_8; Length : Transfer_Length; Data : Byte_Array) is
      X : Action := (Kind => Transmit, Address => Address, Length => Length, others => <>);
   begin
      for K in 0 .. Data'Length - 1 loop
         X.Data (K) := Data (Data'First + K);
      end loop;
      X.Count := Data'Length;
      Add (A, X);
   end Send_Packet;

   procedure Send_Control (C : in out Core; A : in out Actions; Length : Transfer_Length) is
      X     : Action := (Kind => Transmit, Address => 0, Length => Length, others => <>);
      Count : constant Natural :=
        Natural'Min (Natural'Min (Length, C.In_EP (0).Max_Packet), Natural'Min (Packet_Size, Max_Reply - C.Reply_Next));
   begin
      for K in 0 .. Count - 1 loop
         X.Data (K) := C.Reply (C.Reply_Next + K);
      end loop;
      X.Count := Count;
      C.Reply_Next := C.Reply_Next + Count;
      Add (A, X);
   end Send_Control;

   procedure Control_Send (C : in out Core; A : in out Actions; Source : Byte_Array) is
   begin
      for K in 0 .. Source'Length - 1 loop
         C.Reply (K) := Source (Source'First + K);
      end loop;
      C.In_EP (0).Total := Source'Length;
      C.In_EP (0).Remaining := Source'Length;
      C.Stage := Stage_Data_In;
      C.Reply_Next := 0;
      Send_Control (C, A, Source'Length);
   end Control_Send;

   procedure Control_Send_Status (C : in out Core; A : in out Actions) is
   begin
      C.Stage := Stage_Status_In;
      Send_Control (C, A, 0);
      Arm (A);
   end Control_Send_Status;

   procedure Control_Receive_Status (C : in out Core; A : in out Actions) is
   begin
      C.Stage := Stage_Status_Out;
      Prepare (C, A, 0, 0);
      Arm (A);
   end Control_Receive_Status;

   procedure Control_Error (C : in out Core; A : in out Actions) is
   begin
      Stall (C, A, 16#80#);
      Stall (C, A, 16#00#);
      Arm (A);
   end Control_Error;

   procedure Reset (C : in out Core; A : out Actions) is
   begin
      Clear (A);
      Open (C, A, 16#00#, Packet_Size, Control);
      Open (C, A, 16#80#, Packet_Size, Control);
      C.Status := Default;
   end Reset;

   procedure Suspend (C : in out Core) is
   begin
      if C.Status /= Suspended then
         C.Old_Status := C.Status;
      end if;
      C.Status := Suspended;
   end Suspend;

   procedure Resume (C : in out Core) is
   begin
      if C.Status = Suspended then
         C.Status := C.Old_Status;
      end if;
   end Resume;

end Adaflight.USB_Device;
