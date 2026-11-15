with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Mass_Storage;
with Adaflight.Pins;
with Adaflight.STM32.Flash_Chip;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.MCU;
with Adaflight.STM32.SD;
with Adaflight.STM32.Status_LED;
with Adaflight.STM32.Time;
with Adaflight.STM32.USB_Storage;
with Adaflight.USB_Device;
with Adaflight.USB_MSC;
with Adaflight.Virtual_FAT.Disk;
with Adaflight.Virtual_FAT.Logs;
package body Adaflight.STM32.Mass_Storage_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;

   package FAT renames Adaflight.Virtual_FAT;
   package Storage renames Adaflight.STM32.USB_Storage;
   package USB renames Adaflight.USB_Device;
   use type Storage.Event;

   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Flash_Device  : constant := 1;
   Card_Device   : constant := 2;
   Buffer_Blocks : constant := 1;
   --  A file's date without a clock: 2018-01-01 13:00:00 as a FAT entry
   --  packs it.
   Default_Time  : constant Unsigned_32 := 1_277_257_728;
   Activity_Ms   : constant := 50;
   Debounce_Ms   : constant := 20;
   Label         : constant String := "ADAFLT";

   Last_Active : Unsigned_32 := 0;
   Next_Toggle : Unsigned_32 := 0;
   --  Whether the storage is the SD card, a flash chip's logs otherwise.
   Use_Card    : Boolean := False;

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

   --  A card starts here, at a host's configuration, and is polled until
   --  it is ready, absent or failed.
   procedure Start_Storage is
   begin
      Adaflight.STM32.Status_LED.Set (0, False);
      if Use_Card then
         Adaflight.STM32.SD.Raw_Start;
         Last_Active := Adaflight.STM32.Time.Millis;
      end if;
   end Start_Storage;

   procedure Storage_Ready (OK : out Boolean) is
   begin
      if Use_Card then
         Adaflight.STM32.SD.Raw_Ready (OK);
      else
         OK := True;
      end if;
   end Storage_Ready;

   --  A flash chip's logs are read-only, and a card takes writes.
   procedure Write_Protected (Yes : out Boolean) is
   begin
      Yes := not Use_Card;
   end Write_Protected;

   procedure Write_Blocks (First : Unsigned_32; Count : Natural; Data : Byte_Array; OK : out Boolean) is
      Size : constant := Adaflight.STM32.SD.Block_Size;
   begin
      OK := Use_Card and then Data'Length >= Count * Size;
      if OK then
         for K in 0 .. Count - 1 loop
            Adaflight.STM32.SD.Raw_Write
              (First + Unsigned_32 (K), Data (Data'First + K * Size .. Data'First + K * Size + Size - 1), OK);
            exit when not OK;
         end loop;
         Last_Active := Adaflight.STM32.Time.Millis;
      end if;
   end Write_Blocks;

   function Text (S : String) return Byte_Array is
      Result : Byte_Array (0 .. S'Length - 1);
   begin
      for K in Result'Range loop
         Result (K) := Character'Pos (S (S'First + K));
      end loop;
      return Result;
   end Text;

   Card_Inquiry : constant Adaflight.Mass_Storage.Inquiry_Bytes :=
     Byte_Array'(16#00#, 16#80#, 16#02#, 16#02#, Adaflight.Mass_Storage.Inquiry_Length - 5, 0, 0, 0)
     & Text ("ADAFLT  ") & Text ("SD Card         ") & Text ("0.01");

   Inquiry : constant Adaflight.Mass_Storage.Inquiry_Bytes :=
     (16#00#, 16#80#, 16#02#, 16#02#, Adaflight.Mass_Storage.Inquiry_Length - 5, 0, 0, 0,
      Character'Pos ('A'), Character'Pos ('D'), Character'Pos ('A'), Character'Pos ('F'), Character'Pos ('L'),
      Character'Pos ('T'), 32, 32,
      Character'Pos ('O'), Character'Pos ('n'), Character'Pos ('b'), Character'Pos ('o'), Character'Pos ('a'),
      Character'Pos ('r'), Character'Pos ('d'), 32, Character'Pos ('F'), Character'Pos ('l'), Character'Pos ('a'),
      Character'Pos ('s'), Character'Pos ('h'), 32, 32, 32,
      32, 32, 32, 32);

   function Ready (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (Storage.Available
      and then ((C.Blackbox_Config.Device = Flash_Device and then Adaflight.STM32.Flash_Chip.Supported)
                or else (C.Blackbox_Config.Device = Card_Device and then Adaflight.STM32.SD.Functional)));

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
         Adaflight.STM32.Status_LED.Set (0, False);
         Next_Toggle := 0;
      elsif Since (Now, Next_Toggle) > 0 then
         Adaflight.STM32.Status_LED.Toggle (0);
         Next_Toggle := Now + Activity_Ms;
      end if;
   end Activity_LED;

   procedure Run (C : Adaflight.Config_Groups.Configuration; Time_Ms : Interfaces.Unsigned_64) is
      --  The disk's state is large and used in this mode alone, which never
      --  returns, so it is on this procedure's stack.
      Volume : FAT.Volume;

      --  A card that is absent or failed has no capacity.
      procedure Capacity (Blocks : out Unsigned_32; OK : out Boolean) is
      begin
         if Use_Card then
            Adaflight.STM32.SD.Raw_Ready (OK);
            Blocks := (if OK then Adaflight.STM32.SD.Block_Count else 0);
         else
            Blocks := Volume.Disk_Sectors;
            OK := True;
         end if;
      end Capacity;

      procedure Read_Blocks (First : Unsigned_32; Count : Natural; Data : in out Byte_Array; OK : out Boolean) is
         Size : constant := Adaflight.STM32.SD.Block_Size;
      begin
         Last_Active := Adaflight.STM32.Time.Millis;
         if Use_Card then
            OK := Data'Length >= Count * Size;
            if OK then
               for K in 0 .. Count - 1 loop
                  Adaflight.STM32.SD.Raw_Read
                    (First + Unsigned_32 (K), Data (Data'First + K * Size .. Data'First + K * Size + Size - 1), OK);
                  exit when not OK;
               end loop;
            end if;
            return;
         end if;
         OK :=
           FAT.Ready (Volume) and then Count <= Disk.Max_Run and then Data'First = 0
           and then Data'Length >= Count * FAT.Sector_Size;
         if OK then
            Disk.Read (Volume, First, Count, Data);
         end if;
      end Read_Blocks;

      package MSC is new Adaflight.USB_MSC
        (Buffer_Blocks   => Buffer_Blocks,
         Inquiry         => (if C.Blackbox_Config.Device = Card_Device then Card_Inquiry else Inquiry),
         Start_Storage   => Start_Storage,
         Capacity        => Capacity,
         Ready           => Storage_Ready,
         Write_Protected => Write_Protected,
         Read_Blocks     => Read_Blocks,
         Write_Blocks    => Write_Blocks);

      Device : MSC.Device;
      Packet : Byte_Array (0 .. USB.Packet_Size - 1) := (others => 0);

      Used    : constant Unsigned_32 := Unsigned_32'Min (Adaflight.STM32.Flash_Chip.Offset, Logs.Max_Used);
      Mounted : constant Unsigned_32 :=
        (if Time_Ms = 0 then Default_Time else FAT.Packed_Time (Unsigned_32 (Time_Ms / 1_000 mod 2 ** 32)));
      Id      : constant Adaflight.STM32.MCU.Identifier := Adaflight.STM32.MCU.UID;
      OK      : Boolean;
      What    : Storage.Event;
      EP      : USB.Endpoint_Number;
      Count   : Natural;
      Work    : USB.Actions;
   begin
      Adaflight.STM32.Status_LED.Set (0, False);
      Volume.Entries (1).Dir := True;
      Volume.Label (1 .. Label'Length) := Label;
      Volume.Label_Length := Label'Length;
      Use_Card := C.Blackbox_Config.Device = Card_Device;
      if Use_Card then
         OK := Adaflight.STM32.SD.Configured;
      else
         Logs.Build (Volume, Predefined => 1, Used => Used, Prefix => Prefix, Mounted => Mounted, OK => OK);
         OK := OK and then C.Blackbox_Config.Device = Flash_Device;
      end if;
      if not OK or else not Storage.Available then
         Adaflight.STM32.MCU.Reset;
      end if;
      MSC.Init (Device, "Adaflight (" & Adaflight.Board.Board_Name & ") MSC", (Id (1), Id (2), Id (3)));
      Storage.Start;
      while Button_Pressed (C) loop
         null;
      end loop;
      Adaflight.STM32.Time.Delay_Ms (Debounce_Ms);
      loop
         USB.Clear (Work);
         Storage.Next (What, EP, Packet, Count);
         case What is
            when Storage.Nothing =>
               null;
            when Storage.Bus_Reset =>
               MSC.Reset (Device, Work);
            when Storage.Setup =>
               MSC.Setup (Device, Packet (0 .. 7), Work);
            when Storage.Packet_Out =>
               MSC.Data_Out (Device, EP, Packet (0 .. Natural'Min (Count, Packet'Length) - 1), Work);
            when Storage.Packet_In =>
               MSC.Data_In (Device, EP, Work);
            when Storage.Suspend =>
               MSC.Suspend (Device);
            when Storage.Resume =>
               MSC.Resume (Device);
         end case;
         if What /= Storage.Nothing then
            Storage.Execute (Work);
         end if;
         if Button_Pressed (C) then
            Adaflight.STM32.MCU.Reset;
         end if;
         Activity_LED;
      end loop;
   end Run;
end Adaflight.STM32.Mass_Storage_Mode;
