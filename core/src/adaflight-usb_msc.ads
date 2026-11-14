--  The USB mass storage device: the standard device with a mass storage
--  class of one interface and two bulk endpoints, its class requests, and the
--  bulk-only transport and SCSI commands of the mass storage engine over a
--  storage of 512 byte blocks. Transfers on the bulk endpoints go to the
--  controller one 64 byte packet at a time. The controller stays with the
--  target: each event brings what the controller reported, and this unit
--  lists the endpoint operations the event asks for, in their order.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Mass_Storage.Engine;
with Adaflight.USB_Device; use Adaflight.USB_Device;

generic
   Buffer_Blocks : Adaflight.Mass_Storage.Buffer_Block_Count;
   Inquiry : Adaflight.Mass_Storage.Inquiry_Bytes;
   with procedure Start_Storage;
   with procedure Capacity (Blocks : out Interfaces.Unsigned_32; OK : out Boolean);
   with procedure Ready (OK : out Boolean);
   with procedure Write_Protected (Yes : out Boolean);
   with procedure Read_Blocks
     (First : Interfaces.Unsigned_32; Count : Natural; Data : in out Byte_Array; OK : out Boolean);
   with procedure Write_Blocks
     (First : Interfaces.Unsigned_32; Count : Natural; Data : Byte_Array; OK : out Boolean);
package Adaflight.USB_MSC with SPARK_Mode is

   package Engine is new Adaflight.Mass_Storage.Engine
     (Buffer_Blocks   => Buffer_Blocks,
      Inquiry         => Inquiry,
      Start_Storage   => Start_Storage,
      Capacity        => Capacity,
      Ready           => Ready,
      Write_Protected => Write_Protected,
      Read_Blocks     => Read_Blocks,
      Write_Blocks    => Write_Blocks);

   --  The class endpoints by address.
   In_Address  : constant Unsigned_8 := 16#81#;
   Out_Address : constant Unsigned_8 := 16#01#;

   --  The class: the transport's session, the alternate setting, a transfer
   --  toward the host with its length, the next byte of it and a status
   --  wrapper's bytes, and the bytes of a transfer from the host so far.
   type Disk_State is record
      Session     : Engine.Session;
      Alt_Setting : Unsigned_8 := 0;
      Sending     : Adaflight.Mass_Storage.Send_Kind := Adaflight.Mass_Storage.Nothing;
      Send_Total  : Natural := 0;
      Send_Next   : Natural := 0;
      Wrapper     : Adaflight.Mass_Storage.Status_Bytes := (others => 0);
      Out_Data    : Engine.Data_Buffer := (others => 0);
      Out_Count   : Natural := 0;
   end record;

   type Device is record
      Core : Adaflight.USB_Device.Core;
      Disk : Disk_State;
   end record;

   --  The device at startup with its product name and the three words of
   --  the microcontroller's identifier, which give its serial number.
   type Identifier is array (1 .. 3) of Interfaces.Unsigned_32;
   procedure Init (D : out Device; Product : String; Id : Identifier)
     with Pre => Product'Length <= Max_Text;

   --  A bus reset, a setup packet, the bytes of an OUT packet, an IN
   --  transfer done, a suspend and a resume.
   procedure Reset (D : in out Device; A : out Actions);
   procedure Setup (D : in out Device; Packet : Setup_Packet; A : out Actions);
   procedure Data_Out (D : in out Device; EP : Endpoint_Number; Packet : Byte_Array; A : out Actions)
     with Pre => Packet'Length <= Packet_Size;
   procedure Data_In (D : in out Device; EP : Endpoint_Number; A : out Actions);
   procedure Suspend (D : in out Device);
   procedure Resume (D : in out Device);

   function Configured (D : Device) return Boolean is (D.Core.Status = Adaflight.USB_Device.Configured);

end Adaflight.USB_MSC;
