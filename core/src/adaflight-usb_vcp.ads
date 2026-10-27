--  The USB virtual serial port, a full-speed device: the standard requests on
--  the control endpoint with its transfer stages, the device, configuration
--  and string descriptors, and the communications class with its control
--  requests, its line coding and the two buffers between the host and the
--  flight software. The controller stays with the target: each event brings
--  what the controller reported, and the unit lists the endpoint operations
--  the event asks for, in their order.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.USB_VCP with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  The packet size of the control and data endpoints, the class command
   --  buffer and command endpoint packet, the size of each buffer, the
   --  controller's endpoints, the frames between transmit starts, the longest
   --  control reply and the longest product name.
   Packet_Size    : constant := 64;
   Command_Size   : constant := 8;
   Buffer_Size    : constant := 2048;
   Endpoint_Count : constant := 4;
   Frame_Interval : constant := 15;
   Max_Reply      : constant := 255;
   Max_Product    : constant := 64;

   subtype Endpoint_Number is Natural range 0 .. Endpoint_Count - 1;
   subtype Ring_Index is Natural range 0 .. Buffer_Size - 1;
   subtype Transfer_Length is Natural range 0 .. 65_535;
   subtype Packet_Count is Natural range 0 .. Packet_Size;
   subtype Packet_Limit is Natural range 1 .. 65_535;
   subtype Setup_Packet is Byte_Array (0 .. 7);

   --  The class endpoints by address.
   Data_In_Address  : constant Unsigned_8 := 16#81#;
   Data_Out_Address : constant Unsigned_8 := 16#01#;
   Command_Address  : constant Unsigned_8 := 16#82#;

   type Device_Status is (Default, Addressed, Configured, Suspended);
   type Control_Stage is (Stage_Idle, Stage_Setup, Stage_Data_In, Stage_Data_Out, Stage_Status_In, Stage_Status_Out);
   type Transmit_State is (Transmit_Idle, Transmit_Busy, Transmit_Zero_Length);
   type Endpoint_Kind is (Control, Isochronous, Bulk, Interrupt);

   --  An endpoint's halt, its packet size, the length and the rest of a
   --  control transfer, and the length an OUT transfer was armed for with the
   --  bytes it took.
   type Endpoint is record
      Halted     : Boolean := False;
      Max_Packet : Packet_Limit := Packet_Size;
      Total      : Transfer_Length := 0;
      Remaining  : Transfer_Length := 0;
      Prepared   : Transfer_Length := 0;
      Received   : Transfer_Length := 0;
   end record;
   type Endpoint_Set is array (Endpoint_Number) of Endpoint;

   --  The endpoint operations: open with the packet size and type, close,
   --  arm a receive of a length, send the bytes of one packet of a transfer,
   --  stall, clear a stall, take the device address, arm the control
   --  endpoint for the next setup packet, and enter a test mode.
   type Action_Kind is
     (Open_Endpoint, Close_Endpoint, Prepare_Receive, Transmit, Stall_Endpoint, Clear_Stall, Set_Address,
      Arm_Setup, Enter_Test_Mode);
   type Action is record
      Kind    : Action_Kind := Arm_Setup;
      Address : Unsigned_8 := 0;
      Length  : Transfer_Length := 0;
      EP_Kind : Endpoint_Kind := Control;
      Count   : Packet_Count := 0;
      Data    : Byte_Array (0 .. Packet_Size - 1) := (others => 0);
   end record;
   Max_Actions : constant := 12;
   subtype Action_Count is Natural range 0 .. Max_Actions;
   type Action_Array is array (1 .. Max_Actions) of Action;
   type Actions is record
      Count : Action_Count := 0;
      List  : Action_Array;
   end record;

   type Line_Coding is record
      Bit_Rate  : Unsigned_32 := 0;
      Format    : Unsigned_8 := 0;
      Parity    : Unsigned_8 := 0;
      Data_Bits : Unsigned_8 := 0;
   end record;

   subtype Product_Length is Natural range 0 .. Max_Product;
   subtype Descriptor_Bytes is Byte_Array (0 .. 17);

   --  The device: its status and the one a suspend left, the control stage,
   --  the address and configuration, the remote wakeup and a pending test
   --  mode, the endpoints, the requested length of the control transfer, the
   --  reply being sent with the next byte of it, the command bytes being
   --  received, the device descriptor and the product name; the class: the
   --  alternate setting, the command waiting for its data, the command
   --  buffer, the transmit state and the frame count, the received packet,
   --  the buffer toward the host with the length of the block being sent and
   --  the buffer from the host, the line coding and whether the port is
   --  configured.
   type Device is record
      Status          : Device_Status := Default;
      Old_Status      : Device_Status := Default;
      Stage           : Control_Stage := Stage_Idle;
      Address         : Unsigned_8 := 0;
      Config          : Unsigned_8 := 0;
      Remote_Wakeup   : Boolean := False;
      Test_Pending    : Boolean := False;
      Test_Selector   : Unsigned_8 := 0;
      In_EP           : Endpoint_Set;
      Out_EP          : Endpoint_Set;
      Control_Length  : Transfer_Length := 0;
      Reply           : Byte_Array (0 .. Max_Reply - 1) := (others => 0);
      Reply_Next      : Natural range 0 .. Max_Reply := 0;
      Receiving       : Boolean := False;
      Command_Next    : Natural range 0 .. Command_Size := 0;
      Descriptor      : Descriptor_Bytes := (others => 0);
      Product         : String (1 .. Max_Product) := (others => ' ');
      Product_Used    : Product_Length := 0;
      Alt_Setting     : Unsigned_32 := 0;
      Command_Code    : Unsigned_32 := 16#FF#;
      Command_Length  : Unsigned_32 := 0;
      Command         : Byte_Array (0 .. Command_Size - 1) := (others => 0);
      Sending         : Transmit_State := Transmit_Idle;
      Frame_Count     : Unsigned_32 := 0;
      Out_Packet      : Byte_Array (0 .. Packet_Size - 1) := (others => 0);
      To_Host         : Byte_Array (Ring_Index) := (others => 0);
      To_Host_In      : Ring_Index := 0;
      To_Host_Out     : Ring_Index := 0;
      Block_Length    : Natural range 0 .. Buffer_Size := 0;
      From_Host       : Byte_Array (Ring_Index) := (others => 0);
      From_Host_In    : Ring_Index := 0;
      From_Host_Out   : Ring_Index := 0;
      Line            : Line_Coding;
      Port_Configured : Boolean := False;
   end record;

   --  The device at startup with its product name.
   procedure Init (D : out Device; Product : String)
     with Pre => Product'Length <= Max_Product;

   --  A bus reset, a setup packet, the bytes of an OUT packet, an IN
   --  transfer done, a start of frame, a suspend and a resume.
   procedure Reset (D : in out Device; A : out Actions);
   procedure Setup (D : in out Device; Packet : Setup_Packet; A : out Actions);
   procedure Data_Out (D : in out Device; EP : Endpoint_Number; Packet : Byte_Array; A : out Actions)
     with Pre => Packet'Length <= Packet_Size;
   procedure Data_In (D : in out Device; EP : Endpoint_Number; A : out Actions);
   procedure Start_Of_Frame (D : in out Device; A : out Actions);
   procedure Suspend (D : in out Device);
   procedure Resume (D : in out Device);

   --  The flight software's side: bytes toward the host, taken while no
   --  transfer runs and up to the free room, and bytes from the host.
   procedure Send (D : in out Device; Data : Byte_Array; Accepted : out Natural)
     with Post => Accepted <= Data'Length;
   procedure Receive (D : in out Device; Into : out Byte_Array; Count : out Natural)
     with Post => Count <= Into'Length;
   function Receive_Available (D : Device) return Natural
     with Post => Receive_Available'Result < Buffer_Size;
   function Send_Pending (D : Device) return Natural
     with Post => Send_Pending'Result < Buffer_Size;
   function Configured (D : Device) return Boolean is (D.Port_Configured);

end Adaflight.USB_VCP;
