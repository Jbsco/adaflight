with System;
with Adaflight.CLI_Resources;
with Adaflight.RX_PWM;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
with Adaflight.STM32.Timer_Dispatch;
package body Adaflight.STM32.RX_Input is
   use Interfaces;
   use type Adaflight.RX_PWM.Polarity;

   package RX_PWM renames Adaflight.RX_PWM;

   Update_Flag  : constant Unsigned_32 := 2 ** 0;
   Noise_Filter : constant Unsigned_32 := 3;

   type Input_Mode is (Off, PPM_Input, PWM_Input);

   type Decoder_State (Mode : Input_Mode := Off) is record
      case Mode is
         when Off =>
            null;
         when PPM_Input =>
            PPM : RX_PWM.PPM_State;
         when PWM_Input =>
            PWM : RX_PWM.PWM_State;
      end case;
   end record;

   --  The decoder's state, which the timers' interrupts and the receiver task
   --  share.
   protected Input with Interrupt_Priority => System.Interrupt_Priority'Last is
      procedure Reset (To : Input_Mode);
      procedure Edge (Port : RX_PWM.Port_Index; Capture : Unsigned_16; Next : out RX_PWM.Polarity);
      procedure Overflow (Port : RX_PWM.Port_Index; Capture : Unsigned_16);
      procedure Take_Received (Received : out Boolean);
      function Value (Channel : Natural) return Unsigned_16;
   private
      Decoder : Decoder_State;
   end Input;

   protected body Input is
      procedure Reset (To : Input_Mode) is
      begin
         case To is
            when Off =>
               Decoder := (Mode => Off);
            when PPM_Input =>
               declare
                  S : RX_PWM.PPM_State;
               begin
                  RX_PWM.PPM_Init (S, 1);
                  Decoder := (Mode => PPM_Input, PPM => S);
               end;
            when PWM_Input =>
               declare
                  S : RX_PWM.PWM_State;
               begin
                  RX_PWM.PWM_Init (S);
                  Decoder := (Mode => PWM_Input, PWM => S);
               end;
         end case;
      end Reset;

      procedure Edge (Port : RX_PWM.Port_Index; Capture : Unsigned_16; Next : out RX_PWM.Polarity) is
      begin
         Next := RX_PWM.Rising;
         case Decoder.Mode is
            when Off =>
               null;
            when PPM_Input =>
               RX_PWM.PPM_Edge (Decoder.PPM, Capture);
            when PWM_Input =>
               RX_PWM.PWM_Edge (Decoder.PWM, Port, Capture, Next);
         end case;
      end Edge;

      procedure Overflow (Port : RX_PWM.Port_Index; Capture : Unsigned_16) is
      begin
         case Decoder.Mode is
            when Off =>
               null;
            when PPM_Input =>
               RX_PWM.PPM_Overflow (Decoder.PPM, Capture);
            when PWM_Input =>
               RX_PWM.PWM_Overflow (Decoder.PWM, Port);
         end case;
      end Overflow;

      procedure Take_Received (Received : out Boolean) is
      begin
         case Decoder.Mode is
            when Off =>
               Received := False;
            when PPM_Input =>
               Received := RX_PWM.PPM_Receiving (Decoder.PPM);
               RX_PWM.PPM_Reset_Received (Decoder.PPM);
            when PWM_Input =>
               Received := RX_PWM.PWM_Receiving (Decoder.PWM);
         end case;
      end Take_Received;

      function Value (Channel : Natural) return Unsigned_16 is
        (if Channel not in RX_PWM.Capture_Index then 0
         else
           (case Decoder.Mode is
              when Off       => 0,
              when PPM_Input => Decoder.PPM.Captures (Channel),
              when PWM_Input => Decoder.PWM.Captures (Channel)));
   end Input;

   --  Each port's timer channel, the PPM pin's at port 0.
   type Port_Place is record
      Used    : Boolean        := False;
      Timer   : Timer_Name     := TIM1;
      Channel : Channel_Number := 1;
   end record;
   type Port_Places is array (RX_PWM.Port_Index) of Port_Place;

   Running     : Input_Mode := Off with Atomic;
   Places      : Port_Places;
   Filter_Bits : Unsigned_32 := 0;

   function Capture_Flag (C : Channel_Number) return Unsigned_32 is (Shift_Left (1, C));

   --  A channel an input on its own pin through the filter without a
   --  prescaler, capturing the edges of one polarity: its capture off while
   --  the input and the polarity change, then on.
   procedure Configure_Input (T : Timer_Name; C : Channel_Number; Falling : Boolean; Filter : Unsigned_32) is
      Regs       : Timer_Registers with Import, Address => Timer_Base (T);
      Shift      : constant Natural := 8 * ((C - 1) mod 2);
      Bits       : constant Natural := 4 * (C - 1);
      Input_Bits : constant Unsigned_32 := Shift_Left (1 or Shift_Left (Filter, 4), Shift);
   begin
      Regs.CCER := Regs.CCER and not Shift_Left (1, Bits);
      if C <= 2 then
         Regs.CCMR1 := (Regs.CCMR1 and not Shift_Left (16#FF#, Shift)) or Input_Bits;
      else
         Regs.CCMR2 := (Regs.CCMR2 and not Shift_Left (16#FF#, Shift)) or Input_Bits;
      end if;
      Regs.CCER :=
        (Regs.CCER and not Shift_Left (2#1010#, Bits)) or Shift_Left ((if Falling then 2#0011# else 2#0001#), Bits);
   end Configure_Input;

   --  The timer's pending work, as the timer interrupt serves its flags: its
   --  ports' captures from the highest channel down, then its overflow for
   --  each of its ports.
   procedure Serve (T : Timer_Name) is
      Regs   : Timer_Registers with Import, Address => Timer_Base (T);
      Mode   : constant Input_Mode := Running;
      Status : Unsigned_32;
      Next   : RX_PWM.Polarity;
   begin
      if Mode = Off then
         return;
      end if;
      Status := Regs.SR and Regs.DIER;
      for C in reverse Channel_Number loop
         if (Status and Capture_Flag (C)) /= 0 then
            for P in Places'Range loop
               if Places (P).Used and then Places (P).Timer = T and then Places (P).Channel = C then
                  Regs.SR := not Capture_Flag (C);
                  Input.Edge (P, Unsigned_16 (CCR_Value (T, C) and 16#FFFF#), Next);
                  if Mode = PWM_Input then
                     Configure_Input (T, C, Next = RX_PWM.Falling, Filter_Bits);
                  end if;
               end if;
            end loop;
         end if;
      end loop;
      if (Status and Update_Flag) /= 0 then
         Regs.SR := not Update_Flag;
         for P in Places'Range loop
            if Places (P).Used and then Places (P).Timer = T then
               Input.Overflow (P, Unsigned_16 (Regs.ARR and 16#FFFF#));
            end if;
         end loop;
      end if;
   end Serve;

   --  A pin on its timer's alternate function, and its timer stopped and set
   --  to count at 1 MHz over 65,536 counts.
   procedure Set_Up (E : Timer_Entry) is
      Regs : Timer_Registers with Import, Address => Timer_Base (E.Timer);
   begin
      GPIO.Enable_Port (E.Where.Port);
      GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.No_Pull);
      Enable_Clock (E.Timer);
      Regs.CR1 := Regs.CR1 and not CEN;
      Set_Time_Base (E.Timer, Reload => 16#FFFF#, Prescale => Timer_Clock_Hz (E.Timer) / 1_000_000 - 1);
   end Set_Up;

   --  A timer's overflow and its ports' captures given to the interrupt, and
   --  the timer counting.
   procedure Start_Timer (T : Timer_Name) is
      Regs  : Timer_Registers with Import, Address => Timer_Base (T);
      Flags : Unsigned_32 := Update_Flag;
   begin
      for P of Places loop
         if P.Used and then P.Timer = T then
            Flags := Flags or Capture_Flag (P.Channel);
         end if;
      end loop;
      Timer_Dispatch.Register (T, Serve'Access);
      Regs.SR := 0;
      Regs.DIER := Regs.DIER or Flags;
      Regs.CR1 := Regs.CR1 or CEN;
   end Start_Timer;

   --  Whether a pin's timer can give an input: one the dispatch serves and no
   --  motor holds.
   function Free_Timer (E : Timer_Entry) return Boolean is
     (Timer_Dispatch.Served (E.Timer) and then not Held_By (E.Timer, Adaflight.CLI_Resources.Motor));

   procedure Start_PPM (Tag : Unsigned_8; Started : out Boolean) is
      Found : Boolean;
      E     : Timer_Entry;
   begin
      Started := False;
      if Tag = 0 or else not Can_Take (Tag, Adaflight.CLI_Resources.PPM) then
         return;
      end if;
      Peek (Tag, E, Found);
      if not Found or else not Free_Timer (E) then
         return;
      end if;
      Take (Tag, Adaflight.CLI_Resources.PPM, E, Found);
      if not Found then
         return;
      end if;
      Places := (0 => (True, E.Timer, E.Channel), others => <>);
      Filter_Bits := 0;
      Input.Reset (PPM_Input);
      Set_Up (E);
      Configure_Input (E.Timer, E.Channel, Falling => False, Filter => 0);
      Running := PPM_Input;
      Start_Timer (E.Timer);
      Started := True;
   end Start_PPM;

   procedure Start_PWM (Tags : Adaflight.Config_Groups.Bytes_8; Filtering : Boolean) is
      Found : Boolean;
      E     : Timer_Entry;
      Slot  : Natural;
   begin
      Places := (others => <>);
      Filter_Bits := (if Filtering then Noise_Filter else 0);
      Input.Reset (PWM_Input);
      for P in RX_PWM.Port_Index loop
         if Tags (P) /= 0 then
            Peek (Tags (P), E, Found);
            if Found and then Free_Timer (E) then
               Allocate (Tags (P), Adaflight.CLI_Resources.PWM, E, Slot, Found, Ordinal => P + 1);
               if Found then
                  Places (P) := (True, E.Timer, E.Channel);
                  Set_Up (E);
                  Configure_Input (E.Timer, E.Channel, Falling => False, Filter => Filter_Bits);
               end if;
            end if;
         end if;
      end loop;
      Running := PWM_Input;
      for P in RX_PWM.Port_Index loop
         if Places (P).Used
           and then (for all Q in RX_PWM.Port_Index'First .. P - 1 =>
                       not Places (Q).Used or else Places (Q).Timer /= Places (P).Timer)
         then
            Start_Timer (Places (P).Timer);
         end if;
      end loop;
   end Start_PWM;

   procedure Take_Received (Received : out Boolean) is
   begin
      Input.Take_Received (Received);
   end Take_Received;

   function Channel_Value (Channel : Natural) return Unsigned_16 is (Input.Value (Channel));

end Adaflight.STM32.RX_Input;
