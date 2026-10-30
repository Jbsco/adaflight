with Adaflight.PWM_Output;
with Adaflight.Timer_Tables;
package body Adaflight.STM32.Timers is

   RCC_AHB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3830#);
   RCC_APB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   RCC_APB2ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3844#);

   Table : Adaflight.Timer_Allocation.Table;

   function Tagged_Pin (Tag : Unsigned_8) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Unsigned_8) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   --  A timer by its number in the timer table.
   function Name_Of (N : Adaflight.Timer_Tables.Timer_Number) return Timer_Name is
     (case N is
         when 1 => TIM1, when 2 => TIM2, when 3 => TIM3, when 4 => TIM4, when 5 => TIM5, when 8 => TIM8,
         when 9 => TIM9, when 10 => TIM10, when 11 => TIM11, when 12 => TIM12, when 13 => TIM13,
         when 14 => TIM14, when others => TIM1);

   procedure Load (Map : Adaflight.Config_Groups.Timer_Io_Config_Record_List_21) is
   begin
      Adaflight.Timer_Allocation.Load (Table, Map);
   end Load;

   function Owners return Adaflight.CLI_Resources.Timer_Owner_List is (Table.Owners);
   function Option_Of (Slot : Adaflight.Timer_Allocation.Slot) return Integer is
     (Integer (Adaflight.Timer_Allocation.Option_Of (Table, Slot)));

   procedure Allocate
     (Tag : Unsigned_8; Who : Adaflight.CLI_Resources.Owner; E : out Timer_Entry; Slot : out Natural;
      Found : out Boolean; Ordinal : Natural := 0)
   is
      K : Adaflight.Timer_Allocation.Channel_Index;
   begin
      E := (TIM1, 1, False, (Port_A, 0));
      Adaflight.Timer_Allocation.Allocate (Table, Tag, Who, Natural'Min (Ordinal, 16), K, Slot);
      Found := K /= 0 and then Tagged_Pin (Tag);
      if Found then
         declare
            C : Adaflight.Timer_Tables.Timer_Channel renames Adaflight.Timer_Tables.Channels (K);
         begin
            E := (Timer => Name_Of (C.Timer), Channel => C.Channel, N => C.N, Where => Pin_Of (Tag));
         end;
      end if;
   end Allocate;

   --  The stream's interrupt flag clear register and its six-bit group in it.
   procedure Clear_Flags (S : DMA_Stream) is
      Shifts : constant array (0 .. 3) of Natural := (0, 6, 16, 22);
      Clear  : Unsigned_32 with Volatile, Import,
        Address => System'To_Address (DMA_Base (S.Controller) + (if S.Stream < 4 then 16#08# else 16#0C#));
   begin
      Clear := Shift_Left (16#3D#, Shifts (S.Stream mod 4));
   end Clear_Flags;

   procedure Enable_DMA (S : DMA_Stream) is
   begin
      RCC_AHB1ENR := RCC_AHB1ENR or Shift_Left (1, 20 + S.Controller);
   end Enable_DMA;

   procedure Enable_Clock (T : Timer_Name) is
   begin
      if On_APB2 (T) then
         RCC_APB2ENR := RCC_APB2ENR or Shift_Left (1, Enable_Bit (T));
      else
         RCC_APB1ENR := RCC_APB1ENR or Shift_Left (1, Enable_Bit (T));
      end if;
   end Enable_Clock;

   procedure Set_Time_Base (T : Timer_Name; Reload : Unsigned_32; Prescale : Unsigned_32) is
      Regs : Timer_Registers with Import, Address => Timer_Base (T);
   begin
      if T in TIM1 | TIM2 | TIM3 | TIM4 | TIM5 | TIM8 then
         Regs.CR1 := Regs.CR1 and not 2#111_0000#;
      end if;
      Regs.CR1 := Regs.CR1 and not (2 ** 8 or 2 ** 9);
      Regs.ARR := Reload;
      Regs.PSC := Prescale;
      if Advanced (T) then
         Regs.RCR := 0;
      end if;
      Regs.EGR := UG;
   end Set_Time_Base;

   procedure Set_Output_Compare (E : Timer_Entry; Pulse : Unsigned_16; Inverted : Boolean) is
      Regs    : Timer_Registers with Import, Address => Timer_Base (E.Timer);
      CCR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Value (E.Timer, E.Channel));
      Byte    : constant Natural := (if E.Channel mod 2 = 1 then 0 else 8);
      Base    : constant Natural := 4 * (E.Channel - 1);
      Idle    : constant Natural := 8 + 2 * (E.Channel - 1);
      Mode    : Unsigned_32;
      Enables : Unsigned_32;
      Control : Unsigned_32;
   begin
      Regs.CCER := Regs.CCER and not Shift_Left (2#0001#, Base);
      Enables := Regs.CCER and not Shift_Left (2#0010#, Base);
      Control := Regs.CR2;
      Mode := (if E.Channel <= 2 then Regs.CCMR1 else Regs.CCMR2);
      Mode := (Mode and not Shift_Left (16#73#, Byte)) or Shift_Left (16#60#, Byte);
      if not E.N then
         Enables := Enables or Shift_Left (2#0001#, Base) or (if Inverted then Shift_Left (2#0010#, Base) else 0);
      end if;
      if Advanced (E.Timer) then
         if E.Channel < 4 then
            Enables := Enables and not Shift_Left (2#1100#, Base);
            if E.N then
               Enables := Enables or Shift_Left (2#0100#, Base) or (if Inverted then Shift_Left (2#1000#, Base) else 0);
            end if;
            Control := Control and not Shift_Left (2#11#, Idle);
         else
            Control := Control and not Shift_Left (2#01#, Idle);
         end if;
         if not E.N then
            Control := Control or Shift_Left (1, Idle);
         end if;
      end if;
      Regs.CR2 := Control;
      if E.Channel <= 2 then
         Regs.CCMR1 := Mode;
      else
         Regs.CCMR2 := Mode;
      end if;
      CCR := Unsigned_32 (Pulse);
      Regs.CCER := Enables;
      if E.Channel <= 2 then
         Regs.CCMR1 := Regs.CCMR1 or Shift_Left (16#08#, Byte);
      else
         Regs.CCMR2 := Regs.CCMR2 or Shift_Left (16#08#, Byte);
      end if;
   end Set_Output_Compare;

   procedure Configure_PWM
     (E : Timer_Entry; Hz : Unsigned_32; Period : Unsigned_16; Pulse : Unsigned_16; Inverted : Boolean)
   is
      Regs : Timer_Registers with Import, Address => Timer_Base (E.Timer);
      CCR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Value (E.Timer, E.Channel));
   begin
      Enable_Clock (E.Timer);
      Set_Time_Base
        (E.Timer, Adaflight.PWM_Output.Auto_Reload (Period),
         Adaflight.PWM_Output.Prescaler (Timer_Clock_Hz (E.Timer), Hz));
      Set_Output_Compare (E, Pulse, Inverted);
      if Advanced (E.Timer) then
         Regs.BDTR := Regs.BDTR or MOE;
      end if;
      Regs.CR1 := Regs.CR1 or CEN;
      CCR := 0;
   end Configure_PWM;

end Adaflight.STM32.Timers;
