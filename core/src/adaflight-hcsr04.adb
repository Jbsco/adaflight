package body Adaflight.HCSR04 with SPARK_Mode is

   use type Interfaces.Unsigned_32;

   subtype I32 is Interfaces.Integer_32;
   subtype U32 is Interfaces.Unsigned_32;

   Max_Range_Cm       : constant := 400;
   Firing_Interval_Ms : constant := 60;
   Us_Per_Cm_Twice    : constant := 59;
   Attempts           : constant := 5;

   function To_I32 (U : U32) return I32 is
     (if U < 2 ** 31 then I32 (U) else I32 (U - 2 ** 31) - 2_147_483_647 - 1)
     with Global => null;

   procedure Fire (D : in out Pin_Device; C : Config) is
   begin
      Pin_High (D, C.Trigger_Tag);
      Delay_Us (D, 11);
      Pin_Low (D, C.Trigger_Tag);
   end Fire;

   procedure Detect (D : in out Pin_Device; C : Config; S : in out State; Found : out Boolean; Dev : out Device) is
      Owned    : Boolean;
      High     : Boolean;
      Request  : U32;
      Now      : U32;
      Detected : Boolean := False;
   begin
      Dev := (others => <>);
      Found := False;
      S.Pins := C;
      Pin_Owned (D, C.Trigger_Tag, Owned);
      if Owned then
         return;
      end if;
      Pin_Owned (D, C.Echo_Tag, Owned);
      if Owned then
         return;
      end if;
      Init_Pin (D, C.Trigger_Tag, Trigger_Owner);
      Config_Pin (D, C.Trigger_Tag, False);
      Pin_Low (D, C.Trigger_Tag);
      Delay_Ms (D, 100);
      Init_Pin (D, C.Echo_Tag, Echo_Owner);
      Config_Pin (D, C.Echo_Tag, True);
      Read_Pin (D, C.Echo_Tag, High);
      if not High then
         for Attempt in 1 .. Attempts loop
            exit when Detected;
            Millis (D, Request);
            Fire (D, C);
            loop
               Millis (D, Now);
               exit when Now - Request >= Firing_Interval_Ms;
               Read_Pin (D, C.Echo_Tag, High);
               if High then
                  Detected := True;
                  exit;
               end if;
            end loop;
         end loop;
      end if;
      if Detected then
         Interrupt_Init (D);
         Interrupt_Config (D, C.Echo_Tag);
         Interrupt_Enable (D, C.Echo_Tag);
         Dev := (Delay_Ms => 100, Max_Range_Cm => Max_Range_Cm, Cone_Decidegrees => 300,
                 Cone_Extended_Decidegrees => 450);
         Found := True;
      else
         Release_Pin (D, C.Trigger_Tag);
         Release_Pin (D, C.Echo_Tag);
      end if;
   end Detect;

   procedure Echo_Edge (S : in out State; High : Boolean; Now_Us : Interfaces.Unsigned_32) is
   begin
      if High then
         S.Timing_Start_Us := Now_Us;
      elsif Now_Us > S.Timing_Start_Us then
         S.Received_Ms := Now_Us / 1000;
         S.Travel_Us := To_I32 (Now_Us - S.Timing_Start_Us);
      end if;
   end Echo_Edge;

   procedure Update (D : in out Pin_Device; S : in out State) is
      Now      : U32;
      Distance : I32;
   begin
      Millis (D, Now);
      if S.Received_Ms > S.Started_Ms and then S.Received_Ms - S.Started_Ms <= Firing_Interval_Ms then
         Distance := S.Travel_Us / Us_Per_Cm_Twice;
         S.Last_Distance := (if Distance > Max_Range_Cm then Out_Of_Range else Distance);
      elsif S.Received_Ms - S.Started_Ms > Firing_Interval_Ms then
         S.Last_Distance := Hardware_Failure;
      end if;
      if Now > S.Started_Ms + Firing_Interval_Ms then
         S.Started_Ms := Now;
         Fire (D, S.Pins);
      end if;
   end Update;

   procedure Read (S : in out State; Distance : out Reading) is
   begin
      Distance := S.Last_Distance;
      S.Last_Distance := No_New_Data;
   end Read;

end Adaflight.HCSR04;
