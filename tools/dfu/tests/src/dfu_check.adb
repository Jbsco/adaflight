with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces;
with DFU.Flash;
with DFU.Layout;
with DFU.Plan;
with DFU.Session;
with DFU.Transport;
with Model_Device;

--  Checks of the flasher's parsers, its erase plan and a whole flash against the bootloader model.
procedure DFU_Check is

   use Ada.Text_IO;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type DFU.Byte;
   use type DFU.Byte_Array;
   use DFU.Layout;
   use DFU.Plan;
   use DFU.Session;

   Failures : Natural := 0;

   procedure Check (Name : String; Condition : Boolean) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Put_Line ("FAIL " & Name);
      end if;
   end Check;

   function Parses (Text : String) return Boolean is
      M  : Memory;
      Ok : Boolean;
   begin
      Parse (Text, M, Ok);
      return Ok;
   end Parses;

   function Layout_Of (Text : String) return Memory is
      M  : Memory;
      Ok : Boolean;
   begin
      Parse (Text, M, Ok);
      Check ("parse " & Text, Ok);
      return M;
   end Layout_Of;

   procedure Layouts is
      F405 : constant Memory := Layout_Of ("@Internal Flash  /0x08000000/04*016Kg,01*064Kg,07*128Kg");
      F722 : constant Memory := Layout_Of ("@Internal Flash  /0x08000000/04*016Kg,01*64Kg,03*128Kg");
      F745 : constant Memory := Layout_Of ("@Internal Flash  /0x08000000/04*032Kg,01*128Kg,03*256Kg");
      Opt  : constant Memory := Layout_Of ("@Option Bytes  /0x1FFFC000/01*016 e");
      Ext  : constant Memory := Layout_Of ("@External Flash /0x90000000/2*1Mg");
      GD   : constant Memory := Layout_Of ("@InternalFlash   /0x08000000/0512*002Kg");
      Nul  : constant Memory := Layout_Of ("@Internal Flash" & ASCII.NUL & "  /0x08000000/04*016Kg");
   begin
      Check ("F405 pages", F405.Pages = 12 and then F405.First (1) = 16#0800_0000#
                           and then F405.Last (4) = 16#0800_FFFF# and then F405.First (5) = 16#0801_0000#
                           and then F405.Last (5) = 16#0801_FFFF# and then F405.Last (12) = 16#080F_FFFF#);
      Check ("F405 name", Is_Internal_Flash (F405));
      Check ("F722 pages", F722.Pages = 8 and then F722.Last (8) = 16#0807_FFFF#);
      Check ("F745 third page", F745.Pages = 8 and then F745.First (3) = 16#0801_0000#
                                and then F745.Last (8) = 16#080F_FFFF#);
      Check ("option bytes", Opt.Pages = 1 and then Opt.First (1) = 16#1FFF_C000# and then Opt.Last (1) = 16#1FFF_C00F#
                             and then not Is_Internal_Flash (Opt));
      Check ("megabyte pages", Ext.Pages = 2 and then Ext.Last (2) = 16#901F_FFFF#);
      Check ("joined name", Is_Internal_Flash (GD) and then GD.Pages = 512);
      Check ("unprintable dropped", Is_Internal_Flash (Nul) and then Nul.Pages = 4);
      Check ("empty", not Parses (""));
      Check ("no at sign", not Parses ("Internal Flash /0x08000000/04*016Kg"));
      Check ("no groups", not Parses ("@Internal Flash /0x08000000"));
      Check ("empty groups", not Parses ("@Internal Flash /0x08000000/"));
      Check ("no size", not Parses ("@Internal Flash /0x08000000/04*"));
      Check ("zero size", not Parses ("@Internal Flash /0x08000000/04*000Kg"));
      Check ("zero count", not Parses ("@Internal Flash /0x08000000/0*016Kg"));
      Check ("two stars", not Parses ("@Internal Flash /0x08000000/4*1*2Kg"));
      Check ("trailing comma", not Parses ("@Internal Flash /0x08000000/04*016Kg,"));
      Check ("bad start", not Parses ("@Internal Flash /zz/04*016Kg"));
      Check ("past 32 bits", not Parses ("@Internal Flash /0xFFFF0000/02*064Kg"));
      Check ("too many pages", not Parses ("@Internal Flash /0x00000000/3000*001 g"));
   end Layouts;

   procedure Configurations is
      Info : Interface_Info;
      Base : constant DFU.Byte_Array :=
        (9, 2, 54, 0, 1, 1, 0, 16#C0#, 16#32#,
         9, 4, 0, 0, 0, 16#FE#, 1, 2, 4,
         9, 4, 0, 1, 0, 16#FE#, 1, 2, 5,
         9, 4, 0, 2, 0, 16#FE#, 1, 2, 6,
         9, 4, 0, 3, 0, 16#FE#, 1, 2, 7,
         9, 16#21#, 16#0B#, 16#FF#, 0, 0, 8, 16#1A#, 1);
      Hid : constant DFU.Byte_Array :=
        (9, 2, 43, 0, 2, 1, 0, 16#C0#, 16#32#,
         9, 4, 1, 0, 1, 3, 0, 0, 0,
         9, 16#21#, 16#11#, 1, 0, 1, 16#22#, 16#40#, 0,
         9, 4, 0, 0, 0, 16#FE#, 1, 2, 4,
         7, 16#21#, 16#0B#, 16#FF#, 0, 0, 4);
      Zero : constant DFU.Byte_Array := (9, 2, 18, 0, 1, 1, 0, 16#C0#, 16#32#, 0, 4, 0, 0, 0, 16#FE#, 1, 2, 4);
   begin
      Parse_Configuration (Base, Info);
      Check ("alternates", Info.Alternates = 4 and then Info.Strings (1) = 4 and then Info.Strings (4) = 7);
      Check ("transfer size", Info.Transfer_Size = 2048);
      Parse_Configuration (Hid, Info);
      Check ("HID descriptor ignored", Info.Alternates = 1 and then Info.Strings (1) = 4
                                       and then Info.Transfer_Size = 0);
      Parse_Configuration (Zero, Info);
      Check ("zero length descriptor", Info.Alternates = 1 and then Info.Strings (1) = 4);
      Parse_Configuration (Base (0 .. 0), Info);
      Check ("one byte", Info.Alternates = 0 and then Info.Transfer_Size = 0);
   end Configurations;

   procedure Strings is
      Text   : String (1 .. Max_Text);
      Length : Natural;
   begin
      Decode_String ((12, 3, Character'Pos ('@'), 0, 16#14#, 16#20#, Character'Pos ('I'), 0,
                      Character'Pos ('n'), 0, Character'Pos ('t'), 0, Character'Pos ('x'), 0), Text, Length);
      Check ("decode", Length = 4 and then Text (1 .. 4) = "@Int");
      Decode_String ((1 => 2), Text, Length);
      Check ("decode short", Length = 0);
   end Strings;

   procedure Plans is
      F405   : constant Memory := Layout_Of ("@Internal Flash  /0x08000000/04*016Kg,01*064Kg,07*128Kg");
      Small  : constant Memory := Layout_Of ("@Internal Flash  /0x08000000/02*016Kg");
      Images : Image_Array;
      Erase  : Page_Set;
      Ok     : Boolean;
   begin
      Place_Pair (F405, 3000, 300_000, Images, Ok);
      Check ("pair placed", Ok and then Images (1).First = 16#0800_0000# and then Images (2).First = 16#0800_8000#);
      Erase_Set (F405, Images, 2, Erase);
      Check ("pair erase set", Erase (1) and then not Erase (2) and then (for all P in 3 .. 7 => Erase (P))
                               and then (for all P in 8 .. Max_Pages => not Erase (P)));
      Place_Pair (F405, 16_385, 1000, Images, Ok);
      Check ("first file past first page", not Ok);
      Place_Pair (F405, 1000, 1024 * 1024 - 32 * 1024 + 1, Images, Ok);
      Check ("second file past the flash", not Ok);
      Place_Pair (Small, 1000, 1000, Images, Ok);
      Check ("two pages", not Ok);
      Images := (1 => (16#0800_8000#, 100), 2 => (16#0800_8050#, 100), others => (0, 0));
      Check ("overlap refused", not Valid (F405, Images, 2));
      Images := (1 => (16#0800_0000#, 100), 2 => (16#0810_0000#, 100), others => (0, 0));
      Check ("outside refused", not Valid (F405, Images, 2));
      Check ("block numbers", Blocks_Fit (64 * 65_533, 64) and then not Blocks_Fit (64 * 65_533 + 1, 64));
   end Plans;

   procedure Actions is
   begin
      Check ("idle", Clear_Action ((0, 0, Idle), True, False) = Done);
      Check ("download idle", Clear_Action ((0, 0, Download_Idle), True, False) = Abort_Transfer);
      Check ("upload idle", Clear_Action ((0, 0, Upload_Idle), True, False) = Abort_Transfer);
      Check ("error", Clear_Action ((0, 0, Error), True, False) = Clear_Error);
      Check ("stuck busy", Clear_Action ((0, 0, Download_Busy), True, True) = Clear_Error);
      Check ("busy", Clear_Action ((0, 0, Download_Busy), True, False) = Poll_Again);
      Check ("read failed", Clear_Action ((0, 0, Idle), False, False) = Poll_Again);
   end Actions;

   type Phase is (None, Opened, Described, Placed, Cleared, Checked, Erased, Written, Verified, Started);

   function Pattern (Length, Step, Modulus : Natural) return DFU.Byte_Array is
      Result : DFU.Byte_Array (0 .. Length - 1);
   begin
      for I in Result'Range loop
         Result (I) := DFU.Byte ((I * Step + 1) mod Modulus);
      end loop;
      return Result;
   end Pattern;

   Sector_0 : constant DFU.Byte_Array := Pattern (3000, 7, 256);
   Code     : constant DFU.Byte_Array := Pattern (300_000, 13, 251);

   procedure Run
     (Skip_Erase : Boolean; Flip_At : DFU.Address; Reached : out Phase; Failed : out DFU.Address;
      Transfer : out Transfer_Size)
   is
      M       : Memory;
      Options : Memory;
      Has     : Boolean;
      Guard   : Protection;
      Images  : Image_Array;
      Offsets : constant DFU.Flash.Offset_Array := (1 => 0, 2 => Sector_0'Length, others => 0);
      Data    : constant DFU.Byte_Array := Sector_0 & Code;
      Ok      : Boolean;
      Pages   : Natural;
      Bytes   : Interfaces.Unsigned_64;
   begin
      Reached := None;
      Failed := 0;
      Transfer := Default_Transfer;
      DFU.Transport.Open (Ok);
      if not Ok then
         return;
      end if;
      Reached := Opened;
      Read_Layout (M, Options, Has, Transfer, Ok);
      if not Ok then
         return;
      end if;
      Reached := Described;
      Place_Pair (M, Sector_0'Length, Code'Length, Images, Ok);
      if not Ok then
         return;
      end if;
      Reached := Placed;
      Clear_Status (False, Ok);
      if not Ok then
         return;
      end if;
      Reached := Cleared;
      if Has then
         Check_Protection (Options, Guard);
         if Guard /= Readable then
            return;
         end if;
      end if;
      Reached := Checked;
      if not Skip_Erase then
         DFU.Flash.Erase (M, Images, 2, Pages, Bytes, Failed, Ok);
         if not Ok then
            return;
         end if;
      end if;
      Reached := Erased;
      DFU.Flash.Write (Images, Offsets, 2, Data, Transfer, Failed, Ok);
      if not Ok then
         return;
      end if;
      Reached := Written;
      if Flip_At /= 0 then
         Model_Device.Flip (Flip_At);
      end if;
      DFU.Flash.Verify (Images, Offsets, 2, Data, Transfer, Failed, Ok);
      if not Ok then
         return;
      end if;
      Reached := Verified;
      Leave (Images (1).First, Ok);
      if Ok then
         Reached := Started;
      end if;
   end Run;

   procedure Flashes is
      Reached  : Phase;
      Failed   : DFU.Address;
      Transfer : Transfer_Size;
      Flashed  : Boolean;
      Sent     : Boolean;
   begin
      Model_Device.Reset (Model_Device.F405);
      Model_Device.Fill (16#0800_4000#, 16 * 1024, 16#C3#);
      Run (False, 0, Reached, Failed, Transfer);
      Check ("flash F405", Reached = Started and then Transfer = 2048);
      Flashed := (for all I in Sector_0'Range => Model_Device.Peek (16#0800_0000# + DFU.Address (I)) = Sector_0 (I))
        and then (for all I in Code'Range => Model_Device.Peek (16#0800_8000# + DFU.Address (I)) = Code (I));
      Check ("images in flash", Flashed);
      Check ("configuration page kept",
             (for all I in 0 .. 16 * 1024 - 1 => Model_Device.Peek (16#0800_4000# + DFU.Address (I)) = 16#C3#));
      Check ("erased past the images", Model_Device.Peek (16#0800_0BB8#) = 16#FF#
                                       and then Model_Device.Peek (16#0805_13E0#) = 16#FF#
                                       and then Model_Device.Peek (16#0805_FFFF#) = 16#FF#);
      Check ("pages past the images kept", Model_Device.Peek (16#0806_0000#) = 16#5A#);
      Check ("erased pages", Model_Device.Erased_Pages = 6);
      Check ("left at the flash start", Model_Device.Left and then Model_Device.Left_At = 16#0800_0000#);

      Model_Device.Reset (Model_Device.F722, Transfer => 1024);
      Run (False, 0, Reached, Failed, Transfer);
      Check ("flash F722 in 1 KB blocks", Reached = Started and then Transfer = 1024
                                         and then Model_Device.Peek (16#0805_13DF#) = Code (Code'Last));

      Model_Device.Reset (Model_Device.F405);
      Model_Device.Set_Stuck_Erases (2);
      Run (False, 0, Reached, Failed, Transfer);
      Check ("erase stuck busy", Reached = Started and then Model_Device.Erased_Pages = 6);

      Model_Device.Reset (Model_Device.F405);
      Model_Device.Set_Busy_Reads (5);
      Run (False, 0, Reached, Failed, Transfer);
      Check ("write busy for some reads", Reached = Started);

      Model_Device.Reset (Model_Device.F405);
      Model_Device.Set_Busy_Reads (DFU.Session.Slack + 10);
      Run (False, 0, Reached, Failed, Transfer);
      Check ("write busy past its poll time", Reached = Erased);

      Model_Device.Reset (Model_Device.F405);
      Model_Device.Out_Request (9, 0, (1 .. 0 => 0), Sent);
      Check ("model in error", not Sent);
      Run (False, 0, Reached, Failed, Transfer);
      Check ("cleared from error", Reached = Started);

      Model_Device.Reset (Model_Device.F405);
      Run (True, 0, Reached, Failed, Transfer);
      Check ("unerased flash fails verify", Reached = Written and then Failed = 16#0800_0000#);

      Model_Device.Reset (Model_Device.F405);
      Run (False, 16#0800_83E8#, Reached, Failed, Transfer);
      Check ("flipped bit found", Reached = Written and then Failed = 16#0800_83E8#
                                  and then not Model_Device.Left);

      Model_Device.Reset (Model_Device.F405);
      Model_Device.Set_Protected (True);
      Run (False, 0, Reached, Failed, Transfer);
      Check ("protected flash left alone", Reached = Cleared and then Model_Device.Peek (16#0800_0000#) = 16#5A#);

      Model_Device.Reset (Model_Device.F405);
      Model_Device.Set_Present (False);
      Run (False, 0, Reached, Failed, Transfer);
      Check ("no device", Reached = None);
   end Flashes;

   procedure Protections is
      M        : Memory;
      Options  : Memory;
      Has      : Boolean;
      Ok       : Boolean;
      Transfer : Transfer_Size;
      Guard    : Protection;
   begin
      Model_Device.Reset (Model_Device.F405);
      DFU.Transport.Open (Ok);
      Read_Layout (M, Options, Has, Transfer, Ok);
      Check ("option bytes found", Ok and then Has and then Options.First (1) = 16#1FFF_C000#
                                   and then Options.Last (1) = 16#1FFF_C00F#);
      Check ("option bytes name", Is_Option_Bytes (Options) and then not Is_Option_Bytes (M));
      Check_Protection (Options, Guard);
      Check ("readable", Guard = Readable);
      Model_Device.Set_Protected (True);
      Check_Protection (Options, Guard);
      Check ("read protected", Guard = Read_Protected);
      Unprotect (Ok);
      Check ("unprotected", Ok and then not Model_Device.Is_Protected
                            and then Model_Device.Peek (16#0800_4000#) = 16#FF#);
   end Protections;

begin
   Layouts;
   Configurations;
   Strings;
   Plans;
   Actions;
   Protections;
   Flashes;
   if Failures = 0 then
      Put_Line ("dfu checks passed");
   else
      Put_Line ("dfu checks:" & Natural'Image (Failures) & " failed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end DFU_Check;
