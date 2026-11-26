--  The full-speed OTG controller in device mode, polled. No interrupt of the
--  controller runs in mass storage mode: each call of Next reads its status,
--  does the controller's own part of what it finds, and reports one event.
--  The register sequences are those of the USB serial port's driver.
with System;
with Interfaces;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
with Adaflight.STM32.Time;
with Adaflight.STM32.Memory;
package body Adaflight.STM32.USB_Storage is
   package U renames Adaflight.USB_Device;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   function Shift_Left (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Left;
   function Shift_Right (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Right;
   package GPIO renames Adaflight.STM32.GPIO;

   Base : constant := Adaflight.STM32.Memory.OTG_FS_Base;

   GOTGCTL    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#000#);
   GOTGINT    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#004#);
   GAHBCFG    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#008#);
   GUSBCFG    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#00C#);
   GRSTCTL    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#010#);
   GINTSTS    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#014#);
   GINTMSK    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#018#);
   GRXSTSP    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#020#);
   GRXFSIZ    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#024#);
   DIEPTXF0   : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#028#);
   GCCFG      : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#038#);
   DIEPTXF1   : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#104#);
   DIEPTXF2   : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#108#);
   DIEPTXF3   : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#10C#);
   DCFG       : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#800#);
   DCTL       : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#804#);
   DIEPMSK    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#810#);
   DOEPMSK    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#814#);
   DAINT      : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#818#);
   DAINTMSK   : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#81C#);
   DIEPEMPMSK : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#834#);
   PCGCCTL    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#E00#);
   RCC_USB_ENR    : Unsigned_32
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.RCC_USB_Enable);
   RCC_SYSCFG_ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (Adaflight.STM32.Memory.RCC_SYSCFG_Enable);

   subtype Number is U.Endpoint_Number;

   --  An endpoint's register block: control, interrupt, transfer size and,
   --  for an IN endpoint, the free words of its transmit FIFO.
   type Endpoint_Registers is record
      CTL    : Unsigned_32;
      INT    : Unsigned_32;
      TSIZ   : Unsigned_32;
      TXFSTS : Unsigned_32;
      Spare  : Unsigned_32;
   end record with Volatile;
   for Endpoint_Registers use record
      CTL    at 16#00# range 0 .. 31;
      INT    at 16#08# range 0 .. 31;
      TSIZ   at 16#10# range 0 .. 31;
      TXFSTS at 16#18# range 0 .. 31;
      Spare  at 16#1C# range 0 .. 31;
   end record;
   for Endpoint_Registers'Size use 256;
   type Endpoint_Blocks is array (Number) of Endpoint_Registers;
   IN_EP  : Endpoint_Blocks with Volatile, Import, Address => System'To_Address (Base + 16#900#);
   OUT_EP : Endpoint_Blocks with Volatile, Import, Address => System'To_Address (Base + 16#B00#);

   GINTMSK_GLOBAL : constant Unsigned_32 := 2 ** 0;
   PHYSEL         : constant Unsigned_32 := 2 ** 6;
   TRDT           : constant Unsigned_32 := 16#F# * 2 ** 10;
   FORCE_HOST     : constant Unsigned_32 := 2 ** 29;
   FORCE_DEVICE   : constant Unsigned_32 := 2 ** 30;
   CSRST          : constant Unsigned_32 := 2 ** 0;
   RXFFLSH        : constant Unsigned_32 := 2 ** 4;
   TXFFLSH        : constant Unsigned_32 := 2 ** 5;
   AHBIDL         : constant Unsigned_32 := 2 ** 31;
   CMOD           : constant Unsigned_32 := 2 ** 0;
   RXFLVL         : constant Unsigned_32 := 2 ** 4;
   USBSUSP        : constant Unsigned_32 := 2 ** 11;
   USBRST         : constant Unsigned_32 := 2 ** 12;
   ENUMDNE        : constant Unsigned_32 := 2 ** 13;
   IEPINT         : constant Unsigned_32 := 2 ** 18;
   OEPINT         : constant Unsigned_32 := 2 ** 19;
   IISOIXFR       : constant Unsigned_32 := 2 ** 20;
   IPXFR          : constant Unsigned_32 := 2 ** 21;
   WKUPINT        : constant Unsigned_32 := 2 ** 31;
   SDIS           : constant Unsigned_32 := 2 ** 1;
   PWRDWN         : constant Unsigned_32 := 2 ** 16;
   NOVBUSSENS     : constant Unsigned_32 := 2 ** 21;
   B_VALID_SET    : constant Unsigned_32 := 2 ** 6 or 2 ** 7;
   DSPD_FULL      : constant Unsigned_32 := 3;
   PFIVL          : constant Unsigned_32 := 3 * 2 ** 11;
   DAD            : constant Unsigned_32 := 16#7F# * 2 ** 4;
   RWUSIG         : constant Unsigned_32 := 2 ** 0;
   TCTL           : constant Unsigned_32 := 7 * 2 ** 4;
   CGINAK         : constant Unsigned_32 := 2 ** 8;
   XFRC           : constant Unsigned_32 := 2 ** 0;
   EPDISD         : constant Unsigned_32 := 2 ** 1;
   STUP           : constant Unsigned_32 := 2 ** 3;
   TOC            : constant Unsigned_32 := 2 ** 3;
   ITTXFE         : constant Unsigned_32 := 2 ** 4;
   INEPNE         : constant Unsigned_32 := 2 ** 6;
   TXFE           : constant Unsigned_32 := 2 ** 7;
   TXFURM         : constant Unsigned_32 := 2 ** 8;
   MPSIZ          : constant Unsigned_32 := 16#7FF#;
   USBAEP         : constant Unsigned_32 := 2 ** 15;
   STALL          : constant Unsigned_32 := 2 ** 21;
   CNAK           : constant Unsigned_32 := 2 ** 26;
   SNAK           : constant Unsigned_32 := 2 ** 27;
   SD0PID         : constant Unsigned_32 := 2 ** 28;
   EPDIS          : constant Unsigned_32 := 2 ** 30;
   EPENA          : constant Unsigned_32 := 2 ** 31;
   XFRSIZ         : constant Unsigned_32 := 16#7_FFFF#;
   PKTCNT         : constant Unsigned_32 := 16#3FF# * 2 ** 19;

   --  The 48 MHz full-speed pins.
   DM : constant Pin := (Port => Port_A, Number => 11);
   DP : constant Pin := (Port => Port_A, Number => 12);

   procedure Wait_Clear (Bit : Unsigned_32) is
   begin
      for Count in 1 .. 200_000 loop
         exit when (GRSTCTL and Bit) = 0;
      end loop;
      Adaflight.STM32.Time.Delay_Us (3);
   end Wait_Clear;

   --  The core's soft reset once its AHB master is idle.
   procedure Core_Reset is
   begin
      for Count in 1 .. 200_000 loop
         Adaflight.STM32.Time.Delay_Us (3);
         exit when (GRSTCTL and AHBIDL) /= 0;
      end loop;
      GRSTCTL := GRSTCTL or CSRST;
      Wait_Clear (CSRST);
   end Core_Reset;

   procedure Flush_Tx (FIFO : Unsigned_32) is
   begin
      GRSTCTL := TXFFLSH or Shift_Left (FIFO, 6);
      Wait_Clear (TXFFLSH);
   end Flush_Tx;

   procedure Flush_Rx is
   begin
      GRSTCTL := RXFFLSH;
      Wait_Clear (RXFFLSH);
   end Flush_Rx;

   --  An endpoint's packet in progress: the bytes, their count and the bytes
   --  the transmit FIFO took.
   type Packet_State is record
      Data    : Byte_Array (0 .. U.Packet_Size - 1) := (others => 0);
      Count   : U.Packet_Count := 0;
      Written : U.Packet_Count := 0;
   end record;
   type Packets is array (Number) of Packet_State;
   type Kinds is array (Number) of U.Endpoint_Kind;
   type Sizes is array (Number) of U.Packet_Limit;

   Setup_Data : U.Setup_Packet := (others => 0);
   Received   : Packets;
   Sending    : Packets;
   In_Kinds   : Kinds := (others => U.Control);
   Out_Kinds  : Kinds := (others => U.Control);
   In_Sizes   : Sizes := (others => U.Packet_Size);
   Out_Sizes  : Sizes := (others => U.Packet_Size);
   --  A setup packet's flag stays set until its event's operations are done.
   Setup_Waits : Boolean := False;
   Setup_From  : Number := 0;

   function Available return Boolean is (True);

   --  The FIFO's free words above the packet's rest take the rest.
   procedure Write_Empty_Tx_Fifo (N : Number) is
      P     : Packet_State renames Sending (N);
      FIFO  : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#1000# * (N + 1));
      Words : Unsigned_32;
      Word  : Unsigned_32;
      Rest  : Natural;
   begin
      while P.Count /= 0 and then P.Written < P.Count loop
         Rest := P.Count - P.Written;
         Words := Unsigned_32 ((Rest + 3) / 4);
         exit when (IN_EP (N).TXFSTS and 16#FFFF#) <= Words;
         for K in 0 .. Natural (Words) - 1 loop
            Word := 0;
            for B in 0 .. 3 loop
               if P.Written + 4 * K + B < P.Count then
                  Word := Word or Shift_Left (Unsigned_32 (P.Data (P.Written + 4 * K + B)), 8 * B);
               end if;
            end loop;
            FIFO := Word;
         end loop;
         P.Written := P.Count;
         DIEPEMPMSK := DIEPEMPMSK and not Shift_Left (1, N);
      end loop;
   end Write_Empty_Tx_Fifo;

   procedure Execute (A : U.Actions) is
   begin
      for K in 1 .. A.Count loop
         declare
            X : U.Action renames A.List (K);
            N : constant Number := Natural (X.Address and 16#7F#) mod U.Endpoint_Count;
            In_Dir : constant Boolean := (X.Address and 16#80#) /= 0;
            Bit : constant Unsigned_32 := (if In_Dir then Shift_Left (1, N) else Shift_Left (1, 16 + N));
            Control : Unsigned_32;
            Size : Unsigned_32;
         begin
            case X.Kind is
               when U.Open_Endpoint =>
                  if In_Dir then
                     In_Kinds (N) := X.EP_Kind;
                     In_Sizes (N) := Natural'Max (X.Length, 1);
                     Control := IN_EP (N).CTL;
                     if (Control and USBAEP) = 0 then
                        IN_EP (N).CTL := (Control and not (MPSIZ or 3 * 2 ** 18 or 16#F# * 2 ** 22))
                          or Unsigned_32 (X.Length) or Shift_Left (Unsigned_32 (U.Endpoint_Kind'Pos (X.EP_Kind)), 18)
                          or Shift_Left (Unsigned_32 (N), 22) or SD0PID or USBAEP;
                     end if;
                  else
                     Out_Kinds (N) := X.EP_Kind;
                     Out_Sizes (N) := Natural'Max (X.Length, 1);
                     Control := OUT_EP (N).CTL;
                     if (Control and USBAEP) = 0 then
                        OUT_EP (N).CTL := (Control and not (MPSIZ or 3 * 2 ** 18))
                          or Unsigned_32 (X.Length) or Shift_Left (Unsigned_32 (U.Endpoint_Kind'Pos (X.EP_Kind)), 18)
                          or SD0PID or USBAEP;
                     end if;
                  end if;
                  DAINTMSK := DAINTMSK or Bit;
               when U.Close_Endpoint =>
                  if In_Dir then
                     IN_EP (N).CTL := 0;
                  else
                     OUT_EP (N).CTL := 0;
                  end if;
                  DAINTMSK := DAINTMSK and not Bit;
               when U.Flush_Endpoint =>
                  if In_Dir then
                     Flush_Tx (Unsigned_32 (N));
                  else
                     Flush_Rx;
                  end if;
               when U.Prepare_Receive =>
                  Received (N).Count := 0;
                  if N = 0 then
                     OUT_EP (0).TSIZ := (OUT_EP (0).TSIZ and not (XFRSIZ or PKTCNT))
                       or Unsigned_32 (Out_Sizes (0)) or Shift_Left (1, 19);
                  elsif X.Length = 0 then
                     OUT_EP (N).TSIZ := (OUT_EP (N).TSIZ and not (XFRSIZ or PKTCNT))
                       or Unsigned_32 (Out_Sizes (N)) or Shift_Left (1, 19);
                  else
                     Size := Unsigned_32 ((X.Length + Out_Sizes (N) - 1) / Out_Sizes (N));
                     OUT_EP (N).TSIZ := (OUT_EP (N).TSIZ and not (XFRSIZ or PKTCNT))
                       or (Size * Unsigned_32 (Out_Sizes (N))) or Shift_Left (Size, 19);
                  end if;
                  OUT_EP (N).CTL := OUT_EP (N).CTL or CNAK or EPENA;
               when U.Transmit =>
                  Sending (N) := (Data => X.Data, Count => X.Count, Written => 0);
                  if X.Count = 0 then
                     IN_EP (N).TSIZ := (IN_EP (N).TSIZ and not (XFRSIZ or PKTCNT)) or Shift_Left (1, 19);
                  else
                     Size := Unsigned_32 ((X.Count - 1 + In_Sizes (N)) / In_Sizes (N));
                     IN_EP (N).TSIZ := (IN_EP (N).TSIZ and not (XFRSIZ or PKTCNT))
                       or Unsigned_32 (X.Count) or Shift_Left ((if N = 0 then Unsigned_32'(1) else Size), 19);
                  end if;
                  if N /= 0 and then X.Count > 0 then
                     DIEPEMPMSK := DIEPEMPMSK or Shift_Left (1, N);
                  end if;
                  IN_EP (N).CTL := IN_EP (N).CTL or CNAK or EPENA;
                  if N = 0 and then X.Count > 0 then
                     DIEPEMPMSK := DIEPEMPMSK or 1;
                  end if;
               when U.Stall_Endpoint =>
                  if In_Dir then
                     Control := IN_EP (N).CTL;
                     if (Control and EPENA) /= 0 then
                        Control := Control or EPDIS;
                     end if;
                     IN_EP (N).CTL := Control or STALL;
                  else
                     OUT_EP (N).CTL := OUT_EP (N).CTL or STALL;
                  end if;
               when U.Clear_Stall =>
                  if In_Dir then
                     Control := IN_EP (N).CTL and not STALL;
                     if In_Kinds (N) in U.Bulk | U.Interrupt then
                        Control := Control or SD0PID;
                     end if;
                     IN_EP (N).CTL := Control;
                  else
                     Control := OUT_EP (N).CTL and not STALL;
                     if Out_Kinds (N) in U.Bulk | U.Interrupt then
                        Control := Control or SD0PID;
                     end if;
                     OUT_EP (N).CTL := Control;
                  end if;
               when U.Set_Address =>
                  DCFG := (DCFG and not DAD) or Shift_Left (Unsigned_32 (X.Address and 16#7F#), 4);
               when U.Arm_Setup =>
                  OUT_EP (0).TSIZ := Shift_Left (3, 29) or Shift_Left (1, 19) or 24;
               when U.Enter_Test_Mode =>
                  DCTL := (DCTL and not TCTL) or Shift_Left (Unsigned_32 (X.Address and 7), 4);
            end case;
         end;
      end loop;
      if Setup_Waits then
         OUT_EP (Setup_From).INT := STUP;
         Setup_Waits := False;
      end if;
   end Execute;

   --  The receive FIFO's next entry: an OUT packet's bytes into its
   --  endpoint's buffer as far as they fit, or a setup packet.
   procedure Receive_Queue is
      Status : Unsigned_32;
      FIFO   : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#1000#);
      N      : Natural;
      Count  : Natural;
      Word   : Unsigned_32;
   begin
      GINTMSK := GINTMSK and not RXFLVL;
      Status := GRXSTSP;
      N := Natural (Status and 16#F#);
      Count := Natural (Shift_Right (Status, 4) and 16#7FF#);
      case Shift_Right (Status, 17) and 16#F# is
         when 2 =>
            for K in 0 .. (Count + 3) / 4 - 1 loop
               Word := FIFO;
               if N < U.Endpoint_Count then
                  for B in 0 .. 3 loop
                     if 4 * K + B < Count and then Received (N).Count < U.Packet_Size then
                        Received (N).Data (Received (N).Count) := Byte (Shift_Right (Word, 8 * B) and 16#FF#);
                        Received (N).Count := Received (N).Count + 1;
                     end if;
                  end loop;
               end if;
            end loop;
         when 6 =>
            for K in 0 .. 1 loop
               Word := FIFO;
               for B in 0 .. 3 loop
                  Setup_Data (4 * K + B) := Byte (Shift_Right (Word, 8 * B) and 16#FF#);
               end loop;
            end loop;
         when others =>
            null;
      end case;
      GINTMSK := GINTMSK or RXFLVL;
   end Receive_Queue;

   --  The first OUT endpoint flag that is an event: a transfer done, with
   --  the packet it brought, or a setup packet. A disabled endpoint's flag
   --  is cleared on the way.
   procedure Out_Endpoints (What : out Event; EP : out U.Endpoint_Number; Data : in out Byte_Array; Count : out Natural)
   is
      Pending : constant Unsigned_32 := Shift_Right (DAINT and DAINTMSK, 16);
      Flags   : Unsigned_32;
   begin
      What := Nothing;
      EP := 0;
      Count := 0;
      for N in Number loop
         if (Pending and Shift_Left (1, N)) /= 0 then
            Flags := OUT_EP (N).INT and DOEPMSK;
            if (Flags and XFRC) /= 0 then
               OUT_EP (N).INT := XFRC;
               What := Packet_Out;
               EP := N;
               Count := Received (N).Count;
               Data (Data'First .. Data'First + Count - 1) := Received (N).Data (0 .. Count - 1);
               return;
            end if;
            if (Flags and EPDISD) /= 0 then
               OUT_EP (N).INT := EPDISD;
            end if;
            if (Flags and STUP) /= 0 then
               Setup_Waits := True;
               Setup_From := N;
               What := Setup;
               Count := Setup_Data'Length;
               Data (Data'First .. Data'First + Setup_Data'Length - 1) := Setup_Data;
               return;
            end if;
         end if;
      end loop;
   end Out_Endpoints;

   --  The first IN endpoint flag that is an event: a transmission done.
   --  Other flags are cleared on the way, and a FIFO with room takes the
   --  packet that waits for it.
   procedure In_Endpoints (What : out Event; EP : out U.Endpoint_Number) is
      Pending : constant Unsigned_32 := DAINT and DAINTMSK and 16#FFFF#;
      Flags   : Unsigned_32;
   begin
      What := Nothing;
      EP := 0;
      for N in Number loop
         if (Pending and Shift_Left (1, N)) /= 0 then
            Flags := IN_EP (N).INT
              and (DIEPMSK or (if (DIEPEMPMSK and Shift_Left (1, N)) /= 0 then TXFE else Unsigned_32'(0)));
            if (Flags and XFRC) /= 0 then
               DIEPEMPMSK := DIEPEMPMSK and not Shift_Left (1, N);
               IN_EP (N).INT := XFRC;
               What := Packet_In;
               EP := N;
               return;
            end if;
            if (Flags and TOC) /= 0 then
               IN_EP (N).INT := TOC;
            end if;
            if (Flags and ITTXFE) /= 0 then
               IN_EP (N).INT := ITTXFE;
            end if;
            if (Flags and INEPNE) /= 0 then
               IN_EP (N).INT := INEPNE;
            end if;
            if (Flags and EPDISD) /= 0 then
               IN_EP (N).INT := EPDISD;
            end if;
            if (Flags and TXFE) /= 0 then
               Write_Empty_Tx_Fifo (N);
            end if;
         end if;
      end loop;
   end In_Endpoints;

   --  The controller's part of a bus reset: the control endpoint's FIFO
   --  flushed, every endpoint's flags cleared, the control endpoint's flags
   --  unmasked, the address cleared and the control endpoint armed.
   procedure Reset_Controller is
   begin
      DCTL := DCTL and not RWUSIG;
      Flush_Tx (0);
      for N in Number loop
         IN_EP (N).INT := 16#FF#;
         OUT_EP (N).INT := 16#FF#;
      end loop;
      DAINT := 16#FFFF_FFFF#;
      DAINTMSK := 1 or Shift_Left (1, 16);
      DOEPMSK := STUP or XFRC or EPDISD;
      DIEPMSK := XFRC or TOC or EPDISD;
      DCFG := DCFG and not DAD;
      OUT_EP (0).TSIZ := Shift_Left (3, 29) or Shift_Left (1, 19) or 24;
      GINTSTS := USBRST;
   end Reset_Controller;

   --  The enumeration done: the control endpoint's 64-byte packets, the
   --  global IN NAK cleared and the turnaround time.
   procedure Enumeration_Done is
   begin
      IN_EP (0).CTL := IN_EP (0).CTL and not 3;
      DCTL := DCTL or CGINAK;
      GUSBCFG := (GUSBCFG and not TRDT) or Shift_Left (5, 10);
      GINTSTS := ENUMDNE;
   end Enumeration_Done;

   procedure Next
     (What : out Event; EP : out U.Endpoint_Number; Data : in out Byte_Array; Count : out Natural)
   is
      Status : constant Unsigned_32 := GINTSTS and GINTMSK;
   begin
      What := Nothing;
      EP := 0;
      Count := 0;
      if (GINTSTS and CMOD) /= 0 or else Status = 0 then
         return;
      end if;
      if (Status and OEPINT) /= 0 then
         Out_Endpoints (What, EP, Data, Count);
         if What /= Nothing then
            return;
         end if;
      end if;
      if (Status and IEPINT) /= 0 then
         In_Endpoints (What, EP);
         if What /= Nothing then
            return;
         end if;
      end if;
      if (Status and WKUPINT) /= 0 then
         DCTL := DCTL and not RWUSIG;
         GINTSTS := WKUPINT;
         What := Resume;
         return;
      end if;
      if (Status and USBSUSP) /= 0 then
         GINTSTS := USBSUSP;
         What := Suspend;
         return;
      end if;
      if (Status and RXFLVL) /= 0 then
         Receive_Queue;
      end if;
      if (Status and USBRST) /= 0 then
         Reset_Controller;
         What := Bus_Reset;
         return;
      end if;
      if (Status and ENUMDNE) /= 0 then
         Enumeration_Done;
      end if;
      if (Status and IISOIXFR) /= 0 then
         GINTSTS := IISOIXFR;
      end if;
      if (Status and IPXFR) /= 0 then
         GINTSTS := IPXFR;
      end if;
   end Next;

   --  A disconnect pulse on D+, so a host that still has the serial port
   --  sees a new device, then the pins and clocks, then the controller as
   --  the serial port's driver starts it: the core reset on the embedded
   --  transceiver, device mode, a full-speed device with its FIFOs, every
   --  endpoint disabled and its flags cleared. The controller's global
   --  interrupt stays off.
   procedure Start is
   begin
      GPIO.Enable_Port (Port_A);
      GPIO.Set_Output (DP);
      GPIO.Set_Open_Drain (DP);
      GPIO.Set_Low (DP);
      Adaflight.STM32.Time.Delay_Ms (200);
      GPIO.Set_High (DP);
      GPIO.Set_Alternate (DM, 10, Rate => GPIO.Very_High);
      GPIO.Set_Alternate (DP, 10, Rate => GPIO.Very_High);
      RCC_SYSCFG_ENR := RCC_SYSCFG_ENR or 2 ** Adaflight.STM32.Memory.SYSCFG_Enable_Bit;
      RCC_USB_ENR := RCC_USB_ENR or 2 ** Adaflight.STM32.Memory.USB_Enable_Bit;
      GAHBCFG := GAHBCFG and not GINTMSK_GLOBAL;
      GUSBCFG := GUSBCFG or PHYSEL;
      Core_Reset;
      if Adaflight.STM32.Platform.F4 then
         GCCFG := PWRDWN or NOVBUSSENS;
      else
         GCCFG := PWRDWN;
         GOTGCTL := GOTGCTL or B_VALID_SET;
      end if;
      Adaflight.STM32.Time.Delay_Ms (20);
      GUSBCFG := (GUSBCFG and not (FORCE_HOST or FORCE_DEVICE)) or FORCE_DEVICE;
      Adaflight.STM32.Time.Delay_Ms (50);
      PCGCCTL := 0;
      DCFG := (DCFG and not PFIVL) or DSPD_FULL;
      GRXFSIZ := 128;
      DIEPTXF0 := Shift_Left (32, 16) or 128;
      DIEPTXF1 := Shift_Left (64, 16) or 160;
      DIEPTXF2 := Shift_Left (0, 16) or 224;
      DIEPTXF3 := Shift_Left (64, 16) or 224;
      Flush_Tx (16#10#);
      Flush_Rx;
      DIEPMSK := 0;
      DOEPMSK := 0;
      DAINT := 16#FFFF_FFFF#;
      DAINTMSK := 0;
      for N in Number loop
         IN_EP (N).CTL := (if (IN_EP (N).CTL and EPENA) /= 0 then EPDIS or SNAK else Unsigned_32'(0));
         IN_EP (N).TSIZ := 0;
         IN_EP (N).INT := 16#FF#;
      end loop;
      for N in Number loop
         OUT_EP (N).CTL := (if (OUT_EP (N).CTL and EPENA) /= 0 then EPDIS or SNAK else Unsigned_32'(0));
         OUT_EP (N).TSIZ := 0;
         OUT_EP (N).INT := 16#FF#;
      end loop;
      DIEPMSK := DIEPMSK or TXFURM;
      GINTMSK := 0;
      GINTSTS := 16#BFFF_FFFF#;
      GOTGINT := 16#FFFF_FFFF#;
      GINTSTS := 16#BFFF_FFFF#;
      GINTMSK := WKUPINT or USBSUSP or RXFLVL or USBRST or ENUMDNE or IEPINT or OEPINT or IISOIXFR or IPXFR;
      DCTL := DCTL and not SDIS;
   end Start;
end Adaflight.STM32.USB_Storage;
