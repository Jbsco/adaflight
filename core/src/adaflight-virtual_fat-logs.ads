--  The files of a virtual FAT volume over a flash chip's flight logs: after
--  the entries a caller starts from, one file per log found in the flash's
--  used space, then one file of all of it, then a hidden padding file that
--  brings the volume to a fixed size. A log starts where a block of the
--  flash begins with the flight log's product line, and its file takes its
--  date from the log's start time line when one follows. Read brings the
--  flash's bytes at an offset.
generic
   with procedure Read (Offset : Unsigned_32; Data : out Flash_Read);
package Adaflight.Virtual_FAT.Logs with SPARK_Mode is

   Max_Logs       : constant := 100;
   Max_Predefined : constant := Max_Entries - Max_Logs - 2;
   Block_Size     : constant := 2_048;
   Padded_Size    : constant := 256 * 1024 * 1024;
   Max_Used       : constant := 2 ** 30 - 1;

   subtype Prefix_Text is String (1 .. 4);

   --  The volume's entries after its first Predefined ones, which get the
   --  mount time, then the volume started. The logs' files are named by the
   --  prefix and a number from 001. A log without a start time, or with a
   --  year of zero in it, gets the mount time.
   procedure Build
     (V : in out Volume; Predefined : Entry_Count; Used : Unsigned_32; Prefix : Prefix_Text; Mounted : Unsigned_32;
      OK : out Boolean)
     with Pre  => Predefined in 1 .. Max_Predefined and then Used <= Max_Used,
          Post => (if OK then Ready (V));

end Adaflight.Virtual_FAT.Logs;
