with Interfaces;
with DFU.Layout;
with DFU.Transport;

--  The bootloader's DFU requests with ST's extensions: status, address pointer, page erase, block writes
--  and reads, and the empty download that leaves the bootloader.
package DFU.Session with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Download_Request : constant Byte := 1;
   Upload_Request   : constant Byte := 2;
   Status_Request   : constant Byte := 3;
   Clear_Request    : constant Byte := 4;
   Abort_Request    : constant Byte := 6;

   Idle          : constant Byte := 2;
   Download_Busy : constant Byte := 4;
   Download_Idle : constant Byte := 5;
   Upload_Idle   : constant Byte := 9;
   Error         : constant Byte := 10;

   Set_Address_Command : constant Byte := 16#21#;
   Erase_Command       : constant Byte := 16#41#;
   Unprotect_Command   : constant Byte := 16#92#;
   Vendor_Error        : constant Byte := 16#0B#;
   Max_Option_Bytes    : constant := 4096;
   Unprotect_Wait      : constant := 22_000;

   Default_Transfer : constant := 2048;
   Slack            : constant := 1000;
   Max_Attempts     : constant := 100;
   Max_Blocks       : constant := 65_533;

   subtype Poll_Time is Natural range 0 .. 16#FF_FFFF#;

   type Status is record
      Code  : Byte := 0;
      Poll  : Poll_Time := 0;
      State : Byte := 0;
   end record;

   --  The next request while waiting for the idle state: a status read that failed polls again.
   type Clear_Step is (Done, Abort_Transfer, Clear_Error, Poll_Again);

   function Clear_Action (S : Status; Read, Busy_Is_Stuck : Boolean) return Clear_Step is
     (if not Read then Poll_Again
      elsif S.State = Idle then Done
      elsif S.State = Download_Idle or else S.State = Upload_Idle then Abort_Transfer
      elsif S.State = Error or else (Busy_Is_Stuck and then S.State = Download_Busy) then Clear_Error
      else Poll_Again);

   subtype Transfer_Size is Positive range 1 .. DFU.Transport.Max_Length;

   function Blocks_Fit (Length : Data_Index; Transfer : Transfer_Size) return Boolean is
     ((Length + Transfer - 1) / Transfer <= Max_Blocks);

   procedure Get_Status (S : out Status; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device);

   --  Polls, aborts and clears until the bootloader is idle, at most Max_Attempts status reads.
   procedure Clear_Status (Busy_Is_Stuck : Boolean; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device);

   procedure Load_Address (A : Address; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device);

   procedure Erase_Page (A : Address; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device);

   --  Writes Data from A in blocks of the transfer size; Ok is false when a block fails or the blocks run out.
   procedure Write (A : Address; Data : Byte_Array; Transfer : Transfer_Size; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device);

   --  Reads back from A and compares with Data; Mismatch is the offset of the first difference.
   procedure Verify
     (A : Address; Data : Byte_Array; Transfer : Transfer_Size; Ok : out Boolean; Mismatch : out Data_Index)
   with Global => (In_Out => DFU.Transport.Device);

   procedure Leave (A : Address; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device);

   --  The internal flash and option bytes layouts from the alternate settings' strings, and the functional
   --  descriptor's transfer size, Default_Transfer when the device gives none.
   procedure Read_Layout
     (M : out DFU.Layout.Memory; Options : out DFU.Layout.Memory; Has_Options : out Boolean;
      Transfer : out Transfer_Size; Ok : out Boolean)
   with
     Global => (In_Out => DFU.Transport.Device),
     Post   => (if Ok then DFU.Layout.Contiguous (M)) and then (if Has_Options then DFU.Layout.Contiguous (Options));

   --  A vendor error on loading the option bytes' address, or a failed read of them, marks read protection.
   type Protection is (Readable, Read_Protected, Unknown);

   procedure Check_Protection (Options : DFU.Layout.Memory; Result : out Protection)
   with Global => (In_Out => DFU.Transport.Device), Pre => DFU.Layout.Contiguous (Options);

   --  Removes read protection, which erases the whole flash; Ok when the bootloader resets afterwards.
   procedure Unprotect (Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device);

end DFU.Session;
