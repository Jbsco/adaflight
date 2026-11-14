with Adaflight.USB_Device.Requests;

package body Adaflight.USB_MSC with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Adaflight.Mass_Storage.Send_Kind;
   use type Adaflight.Mass_Storage.Receive_Kind;

   package MS renames Adaflight.Mass_Storage;

   Device_Descriptor : constant Descriptor_Bytes :=
     (16#12#, 16#01#, 16#00#, 16#02#, 16#00#, 16#00#, 16#00#, 16#40#, 16#83#, 16#04#, 16#20#, 16#57#,
      16#00#, 16#02#, 16#01#, 16#02#, 16#03#, 16#01#);

   --  One configuration with one interface of the mass storage class, SCSI
   --  commands over the bulk-only transport, and its two bulk endpoints.
   Configuration_Descriptor : constant Byte_Array (0 .. 31) :=
     (16#09#, 16#02#, 16#20#, 16#00#, 16#01#, 16#01#, 16#04#, 16#C0#, 16#32#,
      16#09#, 16#04#, 16#00#, 16#00#, 16#02#, 16#08#, 16#06#, 16#50#, 16#05#,
      16#07#, 16#05#, 16#81#, 16#02#, 16#40#, 16#00#, 16#00#,
      16#07#, 16#05#, 16#01#, 16#02#, 16#40#, 16#00#, 16#00#);

   Transport_Reset_Code : constant Unsigned_8 := 16#FF#;
   Clear_Feature_Code   : constant Unsigned_8 := 16#01#;
   Get_Interface_Code   : constant Unsigned_8 := 16#0A#;
   Set_Interface_Code   : constant Unsigned_8 := 16#0B#;

   --  The next packet of the transfer toward the host.
   procedure Send_Next_Packet (S : in out Disk_State; A : in out Actions)
     with Global => null
   is
      Left  : constant Natural := (if S.Send_Next < S.Send_Total then S.Send_Total - S.Send_Next else 0);
      Count : constant Natural := Natural'Min (Left, Packet_Size);
      Bytes : Byte_Array (0 .. Packet_Size - 1) := (others => 0);
   begin
      for K in 0 .. Count - 1 loop
         if S.Sending = MS.Status then
            if S.Send_Next + K <= S.Wrapper'Last then
               Bytes (K) := S.Wrapper (S.Send_Next + K);
            end if;
         elsif S.Send_Next + K <= S.Session.Data'Last then
            Bytes (K) := S.Session.Data (S.Send_Next + K);
         end if;
      end loop;
      Send_Packet (A, In_Address, Natural'Min (Left, Transfer_Length'Last), Bytes (0 .. Count - 1));
      S.Send_Next := S.Send_Next + Count;
   end Send_Next_Packet;

   --  The endpoint work the transport left, in its order: flushes, halts, a
   --  transfer toward the host started with its first packet, and a receive
   --  armed for a first packet.
   procedure Apply (C : in out Core; S : in out Disk_State; A : in out Actions; Work : MS.Actions)
     with Global => null
   is
   begin
      if Work.Flush then
         Flush (A, Out_Address);
         Flush (A, In_Address);
      end if;
      if Work.Halt_Out then
         Stall (C, A, Out_Address);
      end if;
      if Work.Halt_In then
         Stall (C, A, In_Address);
      end if;
      if Work.Send /= MS.Nothing then
         S.Sending := Work.Send;
         S.Send_Next := 0;
         if Work.Send = MS.Status then
            S.Wrapper := Engine.Status_Wrapper (S.Session);
            S.Send_Total := MS.Status_Length;
         else
            S.Send_Total := Natural'Min (Work.Send_Length, Engine.Buffer_Size);
         end if;
         Send_Next_Packet (S, A);
      end if;
      if Work.Receive /= MS.Nothing then
         S.Out_Count := 0;
         Prepare (C, A, Out_Address, Natural'Min (Work.Receive_Length, Packet_Size));
      end if;
   end Apply;

   procedure Class_Deinit (C : in out Core; S : in out Disk_State; A : in out Actions) is
      pragma Unreferenced (C);
   begin
      Close (A, In_Address);
      Close (A, Out_Address);
      Engine.Stop (S.Session);
   end Class_Deinit;

   procedure Class_Init (C : in out Core; S : in out Disk_State; A : in out Actions) is
      Work : MS.Actions;
   begin
      Class_Deinit (C, S, A);
      S.Sending := MS.Nothing;
      Open (C, A, In_Address, Packet_Size, Bulk);
      Open (C, A, Out_Address, Packet_Size, Bulk);
      Engine.Start (S.Session, Work);
      Apply (C, S, A, Work);
   end Class_Init;

   --  The class's requests. Of its own it takes the transport's reset and
   --  refuses the others, the count of its units past one among them, as a
   --  storage of one unit may. Of the
   --  standard ones it takes the alternate setting, and a halt cleared on
   --  one of its two endpoints, which it flushes and reopens before the
   --  transport goes on.
   procedure Class_Setup (C : in out Core; S : in out Disk_State; A : in out Actions; R : Request) is
      Work    : MS.Actions;
      Address : constant Unsigned_8 := Unsigned_8 (R.Index and 16#FF#);
   begin
      case R.Request_Type and 16#60# is
         when 16#20# =>
            if R.Code = Transport_Reset_Code and then R.Value = 0 and then R.Length = 0
              and then (R.Request_Type and 16#80#) = 0
            then
               Engine.Reset (S.Session, Work);
               S.Sending := MS.Nothing;
               Apply (C, S, A, Work);
            else
               Control_Error (C, A);
            end if;
         when 16#00# =>
            if R.Code = Get_Interface_Code then
               Control_Send (C, A, (0 => S.Alt_Setting));
            elsif R.Code = Set_Interface_Code then
               S.Alt_Setting := Unsigned_8 (R.Value and 16#FF#);
            elsif R.Code = Clear_Feature_Code and then (R.Request_Type and 16#1F#) = 2
              and then (Address = In_Address or else Address = Out_Address)
            then
               Flush (A, Address);
               Close (A, Address);
               Open (C, A, Address, Packet_Size, Bulk);
               Engine.Halt_Cleared (S.Session, In_Endpoint => Address = In_Address, Next => Work);
               Apply (C, S, A, Work);
            end if;
         when others =>
            null;
      end case;
   end Class_Setup;

   --  A packet from the host: its bytes after those the transfer already
   --  has. A short packet or the length asked for ends the transfer, which
   --  goes to the transport; before that the next packet's receive is armed.
   --  A transfer that goes on after a full packet has a whole packet or more
   --  left, since the transport asks for a command wrapper or for whole
   --  blocks.
   procedure Class_Data_Out
     (C : in out Core; S : in out Disk_State; A : in out Actions; EP : Endpoint_Number; Packet : Byte_Array)
   is
      pragma Unreferenced (EP);
      Asked : constant Natural := Natural'Min (S.Session.Receive_Length, Engine.Buffer_Size);
      Have  : constant Natural := Natural'Min (S.Out_Count, Asked);
      Taken : constant Natural := Natural'Min (Packet'Length, Asked - Have);
      Work  : MS.Actions;
   begin
      if S.Session.Receiving = MS.Nothing then
         return;
      end if;
      for K in 0 .. Taken - 1 loop
         S.Out_Data (Have + K) := Packet (Packet'First + K);
      end loop;
      S.Out_Count := Have + Taken;
      if Packet'Length < Packet_Size or else S.Out_Count >= Asked then
         Engine.Packet_Out (S.Session, S.Out_Data (0 .. Have + Taken - 1), Work);
         Apply (C, S, A, Work);
      else
         Prepare (C, A, Out_Address, Packet_Size);
      end if;
   end Class_Data_Out;

   --  A transmission ended: the transfer's next packet, or with its last
   --  one done the transport goes on.
   procedure Class_Data_In (C : in out Core; S : in out Disk_State; A : in out Actions; EP : Endpoint_Number) is
      Work : MS.Actions;
   begin
      if EP = 1 and then S.Sending /= MS.Nothing and then S.Send_Next < S.Send_Total then
         Send_Next_Packet (S, A);
      else
         S.Sending := MS.Nothing;
         Engine.Packet_In (S.Session, Work);
         Apply (C, S, A, Work);
      end if;
   end Class_Data_In;

   package Device_Requests is new Adaflight.USB_Device.Requests
     (Class_State              => Disk_State,
      Configuration_Descriptor => Configuration_Descriptor,
      Manufacturer_Name        => "Adaflight",
      Configuration_Name       => "MSC Config",
      Interface_Name           => "MSC Interface",
      Class_Init               => Class_Init,
      Class_Deinit             => Class_Deinit,
      Class_Setup              => Class_Setup,
      Class_Data_Out           => Class_Data_Out,
      Class_Data_In            => Class_Data_In);

   --  The serial number: eight hexadecimal digits of the identifier's first
   --  and third words added, then the upper four of its second word, or
   --  twelve zero characters when that sum is zero.
   procedure Init (D : out Device; Product : String; Id : Identifier) is
      Hex    : constant String := "0123456789ABCDEF";
      Sum    : constant Interfaces.Unsigned_32 := Id (1) + Id (3);
      Serial : String (1 .. 12) := (others => Character'Val (0));
   begin
      if Sum /= 0 then
         for K in 0 .. 7 loop
            Serial (K + 1) := Hex (Natural (Interfaces.Shift_Right (Sum, 28 - 4 * K) and 16#F#) + 1);
         end loop;
         for K in 0 .. 3 loop
            Serial (K + 9) := Hex (Natural (Interfaces.Shift_Right (Id (2), 28 - 4 * K) and 16#F#) + 1);
         end loop;
      end if;
      D := (others => <>);
      Adaflight.USB_Device.Init (D.Core, Device_Descriptor, Product, Serial);
   end Init;

   procedure Reset (D : in out Device; A : out Actions) is
   begin
      Adaflight.USB_Device.Reset (D.Core, A);
      D.Disk.Sending := MS.Nothing;
      D.Disk.Out_Count := 0;
   end Reset;

   procedure Setup (D : in out Device; Packet : Setup_Packet; A : out Actions) is
   begin
      Device_Requests.Setup (D.Core, D.Disk, Packet, A);
   end Setup;

   procedure Data_Out (D : in out Device; EP : Endpoint_Number; Packet : Byte_Array; A : out Actions) is
   begin
      Device_Requests.Data_Out (D.Core, D.Disk, EP, Packet, A);
   end Data_Out;

   procedure Data_In (D : in out Device; EP : Endpoint_Number; A : out Actions) is
   begin
      Device_Requests.Data_In (D.Core, D.Disk, EP, A);
   end Data_In;

   procedure Suspend (D : in out Device) is
   begin
      Adaflight.USB_Device.Suspend (D.Core);
   end Suspend;

   procedure Resume (D : in out Device) is
   begin
      Adaflight.USB_Device.Resume (D.Core);
   end Resume;

end Adaflight.USB_MSC;
