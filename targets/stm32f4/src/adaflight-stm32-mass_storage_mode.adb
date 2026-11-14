with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Mass_Storage.Engine;
with Adaflight.Pins;
with Adaflight.STM32.Flash_Chip;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.MCU;
with Adaflight.STM32.Time;
with Adaflight.STM32.USB_Storage;
with Adaflight.Virtual_FAT.Disk;
with Adaflight.Virtual_FAT.Logs;
package body Adaflight.STM32.Mass_Storage_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;
   use type Adaflight.Mass_Storage.Receive_Kind;

   package FAT renames Adaflight.Virtual_FAT;
   package Storage renames Adaflight.STM32.USB_Storage;

   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Flash_Device  : constant := 1;
   Buffer_Blocks : constant := 1;
   --  A file's date without a clock: 2018-01-01 13:00:00 as a FAT entry
   --  packs it.
   Default_Time  : constant Unsigned_32 := 1_277_257_728;
   Activity_Ms   : constant := 50;
   Debounce_Ms   : constant := 20;
   Label         : constant String := "ADAFLT";

   Last_Active : Unsigned_32 := 0;
   Next_Toggle : Unsigned_32 := 0;

   --  A signed distance between two millisecond counts, as the counter wraps.
   function Since (Now, Before : Unsigned_32) return Interfaces.Integer_32 is
      Distance : constant Unsigned_32 := Now - Before;
   begin
      return (if Distance < 2 ** 31 then Interfaces.Integer_32 (Distance)
              else -Interfaces.Integer_32 (Unsigned_32'Last - Distance) - 1);
   end Since;

   procedure Read_Start (Offset : Unsigned_32; Data : out FAT.Flash_Read) is
   begin
      Adaflight.STM32.Flash_Chip.Read (Offset, Data);
   end Read_Start;

   procedure Read_Sector (File : FAT.Entry_Index; Offset : Unsigned_32; Data : out FAT.Sector) is
      pragma Unreferenced (File);
   begin
      Adaflight.STM32.Flash_Chip.Read (Offset, Data);
   end Read_Sector;

   package Logs is new FAT.Logs (Read => Read_Start);
   package Disk is new FAT.Disk (Read_File => Read_Sector);

   Prefix : constant Logs.Prefix_Text := "ADFL";

   procedure Start_Storage is
   begin
      Adaflight.STM32.GPIO.Set_High (Adaflight.Board.LED0_Pin);
   end Start_Storage;

   procedure Storage_Ready (OK : out Boolean) is
   begin
      OK := True;
   end Storage_Ready;

   procedure Write_Protected (Yes : out Boolean) is
   begin
      Yes := True;
   end Write_Protected;

   procedure Write_Blocks (First : Unsigned_32; Count : Natural; Data : Byte_Array; OK : out Boolean) is
      pragma Unreferenced (First, Count, Data);
   begin
      OK := False;
   end Write_Blocks;

   Inquiry : constant Adaflight.Mass_Storage.Inquiry_Bytes :=
     (16#00#, 16#80#, 16#02#, 16#02#, Adaflight.Mass_Storage.Inquiry_Length - 5, 0, 0, 0,
      Character'Pos ('A'), Character'Pos ('D'), Character'Pos ('A'), Character'Pos ('F'), Character'Pos ('L'),
      Character'Pos ('T'), 32, 32,
      Character'Pos ('O'), Character'Pos ('n'), Character'Pos ('b'), Character'Pos ('o'), Character'Pos ('a'),
      Character'Pos ('r'), Character'Pos ('d'), 32, Character'Pos ('F'), Character'Pos ('l'), Character'Pos ('a'),
      Character'Pos ('s'), Character'Pos ('h'), 32, 32, 32,
      32, 32, 32, 32);

   function Ready (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (Storage.Available and then C.Blackbox_Config.Device = Flash_Device
      and then Adaflight.STM32.Flash_Chip.Supported);

   function Has_Button (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (C.Usb_Dev_Config.Msc_Button_Pin / 16 in 1 .. Adaflight.Pins.Port_Name'Pos (Adaflight.Pins.Port_Name'Last) + 1);

   function Button (C : Adaflight.Config_Groups.Configuration) return Adaflight.Pins.Pin is
     ((Port   => Adaflight.Pins.Port_Name'Val (Natural (C.Usb_Dev_Config.Msc_Button_Pin / 16) - 1),
       Number => Adaflight.Pins.Pin_Number (C.Usb_Dev_Config.Msc_Button_Pin mod 16)))
     with Pre => Has_Button (C);

   procedure Init_Button (C : Adaflight.Config_Groups.Configuration) is
   begin
      if Has_Button (C) then
         Adaflight.STM32.GPIO.Enable_Port (Button (C).Port);
         Adaflight.STM32.GPIO.Set_Input
           (Button (C),
            (if C.Usb_Dev_Config.Msc_Button_Use_Pullup /= 0 then Adaflight.STM32.GPIO.Up
             else Adaflight.STM32.GPIO.Down));
      end if;
   end Init_Button;

   function Button_Pressed (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (Storage.Available and then Has_Button (C)
      and then Adaflight.STM32.GPIO.Is_High (Button (C)) = (C.Usb_Dev_Config.Msc_Button_Use_Pullup = 0));

   --  The LED off after 50 milliseconds without a read, and toggled every
   --  50 milliseconds while reads go on.
   procedure Activity_LED is
      Now : constant Unsigned_32 := Adaflight.STM32.Time.Millis;
   begin
      if Since (Now, Last_Active) > Activity_Ms then
         Adaflight.STM32.GPIO.Set_High (Adaflight.Board.LED0_Pin);
         Next_Toggle := 0;
      elsif Since (Now, Next_Toggle) > 0 then
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
         Next_Toggle := Now + Activity_Ms;
      end if;
   end Activity_LED;

   procedure Run (C : Adaflight.Config_Groups.Configuration; Time_Ms : Interfaces.Unsigned_64) is
      --  The disk's state is large and used in this mode alone, which never
      --  returns, so it is on this procedure's stack.
      Volume : FAT.Volume;

      procedure Capacity (Blocks : out Unsigned_32; OK : out Boolean) is
      begin
         Blocks := Volume.Disk_Sectors;
         OK := True;
      end Capacity;

      procedure Read_Blocks (First : Unsigned_32; Count : Natural; Data : in out Byte_Array; OK : out Boolean) is
      begin
         Last_Active := Adaflight.STM32.Time.Millis;
         OK :=
           FAT.Ready (Volume) and then Count <= Disk.Max_Run and then Data'First = 0
           and then Data'Length >= Count * FAT.Sector_Size;
         if OK then
            Disk.Read (Volume, First, Count, Data);
         end if;
      end Read_Blocks;

      package Engine is new Adaflight.Mass_Storage.Engine
        (Buffer_Blocks   => Buffer_Blocks,
         Inquiry         => Inquiry,
         Start_Storage   => Start_Storage,
         Capacity        => Capacity,
         Ready           => Storage_Ready,
         Write_Protected => Write_Protected,
         Read_Blocks     => Read_Blocks,
         Write_Blocks    => Write_Blocks);

      Session : Engine.Session;
      Packet  : Byte_Array (0 .. Engine.Buffer_Size - 1) := (others => 0);

      --  The endpoint work an event left, in the engine's order.
      procedure Apply (Work : Adaflight.Mass_Storage.Actions) is
      begin
         if Work.Flush then
            Storage.Flush;
         end if;
         if Work.Halt_Out then
            Storage.Halt_Out;
         end if;
         if Work.Halt_In then
            Storage.Halt_In;
         end if;
         case Work.Send is
            when Adaflight.Mass_Storage.Nothing =>
               null;
            when Adaflight.Mass_Storage.Data =>
               Storage.Send (Session.Data (0 .. Work.Send_Length - 1));
            when Adaflight.Mass_Storage.Status =>
               Storage.Send (Engine.Status_Wrapper (Session));
         end case;
         if Work.Receive /= Adaflight.Mass_Storage.Nothing then
            Storage.Receive (Work.Receive_Length);
         end if;
      end Apply;

      Used    : constant Unsigned_32 := Unsigned_32'Min (Adaflight.STM32.Flash_Chip.Offset, Logs.Max_Used);
      Mounted : constant Unsigned_32 :=
        (if Time_Ms = 0 then Default_Time else FAT.Packed_Time (Unsigned_32 (Time_Ms / 1_000 mod 2 ** 32)));
      OK      : Boolean;
      What    : Storage.Event;
      Count   : Natural;
      Work    : Adaflight.Mass_Storage.Actions;
   begin
      Adaflight.STM32.GPIO.Set_High (Adaflight.Board.LED0_Pin);
      Volume.Entries (1).Dir := True;
      Volume.Label (1 .. Label'Length) := Label;
      Volume.Label_Length := Label'Length;
      Logs.Build (Volume, Predefined => 1, Used => Used, Prefix => Prefix, Mounted => Mounted, OK => OK);
      if not OK or else not Storage.Available or else C.Blackbox_Config.Device /= Flash_Device then
         Adaflight.STM32.MCU.Reset;
      end if;
      Storage.Start ("Adaflight (" & Adaflight.Board.Board_Name & ")");
      while Button_Pressed (C) loop
         null;
      end loop;
      Adaflight.STM32.Time.Delay_Ms (Debounce_Ms);
      loop
         Work := (others => <>);
         Storage.Next (What, Packet, Count);
         case What is
            when Storage.Nothing =>
               null;
            when Storage.Started =>
               Engine.Start (Session, Work);
            when Storage.Transport_Reset =>
               Engine.Reset (Session, Work);
            when Storage.Stopped =>
               Engine.Stop (Session);
            when Storage.Packet_Out =>
               if Session.Receiving /= Adaflight.Mass_Storage.Nothing then
                  Engine.Packet_Out (Session, Packet (0 .. Natural'Min (Count, Packet'Length) - 1), Work);
               end if;
            when Storage.Packet_In =>
               Engine.Packet_In (Session, Work);
            when Storage.Cleared_In =>
               Engine.Halt_Cleared (Session, In_Endpoint => True, Next => Work);
            when Storage.Cleared_Out =>
               Engine.Halt_Cleared (Session, In_Endpoint => False, Next => Work);
         end case;
         Apply (Work);
         if Button_Pressed (C) then
            Adaflight.STM32.MCU.Reset;
         end if;
         Activity_LED;
      end loop;
   end Run;
end Adaflight.STM32.Mass_Storage_Mode;
