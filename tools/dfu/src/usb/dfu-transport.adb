with Interfaces.C;
with System;

package body DFU.Transport with SPARK_Mode => Off is

   use Interfaces.C;
   use type System.Address;

   pragma Linker_Options ("-lusb-1.0");

   Vendor  : constant := 16#0483#;
   Product : constant := 16#DF11#;
   Timeout : constant := 20_000;

   Standard_In : constant := 16#80#;
   Class_Out   : constant := 16#21#;
   Class_In    : constant := 16#A1#;
   Get_Descriptor_Request : constant := 6;

   Context : aliased System.Address := System.Null_Address;
   Handle  : System.Address := System.Null_Address;

   function Init (Ctx : access System.Address) return int
   with Import, Convention => C, External_Name => "libusb_init";

   procedure Finish (Ctx : System.Address)
   with Import, Convention => C, External_Name => "libusb_exit";

   function Open_Device (Ctx : System.Address; Vid, Pid : unsigned_short) return System.Address
   with Import, Convention => C, External_Name => "libusb_open_device_with_vid_pid";

   procedure Close_Device (H : System.Address)
   with Import, Convention => C, External_Name => "libusb_close";

   function Claim (H : System.Address; Number : int) return int
   with Import, Convention => C, External_Name => "libusb_claim_interface";

   function Release (H : System.Address; Number : int) return int
   with Import, Convention => C, External_Name => "libusb_release_interface";

   function Control
     (H : System.Address; Request_Type, Request : unsigned_char; Value, Index : unsigned_short; Data : System.Address;
      Length : unsigned_short; Time : unsigned) return int
   with Import, Convention => C, External_Name => "libusb_control_transfer";

   procedure Open (Ok : out Boolean) is
   begin
      Ok := False;
      if Context = System.Null_Address and then Init (Context'Access) /= 0 then
         return;
      end if;
      Handle := Open_Device (Context, Vendor, Product);
      if Handle = System.Null_Address then
         return;
      end if;
      if Claim (Handle, 0) /= 0 then
         Close_Device (Handle);
         Handle := System.Null_Address;
         return;
      end if;
      Ok := True;
   end Open;

   procedure Close is
      Released : int with Unreferenced;
   begin
      if Handle /= System.Null_Address then
         Released := Release (Handle, 0);
         Close_Device (Handle);
         Handle := System.Null_Address;
      end if;
      if Context /= System.Null_Address then
         Finish (Context);
         Context := System.Null_Address;
      end if;
   end Close;

   procedure Transfer
     (Request_Type, Request : unsigned_char; Value, Index : Interfaces.Unsigned_16; Data : System.Address;
      Length : Natural; Got : out Natural; Ok : out Boolean)
   is
      Result : int;
   begin
      Got := 0;
      Ok := False;
      if Handle = System.Null_Address then
         return;
      end if;
      Result := Control (Handle, Request_Type, Request, unsigned_short (Value), unsigned_short (Index), Data,
                         unsigned_short (Length), Timeout);
      if Result >= 0 then
         Got := Natural (Result);
         Ok := True;
      end if;
   end Transfer;

   procedure Get_Descriptor
     (Value, Index : Interfaces.Unsigned_16; Data : out Byte_Array; Got : out Natural; Ok : out Boolean)
   is
   begin
      Data := (others => 0);
      Transfer (Standard_In, Get_Descriptor_Request, Value, Index, Data'Address, Data'Length, Got, Ok);
   end Get_Descriptor;

   procedure Send (Request : Byte; Value : Interfaces.Unsigned_16; Data : Byte_Array; Ok : out Boolean) is
      Got : Natural;
   begin
      Transfer (Class_Out, unsigned_char (Request), Value, 0, Data'Address, Data'Length, Got, Ok);
      Ok := Ok and then Got = Data'Length;
   end Send;

   procedure Receive
     (Request : Byte; Value : Interfaces.Unsigned_16; Data : out Byte_Array; Got : out Natural; Ok : out Boolean)
   is
   begin
      Data := (others => 0);
      Transfer (Class_In, unsigned_char (Request), Value, 0, Data'Address, Data'Length, Got, Ok);
   end Receive;

   procedure Wait (Milliseconds : Natural) is
   begin
      delay Duration (Milliseconds) / 1000.0;
   end Wait;

end DFU.Transport;
