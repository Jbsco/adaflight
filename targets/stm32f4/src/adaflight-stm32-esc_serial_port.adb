with System;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Timer_Dispatch;
package body Adaflight.STM32.ESC_Serial_Port is
   use Interfaces;
   use Adaflight.STM32.Timers;
   subtype Byte_Array is Adaflight.Bytes.Byte_Array;
   package GPIO renames Adaflight.STM32.GPIO;
   use type Engine.Target;
   use type Engine.Op_Kind;

   P      : Engine.Port;
   Parser : Engine.Exit_Parser;

   --  The timer channels the port took, by the engine's targets.
   Taken   : array (Pin_Target) of Boolean := (others => False);
   Entries : array (Pin_Target) of Timer_Entry := (others => (TIM1, 1, False, (Port_A, 0)));

   --  The timer whose update is the bit tick and the channel whose capture
   --  is an edge, while each has its handler.
   Tick_On    : Boolean := False with Atomic;
   Tick_Timer : Timer_Name := TIM1 with Atomic;
   Edge_On    : Boolean := False with Atomic;
   Edge_Entry : Timer_Entry := (TIM1, 1, False, (Port_A, 0));

   Update_Flag : constant Unsigned_32 := 2 ** 0;
   Flags       : constant Unsigned_32 := 16#FF#;
   function Capture_Flag (E : Timer_Entry) return Unsigned_32 is (Shift_Left (1, E.Channel));
   function Enable_Bits (E : Timer_Entry) return Natural is (4 * (E.Channel - 1));

   --  A channel as an input on its own pin, with no filter and no prescaler,
   --  capturing a rising or a falling edge.
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
      Regs.CCER := Regs.CCER or Shift_Left (1, Enable_Bits (E));
   end Capture_Polarity;

   procedure Serve (T : Timer_Name);

   --  A timer's prescaler for a count rate, in the register's sixteen bits.
   function Prescaler (T : Timer_Name; Rate : Unsigned_32) return Unsigned_32 is
     ((Unsigned_32'Max (Timer_Clock_Hz (T) / Unsigned_32'Max (Rate, 1), 1) - 1) and 16#FFFF#);

   --  One pin or timer operation on the registers. A timer's setup resets
   --  it first, which ends a motor output's compare events and its drive of
   --  the pin, then starts it at the setup's time base with its interrupts
   --  served. The bit tick is the timer's update. A counter set starts a new
   --  bit clock, so it drops an update left pending from the old one.
   procedure Apply (O : Engine.Op) is
   begin
      if O.Who not in Pin_Target or else not Taken (O.Who) then
         return;
      end if;
      declare
         E    : constant Timer_Entry := Entries (O.Who);
         Regs : Timer_Registers with Import, Address => Timer_Base (E.Timer);
      begin
         case O.Kind is
            when Engine.Allocate | Engine.Claim | Engine.Motors_Off | Engine.Wait | Engine.Host_Byte
               | Engine.ESC_Byte =>
               null;
            when Engine.Pin_Mode =>
               GPIO.Enable_Port (E.Where.Port);
               if O.A = Engine.Mode_Capture then
                  GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.Up);
               elsif O.A = Engine.Mode_Output then
                  GPIO.Set_Output (E.Where);
               else
                  GPIO.Set_Input (E.Where, GPIO.Up);
               end if;
            when Engine.Pin_High =>
               GPIO.Set_High (E.Where);
            when Engine.Pin_Low =>
               GPIO.Set_Low (E.Where);
            when Engine.Configure =>
               Enable_Clock (E.Timer);
               Reset (E.Timer);
               Set_Time_Base (E.Timer, Reload => Unsigned_32'Max (O.A, 1) - 1, Prescale => Prescaler (E.Timer, O.B));
               Regs.CR1 := Regs.CR1 or CEN;
               Adaflight.STM32.Timer_Dispatch.Register (E.Timer, Serve'Access);
            when Engine.Reset =>
               Reset (E.Timer);
            when Engine.Time_Base =>
               Set_Time_Base (E.Timer, Reload => Unsigned_32'Max (O.A, 1) - 1, Prescale => Prescaler (E.Timer, O.B));
            when Engine.Start =>
               Regs.CR1 := Regs.CR1 or CEN;
            when Engine.Set_Counter =>
               Regs.CNT := O.A;
               Regs.SR := not Update_Flag;
            when Engine.Polarity =>
               Capture_Polarity (E, Rising => O.A = 1);
            when Engine.Clear_Flag =>
               Regs.SR := not Capture_Flag (E);
            when Engine.Interrupt =>
               if O.A = 1 then
                  Regs.DIER := Regs.DIER or Capture_Flag (E);
               else
                  Regs.DIER := Regs.DIER and not Capture_Flag (E);
               end if;
            when Engine.Tick_Handler =>
               if O.A = 1 then
                  Tick_Timer := E.Timer;
                  Tick_On := True;
                  Regs.DIER := Regs.DIER or Update_Flag;
               else
                  Regs.DIER := Regs.DIER and not Update_Flag;
                  Tick_On := False;
               end if;
            when Engine.Edge_Handler =>
               if O.A = 1 then
                  Edge_Entry := E;
                  Edge_On := True;
                  Regs.DIER := Regs.DIER or Capture_Flag (E);
               else
                  Regs.DIER := Regs.DIER and not Capture_Flag (E);
                  Edge_On := False;
               end if;
         end case;
      end;
   end Apply;

   --  A timer's pending interrupts, each flag cleared whether or not it has
   --  a handler: its update as the port's bit tick, then its channel's
   --  capture as an edge with the captured count. A tick that waits beside a
   --  start edge fell before the edge's bit clock, so it runs first, while
   --  the port still searches.
   procedure Serve (T : Timer_Name) is
      Regs   : Timer_Registers with Import, Address => Timer_Base (T);
      Status : constant Unsigned_32 := Regs.SR and Regs.DIER and Flags;
   begin
      Regs.SR := not Status;
      if Tick_On and then Tick_Timer = T and then (Status and Update_Flag) /= 0 then
         declare
            Ops : Engine.Op_List (Engine.Tick_Ops);
         begin
            Engine.Tick (P, Ops);
            for I in 1 .. Ops.Count loop
               Apply (Ops.Items (I));
            end loop;
         end;
      end if;
      if Edge_On and then Edge_Entry.Timer = T and then (Status and Capture_Flag (Edge_Entry)) /= 0 then
         declare
            Captured : Unsigned_32
              with Volatile, Import, Address => System'To_Address (CCR_Value (T, Edge_Entry.Channel));
            Count    : constant Unsigned_32 := Captured;
            Ops      : Engine.Op_List (Engine.Edge_Ops);
         begin
            Engine.Edge (P, Unsigned_16 (Count and 16#FFFF#), Ops);
            for I in 1 .. Ops.Count loop
               Apply (Ops.Items (I));
            end loop;
         end;
      end if;
   end Serve;

   --  The timers the port took go back to no handler.
   procedure Drop is
   begin
      Tick_On := False;
      Edge_On := False;
      for Who in Pin_Target loop
         if Taken (Who) then
            Adaflight.STM32.Timer_Dispatch.Register (Entries (Who).Timer, null);
            Taken (Who) := False;
         end if;
      end loop;
   end Drop;

   procedure Assign (Who : Pin_Target; E : Timer_Entry; Found : Boolean) is
   begin
      Entries (Who) := E;
      Taken (Who) := Found;
   end Assign;

   --  A task's calls take this object, whose ceiling keeps every interrupt
   --  off, so a tick or an edge never meets one of them half done.
   protected Guard with Interrupt_Priority => System.Interrupt_Priority'Last is
      procedure Start
        (Mode : Engine.Protocol; Index : Natural; B : Engine.Board; Ops : in out Engine.Op_List;
         Started : out Boolean);
      procedure Open_All (Baud : Unsigned_32; B : Engine.Board; Ops : in out Engine.Op_List; Started : out Boolean);
      procedure Forward (Ops : in out Engine.Op_List; More : out Boolean);
      procedure From_Host (Host : Byte_Array; Ops : in out Engine.Op_List; Left : out Boolean);
      procedure Perform (Ops : Engine.Op_List; First, Last : Positive);
      procedure Release;
   end Guard;

   protected body Guard is

      procedure Start
        (Mode : Engine.Protocol; Index : Natural; B : Engine.Board; Ops : in out Engine.Op_List;
         Started : out Boolean) is
      begin
         Drop;
         Parser := (others => <>);
         Engine.Start (P, Mode, Index, B, Ops, Started);
      end Start;

      procedure Open_All (Baud : Unsigned_32; B : Engine.Board; Ops : in out Engine.Op_List; Started : out Boolean)
      is
      begin
         Drop;
         Parser := (others => <>);
         Engine.Open (P, Engine.KISS_All, 0, Baud, B, Ops, Started);
      end Open_All;

      procedure Forward (Ops : in out Engine.Op_List; More : out Boolean) is
      begin
         Engine.Forward (P, Ops, More);
      end Forward;

      procedure From_Host (Host : Byte_Array; Ops : in out Engine.Op_List; Left : out Boolean) is
      begin
         Engine.From_Host (P, Parser, Host, Ops, Left);
         if Left then
            for I in 1 .. Ops.Count loop
               Apply (Ops.Items (I));
            end loop;
            Drop;
         end if;
      end From_Host;

      procedure Perform (Ops : Engine.Op_List; First, Last : Positive) is
      begin
         for I in First .. Natural'Min (Last, Ops.Count) loop
            Apply (Ops.Items (I));
         end loop;
      end Perform;

      procedure Release is
      begin
         Drop;
      end Release;

   end Guard;

   procedure Start
     (Mode : Engine.Protocol; Index : Natural; B : Engine.Board; Ops : in out Engine.Op_List; Started : out Boolean)
   is
   begin
      Guard.Start (Mode, Index, B, Ops, Started);
   end Start;

   procedure Open_All (Baud : Unsigned_32; B : Engine.Board; Ops : in out Engine.Op_List; Started : out Boolean) is
   begin
      Guard.Open_All (Baud, B, Ops, Started);
   end Open_All;

   procedure Forward (Ops : in out Engine.Op_List; More : out Boolean) is
   begin
      Guard.Forward (Ops, More);
   end Forward;

   procedure From_Host (Host : Byte_Array; Ops : in out Engine.Op_List; Left : out Boolean) is
   begin
      Guard.From_Host (Host, Ops, Left);
   end From_Host;

   function Pass_Wait_Ms return Natural is (Engine.Pass_Wait_Ms (P));

   procedure Perform (Ops : Engine.Op_List; First, Last : Positive) is
   begin
      Guard.Perform (Ops, First, Last);
   end Perform;

   procedure Release is
   begin
      Guard.Release;
   end Release;

end Adaflight.STM32.ESC_Serial_Port;
