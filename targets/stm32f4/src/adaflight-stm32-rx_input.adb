with System;
with Adaflight.CLI_Resources;
with Adaflight.RX_PWM;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
with Adaflight.STM32.Timer_Dispatch;
package body Adaflight.STM32.RX_Input is
   use Interfaces;

   Update_Flag : constant Unsigned_32 := 2 ** 0;

   --  The decoder's state, which the timer's interrupt and the receiver task
   --  share.
   protected Input with Interrupt_Priority => System.Interrupt_Priority'Last is
      procedure Reset;
      procedure Edge (Capture : Unsigned_16);
      procedure Overflow (Capture : Unsigned_16);
      procedure Take_Received (Received : out Boolean);
      function Value (Channel : Natural) return Unsigned_16;
   private
      PPM : Adaflight.RX_PWM.PPM_State;
   end Input;

   protected body Input is
      procedure Reset is
      begin
         Adaflight.RX_PWM.PPM_Init (PPM, 1);
      end Reset;

      procedure Edge (Capture : Unsigned_16) is
      begin
         Adaflight.RX_PWM.PPM_Edge (PPM, Capture);
      end Edge;

      procedure Overflow (Capture : Unsigned_16) is
      begin
         Adaflight.RX_PWM.PPM_Overflow (PPM, Capture);
      end Overflow;

      procedure Take_Received (Received : out Boolean) is
      begin
         Received := Adaflight.RX_PWM.PPM_Receiving (PPM);
         Adaflight.RX_PWM.PPM_Reset_Received (PPM);
      end Take_Received;

      function Value (Channel : Natural) return Unsigned_16 is
        (if Channel in Adaflight.RX_PWM.Capture_Index then PPM.Captures (Channel) else 0);
   end Input;

   Running : Boolean := False with Atomic;
   Where   : Timer_Entry;

   function Capture_Flag (E : Timer_Entry) return Unsigned_32 is (Shift_Left (1, E.Channel));

   --  The timer's pending work, its captures before its overflow as the
   --  timer interrupt serves the highest flag first.
   procedure Serve (T : Timer_Name) is
      Regs   : Timer_Registers with Import, Address => Timer_Base (T);
      Status : Unsigned_32;
   begin
      if not Running or else T /= Where.Timer then
         return;
      end if;
      Status := Regs.SR and Regs.DIER;
      if (Status and Capture_Flag (Where)) /= 0 then
         Regs.SR := not Capture_Flag (Where);
         Input.Edge (Unsigned_16 (CCR_Value (T, Where.Channel) and 16#FFFF#));
      end if;
      if (Status and Update_Flag) /= 0 then
         Regs.SR := not Update_Flag;
         Input.Overflow (Unsigned_16 (Regs.ARR and 16#FFFF#));
      end if;
   end Serve;

   procedure Start_PPM (Tag : Unsigned_8; Started : out Boolean) is
      Found : Boolean;
      E     : Timer_Entry;
   begin
      Started := False;
      if Tag = 0 or else not Can_Take (Tag, Adaflight.CLI_Resources.PPM) then
         return;
      end if;
      Peek (Tag, E, Found);
      if not Found or else not Timer_Dispatch.Served (E.Timer) or else Held_By (E.Timer, Adaflight.CLI_Resources.Motor) then
         return;
      end if;
      Take (Tag, Adaflight.CLI_Resources.PPM, E, Found);
      if not Found then
         return;
      end if;
      Where := E;
      Input.Reset;
      GPIO.Enable_Port (E.Where.Port);
      GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.No_Pull);
      declare
         Regs  : Timer_Registers with Import, Address => Timer_Base (E.Timer);
         Shift : constant Natural := 8 * ((E.Channel - 1) mod 2);
         Bits  : constant Natural := 4 * (E.Channel - 1);
      begin
         Enable_Clock (E.Timer);
         Regs.CR1 := Regs.CR1 and not CEN;
         Set_Time_Base (E.Timer, Reload => 16#FFFF#, Prescale => Timer_Clock_Hz (E.Timer) / 1_000_000 - 1);
         --  The channel an input on its own pin, no filter, no prescaler,
         --  capturing rising edges.
         Regs.CCER := Regs.CCER and not Shift_Left (2#1011#, Bits);
         if E.Channel <= 2 then
            Regs.CCMR1 := (Regs.CCMR1 and not Shift_Left (16#FF#, Shift)) or Shift_Left (1, Shift);
         else
            Regs.CCMR2 := (Regs.CCMR2 and not Shift_Left (16#FF#, Shift)) or Shift_Left (1, Shift);
         end if;
         Regs.CCER := Regs.CCER or Shift_Left (1, Bits);
         Running := True;
         Timer_Dispatch.Register (E.Timer, Serve'Access);
         Regs.SR := 0;
         Regs.DIER := Regs.DIER or Update_Flag or Capture_Flag (E);
         Regs.CR1 := Regs.CR1 or CEN;
      end;
      Started := True;
   end Start_PPM;

   procedure Take_Received (Received : out Boolean) is
   begin
      Input.Take_Received (Received);
   end Take_Received;

   function Channel_Value (Channel : Natural) return Unsigned_16 is (Input.Value (Channel));

end Adaflight.STM32.RX_Input;
