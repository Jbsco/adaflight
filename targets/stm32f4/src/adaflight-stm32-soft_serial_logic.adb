with Adaflight.CLI_Resources;
with Adaflight.Pins;
package body Adaflight.STM32.Soft_Serial_Logic is
   use type Engine.Tx_Effect;
   use type Engine.Timer_Mode;

   use type Interfaces.Unsigned_8;

   Feature : Boolean := False;
   TX_Tags : array (Port_Number) of Interfaces.Unsigned_8 := (others => 0);
   RX_Tags : array (Port_Number) of Interfaces.Unsigned_8 := (others => 0);

   procedure Configure (C : Adaflight.Config_Groups.Configuration; Feature_On : Boolean) is
      --  The software ports' pins follow the six UARTs' in the pin lists.
      Offset : constant := 6;
   begin
      Feature := Feature_On;
      for N in Port_Number loop
         TX_Tags (N) := C.Serial_Pin_Config.Io_Tag_Tx (Offset + N - 1);
         RX_Tags (N) := C.Serial_Pin_Config.Io_Tag_Rx (Offset + N - 1);
      end loop;
   end Configure;

   function Present (N : Port_Number) return Boolean is
     (Feature and then (TX_Tags (N) /= 0 or else RX_Tags (N) /= 0));

   function TX_Tag (N : Port_Number) return Interfaces.Unsigned_8 is (TX_Tags (N));
   function RX_Tag (N : Port_Number) return Interfaces.Unsigned_8 is (RX_Tags (N));

   Ports  : array (Port_Number) of Engine.Port;
   Opened : array (Port_Number) of Boolean := (others => False);

   procedure Open_On
     (N : Port_Number; Baud : Positive; Half_Duplex : Boolean; Inverted : Boolean;
      Resistor : Adaflight.STM32.GPIO.Pull; C : out Channels; Plan : out Engine.Open_Plan)
   is
      use Adaflight.STM32.Timers;
      use type Adaflight.STM32.GPIO.Pull;
      TX_Tag : constant Interfaces.Unsigned_8 := TX_Tags (N);
      RX_Tag : constant Interfaces.Unsigned_8 := RX_Tags (N);
      Same   : constant Boolean := TX_Tag = RX_Tag;
      Slot : Natural;
      None : constant Timer_Entry := (TIM1, 1, False, (Adaflight.Pins.Port_A, 0));
   begin
      C := (TX => None, RX => None, TX_Found => False, RX_Found => False);
      Plan := (others => <>);
      Opened (N) := False;
      if Baud > Max_Baud then
         return;
      end if;
      Allocate (TX_Tag, Adaflight.CLI_Resources.Softserial_TX, C.TX, Slot, C.TX_Found, Ordinal => N);
      if Same then
         C.RX := C.TX;
         C.RX_Found := C.TX_Found;
      else
         Allocate (RX_Tag, Adaflight.CLI_Resources.Softserial_RX, C.RX, Slot, C.RX_Found, Ordinal => N);
      end if;
      Engine.Open
        (Ports (N),
         (Mode        => (Rx => RX_Tag /= 0 or else Half_Duplex, Tx => TX_Tag /= 0),
          Options     => (Inverted        => Inverted,
                          Bidirectional   => Half_Duplex,
                          No_Pull         => Half_Duplex and then Resistor = Adaflight.STM32.GPIO.No_Pull,
                          SmartAudio_Pull => Half_Duplex and then not Inverted
                                             and then Resistor = Adaflight.STM32.GPIO.Down),
          Baud        => Interfaces.Unsigned_32 (Baud),
          Tx_Assigned => TX_Tag /= 0,
          Rx_Assigned => RX_Tag /= 0,
          Same_Pin    => Same,
          Tx_Timer    => C.TX_Found,
          Rx_Timer    => C.RX_Found,
          Tx_N        => C.TX_Found and then C.TX.N,
          Rx_N        => C.RX_Found and then C.RX.N,
          Same_Timer  => C.TX_Found and then C.RX_Found and then C.TX.Timer = C.RX.Timer,
          Tx_Clock    => (if C.TX_Found then Timer_Clock_Hz (C.TX.Timer) else 0),
          Rx_Clock    => (if C.RX_Found then Timer_Clock_Hz (C.RX.Timer) else 0)),
         Plan);
      Opened (N) := Plan.Opened;
   end Open_On;

   function Is_Open (N : Port_Number) return Boolean is (Opened (N));

   procedure Close (N : Port_Number) is
   begin
      Opened (N) := False;
   end Close;

   function Options (N : Port_Number) return Engine.Port_Options is (Ports (N).Options);

   function Timing (N : Port_Number) return Engine.Timer_Mode is (Ports (N).Timing);

   procedure Tick (N : Port_Number; T : Timer) is
      Effect : Engine.Tx_Effect := Engine.Nothing;
      Again  : Boolean := False;
   begin
      if not Opened (N) then
         return;
      end if;
      if Ports (N).Timing = Engine.Single then
         if T = Main then
            Engine.Clock (Ports (N), Effect, Again);
         end if;
      elsif T = Main then
         if Ports (N).Mode.Rx then
            Engine.Clock_Rx (Ports (N), Again);
         end if;
      elsif Ports (N).Mode.Tx then
         Engine.Clock_Tx (Ports (N), Effect);
      end if;
      if Effect /= Engine.Nothing then
         Send_Effect (N, Effect);
      end if;
      if Again then
         Rearm (N, Rising => Ports (N).Options.Inverted);
      end if;
   end Tick;

   procedure Edge (N : Port_Number) is
      Acted, Centre, Rising : Boolean;
   begin
      if not Opened (N) then
         return;
      end if;
      Engine.Edge (Ports (N), Acted, Centre, Rising);
      if Acted then
         After_Edge (N, Centre, Rising);
      end if;
   end Edge;

   procedure Queue (N : Port_Number; Data : Byte_Array; Taken : out Natural) is
   begin
      Taken := 0;
      if not Opened (N) then
         return;
      end if;
      while Taken < Data'Length and then Engine.Tx_Free (Ports (N)) > 0 loop
         Engine.Write (Ports (N), Data (Data'First + Taken));
         Taken := Taken + 1;
      end loop;
   end Queue;

   procedure Take (N : Port_Number; Into : out Byte_Array; Count : out Natural) is
   begin
      Into := (others => 0);
      Count := 0;
      if not Opened (N) then
         return;
      end if;
      while Count < Into'Length and then Engine.Rx_Waiting (Ports (N)) > 0 loop
         Engine.Read (Ports (N), Into (Into'First + Count));
         Count := Count + 1;
      end loop;
   end Take;

   function Waiting (N : Port_Number) return Natural is
     (if Opened (N) then Engine.Rx_Waiting (Ports (N)) else 0);

   function Free (N : Port_Number) return Natural is
     (if Opened (N) then Engine.Tx_Free (Ports (N)) else 0);

   function Transmit_Empty (N : Port_Number) return Boolean is
     (not Opened (N) or else (Engine.Tx_Empty (Ports (N)) and then not Ports (N).Transmitting));

end Adaflight.STM32.Soft_Serial_Logic;
