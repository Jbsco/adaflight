with Adaflight.Maths;
package body Adaflight.Camera_Control with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   procedure Init (S : out State; C : Settings; Has_Pin : Boolean; Timer_Found : Boolean) is
   begin
      S := (Enabled => False, Output => C.Output, Inverted => C.Inverted, Period => 0, Pulse => 0, End_Ms => 0);
      if not Has_Pin then
         return;
      end if;
      case C.Output is
         when Hardware_PWM =>
            if Timer_Found then
               S.Period := PWM_Resolution;
               S.Pulse := PWM_Resolution;
               S.Enabled := True;
            end if;
         when Software_PWM =>
            S.Period := Soft_PWM_Resolution;
            S.Enabled := True;
         when DAC | Unknown =>
            null;
      end case;
   end Init;

   --  The key's voltage in volts: the reference voltage over the ladder of
   --  the internal and the key resistance, in the reference's single
   --  precision order, zero for a ladder without resistance.
   subtype Count_Volts is Float range 0.0 .. 700.0;
   subtype Button_Ohms is Natural range 0 .. Setting_Value'Last * 100;
   subtype Volt_Ohms is Float range 0.0 .. 1.0e10;
   function Key_Voltage (C : Settings; K : Key) return Float
     with Post => Key_Voltage'Result in Volt_Ohms;
   function Key_Voltage (C : Settings; K : Key) return Float is
      Ohms        : constant Button_Ohms := C.Buttons (K) * 100;
      Ladder_Ohms : constant Natural := 100 * C.Internal_Resistance + Ohms;
   begin
      if Ladder_Ohms = 0 then
         return 0.0;
      end if;
      declare
         Per_Count : constant Count_Volts := 1.0e-2 * Float (C.Ref_Voltage);
         Product   : constant Volt_Ohms := Per_Count * Float (Ohms);
      begin
         return Product / Float (Ladder_Ohms);
      end;
   end Key_Voltage;

   --  The count of a duty over a period, rounded as the C library rounds.
   function Duty_Count (C : Settings; K : Key; Period : Natural) return Count is
      Voltage : constant Volt_Ohms := Key_Voltage (C, K);
      Duty    : constant Float := Voltage / Supply_Volts;
      Scaled  : constant Float := Duty * Float (Period);
   begin
      if Scaled <= 0.0 then
         return 0;
      elsif Scaled >= Float (Count'Last) then
         return Count'Last;
      end if;
      return Count (Integer'Max (0, Integer'Min (Count'Last, Adaflight.Maths.Round_Half_Even (Scaled))));
   end Duty_Count;

   procedure Key_Press
     (S : in out State; C : Settings; Code : Interfaces.Unsigned_8; Hold_Ms : Hold_Time; Now_Ms : Unsigned_32;
      P : out Press)
   is
      K : Key;
   begin
      P := (Taken => False, OSD_Reset => False, Hi_Time => 0, Wait_Ms => 0, Low_Only => False);
      if not S.Enabled or else Natural (Code) > Key'Pos (Key'Last) then
         return;
      end if;
      K := Key'Val (Natural (Code));
      P.Taken := True;
      P.OSD_Reset := True;
      case S.Output is
         when Hardware_PWM =>
            S.Pulse := Duty_Count (C, K, S.Period);
            S.End_Ms := Now_Ms + Unsigned_32 (C.Key_Delay_Ms) + Unsigned_32 (Hold_Ms);
         when Software_PWM =>
            P.Hi_Time := Duty_Count (C, K, S.Period);
            P.Wait_Ms := C.Key_Delay_Ms + Hold_Ms;
            P.Low_Only := P.Hi_Time = 0;
         when DAC | Unknown =>
            null;
      end case;
   end Key_Press;

   procedure Process (S : in out State; Now_Us : Unsigned_32; Idle : out Boolean) is
   begin
      Idle := False;
      if not S.Enabled or else S.End_Ms = 0 or else Now_Us / 1_000 < S.End_Ms then
         return;
      end if;
      if S.Output = Hardware_PWM then
         S.Pulse := S.Period;
      end if;
      S.End_Ms := 0;
      Idle := True;
   end Process;

end Adaflight.Camera_Control;
