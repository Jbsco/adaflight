package body Adaflight.PWM_Output with SPARK_Mode is

   procedure Endpoints
     (Min_Command, Max_Throttle, Idle, Limit_3D_Low, Limit_3D_High, Neutral_3D, Deadband_3D_Low,
      Deadband_3D_High : Pulse_Width; Output_Limit : Maths.Unit_Interval; Two_Direction : Boolean;
      Low, High, Disarm : out Float; Deadband_High, Deadband_Low : in out Float)
   is
   begin
      if Two_Direction then
         declare
            Offset : constant Float :=
              Float (Integer (Limit_3D_High) - Integer (Limit_3D_Low)) * (1.0 - Output_Limit) / 2.0;
         begin
            Disarm := Float (Neutral_3D);
            Low := Float (Limit_3D_Low) + Offset;
            High := Float (Limit_3D_High) - Offset;
            Deadband_High := Float (Deadband_3D_High);
            Deadband_Low := Float (Deadband_3D_Low);
         end;
      else
         declare
            Min_Throttle : constant Float := Float (Min_Command) + Float (Idle) * 0.1;
         begin
            Disarm := Float (Min_Command);
            Low := Min_Throttle;
            High := Float (Max_Throttle) - ((Float (Max_Throttle) - Min_Throttle) * (1.0 - Output_Limit));
         end;
      end if;
   end Endpoints;

end Adaflight.PWM_Output;
