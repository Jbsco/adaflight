with Interfaces;
with DFU;

--  A model of the STM32 ROM bootloader in DFU mode: its descriptors, its state machine with ST's
--  extensions, and a flash that programs only erased bits.
package Model_Device is

   type Chip is (F405, F722);

   procedure Reset (Kind : Chip; Transfer : Natural := 2048);

   procedure Fill (First : DFU.Address; Length : Natural; Value : DFU.Byte);

   function Peek (A : DFU.Address) return DFU.Byte;

   procedure Flip (A : DFU.Address);

   procedure Set_Present (Present : Boolean);

   --  A protected device refuses its option bytes' address with a vendor error until an unprotect
   --  request erases the flash.
   procedure Set_Protected (Locked : Boolean);

   function Is_Protected return Boolean;

   function Is_Present return Boolean;

   --  The next Count erases stay busy until a clear status request.
   procedure Set_Stuck_Erases (Count : Natural);

   --  Each block write then reports busy for Count more status reads before it is done.
   procedure Set_Busy_Reads (Count : Natural);

   function Erased_Pages return Natural;

   function Left return Boolean;

   function Left_At return DFU.Address;

   procedure Descriptor
     (Value, Index : Interfaces.Unsigned_16; Data : out DFU.Byte_Array; Got : out Natural; Ok : out Boolean);

   procedure Out_Request (Request : DFU.Byte; Value : Interfaces.Unsigned_16; Data : DFU.Byte_Array; Ok : out Boolean);

   procedure In_Request
     (Request : DFU.Byte; Value : Interfaces.Unsigned_16; Data : out DFU.Byte_Array; Got : out Natural;
      Ok : out Boolean);

end Model_Device;
