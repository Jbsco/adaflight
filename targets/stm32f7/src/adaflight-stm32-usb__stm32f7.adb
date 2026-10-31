with Ada.Interrupts.Names;
with System;
with Interfaces;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Time;
with Adaflight.USB_VCP;
--  The STM32F7's USB device: the F4's core with the VBUS detection left
--  off and the B session forced valid, since the board does not sense VBUS.
package body Adaflight.STM32.USB is
   package U renames Adaflight.USB_VCP;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   function Shift_Left (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Left;
   function Shift_Right (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Right;
   package GPIO renames Adaflight.STM32.GPIO;

   Base : constant := 16#5000_0000#;

   GOTGINT    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#004#);
   GAHBCFG    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#008#);
   GUSBCFG    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#00C#);
   GRSTCTL    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#010#);
   GINTSTS    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#014#);
   GINTMSK    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#018#);
   GRXSTSP    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#020#);
   GRXFSIZ    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#024#);
   DIEPTXF0   : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#028#);
   GOTGCTL    : Unsigned_32 with Volatile, Import, Address => System'To_Address (Base + 16#000#);
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
   RCC_AHB2ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3834#);
   RCC_APB2ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3844#);

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
   MMIS           : constant Unsigned_32 := 2 ** 1;
   SOF            : constant Unsigned_32 := 2 ** 3;
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
   B_Valid_Override : constant Unsigned_32 := 2 ** 6;
   B_Valid_Value    : constant Unsigned_32 := 2 ** 7;
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

   protected Controller with Interrupt_Priority => System.Interrupt_Priority'First, Linker_Section => ".bss.ccm" is
      procedure Start (Product : String);
      procedure Send (Data : Byte_Array; Accepted : out Natural);
      procedure Take (Into : out Byte_Array; Count : out Natural);
      function Configured return Boolean;
      function Line_Rate return Interfaces.Unsigned_32;
      function Control_State return Interfaces.Unsigned_16;
      function Control_Count return Interfaces.Unsigned_32;
   private
      procedure Handler with Attach_Handler => Ada.Interrupts.Names.OTG_FS_Interrupt;
      D          : U.Device;
      Setup      : U.Setup_Packet := (others => 0);
      Received   : Packets;
      Sending    : Packets;
      In_Kinds   : Kinds := (others => U.Control);
      Out_Kinds  : Kinds := (others => U.Control);
      In_Sizes   : Sizes := (others => U.Packet_Size);
      Out_Sizes  : Sizes := (others => U.Packet_Size);
      --  The endpoint operations an event asks for, kept here: the interrupt
      --  stack is 2 KB and this record is near 1 KB.
      A          : U.Actions;
   end Controller;

   protected body Controller is

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

      --  The endpoint operations an event asked for, in their order.
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
                        In_Sizes (N) := X.Length;
                        Control := IN_EP (N).CTL;
                        if (Control and USBAEP) = 0 then
                           IN_EP (N).CTL := (Control and not (MPSIZ or 3 * 2 ** 18 or 16#F# * 2 ** 22))
                             or Unsigned_32 (X.Length) or Shift_Left (Unsigned_32 (U.Endpoint_Kind'Pos (X.EP_Kind)), 18)
                             or Shift_Left (Unsigned_32 (N), 22) or SD0PID or USBAEP;
                        end if;
                     else
                        Out_Kinds (N) := X.EP_Kind;
                        Out_Sizes (N) := X.Length;
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
                     Setup (4 * K + B) := Byte (Shift_Right (Word, 8 * B) and 16#FF#);
                  end loop;
               end loop;
            when others =>
               null;
         end case;
         GINTMSK := GINTMSK or RXFLVL;
      end Receive_Queue;

      procedure Out_Endpoints is
         Pending : constant Unsigned_32 := Shift_Right (DAINT and DAINTMSK, 16);
         Flags   : Unsigned_32;
      begin
         for N in Number loop
            if (Pending and Shift_Left (1, N)) /= 0 then
               Flags := OUT_EP (N).INT and DOEPMSK;
               if (Flags and XFRC) /= 0 then
                  OUT_EP (N).INT := XFRC;
                  U.Data_Out (D, N, Received (N).Data (0 .. Received (N).Count - 1), A);
                  Execute (A);
               end if;
               if (Flags and EPDISD) /= 0 then
                  OUT_EP (N).INT := EPDISD;
               end if;
               if (Flags and STUP) /= 0 then
                  U.Setup (D, Setup, A);
                  Execute (A);
                  OUT_EP (N).INT := STUP;
               end if;
            end if;
         end loop;
      end Out_Endpoints;

      procedure In_Endpoints is
         Pending : constant Unsigned_32 := DAINT and DAINTMSK and 16#FFFF#;
         Flags   : Unsigned_32;
      begin
         for N in Number loop
            if (Pending and Shift_Left (1, N)) /= 0 then
               Flags := IN_EP (N).INT
                 and (DIEPMSK or (if (DIEPEMPMSK and Shift_Left (1, N)) /= 0 then TXFE else Unsigned_32'(0)));
               if (Flags and XFRC) /= 0 then
                  DIEPEMPMSK := DIEPEMPMSK and not Shift_Left (1, N);
                  IN_EP (N).INT := XFRC;
                  U.Data_In (D, N, A);
                  Execute (A);
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

      --  A bus reset: the control endpoint's FIFO flushed, every endpoint's
      --  interrupts cleared, the control endpoint's interrupts unmasked, the
      --  address cleared and the control endpoint armed, then the device's
      --  reset.
      procedure Bus_Reset is
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
         U.Reset (D, A);
         Execute (A);
      end Bus_Reset;

      --  The enumeration done: the control endpoint's 64-byte packets, the
      --  global IN NAK cleared and the turnaround time for the 168 MHz bus.
      procedure Enumeration_Done is
      begin
         IN_EP (0).CTL := IN_EP (0).CTL and not 3;
         DCTL := DCTL or CGINAK;
         GUSBCFG := (GUSBCFG and not TRDT) or Shift_Left (5, 10);
         GINTSTS := ENUMDNE;
      end Enumeration_Done;

      procedure Handler is
         Status : constant Unsigned_32 := GINTSTS and GINTMSK;
      begin
         if (GINTSTS and CMOD) /= 0 or else Status = 0 then
            return;
         end if;
         if (Status and OEPINT) /= 0 then
            Out_Endpoints;
         end if;
         if (Status and IEPINT) /= 0 then
            In_Endpoints;
         end if;
         if (Status and MMIS) /= 0 then
            GINTSTS := MMIS;
         end if;
         if (Status and WKUPINT) /= 0 then
            DCTL := DCTL and not RWUSIG;
            U.Resume (D);
            GINTSTS := WKUPINT;
         end if;
         if (Status and USBSUSP) /= 0 then
            U.Suspend (D);
            GINTSTS := USBSUSP;
         end if;
         if (Status and SOF) /= 0 then
            U.Start_Of_Frame (D, A);
            Execute (A);
            GINTSTS := SOF;
         end if;
         if (Status and RXFLVL) /= 0 then
            Receive_Queue;
         end if;
         if (Status and USBRST) /= 0 then
            Bus_Reset;
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
      end Handler;

      procedure Start (Product : String) is
      begin
         U.Init (D, Product (Product'First .. Product'First + Natural'Min (Product'Length, U.Max_Product) - 1));
      end Start;

      procedure Send (Data : Byte_Array; Accepted : out Natural) is
      begin
         U.Send (D, Data, Accepted);
      end Send;

      procedure Take (Into : out Byte_Array; Count : out Natural) is
      begin
         U.Receive (D, Into, Count);
      end Take;

      function Configured return Boolean is (U.Configured (D));
      function Line_Rate return Interfaces.Unsigned_32 is (D.Line.Bit_Rate);
      function Control_State return Interfaces.Unsigned_16 is (D.Control_Line);
      function Control_Count return Interfaces.Unsigned_32 is (D.Control_Count);
   end Controller;

   --  The disconnect pulse of the reference's port open, D+ held low for 200
   --  milliseconds so a host still holding the previous connection sees a new
   --  device, then the pins and clocks, then the controller as the
   --  reference's device start brings it up: the core reset on the embedded
   --  transceiver with bus sensing off, device mode, the full-speed device
   --  with its FIFOs, every endpoint disabled, the interrupts, and the global
   --  interrupt last.
   procedure Init (Product : String) is
   begin
      GPIO.Enable_Port (Port_A);
      GPIO.Set_Output (DP);
      GPIO.Set_Open_Drain (DP);
      GPIO.Set_Low (DP);
      Adaflight.STM32.Time.Delay_Ms (200);
      GPIO.Set_High (DP);
      GPIO.Set_Alternate (DM, 10, Rate => GPIO.Very_High);
      GPIO.Set_Alternate (DP, 10, Rate => GPIO.Very_High);
      RCC_APB2ENR := RCC_APB2ENR or 2 ** 14;
      RCC_AHB2ENR := RCC_AHB2ENR or 2 ** 7;
      GAHBCFG := GAHBCFG and not GINTMSK_GLOBAL;
      GUSBCFG := GUSBCFG or PHYSEL;
      Core_Reset;
      GCCFG := PWRDWN;
      GOTGCTL := GOTGCTL or B_Valid_Override or B_Valid_Value;
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
      GINTMSK := WKUPINT or USBSUSP;
      GINTMSK := GINTMSK or RXFLVL or USBSUSP or USBRST or ENUMDNE or IEPINT or OEPINT or SOF or IISOIXFR or IPXFR;
      Controller.Start (Product);
      GAHBCFG := GAHBCFG or GINTMSK_GLOBAL;
      DCTL := DCTL and not SDIS;
   end Init;

   function Configured return Boolean is (Controller.Configured);

   procedure Send (Data : Byte_Array; Accepted : out Natural) is
   begin
      Controller.Send (Data, Accepted);
   end Send;

   procedure Take (Into : out Byte_Array; Count : out Natural) is
   begin
      Controller.Take (Into, Count);
   end Take;

   function Line_Rate return Interfaces.Unsigned_32 is (Controller.Line_Rate);

   procedure Control_Line (State : out Interfaces.Unsigned_16; Count : out Interfaces.Unsigned_32) is
   begin
      State := Controller.Control_State;
      Count := Controller.Control_Count;
   end Control_Line;
end Adaflight.STM32.USB;
