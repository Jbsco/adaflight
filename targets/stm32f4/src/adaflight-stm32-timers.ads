--  The STM32F405's timers: the timer table, each timer's registers, clock,
--  alternate function and enable bit, the owners of the configured timer
--  pin map's entries, and a channel's setup as a PWM output.
with Interfaces;
with System;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.CLI_Resources;
with Adaflight.Config_Groups;
with Adaflight.Timer_Allocation;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
package Adaflight.STM32.Timers is
   use Interfaces;

   type Timer_Name is (TIM1, TIM2, TIM3, TIM4, TIM5, TIM8, TIM9, TIM10, TIM11, TIM12, TIM13, TIM14);
   subtype Channel_Number is Positive range 1 .. 4;

   --  An entry of the processor's timer table: the timer, the channel,
   --  whether the pin is the complementary output, and the pin.
   type Timer_Entry is record
      Timer   : Timer_Name;
      Channel : Channel_Number;
      N       : Boolean;
      Where   : Pin;
   end record;

   Timer_Base_Value : constant array (Timer_Name) of Unsigned_32 :=
     (TIM1  => 16#4001_0000#, TIM2  => 16#4000_0000#, TIM3  => 16#4000_0400#, TIM4  => 16#4000_0800#,
      TIM5  => 16#4000_0C00#, TIM8  => 16#4001_0400#, TIM9  => 16#4001_4000#, TIM10 => 16#4001_4400#,
      TIM11 => 16#4001_4800#, TIM12 => 16#4000_1800#, TIM13 => 16#4000_1C00#, TIM14 => 16#4000_2000#);

   function Timer_Base (T : Timer_Name) return System.Address is (System'To_Address (Timer_Base_Value (T)));

   --  The timers on the APB2 bus count at 168 MHz, the others at 84 MHz.
   Timer_Clock_Hz : constant array (Timer_Name) of Unsigned_32 :=
     (TIM1 | TIM8 | TIM9 | TIM10 | TIM11 => Adaflight.STM32.Platform.APB2_Timer_Hz,
      others => Adaflight.STM32.Platform.APB1_Timer_Hz);

   Alternate : constant array (Timer_Name) of Adaflight.STM32.GPIO.Alternate_Function :=
     (TIM1 | TIM2 => 1, TIM3 | TIM4 | TIM5 => 2, TIM8 | TIM9 | TIM10 | TIM11 => 3, TIM12 | TIM13 | TIM14 => 9);

   Advanced : constant array (Timer_Name) of Boolean := (TIM1 | TIM8 => True, others => False);

   --  The enable bit of each timer in RCC_APB1ENR, or in RCC_APB2ENR for
   --  the APB2 timers.
   On_APB2    : constant array (Timer_Name) of Boolean := (TIM1 | TIM8 | TIM9 | TIM10 | TIM11 => True, others => False);
   Enable_Bit : constant array (Timer_Name) of Natural :=
     (TIM2 => 0, TIM3 => 1, TIM4 => 2, TIM5 => 3, TIM12 => 6, TIM13 => 7, TIM14 => 8,
      TIM1 => 0, TIM8 => 1, TIM9 => 16, TIM10 => 17, TIM11 => 18);

   type Timer_Registers is record
      CR1, CR2, SMCR, DIER, SR, EGR, CCMR1, CCMR2, CCER, CNT, PSC, ARR, RCR : Unsigned_32;
      CCR                                                                : Unsigned_32;
      CCR2, CCR3, CCR4, BDTR                                             : Unsigned_32;
   end record with Volatile;
   for Timer_Registers use record
      CR1   at 16#00# range 0 .. 31;
      CR2   at 16#04# range 0 .. 31;
      SMCR  at 16#08# range 0 .. 31;
      DIER  at 16#0C# range 0 .. 31;
      SR    at 16#10# range 0 .. 31;
      EGR   at 16#14# range 0 .. 31;
      CCMR1 at 16#18# range 0 .. 31;
      CCMR2 at 16#1C# range 0 .. 31;
      CCER  at 16#20# range 0 .. 31;
      CNT   at 16#24# range 0 .. 31;
      PSC   at 16#28# range 0 .. 31;
      ARR   at 16#2C# range 0 .. 31;
      RCR   at 16#30# range 0 .. 31;
      CCR   at 16#34# range 0 .. 31;
      CCR2  at 16#38# range 0 .. 31;
      CCR3  at 16#3C# range 0 .. 31;
      CCR4  at 16#40# range 0 .. 31;
      BDTR  at 16#44# range 0 .. 31;
   end record;

   CEN  : constant Unsigned_32 := 2 ** 0;
   ARPE : constant Unsigned_32 := 2 ** 7;
   UG   : constant Unsigned_32 := 2 ** 0;
   MOE  : constant Unsigned_32 := 2 ** 15;

   --  The channel's compare register.
   function CCR_Value (T : Timer_Name; C : Channel_Number) return Unsigned_32 is
     (Timer_Base_Value (T) + 16#34# + 4 * Unsigned_32 (C - 1));

   --  A DMA stream: its controller, its number and its channel.
   type DMA_Stream is record
      Controller : Positive range 1 .. 2 := 1;
      Stream     : Natural range 0 .. 7 := 0;
      Channel    : Natural range 0 .. 7 := 0;
   end record;
   type DMA_Options is array (Natural range <>) of DMA_Stream;

   --  The streams a timer channel's request reaches, by option.
   function Options_Of (T : Timer_Name; C : Channel_Number) return DMA_Options is
     (case T is
         when TIM1 =>
           (case C is
               when 1 => ((2, 6, 0), (2, 1, 6), (2, 3, 6)),
               when 2 => ((2, 6, 0), (2, 2, 6)),
               when 3 => ((2, 6, 0), (2, 6, 6)),
               when 4 => (0 => (2, 4, 6))),
         when TIM2 =>
           (case C is
               when 1 => (0 => (1, 5, 3)),
               when 2 => (0 => (1, 6, 3)),
               when 3 => (0 => (1, 1, 3)),
               when 4 => ((1, 7, 3), (1, 6, 3))),
         when TIM3 =>
           (case C is
               when 1 => (0 => (1, 4, 5)),
               when 2 => (0 => (1, 5, 5)),
               when 3 => (0 => (1, 7, 5)),
               when 4 => (0 => (1, 2, 5))),
         when TIM4 =>
           (case C is
               when 1 => (0 => (1, 0, 2)),
               when 2 => (0 => (1, 3, 2)),
               when 3 => (0 => (1, 7, 2)),
               when 4 => (1 .. 0 => (1, 0, 0))),
         when TIM5 =>
           (case C is
               when 1 => (0 => (1, 2, 6)),
               when 2 => (0 => (1, 4, 6)),
               when 3 => (0 => (1, 0, 6)),
               when 4 => ((1, 1, 6), (1, 3, 6))),
         when TIM8 =>
           (case C is
               when 1 => ((2, 2, 0), (2, 2, 7)),
               when 2 => ((2, 2, 0), (2, 3, 7)),
               when 3 => ((2, 2, 0), (2, 4, 7)),
               when 4 => (0 => (2, 7, 7))),
         when others => (1 .. 0 => (1, 0, 0)));

   DMA_Base : constant array (1 .. 2) of Unsigned_32 := (16#4002_6000#, 16#4002_6400#);

   type Stream_Registers is record
      CR, NDTR, PAR, M0AR, M1AR, FCR : Unsigned_32;
   end record with Volatile;
   for Stream_Registers use record
      CR   at 16#00# range 0 .. 31;
      NDTR at 16#04# range 0 .. 31;
      PAR  at 16#08# range 0 .. 31;
      M0AR at 16#0C# range 0 .. 31;
      M1AR at 16#10# range 0 .. 31;
      FCR  at 16#14# range 0 .. 31;
   end record;

   function Stream_Address (S : DMA_Stream) return System.Address is
     (System'To_Address (DMA_Base (S.Controller) + 16#10# + 16#18# * Unsigned_32 (S.Stream)));

   EN       : constant Unsigned_32 := 2 ** 0;
   DIR_M2P  : constant Unsigned_32 := 2 ** 6;
   MINC     : constant Unsigned_32 := 2 ** 10;
   PSIZE_32 : constant Unsigned_32 := 2 ** 12;
   MSIZE_32 : constant Unsigned_32 := 2 ** 14;
   PL_High  : constant Unsigned_32 := 2 ** 17;
   DMDIS    : constant Unsigned_32 := 2 ** 2;

   --  A stream's flags cleared, and its controller's clock on.
   procedure Clear_Flags (S : DMA_Stream);
   procedure Enable_DMA (S : DMA_Stream);

   --  The configured timer pin map taken in at boot, every entry free.
   procedure Load (Map : Adaflight.Config_Groups.Timer_Io_Config_Record_List_21);

   --  The timer channel of a pin by its tag, which the owner holds from then
   --  on: the pin's first map entry at its occurrence among the pin's
   --  channels, with the entry's slot. A pin without an entry, an occurrence
   --  past the pin's channels, or a channel another owner holds gives none.
   procedure Allocate
     (Tag : Unsigned_8; Who : Adaflight.CLI_Resources.Owner; E : out Timer_Entry; Slot : out Natural;
      Found : out Boolean; Ordinal : Natural := 0);

   --  The map entries' owners with their ordinals, and an entry's DMA
   --  option, minus one for none.
   function Owners return Adaflight.CLI_Resources.Timer_Owner_List;
   function Option_Of (Slot : Adaflight.Timer_Allocation.Slot) return Integer;

   --  A timer's clock on.
   procedure Enable_Clock (T : Timer_Name);
   --  A timer counting up without clock division at a prescaler over an
   --  auto-reload value, the repetition counter cleared and the update
   --  generated.
   procedure Set_Time_Base (T : Timer_Name; Reload : Unsigned_32; Prescale : Unsigned_32);
   --  A channel in PWM mode 1 at Pulse with its preload and its output on,
   --  high or, when Inverted, low.
   procedure Set_Output_Compare (E : Timer_Entry; Pulse : Unsigned_16; Inverted : Boolean);

   --  A channel set up as a PWM output: the timer's clock on, the timer
   --  counting up at Hz over Period, the channel in PWM mode 1 at Pulse with
   --  its preload and its output on, high or, when Inverted, low, then the
   --  outputs and the timer on and the compare register cleared.
   procedure Configure_PWM
     (E : Timer_Entry; Hz : Unsigned_32; Period : Unsigned_16; Pulse : Unsigned_16; Inverted : Boolean);

end Adaflight.STM32.Timers;
