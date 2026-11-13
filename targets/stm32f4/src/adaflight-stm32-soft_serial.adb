with Ada.Interrupts.Names;
with System;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.Soft_Serial;
with Adaflight.STM32.Soft_Serial_Logic;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
package body Adaflight.STM32.Soft_Serial is
   use Interfaces;
   package Engine renames Adaflight.Soft_Serial;
   package GPIO renames Adaflight.STM32.GPIO;
   use type Engine.Pin;
   use type Engine.Timer_Mode;

   --  A port's pins and timers once it is open: the main timer's channel,
   --  which captures the receive pin, the second timer of a port with two,
   --  the pins and the receive pin's pull.
   type Hardware is record
      Used        : Boolean := False;
      Main        : Timer_Entry := (TIM1, 1, False, (Port_A, 0));
      Dual        : Boolean := False;
      Second      : Timer_Name := TIM1;
      Has_Send    : Boolean := False;
      Send        : Pin := (Port_A, 0);
      Has_Receive : Boolean := False;
      Receive     : Pin := (Port_A, 0);
      Resistor    : GPIO.Pull := GPIO.Up;
   end record;
   HW : array (Port_Number) of Hardware;

   Update_Flag : constant Interfaces.Unsigned_32 := 2 ** 0;
   function Capture_Flag (E : Timer_Entry) return Interfaces.Unsigned_32 is (Shift_Left (1, E.Channel));
   function Enable_Bits (E : Timer_Entry) return Natural is (4 * (E.Channel - 1));

   --  The main channel as an input on its own pin, with no filter and no
   --  prescaler, off, to capture a rising or a falling edge.
   procedure Capture_Polarity (E : Timer_Entry; Rising : Boolean) is
      Regs  : Timer_Registers with Import, Address => Timer_Base (E.Timer);
      Shift : constant Natural := 8 * ((E.Channel - 1) mod 2);
   begin
      Regs.CCER := Regs.CCER and not Shift_Left (2#1011#, Enable_Bits (E));
      if E.Channel <= 2 then
         Regs.CCMR1 := (Regs.CCMR1 and not Shift_Left (16#FF#, Shift)) or Shift_Left (1, Shift);
      else
         Regs.CCMR2 := (Regs.CCMR2 and not Shift_Left (16#FF#, Shift)) or Shift_Left (1, Shift);
      end if;
      if not Rising then
         Regs.CCER := Regs.CCER or Shift_Left (2#0010#, Enable_Bits (E));
      end if;
   end Capture_Polarity;

   procedure Capture_On (E : Timer_Entry) is
      Regs : Timer_Registers with Import, Address => Timer_Base (E.Timer);
   begin
      Regs.CCER := Regs.CCER or Shift_Left (1, Enable_Bits (E));
   end Capture_On;

   procedure Capture_Off (E : Timer_Entry) is
      Regs : Timer_Registers with Import, Address => Timer_Base (E.Timer);
   begin
      Regs.CCER := Regs.CCER and not Shift_Left (1, Enable_Bits (E));
   end Capture_Off;

   --  The receive pin on the main timer with its pull, and the capture on.
   procedure Listen (H : Hardware) is
   begin
      if H.Has_Receive then
         GPIO.Set_Alternate (H.Receive, Alternate (H.Main.Timer), H.Resistor);
      end if;
      Capture_On (H.Main);
   end Listen;

   procedure Send_Effect (N : Positive; E : Engine.Tx_Effect) is
      H : Hardware renames HW (N);
   begin
      case E is
         when Engine.Nothing =>
            null;
         when Engine.To_Receive =>
            if H.Has_Send then
               GPIO.Set_Input (H.Send);
            end if;
            Listen (H);
         when Engine.To_Transmit =>
            Capture_Off (H.Main);
            if H.Has_Receive then
               GPIO.Set_Input (H.Receive);
            end if;
            if H.Has_Send then
               GPIO.Set_Output (H.Send);
            end if;
         when Engine.Level_Low =>
            if H.Has_Send then
               GPIO.Set_Low (H.Send);
            end if;
         when Engine.Level_High =>
            if H.Has_Send then
               GPIO.Set_High (H.Send);
            end if;
      end case;
   end Send_Effect;

   procedure Rearm (N : Positive; Rising : Boolean) is
   begin
      Capture_Polarity (HW (N).Main, Rising);
      Capture_On (HW (N).Main);
   end Rearm;

   procedure After_Edge (N : Positive; Centre : Boolean; Rising : Boolean) is
      Regs : Timer_Registers with Import, Address => Timer_Base (HW (N).Main.Timer);
   begin
      if Centre then
         Regs.CNT := Regs.ARR / 2;
      end if;
      Capture_Polarity (HW (N).Main, Rising);
      Capture_On (HW (N).Main);
   end After_Edge;

   package Logic is new Adaflight.STM32.Soft_Serial_Logic
     (Send_Effect => Send_Effect, Rearm => Rearm, After_Edge => After_Edge);

   --  A timer at a time base, counting, with its update interrupt on.
   procedure Start_Clock (T : Timer_Name; Base : Engine.Time_Base) is
      Regs : Timer_Registers with Import, Address => Timer_Base (T);
   begin
      Enable_Clock (T);
      Regs.CR1 := Regs.CR1 and not CEN;
      Set_Time_Base
        (T, Reload => Interfaces.Unsigned_32 (Interfaces.Unsigned_16'Max (Base.Period, 1)) - 1,
         Prescale => Timer_Clock_Hz (T) / Interfaces.Unsigned_32'Max (Base.Clock, 1) - 1);
      Regs.SR := 0;
      Regs.DIER := Regs.DIER or Update_Flag;
      Regs.CR1 := Regs.CR1 or CEN;
   end Start_Clock;

   --  TIM1's update and capture interrupts by number: the STM32F7 run time's
   --  names give the update the break's number and leave the capture out.
   TIM1_Update_ID  : constant Ada.Interrupts.Interrupt_ID := 25;
   TIM1_Capture_ID : constant Ada.Interrupts.Interrupt_ID := 27;

   --  The timers that have an interrupt handler here. TIM5's interrupt is
   --  the SPI receiver's.
   function Served (T : Timer_Name) return Boolean is (T /= TIM5);

   --  The handlers run above the other interrupt handlers of the board, so
   --  a UART's or the USB port's work does not hold a bit clock's tick off.
   protected Handlers with Interrupt_Priority => System.Interrupt_Priority'Last is
      procedure Open
        (N : Port_Number; Baud : Positive; Half_Duplex : Boolean; Inverted : Boolean; Resistor : GPIO.Pull;
         Opened : out Boolean);
      procedure Set_Baud (N : Port_Number; Baud : Positive; Changed : out Boolean);
      procedure Queue (N : Port_Number; Data : Byte_Array; Taken : out Natural);
      procedure Take (N : Port_Number; Into : out Byte_Array; Count : out Natural);
      function Free (N : Port_Number) return Natural;
      function Empty (N : Port_Number) return Boolean;
      function Is_Open (N : Port_Number) return Boolean;
   private
      procedure Serve (T : Timer_Name);
      procedure TIM1_Update with Attach_Handler => TIM1_Update_ID;
      procedure TIM1_Capture with Attach_Handler => TIM1_Capture_ID;
      procedure TIM9_Any with Attach_Handler => Ada.Interrupts.Names.TIM1_BRK_TIM9_Interrupt;
      procedure TIM11_Any with Attach_Handler => Ada.Interrupts.Names.TIM1_TRG_COM_TIM11_Interrupt;
      procedure TIM2_Any with Attach_Handler => Ada.Interrupts.Names.TIM2_Interrupt;
      procedure TIM3_Any with Attach_Handler => Ada.Interrupts.Names.TIM3_Interrupt;
      procedure TIM4_Any with Attach_Handler => Ada.Interrupts.Names.TIM4_Interrupt;
      procedure TIM8_Update with Attach_Handler => Ada.Interrupts.Names.TIM8_UP_TIM13_Interrupt;
      procedure TIM8_Capture with Attach_Handler => Ada.Interrupts.Names.TIM8_CC_Interrupt;
      procedure TIM12_Any with Attach_Handler => Ada.Interrupts.Names.TIM8_BRK_TIM12_Interrupt;
      procedure TIM14_Any with Attach_Handler => Ada.Interrupts.Names.TIM8_TRG_COM_TIM14_Interrupt;
   end Handlers;

   protected body Handlers is

      procedure Open
        (N : Port_Number; Baud : Positive; Half_Duplex : Boolean; Inverted : Boolean; Resistor : GPIO.Pull;
         Opened : out Boolean)
      is
         C    : Logic.Channels;
         Plan : Engine.Open_Plan;
         H    : Hardware;
      begin
         if Logic.Is_Open (N) then
            Opened := True;
            return;
         end if;
         Opened := False;
         Logic.Open_On (N, Baud, Half_Duplex, Inverted, Resistor, C, Plan);
         if not Plan.Opened then
            return;
         end if;
         H.Main := (if Plan.Main = Engine.Tx_Pin then C.TX else C.RX);
         H.Dual := Plan.Timing = Engine.Dual;
         H.Second := C.TX.Timer;
         if not Served (H.Main.Timer) or else (H.Dual and then not Served (H.Second)) then
            Logic.Close (N);
            return;
         end if;
         H.Has_Send := Plan.Send_On /= Engine.No_Pin;
         H.Has_Receive := Plan.Receive_On /= Engine.No_Pin;
         if H.Has_Send then
            H.Send := Pin_Of (Natural (Logic.TX_Tag (N)));
            GPIO.Enable_Port (H.Send.Port);
         end if;
         if H.Has_Receive then
            H.Receive :=
              Pin_Of (Natural (if Plan.Receive_On = Engine.Tx_Pin then Logic.TX_Tag (N) else Logic.RX_Tag (N)));
            GPIO.Enable_Port (H.Receive.Port);
         end if;
         H.Resistor :=
           (case Engine.Pull_Of (Logic.Options (N)) is
               when Engine.None => GPIO.No_Pull, when Engine.Down => GPIO.Down, when Engine.Up => GPIO.Up);
         H.Used := True;
         HW (N) := H;
         Start_Clock (H.Main.Timer, Plan.Main_Base);
         Capture_Polarity (H.Main, Rising => Inverted);
         declare
            Regs : Timer_Registers with Import, Address => Timer_Base (H.Main.Timer);
         begin
            Regs.DIER := Regs.DIER or Capture_Flag (H.Main);
         end;
         if H.Dual then
            Start_Clock (H.Second, Plan.Second_Base);
         end if;
         if H.Has_Send then
            if Inverted then
               GPIO.Set_Low (H.Send);
            else
               GPIO.Set_High (H.Send);
            end if;
            if not Half_Duplex then
               GPIO.Set_Output (H.Send);
            end if;
         end if;
         Listen (H);
         Opened := True;
      end Open;

      procedure Set_Baud (N : Port_Number; Baud : Positive; Changed : out Boolean) is
         H : Hardware renames HW (N);
      begin
         Changed := Logic.Is_Open (N) and then Baud <= Logic.Max_Baud;
         if Changed then
            Start_Clock
              (H.Main.Timer, Engine.Time_Base_Of (Timer_Clock_Hz (H.Main.Timer), Interfaces.Unsigned_32 (Baud)));
            if H.Dual then
               Start_Clock (H.Second, Engine.Time_Base_Of (Timer_Clock_Hz (H.Second), Interfaces.Unsigned_32 (Baud)));
            end if;
         end if;
      end Set_Baud;

      procedure Queue (N : Port_Number; Data : Byte_Array; Taken : out Natural) is
      begin
         Logic.Queue (N, Data, Taken);
      end Queue;

      procedure Take (N : Port_Number; Into : out Byte_Array; Count : out Natural) is
      begin
         Logic.Take (N, Into, Count);
      end Take;

      function Free (N : Port_Number) return Natural is (Logic.Free (N));

      function Empty (N : Port_Number) return Boolean is (Logic.Transmit_Empty (N));

      function Is_Open (N : Port_Number) return Boolean is (Logic.Is_Open (N));

      --  A timer's pending work: its update as a tick for the ports it
      --  clocks, then its capture as an edge for the port it is the main
      --  timer of.
      procedure Serve (T : Timer_Name) is
         Regs   : Timer_Registers with Import, Address => Timer_Base (T);
         Status : Interfaces.Unsigned_32;
      begin
         if not (for some N in Port_Number =>
                   HW (N).Used and then (HW (N).Main.Timer = T or else (HW (N).Dual and then HW (N).Second = T)))
         then
            return;
         end if;
         Status := Regs.SR and Regs.DIER;
         if (Status and Update_Flag) /= 0 then
            Regs.SR := not Update_Flag;
            for N in Port_Number loop
               if HW (N).Used and then HW (N).Main.Timer = T then
                  Logic.Tick (N, Logic.Main);
               end if;
               if HW (N).Used and then HW (N).Dual and then HW (N).Second = T then
                  Logic.Tick (N, Logic.Second);
               end if;
            end loop;
         end if;
         for N in Port_Number loop
            if HW (N).Used and then HW (N).Main.Timer = T and then (Status and Capture_Flag (HW (N).Main)) /= 0 then
               Regs.SR := not Capture_Flag (HW (N).Main);
               Logic.Edge (N);
            end if;
         end loop;
      end Serve;

      procedure TIM1_Update is
      begin
         Serve (TIM1);
         Serve (TIM10);
      end TIM1_Update;

      procedure TIM1_Capture is
      begin
         Serve (TIM1);
      end TIM1_Capture;

      procedure TIM9_Any is
      begin
         Serve (TIM9);
      end TIM9_Any;

      procedure TIM11_Any is
      begin
         Serve (TIM11);
      end TIM11_Any;

      procedure TIM2_Any is
      begin
         Serve (TIM2);
      end TIM2_Any;

      procedure TIM3_Any is
      begin
         Serve (TIM3);
      end TIM3_Any;

      procedure TIM4_Any is
      begin
         Serve (TIM4);
      end TIM4_Any;

      procedure TIM8_Update is
      begin
         Serve (TIM8);
         Serve (TIM13);
      end TIM8_Update;

      procedure TIM8_Capture is
      begin
         Serve (TIM8);
      end TIM8_Capture;

      procedure TIM12_Any is
      begin
         Serve (TIM12);
      end TIM12_Any;

      procedure TIM14_Any is
      begin
         Serve (TIM14);
      end TIM14_Any;

   end Handlers;

   procedure Configure (C : Adaflight.Config_Groups.Configuration; Feature_On : Boolean) is
   begin
      Logic.Configure (C, Feature_On);
   end Configure;

   function Present (N : Port_Number) return Boolean is (Logic.Present (N));

   function TX_Tag (N : Port_Number) return Unsigned_8 is (Logic.TX_Tag (N));
   function RX_Tag (N : Port_Number) return Unsigned_8 is (Logic.RX_Tag (N));

   procedure Open
     (N : Port_Number; Baud : Positive; Half_Duplex : Boolean; Inverted : Boolean;
      Resistor : Adaflight.STM32.GPIO.Pull; Opened : out Boolean) is
   begin
      Handlers.Open (N, Baud, Half_Duplex, Inverted, Resistor, Opened);
   end Open;

   function Is_Open (N : Port_Number) return Boolean is (Handlers.Is_Open (N));

   procedure Set_Baud (N : Port_Number; Baud : Positive; Changed : out Boolean) is
   begin
      Handlers.Set_Baud (N, Baud, Changed);
   end Set_Baud;

   --  The task-side calls go to the handlers' object a few bytes at a time,
   --  so the ticks are held off for a short time only.
   Chunk : constant := 16;

   procedure Queue (N : Port_Number; Data : Byte_Array; Taken : out Natural) is
      Part : Natural;
   begin
      Taken := 0;
      while Taken < Data'Length loop
         Handlers.Queue
           (N, Data (Data'First + Taken .. Natural'Min (Data'Last, Data'First + Taken + Chunk - 1)), Part);
         Taken := Taken + Part;
         exit when Part = 0;
      end loop;
   end Queue;

   function Free (N : Port_Number) return Natural is (Handlers.Free (N));

   function Transmit_Empty (N : Port_Number) return Boolean is (Handlers.Empty (N));

   procedure Take (N : Port_Number; Into : out Byte_Array; Count : out Natural) is
      Part : Natural;
   begin
      Into := (others => 0);
      Count := 0;
      while Count < Into'Length loop
         Handlers.Take
           (N, Into (Into'First + Count .. Natural'Min (Into'Last, Into'First + Count + Chunk - 1)), Part);
         Count := Count + Part;
         exit when Part = 0;
      end loop;
   end Take;

end Adaflight.STM32.Soft_Serial;
