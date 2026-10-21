--  The flight log on an SD card: the log directory found or made, the log
--  numbers read from the names already in it, each log a new contiguous file
--  named after the next number, and the end of a log closing or deleting its
--  file. The callbacks of the directory and file opens come back from the
--  file system as notices, which the unit takes after each call it makes and
--  after the main task's poll.
with Interfaces;
with Adaflight.FAT; use Adaflight.FAT;
with Adaflight.FAT_FS;

generic
   with package FS_Ops is new Adaflight.FAT_FS (<>);
package Adaflight.Blackbox_SD with SPARK_Mode is
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;
   subtype Integer_8 is Interfaces.Integer_8;

   type Log_State is (Initial, Waiting, Enumerate_Files, Change_Into_Log_Directory, Ready_To_Create_Log, Ready_To_Log);

   type SD_Log is record
      Log_File      : File_Ref := No_File;
      Log_Directory : File_Ref := No_File;
      Finder        : Entry_Position;
      Largest       : Integer_32 := 0;
      State         : Log_State := Initial;
   end record;

   --  The notice numbers of the two opens.
   Directory_Opened : constant Callback_Tag := 1;
   File_Opened      : constant Callback_Tag := 2;

   --  The number a log name holds after "LOG": five characters read as C
   --  reads an integer, from leading blanks and a sign to the first
   --  character that is not a digit.
   function Name_Number (Name : FAT_Name) return Integer_32;

   --  The notices of this unit's opens, taken from the file system.
   procedure Take_Notices (L : in out SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State)
     with Global => null;

   --  The main task's file system poll, then the notices it raised.
   procedure Poll (L : in out SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State; Card_Ready : Boolean)
     with Global => null;

   --  Whether the card can take a log: a file system that is neither fatal
   --  nor unknown, and not full.
   function Device_Open (FS : File_System) return Boolean is
     (FS.State not in Fatal | Unknown and then not FS.Full);

   function Device_Full (FS : File_System) return Boolean is (FS.Full);

   function Device_Working (FS : File_System; Inserted : Boolean; Functional : Boolean) return Boolean is
     (Inserted and then Functional and then FS.State = Ready);

   function Log_Number (L : SD_Log) return Integer_32 is (L.Largest);

   --  The current log's number while a log is open, cut to 8 bits, else -1.
   function Log_File_Number (L : SD_Log) return Integer_8 is
     (if L.State = Ready_To_Log then Integer_8 (Integer_32'((L.Largest mod 256 + 128) mod 256) - 128) else -1);

   --  The next step of a log start: the log directory made or opened, its
   --  names read for the largest number, the directory entered, and the next
   --  log file opened. Done once the file is open.
   procedure Begin_Log (L : in out SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State; Done : out Boolean)
     with Global => null;

   --  The log file closed, or deleted when not kept; done once queued.
   procedure End_Log
     (L : in out SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State; Retain : Boolean; Done : out Boolean)
     with Global => null;

   procedure Write_Byte (L : SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State; Value : Unsigned_8)
     with Global => null;

   --  A text written to the log file, its whole length counted whatever the
   --  file takes.
   procedure Write_Text
     (L      : SD_Log;
      FS     : in out File_System;
      Card   : in out FS_Ops.Card_State;
      Text   : Data_Bytes;
      Length : out Natural)
     with Global => null,
          Pre    => Text'Length <= Max_Transfer;

   --  A flush of the dirty sector written first; done when none is left.
   procedure Flush_Force (FS : in out File_System; Card : in out FS_Ops.Card_State; Done : out Boolean)
     with Global => null;

   --  Done once every sector is on the card; a flush otherwise.
   procedure Flush_Force_Complete (FS : in out File_System; Card : in out FS_Ops.Card_State; Done : out Boolean)
     with Global => null;

end Adaflight.Blackbox_SD;
