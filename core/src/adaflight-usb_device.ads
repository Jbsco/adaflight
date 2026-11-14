--  A full-speed USB device without its class: the control endpoint with its
--  transfer stages, the endpoints' state, and the endpoint operations an
--  event asks of a controller, in their order. The controller stays with the
--  target. A class builds on this with the standard requests of the child
--  unit Requests.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.USB_Device with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;

   --  The packet size of the control endpoint and of full-speed bulk
   --  endpoints, the controller's endpoints, the longest control reply and
   --  the longest text of a string descriptor.
   Packet_Size    : constant := 64;
   Endpoint_Count : constant := 4;
   Max_Reply      : constant := 255;
   Max_Text       : constant := 64;

   subtype Endpoint_Number is Natural range 0 .. Endpoint_Count - 1;
   subtype Transfer_Length is Natural range 0 .. 65_535;
   subtype Packet_Count is Natural range 0 .. Packet_Size;
   subtype Packet_Limit is Natural range 1 .. 65_535;
   subtype Setup_Packet is Byte_Array (0 .. 7);
   subtype Descriptor_Bytes is Byte_Array (0 .. 17);
   subtype Text_Length is Natural range 0 .. Max_Text;

   type Device_Status is (Default, Addressed, Configured, Suspended);
   type Control_Stage is (Stage_Idle, Stage_Setup, Stage_Data_In, Stage_Data_Out, Stage_Status_In, Stage_Status_Out);
   type Endpoint_Kind is (Control, Isochronous, Bulk, Interrupt);

   --  An endpoint's halt, its packet size, the length and the rest of a
   --  control transfer, and the length a receive was armed for.
   type Endpoint is record
      Halted     : Boolean := False;
      Max_Packet : Packet_Limit := Packet_Size;
      Total      : Transfer_Length := 0;
      Remaining  : Transfer_Length := 0;
      Prepared   : Transfer_Length := 0;
   end record;
   type Endpoint_Set is array (Endpoint_Number) of Endpoint;

   --  The endpoint operations: open with the packet size and type, close,
   --  arm a receive of a length, send the bytes of one packet of a transfer
   --  with the length left of it, stall, clear a stall, take the device
   --  address, arm the control endpoint for the next setup packet, enter a
   --  test mode, and flush.
   type Action_Kind is
     (Open_Endpoint, Close_Endpoint, Prepare_Receive, Transmit, Stall_Endpoint, Clear_Stall, Set_Address,
      Arm_Setup, Enter_Test_Mode, Flush_Endpoint);
   type Action is record
      Kind    : Action_Kind := Arm_Setup;
      Address : Unsigned_8 := 0;
      Length  : Transfer_Length := 0;
      EP_Kind : Endpoint_Kind := Control;
      Count   : Packet_Count := 0;
      Data    : Byte_Array (0 .. Packet_Size - 1) := (others => 0);
   end record;
   Max_Actions : constant := 16;
   subtype Action_Count is Natural range 0 .. Max_Actions;
   type Action_Array is array (1 .. Max_Actions) of Action;
   type Actions is record
      Count : Action_Count := 0;
      List  : Action_Array;
   end record;

   --  A setup packet's fields.
   type Request is record
      Request_Type : Unsigned_8 := 0;
      Code         : Unsigned_8 := 0;
      Value        : Unsigned_16 := 0;
      Index        : Unsigned_16 := 0;
      Length       : Unsigned_16 := 0;
   end record;

   --  The device: its status and the one a suspend left, the control stage,
   --  the address and configuration, the remote wakeup and a pending test
   --  mode, the endpoints, the requested length of the control transfer, the
   --  reply being sent with the next byte of it, the device descriptor, the
   --  product name and the serial number.
   type Core is record
      Status        : Device_Status := Default;
      Old_Status    : Device_Status := Default;
      Stage         : Control_Stage := Stage_Idle;
      Address       : Unsigned_8 := 0;
      Config        : Unsigned_8 := 0;
      Remote_Wakeup : Boolean := False;
      Test_Pending  : Boolean := False;
      Test_Selector : Unsigned_8 := 0;
      In_EP         : Endpoint_Set;
      Out_EP        : Endpoint_Set;
      Control_Length : Transfer_Length := 0;
      Reply         : Byte_Array (0 .. Max_Reply - 1) := (others => 0);
      Reply_Next    : Natural range 0 .. Max_Reply := 0;
      Descriptor    : Descriptor_Bytes := (others => 0);
      Product       : String (1 .. Max_Text) := (others => ' ');
      Product_Used  : Text_Length := 0;
      Serial        : String (1 .. Max_Text) := (others => ' ');
      Serial_Used   : Text_Length := 0;
   end record;

   --  The device at startup with its descriptor and texts.
   procedure Init (C : out Core; Descriptor : Descriptor_Bytes; Product : String; Serial : String)
     with Pre => Product'Length <= Max_Text and then Serial'Length <= Max_Text;

   --  An endpoint address the controller has, its number and its direction.
   function Valid (Address : Unsigned_8) return Boolean is ((Address and 16#7F#) < Endpoint_Count);
   function Number (Address : Unsigned_8) return Endpoint_Number is (Natural (Address and 16#7F#))
     with Pre => Valid (Address);
   function Is_In (Address : Unsigned_8) return Boolean is ((Address and 16#80#) /= 0);

   --  An action list emptied, and an action at its end.
   procedure Clear (A : out Actions);
   procedure Add (A : in out Actions; X : Action);

   procedure Open (C : in out Core; A : in out Actions; Address : Unsigned_8; Max : Packet_Limit; Kind : Endpoint_Kind)
     with Pre => Valid (Address);
   procedure Close (A : in out Actions; Address : Unsigned_8);
   procedure Flush (A : in out Actions; Address : Unsigned_8);
   procedure Prepare (C : in out Core; A : in out Actions; Address : Unsigned_8; Length : Transfer_Length)
     with Pre => Valid (Address);
   procedure Stall (C : in out Core; A : in out Actions; Address : Unsigned_8)
     with Pre => Valid (Address);
   procedure Clear_Stall (C : in out Core; A : in out Actions; Address : Unsigned_8)
     with Pre => Valid (Address);
   procedure Arm (A : in out Actions);

   --  One packet of a transfer on a class endpoint, with the length left of
   --  that transfer.
   procedure Send_Packet (A : in out Actions; Address : Unsigned_8; Length : Transfer_Length; Data : Byte_Array)
     with Pre => Data'Length <= Packet_Size;

   --  The control endpoint: one packet of the reply from its next byte, a
   --  reply started, the status stage toward the host and from it, and both
   --  directions stalled for a request that is refused.
   procedure Send_Control (C : in out Core; A : in out Actions; Length : Transfer_Length);
   procedure Control_Send (C : in out Core; A : in out Actions; Source : Byte_Array)
     with Pre => Source'Length <= Max_Reply;
   procedure Control_Send_Status (C : in out Core; A : in out Actions);
   procedure Control_Receive_Status (C : in out Core; A : in out Actions);
   procedure Control_Error (C : in out Core; A : in out Actions);

   --  A bus reset, a suspend and a resume.
   procedure Reset (C : in out Core; A : out Actions);
   procedure Suspend (C : in out Core);
   procedure Resume (C : in out Core);

end Adaflight.USB_Device;
