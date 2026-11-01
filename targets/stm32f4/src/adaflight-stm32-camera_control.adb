with System;
with Ada.Interrupts.Names;
with Adaflight.CLI_Resources;
with Adaflight.Config_Runtime;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Time;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.Camera_Control is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   package GPIO renames Adaflight.STM32.GPIO;
   package Core renames Adaflight.Camera_Control;
   use type Core.Mode;

   Settings    : Core.Settings;
   State       : Core.State;
   Output      : Pin := (Port_A, 0);
   CCR_Address : Unsigned_32 := 0;

   --  The basic timers of the software PWM: TIM6 counts the hi time and
   --  TIM7 the period, each update toggling the pin.
   RCC_APB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   TIM6_CR1    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_1000#);
   TIM6_DIER   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_100C#);
   TIM6_SR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_1010#);
   TIM6_CNT    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_1024#);
   TIM6_PSC    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_1028#);
   TIM6_ARR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_102C#);
   TIM7_CR1    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_1400#);
   TIM7_DIER   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_140C#);
   TIM7_SR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_1410#);
   TIM7_CNT    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_1424#);
   TIM7_PSC    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_1428#);
   TIM7_ARR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4000_142C#);
   TIM6_Enable : constant Unsigned_32 := 16#10#;
   TIM7_Enable : constant Unsigned_32 := 16#20#;
   Counter_On  : constant Unsigned_32 := 1;
   Update_IRQ  : constant Unsigned_32 := 1;

   --  The pin high, or low when inverted.
   procedure Set_Level (High : Boolean) is
   begin
      if High /= State.Inverted then
         GPIO.Set_High (Output);
      else
         GPIO.Set_Low (Output);
      end if;
   end Set_Level;

   protected Soft_PWM with Interrupt_Priority => System.Interrupt_Priority'First is
      --  Both timers started as one, then their update interrupts on.
      procedure Start (Hi_Time : Unsigned_32; Period : Unsigned_32);
      procedure Stop;
      procedure Hi with Attach_Handler => Ada.Interrupts.Names.TIM6_DAC_Interrupt;
      procedure Lo with Attach_Handler => Ada.Interrupts.Names.TIM7_Interrupt;
   end Soft_PWM;

   protected body Soft_PWM is
      procedure Start (Hi_Time : Unsigned_32; Period : Unsigned_32) is
      begin
         TIM6_CNT := Hi_Time;
         TIM6_ARR := Period;
         TIM7_CNT := 0;
         TIM7_ARR := Period;
         TIM6_CR1 := Counter_On;
         TIM7_CR1 := Counter_On;
         TIM6_DIER := Update_IRQ;
         TIM7_DIER := Update_IRQ;
      end Start;
      procedure Stop is
      begin
         TIM6_CR1 := TIM6_CR1 and not Counter_On;
         TIM7_CR1 := TIM7_CR1 and not Counter_On;
         TIM6_DIER := 0;
         TIM7_DIER := 0;
      end Stop;
      procedure Hi is
      begin
         Set_Level (High => True);
         TIM6_SR := 0;
      end Hi;
      procedure Lo is
      begin
         Set_Level (High => False);
         TIM7_SR := 0;
      end Lo;
   end Soft_PWM;

   procedure Write_Compare (Value : Natural) is
   begin
      if CCR_Address /= 0 then
         declare
            CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Address);
         begin
            CCR := Unsigned_32 (Value);
         end;
      end if;
   end Write_Compare;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      use Adaflight.STM32.Timers;
      Tag   : constant Interfaces.Unsigned_8 := C.Camera_Control_Config.Io_Tag;
      E     : Timer_Entry;
      Slot  : Natural;
      Found : Boolean := False;
   begin
      Settings := Adaflight.Config_Runtime.Camera_Control_Settings_Of (C.Camera_Control_Config);
      CCR_Address := 0;
      if Tag /= 0 then
         Output := Pin_Of (Natural (Tag));
         GPIO.Enable_Port (Output.Port);
         case Settings.Output is
            when Core.Hardware_PWM =>
               Allocate (Tag, Adaflight.CLI_Resources.Camera_Control, E, Slot, Found);
               if Found then
                  GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.No_Pull, Rate => GPIO.Low);
                  Configure_PWM
                    (E, Timer_Clock_Hz (E.Timer), Core.PWM_Resolution, Core.PWM_Resolution, Settings.Inverted);
                  CCR_Address := CCR_Value (E.Timer, E.Channel);
               end if;
            when Core.Software_PWM =>
               State.Inverted := Settings.Inverted;
               GPIO.Set_Output (Output);
               Set_Level (High => True);
               RCC_APB1ENR := RCC_APB1ENR or TIM6_Enable or TIM7_Enable;
               TIM6_PSC := 0;
               TIM7_PSC := 0;
            when Core.DAC | Core.Unknown =>
               null;
         end case;
      end if;
      Core.Init (State, Settings, Has_Pin => Tag /= 0, Timer_Found => Found);
   end Init;

   function Enabled return Boolean is (State.Enabled);

   procedure Key_Press
     (Code : Interfaces.Unsigned_8; Hold_Ms : Adaflight.Camera_Control.Hold_Time; OSD_Reset : out Boolean)
   is
      P : Core.Press;
   begin
      Core.Key_Press (State, Settings, Code, Hold_Ms, Adaflight.STM32.Time.Millis, P);
      OSD_Reset := P.OSD_Reset;
      if not P.Taken then
         return;
      end if;
      case State.Output is
         when Core.Hardware_PWM =>
            Write_Compare (State.Pulse);
         when Core.Software_PWM =>
            if P.Low_Only then
               Set_Level (High => False);
               Adaflight.STM32.Time.Delay_Ms (P.Wait_Ms);
               Set_Level (High => True);
            else
               Soft_PWM.Start (Unsigned_32 (P.Hi_Time), Unsigned_32 (State.Period));
               declare
                  End_Ms : constant Unsigned_32 := Adaflight.STM32.Time.Millis + Unsigned_32 (P.Wait_Ms);
               begin
                  while Adaflight.STM32.Time.Millis < End_Ms loop
                     null;
                  end loop;
               end;
               Soft_PWM.Stop;
               Set_Level (High => True);
            end if;
         when Core.DAC | Core.Unknown =>
            null;
      end case;
   end Key_Press;

   procedure Process (Now_Us : Adaflight.Scheduler.Time_Us) is
      Idle : Boolean;
   begin
      Core.Process (State, Now_Us, Idle);
      if Idle and then State.Output = Core.Hardware_PWM then
         Write_Compare (State.Pulse);
      end if;
   end Process;

end Adaflight.STM32.Camera_Control;
