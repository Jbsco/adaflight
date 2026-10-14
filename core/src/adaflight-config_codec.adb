with Ada.Unchecked_Conversion;
with Interfaces; use Interfaces;
with Adaflight.Float_Bits;

package body Adaflight.Config_Codec with SPARK_Mode => Off is

   procedure Put_Unsigned_8 (D : in out Data; Pos : Natural; V : Unsigned_8)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      D (Pos) := V;
   end Put_Unsigned_8;

   function Get_Unsigned_8 (D : Data; Pos : Natural) return Unsigned_8 is (D (Pos))
     with Pre => Pos <= Data_Size - 1;

   procedure Put_Integer_8 (D : in out Data; Pos : Natural; V : Integer_8)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      D (Pos) := (if V < 0 then Unsigned_8 (Integer (V) + 256) else Unsigned_8 (V));
   end Put_Integer_8;

   function Get_Integer_8 (D : Data; Pos : Natural) return Integer_8 is
     (if D (Pos) > 127 then Integer_8 (Integer (D (Pos)) - 256) else Integer_8 (D (Pos)))
     with Pre => Pos <= Data_Size - 1;

   procedure Put_Boolean (D : in out Data; Pos : Natural; V : Boolean)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      D (Pos) := Boolean'Pos (V);
   end Put_Boolean;

   function Get_Boolean (D : Data; Pos : Natural) return Boolean is (D (Pos) /= 0)
     with Pre => Pos <= Data_Size - 1;

   procedure Put_Unsigned_16 (D : in out Data; Pos : Natural; V : Unsigned_16)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      D (Pos) := Unsigned_8 (V and 16#FF#);
      D (Pos + 1) := Unsigned_8 (Shift_Right (V, 8));
   end Put_Unsigned_16;

   function Get_Unsigned_16 (D : Data; Pos : Natural) return Unsigned_16 is
     (Unsigned_16 (D (Pos)) or Shift_Left (Unsigned_16 (D (Pos + 1)), 8))
     with Pre => Pos <= Data_Size - 2;

   procedure Put_Integer_16 (D : in out Data; Pos : Natural; V : Integer_16)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      Put_Unsigned_16 (D, Pos, (if V < 0 then Unsigned_16 (Integer (V) + 65_536) else Unsigned_16 (V)));
   end Put_Integer_16;

   function Get_Integer_16 (D : Data; Pos : Natural) return Integer_16
     with Pre => Pos <= Data_Size - 2
   is
      U : constant Unsigned_16 := Get_Unsigned_16 (D, Pos);
   begin
      return (if U > 32_767 then Integer_16 (Integer (U) - 65_536) else Integer_16 (U));
   end Get_Integer_16;

   procedure Put_Unsigned_32 (D : in out Data; Pos : Natural; V : Unsigned_32)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 3 loop
         D (Pos + I) := Unsigned_8 (Shift_Right (V, 8 * I) and 16#FF#);
      end loop;
   end Put_Unsigned_32;

   function Get_Unsigned_32 (D : Data; Pos : Natural) return Unsigned_32 is
     (Unsigned_32 (D (Pos)) or Shift_Left (Unsigned_32 (D (Pos + 1)), 8)
      or Shift_Left (Unsigned_32 (D (Pos + 2)), 16) or Shift_Left (Unsigned_32 (D (Pos + 3)), 24))
     with Pre => Pos <= Data_Size - 4;

   procedure Put_Integer_32 (D : in out Data; Pos : Natural; V : Integer_32)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_32 (D, Pos, Unsigned_32 (Integer_64 (V) mod 2 ** 32));
   end Put_Integer_32;

   function Get_Integer_32 (D : Data; Pos : Natural) return Integer_32
     with Pre => Pos <= Data_Size - 4
   is
      U : constant Unsigned_32 := Get_Unsigned_32 (D, Pos);
   begin
      return (if U > 2 ** 31 - 1 then Integer_32 (Integer_64 (U) - 2 ** 32) else Integer_32 (U));
   end Get_Integer_32;

   --  The float whose bit pattern a word holds.
   function To_Float is new Ada.Unchecked_Conversion (Unsigned_32, Float);

   procedure Put_Float (D : in out Data; Pos : Natural; V : Float)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_32 (D, Pos, Adaflight.Float_Bits.Float_Bits (V));
   end Put_Float;

   function Get_Float (D : Data; Pos : Natural) return Float is (To_Float (Get_Unsigned_32 (D, Pos)))
     with Pre => Pos <= Data_Size - 4;

   procedure Put_Blackbox_Config_Record (D : in out Data; Pos : Natural; V : Blackbox_Config_Record)
     with Pre => Pos <= Data_Size - 10
   is
   begin
      Put_Unsigned_32 (D, Pos + 0, V.Fields_Disabled_Mask);
      Put_Unsigned_8 (D, Pos + 4, V.Sample_Rate);
      Put_Unsigned_8 (D, Pos + 5, V.Device);
      Put_Unsigned_8 (D, Pos + 6, V.Mode);
      Put_Unsigned_8 (D, Pos + 7, V.High_Resolution);
      Put_Integer_8 (D, Pos + 8, V.Blackbox_Uart);
      Put_Unsigned_8 (D, Pos + 9, V.Blackbox_Baud);
   end Put_Blackbox_Config_Record;

   procedure Get_Blackbox_Config_Record (D : Data; Pos : Natural; V : in out Blackbox_Config_Record)
     with Pre => Pos <= Data_Size - 10
   is
   begin
      V.Fields_Disabled_Mask := Get_Unsigned_32 (D, Pos + 0);
      V.Sample_Rate := Get_Unsigned_8 (D, Pos + 4);
      V.Device := Get_Unsigned_8 (D, Pos + 5);
      V.Mode := Get_Unsigned_8 (D, Pos + 6);
      V.High_Resolution := Get_Unsigned_8 (D, Pos + 7);
      V.Blackbox_Uart := Get_Integer_8 (D, Pos + 8);
      V.Blackbox_Baud := Get_Unsigned_8 (D, Pos + 9);
   end Get_Blackbox_Config_Record;

   procedure Put_Time_Config_Record (D : in out Data; Pos : Natural; V : Time_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      Put_Integer_16 (D, Pos + 0, V.Tz_Offset_Minutes);
   end Put_Time_Config_Record;

   procedure Get_Time_Config_Record (D : Data; Pos : Natural; V : in out Time_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      V.Tz_Offset_Minutes := Get_Integer_16 (D, Pos + 0);
   end Get_Time_Config_Record;

   procedure Put_Bytes_6 (D : in out Data; Pos : Natural; V : Bytes_6)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      for I in 0 .. 5 loop
         pragma Loop_Invariant (Pos <= Data_Size - 6);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_6;

   procedure Get_Bytes_6 (D : Data; Pos : Natural; V : in out Bytes_6)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      for I in 0 .. 5 loop
         pragma Loop_Invariant (Pos <= Data_Size - 6);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_6;

   procedure Put_System_Config_Record (D : in out Data; Pos : Natural; V : System_Config_Record)
     with Pre => Pos <= Data_Size - 17
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Pid_Profile_Index);
      Put_Unsigned_8 (D, Pos + 1, V.Active_Rate_Profile);
      Put_Unsigned_8 (D, Pos + 2, V.Debug_Mode);
      Put_Unsigned_8 (D, Pos + 3, V.Task_Statistics);
      Put_Unsigned_8 (D, Pos + 4, V.Rate_Profile6_Pos_Switch);
      Put_Unsigned_8 (D, Pos + 5, V.Cpu_Overclock);
      Put_Unsigned_8 (D, Pos + 6, V.Power_On_Arming_Grace_Time);
      Put_Bytes_6 (D, Pos + 7, V.Board_Identifier);
      Put_Unsigned_8 (D, Pos + 13, V.Hse_Mhz);
      Put_Unsigned_8 (D, Pos + 14, V.Configuration_State);
      Put_Unsigned_8 (D, Pos + 15, V.Enable_Stick_Arming);
      Put_Unsigned_8 (D, Pos + 16, V.Active_Battery_Profile);
   end Put_System_Config_Record;

   procedure Get_System_Config_Record (D : Data; Pos : Natural; V : in out System_Config_Record)
     with Pre => Pos <= Data_Size - 17
   is
   begin
      V.Pid_Profile_Index := Get_Unsigned_8 (D, Pos + 0);
      V.Active_Rate_Profile := Get_Unsigned_8 (D, Pos + 1);
      V.Debug_Mode := Get_Unsigned_8 (D, Pos + 2);
      V.Task_Statistics := Get_Unsigned_8 (D, Pos + 3);
      V.Rate_Profile6_Pos_Switch := Get_Unsigned_8 (D, Pos + 4);
      V.Cpu_Overclock := Get_Unsigned_8 (D, Pos + 5);
      V.Power_On_Arming_Grace_Time := Get_Unsigned_8 (D, Pos + 6);
      Get_Bytes_6 (D, Pos + 7, V.Board_Identifier);
      V.Hse_Mhz := Get_Unsigned_8 (D, Pos + 13);
      V.Configuration_State := Get_Unsigned_8 (D, Pos + 14);
      V.Enable_Stick_Arming := Get_Unsigned_8 (D, Pos + 15);
      V.Active_Battery_Profile := Get_Unsigned_8 (D, Pos + 16);
   end Get_System_Config_Record;

   procedure Put_Feature_Config_Record (D : in out Data; Pos : Natural; V : Feature_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_32 (D, Pos + 0, V.Enabled_Features);
   end Put_Feature_Config_Record;

   procedure Get_Feature_Config_Record (D : Data; Pos : Natural; V : in out Feature_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Enabled_Features := Get_Unsigned_32 (D, Pos + 0);
   end Get_Feature_Config_Record;

   procedure Put_Bytes_3 (D : in out Data; Pos : Natural; V : Bytes_3)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 3);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_3;

   procedure Get_Bytes_3 (D : Data; Pos : Natural; V : in out Bytes_3)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 3);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_3;

   procedure Put_Status_Led_Config_Record (D : in out Data; Pos : Natural; V : Status_Led_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Bytes_3 (D, Pos + 0, V.Io_Tags);
      Put_Unsigned_8 (D, Pos + 3, V.Inversion);
   end Put_Status_Led_Config_Record;

   procedure Get_Status_Led_Config_Record (D : Data; Pos : Natural; V : in out Status_Led_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Get_Bytes_3 (D, Pos + 0, V.Io_Tags);
      V.Inversion := Get_Unsigned_8 (D, Pos + 3);
   end Get_Status_Led_Config_Record;

   procedure Put_Bytes_8 (D : in out Data; Pos : Natural; V : Bytes_8)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 8);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_8;

   procedure Get_Bytes_8 (D : Data; Pos : Natural; V : in out Bytes_8)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 8);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_8;

   procedure Put_Serial_Pin_Config_Record (D : in out Data; Pos : Natural; V : Serial_Pin_Config_Record)
     with Pre => Pos <= Data_Size - 22
   is
   begin
      Put_Bytes_8 (D, Pos + 0, V.Io_Tag_Tx);
      Put_Bytes_8 (D, Pos + 8, V.Io_Tag_Rx);
      Put_Bytes_6 (D, Pos + 16, V.Io_Tag_Inverter);
   end Put_Serial_Pin_Config_Record;

   procedure Get_Serial_Pin_Config_Record (D : Data; Pos : Natural; V : in out Serial_Pin_Config_Record)
     with Pre => Pos <= Data_Size - 22
   is
   begin
      Get_Bytes_8 (D, Pos + 0, V.Io_Tag_Tx);
      Get_Bytes_8 (D, Pos + 8, V.Io_Tag_Rx);
      Get_Bytes_6 (D, Pos + 16, V.Io_Tag_Inverter);
   end Get_Serial_Pin_Config_Record;

   procedure Put_Unsigned_16_List_3 (D : in out Data; Pos : Natural; V : Unsigned_16_List_3)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 6);
         Put_Unsigned_16 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Unsigned_16_List_3;

   procedure Get_Unsigned_16_List_3 (D : Data; Pos : Natural; V : in out Unsigned_16_List_3)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 6);
         V (V'First + I) := Get_Unsigned_16 (D, Pos + I * 2);
      end loop;
   end Get_Unsigned_16_List_3;

   procedure Put_Bytes_9 (D : in out Data; Pos : Natural; V : Bytes_9)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      for I in 0 .. 8 loop
         pragma Loop_Invariant (Pos <= Data_Size - 9);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_9;

   procedure Get_Bytes_9 (D : Data; Pos : Natural; V : in out Bytes_9)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      for I in 0 .. 8 loop
         pragma Loop_Invariant (Pos <= Data_Size - 9);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_9;

   procedure Put_Control_Rate_Config_Record (D : in out Data; Pos : Natural; V : Control_Rate_Config_Record)
     with Pre => Pos <= Data_Size - 31
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Thr_Mid8);
      Put_Unsigned_8 (D, Pos + 1, V.Thr_Expo8);
      Put_Unsigned_8 (D, Pos + 2, V.Rates_Type);
      Put_Bytes_3 (D, Pos + 3, V.Rc_Rates);
      Put_Bytes_3 (D, Pos + 6, V.Rc_Expo);
      Put_Bytes_3 (D, Pos + 9, V.Rates);
      Put_Unsigned_8 (D, Pos + 12, V.Throttle_Limit_Type);
      Put_Unsigned_8 (D, Pos + 13, V.Throttle_Limit_Percent);
      Put_Unsigned_16_List_3 (D, Pos + 14, V.Rate_Limit);
      Put_Bytes_9 (D, Pos + 20, V.Profile_Name);
      Put_Unsigned_8 (D, Pos + 29, V.Quick_Rates_Rc_Expo);
      Put_Unsigned_8 (D, Pos + 30, V.Thr_Hover8);
   end Put_Control_Rate_Config_Record;

   procedure Get_Control_Rate_Config_Record (D : Data; Pos : Natural; V : in out Control_Rate_Config_Record)
     with Pre => Pos <= Data_Size - 31
   is
   begin
      V.Thr_Mid8 := Get_Unsigned_8 (D, Pos + 0);
      V.Thr_Expo8 := Get_Unsigned_8 (D, Pos + 1);
      V.Rates_Type := Get_Unsigned_8 (D, Pos + 2);
      Get_Bytes_3 (D, Pos + 3, V.Rc_Rates);
      Get_Bytes_3 (D, Pos + 6, V.Rc_Expo);
      Get_Bytes_3 (D, Pos + 9, V.Rates);
      V.Throttle_Limit_Type := Get_Unsigned_8 (D, Pos + 12);
      V.Throttle_Limit_Percent := Get_Unsigned_8 (D, Pos + 13);
      Get_Unsigned_16_List_3 (D, Pos + 14, V.Rate_Limit);
      Get_Bytes_9 (D, Pos + 20, V.Profile_Name);
      V.Quick_Rates_Rc_Expo := Get_Unsigned_8 (D, Pos + 29);
      V.Thr_Hover8 := Get_Unsigned_8 (D, Pos + 30);
   end Get_Control_Rate_Config_Record;

   procedure Put_Control_Rate_Config_Record_List_4
     (D : in out Data; Pos : Natural; V : Control_Rate_Config_Record_List_4)
     with Pre => Pos <= Data_Size - 124
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 124);
         Put_Control_Rate_Config_Record (D, Pos + I * 31, V (V'First + I));
      end loop;
   end Put_Control_Rate_Config_Record_List_4;

   procedure Get_Control_Rate_Config_Record_List_4
     (D : Data; Pos : Natural; V : in out Control_Rate_Config_Record_List_4)
     with Pre => Pos <= Data_Size - 124
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 124);
         Get_Control_Rate_Config_Record (D, Pos + I * 31, V (V'First + I));
      end loop;
   end Get_Control_Rate_Config_Record_List_4;

   procedure Put_Throttle_Correction_Config_Record
     (D : in out Data; Pos : Natural; V : Throttle_Correction_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Throttle_Correction_Angle);
      Put_Unsigned_8 (D, Pos + 2, V.Throttle_Correction_Value);
   end Put_Throttle_Correction_Config_Record;

   procedure Get_Throttle_Correction_Config_Record
     (D : Data; Pos : Natural; V : in out Throttle_Correction_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Throttle_Correction_Angle := Get_Unsigned_16 (D, Pos + 0);
      V.Throttle_Correction_Value := Get_Unsigned_8 (D, Pos + 2);
   end Get_Throttle_Correction_Config_Record;

   procedure Put_Channel_Range_Record (D : in out Data; Pos : Natural; V : Channel_Range_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Start_Step);
      Put_Unsigned_8 (D, Pos + 1, V.End_Step);
   end Put_Channel_Range_Record;

   procedure Get_Channel_Range_Record (D : Data; Pos : Natural; V : in out Channel_Range_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      V.Start_Step := Get_Unsigned_8 (D, Pos + 0);
      V.End_Step := Get_Unsigned_8 (D, Pos + 1);
   end Get_Channel_Range_Record;

   procedure Put_Adjustment_Range_Record (D : in out Data; Pos : Natural; V : Adjustment_Range_Record)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Aux_Channel_Index);
      Put_Channel_Range_Record (D, Pos + 1, V.Range_Value);
      Put_Unsigned_8 (D, Pos + 3, V.Adjustment_Config);
      Put_Unsigned_8 (D, Pos + 4, V.Aux_Switch_Channel_Index);
      Put_Unsigned_16 (D, Pos + 5, V.Adjustment_Center);
      Put_Unsigned_16 (D, Pos + 7, V.Adjustment_Scale);
   end Put_Adjustment_Range_Record;

   procedure Get_Adjustment_Range_Record (D : Data; Pos : Natural; V : in out Adjustment_Range_Record)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      V.Aux_Channel_Index := Get_Unsigned_8 (D, Pos + 0);
      Get_Channel_Range_Record (D, Pos + 1, V.Range_Value);
      V.Adjustment_Config := Get_Unsigned_8 (D, Pos + 3);
      V.Aux_Switch_Channel_Index := Get_Unsigned_8 (D, Pos + 4);
      V.Adjustment_Center := Get_Unsigned_16 (D, Pos + 5);
      V.Adjustment_Scale := Get_Unsigned_16 (D, Pos + 7);
   end Get_Adjustment_Range_Record;

   procedure Put_Adjustment_Range_Record_List_30 (D : in out Data; Pos : Natural; V : Adjustment_Range_Record_List_30)
     with Pre => Pos <= Data_Size - 270
   is
   begin
      for I in 0 .. 29 loop
         pragma Loop_Invariant (Pos <= Data_Size - 270);
         Put_Adjustment_Range_Record (D, Pos + I * 9, V (V'First + I));
      end loop;
   end Put_Adjustment_Range_Record_List_30;

   procedure Get_Adjustment_Range_Record_List_30 (D : Data; Pos : Natural; V : in out Adjustment_Range_Record_List_30)
     with Pre => Pos <= Data_Size - 270
   is
   begin
      for I in 0 .. 29 loop
         pragma Loop_Invariant (Pos <= Data_Size - 270);
         Get_Adjustment_Range_Record (D, Pos + I * 9, V (V'First + I));
      end loop;
   end Get_Adjustment_Range_Record_List_30;

   procedure Put_Rc_Controls_Config_Record (D : in out Data; Pos : Natural; V : Rc_Controls_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Deadband);
      Put_Unsigned_8 (D, Pos + 1, V.Yaw_Deadband);
      Put_Boolean (D, Pos + 2, V.Yaw_Control_Reversed);
   end Put_Rc_Controls_Config_Record;

   procedure Get_Rc_Controls_Config_Record (D : Data; Pos : Natural; V : in out Rc_Controls_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Deadband := Get_Unsigned_8 (D, Pos + 0);
      V.Yaw_Deadband := Get_Unsigned_8 (D, Pos + 1);
      V.Yaw_Control_Reversed := Get_Boolean (D, Pos + 2);
   end Get_Rc_Controls_Config_Record;

   procedure Put_Arming_Config_Record (D : in out Data; Pos : Natural; V : Arming_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Gyro_Cal_On_First_Arm);
      Put_Unsigned_8 (D, Pos + 1, V.Auto_Disarm_Delay);
      Put_Unsigned_8 (D, Pos + 2, V.Prearm_Allow_Rearm);
   end Put_Arming_Config_Record;

   procedure Get_Arming_Config_Record (D : Data; Pos : Natural; V : in out Arming_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Gyro_Cal_On_First_Arm := Get_Unsigned_8 (D, Pos + 0);
      V.Auto_Disarm_Delay := Get_Unsigned_8 (D, Pos + 1);
      V.Prearm_Allow_Rearm := Get_Unsigned_8 (D, Pos + 2);
   end Get_Arming_Config_Record;

   procedure Put_Flight3_D_Config_Record (D : in out Data; Pos : Natural; V : Flight3_D_Config_Record)
     with Pre => Pos <= Data_Size - 13
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Deadband3d_Low);
      Put_Unsigned_16 (D, Pos + 2, V.Deadband3d_High);
      Put_Unsigned_16 (D, Pos + 4, V.Neutral3d);
      Put_Unsigned_16 (D, Pos + 6, V.Deadband3d_Throttle);
      Put_Unsigned_16 (D, Pos + 8, V.Limit3d_Low);
      Put_Unsigned_16 (D, Pos + 10, V.Limit3d_High);
      Put_Unsigned_8 (D, Pos + 12, V.Switched_Mode3d);
   end Put_Flight3_D_Config_Record;

   procedure Get_Flight3_D_Config_Record (D : Data; Pos : Natural; V : in out Flight3_D_Config_Record)
     with Pre => Pos <= Data_Size - 13
   is
   begin
      V.Deadband3d_Low := Get_Unsigned_16 (D, Pos + 0);
      V.Deadband3d_High := Get_Unsigned_16 (D, Pos + 2);
      V.Neutral3d := Get_Unsigned_16 (D, Pos + 4);
      V.Deadband3d_Throttle := Get_Unsigned_16 (D, Pos + 6);
      V.Limit3d_Low := Get_Unsigned_16 (D, Pos + 8);
      V.Limit3d_High := Get_Unsigned_16 (D, Pos + 10);
      V.Switched_Mode3d := Get_Unsigned_8 (D, Pos + 12);
   end Get_Flight3_D_Config_Record;

   procedure Put_Mode_Activation_Condition_Record (D : in out Data; Pos : Natural; V : Mode_Activation_Condition_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Mode_Id);
      Put_Unsigned_8 (D, Pos + 1, V.Aux_Channel_Index);
      Put_Channel_Range_Record (D, Pos + 2, V.Range_Value);
      Put_Unsigned_8 (D, Pos + 4, V.Mode_Logic);
      Put_Unsigned_8 (D, Pos + 5, V.Linked_To);
   end Put_Mode_Activation_Condition_Record;

   procedure Get_Mode_Activation_Condition_Record (D : Data; Pos : Natural; V : in out Mode_Activation_Condition_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      V.Mode_Id := Get_Unsigned_8 (D, Pos + 0);
      V.Aux_Channel_Index := Get_Unsigned_8 (D, Pos + 1);
      Get_Channel_Range_Record (D, Pos + 2, V.Range_Value);
      V.Mode_Logic := Get_Unsigned_8 (D, Pos + 4);
      V.Linked_To := Get_Unsigned_8 (D, Pos + 5);
   end Get_Mode_Activation_Condition_Record;

   procedure Put_Mode_Activation_Condition_Record_List_20
     (D : in out Data; Pos : Natural; V : Mode_Activation_Condition_Record_List_20)
     with Pre => Pos <= Data_Size - 120
   is
   begin
      for I in 0 .. 19 loop
         pragma Loop_Invariant (Pos <= Data_Size - 120);
         Put_Mode_Activation_Condition_Record (D, Pos + I * 6, V (V'First + I));
      end loop;
   end Put_Mode_Activation_Condition_Record_List_20;

   procedure Get_Mode_Activation_Condition_Record_List_20
     (D : Data; Pos : Natural; V : in out Mode_Activation_Condition_Record_List_20)
     with Pre => Pos <= Data_Size - 120
   is
   begin
      for I in 0 .. 19 loop
         pragma Loop_Invariant (Pos <= Data_Size - 120);
         Get_Mode_Activation_Condition_Record (D, Pos + I * 6, V (V'First + I));
      end loop;
   end Get_Mode_Activation_Condition_Record_List_20;

   procedure Put_Bytes_16 (D : in out Data; Pos : Natural; V : Bytes_16)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      for I in 0 .. 15 loop
         pragma Loop_Invariant (Pos <= Data_Size - 16);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_16;

   procedure Get_Bytes_16 (D : Data; Pos : Natural; V : in out Bytes_16)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      for I in 0 .. 15 loop
         pragma Loop_Invariant (Pos <= Data_Size - 16);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_16;

   procedure Put_Bytes_16_List_4 (D : in out Data; Pos : Natural; V : Bytes_16_List_4)
     with Pre => Pos <= Data_Size - 64
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 64);
         Put_Bytes_16 (D, Pos + I * 16, V (V'First + I));
      end loop;
   end Put_Bytes_16_List_4;

   procedure Get_Bytes_16_List_4 (D : Data; Pos : Natural; V : in out Bytes_16_List_4)
     with Pre => Pos <= Data_Size - 64
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 64);
         Get_Bytes_16 (D, Pos + I * 16, V (V'First + I));
      end loop;
   end Get_Bytes_16_List_4;

   procedure Put_Mode_Activation_Config_Record (D : in out Data; Pos : Natural; V : Mode_Activation_Config_Record)
     with Pre => Pos <= Data_Size - 64
   is
   begin
      Put_Bytes_16_List_4 (D, Pos + 0, V.Box_User_Names);
   end Put_Mode_Activation_Config_Record;

   procedure Get_Mode_Activation_Config_Record (D : Data; Pos : Natural; V : in out Mode_Activation_Config_Record)
     with Pre => Pos <= Data_Size - 64
   is
   begin
      Get_Bytes_16_List_4 (D, Pos + 0, V.Box_User_Names);
   end Get_Mode_Activation_Config_Record;

   procedure Put_Failsafe_Config_Record (D : in out Data; Pos : Natural; V : Failsafe_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Failsafe_Throttle);
      Put_Unsigned_16 (D, Pos + 2, V.Failsafe_Throttle_Low_Delay);
      Put_Unsigned_8 (D, Pos + 4, V.Failsafe_Delay);
      Put_Unsigned_8 (D, Pos + 5, V.Failsafe_Landing_Time);
      Put_Unsigned_8 (D, Pos + 6, V.Failsafe_Switch_Mode);
      Put_Unsigned_8 (D, Pos + 7, V.Failsafe_Procedure);
      Put_Unsigned_16 (D, Pos + 8, V.Failsafe_Recovery_Delay);
      Put_Unsigned_8 (D, Pos + 10, V.Failsafe_Stick_Threshold);
   end Put_Failsafe_Config_Record;

   procedure Get_Failsafe_Config_Record (D : Data; Pos : Natural; V : in out Failsafe_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      V.Failsafe_Throttle := Get_Unsigned_16 (D, Pos + 0);
      V.Failsafe_Throttle_Low_Delay := Get_Unsigned_16 (D, Pos + 2);
      V.Failsafe_Delay := Get_Unsigned_8 (D, Pos + 4);
      V.Failsafe_Landing_Time := Get_Unsigned_8 (D, Pos + 5);
      V.Failsafe_Switch_Mode := Get_Unsigned_8 (D, Pos + 6);
      V.Failsafe_Procedure := Get_Unsigned_8 (D, Pos + 7);
      V.Failsafe_Recovery_Delay := Get_Unsigned_16 (D, Pos + 8);
      V.Failsafe_Stick_Threshold := Get_Unsigned_8 (D, Pos + 10);
   end Get_Failsafe_Config_Record;

   procedure Put_Imu_Config_Record (D : in out Data; Pos : Natural; V : Imu_Config_Record)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Imu_Dcm_Kp);
      Put_Unsigned_16 (D, Pos + 2, V.Imu_Dcm_Ki);
      Put_Unsigned_8 (D, Pos + 4, V.Small_Angle);
      Put_Unsigned_8 (D, Pos + 5, V.Imu_Process_Denom);
      Put_Integer_16 (D, Pos + 6, V.Mag_Declination);
   end Put_Imu_Config_Record;

   procedure Get_Imu_Config_Record (D : Data; Pos : Natural; V : in out Imu_Config_Record)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      V.Imu_Dcm_Kp := Get_Unsigned_16 (D, Pos + 0);
      V.Imu_Dcm_Ki := Get_Unsigned_16 (D, Pos + 2);
      V.Small_Angle := Get_Unsigned_8 (D, Pos + 4);
      V.Imu_Process_Denom := Get_Unsigned_8 (D, Pos + 5);
      V.Mag_Declination := Get_Integer_16 (D, Pos + 6);
   end Get_Imu_Config_Record;

   procedure Put_Mixer_Config_Record (D : in out Data; Pos : Natural; V : Mixer_Config_Record)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Mixer_Mode);
      Put_Boolean (D, Pos + 1, V.Yaw_Motors_Reversed);
      Put_Unsigned_8 (D, Pos + 2, V.Crashflip_Motor_Percent);
      Put_Unsigned_8 (D, Pos + 3, V.Crashflip_Rate);
      Put_Boolean (D, Pos + 4, V.Crashflip_Auto_Rearm);
      Put_Unsigned_8 (D, Pos + 5, V.Mixer_Type);
      Put_Boolean (D, Pos + 6, V.Rpm_Limit);
      Put_Unsigned_16 (D, Pos + 7, V.Rpm_Limit_P);
      Put_Unsigned_16 (D, Pos + 9, V.Rpm_Limit_I);
      Put_Unsigned_16 (D, Pos + 11, V.Rpm_Limit_D);
      Put_Unsigned_16 (D, Pos + 13, V.Rpm_Limit_Value);
   end Put_Mixer_Config_Record;

   procedure Get_Mixer_Config_Record (D : Data; Pos : Natural; V : in out Mixer_Config_Record)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      V.Mixer_Mode := Get_Unsigned_8 (D, Pos + 0);
      V.Yaw_Motors_Reversed := Get_Boolean (D, Pos + 1);
      V.Crashflip_Motor_Percent := Get_Unsigned_8 (D, Pos + 2);
      V.Crashflip_Rate := Get_Unsigned_8 (D, Pos + 3);
      V.Crashflip_Auto_Rearm := Get_Boolean (D, Pos + 4);
      V.Mixer_Type := Get_Unsigned_8 (D, Pos + 5);
      V.Rpm_Limit := Get_Boolean (D, Pos + 6);
      V.Rpm_Limit_P := Get_Unsigned_16 (D, Pos + 7);
      V.Rpm_Limit_I := Get_Unsigned_16 (D, Pos + 9);
      V.Rpm_Limit_D := Get_Unsigned_16 (D, Pos + 11);
      V.Rpm_Limit_Value := Get_Unsigned_16 (D, Pos + 13);
   end Get_Mixer_Config_Record;

   procedure Put_Motor_Mixer_Record (D : in out Data; Pos : Natural; V : Motor_Mixer_Record)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      Put_Float (D, Pos + 0, V.Throttle);
      Put_Float (D, Pos + 4, V.Roll);
      Put_Float (D, Pos + 8, V.Pitch);
      Put_Float (D, Pos + 12, V.Yaw);
   end Put_Motor_Mixer_Record;

   procedure Get_Motor_Mixer_Record (D : Data; Pos : Natural; V : in out Motor_Mixer_Record)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      V.Throttle := Get_Float (D, Pos + 0);
      V.Roll := Get_Float (D, Pos + 4);
      V.Pitch := Get_Float (D, Pos + 8);
      V.Yaw := Get_Float (D, Pos + 12);
   end Get_Motor_Mixer_Record;

   procedure Put_Motor_Mixer_Record_List_8 (D : in out Data; Pos : Natural; V : Motor_Mixer_Record_List_8)
     with Pre => Pos <= Data_Size - 128
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 128);
         Put_Motor_Mixer_Record (D, Pos + I * 16, V (V'First + I));
      end loop;
   end Put_Motor_Mixer_Record_List_8;

   procedure Get_Motor_Mixer_Record_List_8 (D : Data; Pos : Natural; V : in out Motor_Mixer_Record_List_8)
     with Pre => Pos <= Data_Size - 128
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 128);
         Get_Motor_Mixer_Record (D, Pos + I * 16, V (V'First + I));
      end loop;
   end Get_Motor_Mixer_Record_List_8;

   procedure Put_Tricopter_Mixer_Config_Record (D : in out Data; Pos : Natural; V : Tricopter_Mixer_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Dummy);
   end Put_Tricopter_Mixer_Config_Record;

   procedure Get_Tricopter_Mixer_Config_Record (D : Data; Pos : Natural; V : in out Tricopter_Mixer_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      V.Dummy := Get_Unsigned_8 (D, Pos + 0);
   end Get_Tricopter_Mixer_Config_Record;

   procedure Put_Pid_Config_Record (D : in out Data; Pos : Natural; V : Pid_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Pid_Process_Denom);
      Put_Unsigned_8 (D, Pos + 1, V.Runaway_Takeoff_Prevention);
      Put_Unsigned_16 (D, Pos + 2, V.Runaway_Takeoff_Deactivate_Delay);
      Put_Unsigned_8 (D, Pos + 4, V.Runaway_Takeoff_Deactivate_Throttle);
   end Put_Pid_Config_Record;

   procedure Get_Pid_Config_Record (D : Data; Pos : Natural; V : in out Pid_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Pid_Process_Denom := Get_Unsigned_8 (D, Pos + 0);
      V.Runaway_Takeoff_Prevention := Get_Unsigned_8 (D, Pos + 1);
      V.Runaway_Takeoff_Deactivate_Delay := Get_Unsigned_16 (D, Pos + 2);
      V.Runaway_Takeoff_Deactivate_Throttle := Get_Unsigned_8 (D, Pos + 4);
   end Get_Pid_Config_Record;

   procedure Put_Pidf_Record (D : in out Data; Pos : Natural; V : Pidf_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.P);
      Put_Unsigned_8 (D, Pos + 1, V.I);
      Put_Unsigned_8 (D, Pos + 2, V.D);
      Put_Unsigned_16 (D, Pos + 3, V.F);
      Put_Unsigned_8 (D, Pos + 5, V.S);
   end Put_Pidf_Record;

   procedure Get_Pidf_Record (D : Data; Pos : Natural; V : in out Pidf_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      V.P := Get_Unsigned_8 (D, Pos + 0);
      V.I := Get_Unsigned_8 (D, Pos + 1);
      V.D := Get_Unsigned_8 (D, Pos + 2);
      V.F := Get_Unsigned_16 (D, Pos + 3);
      V.S := Get_Unsigned_8 (D, Pos + 5);
   end Get_Pidf_Record;

   procedure Put_Pidf_Record_List_5 (D : in out Data; Pos : Natural; V : Pidf_Record_List_5)
     with Pre => Pos <= Data_Size - 30
   is
   begin
      for I in 0 .. 4 loop
         pragma Loop_Invariant (Pos <= Data_Size - 30);
         Put_Pidf_Record (D, Pos + I * 6, V (V'First + I));
      end loop;
   end Put_Pidf_Record_List_5;

   procedure Get_Pidf_Record_List_5 (D : Data; Pos : Natural; V : in out Pidf_Record_List_5)
     with Pre => Pos <= Data_Size - 30
   is
   begin
      for I in 0 .. 4 loop
         pragma Loop_Invariant (Pos <= Data_Size - 30);
         Get_Pidf_Record (D, Pos + I * 6, V (V'First + I));
      end loop;
   end Get_Pidf_Record_List_5;

   procedure Put_Pid_Profile_Record (D : in out Data; Pos : Natural; V : Pid_Profile_Record)
     with Pre => Pos <= Data_Size - 211
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Yaw_Lowpass_Hz);
      Put_Unsigned_16 (D, Pos + 2, V.Dterm_Lpf1_Static_Hz);
      Put_Unsigned_16 (D, Pos + 4, V.Dterm_Notch_Hz);
      Put_Unsigned_16 (D, Pos + 6, V.Dterm_Notch_Cutoff);
      Put_Pidf_Record_List_5 (D, Pos + 8, V.Pid);
      Put_Unsigned_8 (D, Pos + 38, V.Dterm_Lpf1_Type);
      Put_Unsigned_8 (D, Pos + 39, V.Iterm_Windup);
      Put_Unsigned_16 (D, Pos + 40, V.Pid_Sum_Limit);
      Put_Unsigned_16 (D, Pos + 42, V.Pid_Sum_Limit_Yaw);
      Put_Unsigned_8 (D, Pos + 44, V.Pid_At_Min_Throttle);
      Put_Unsigned_8 (D, Pos + 45, V.Angle_Limit);
      Put_Unsigned_8 (D, Pos + 46, V.Horizon_Limit_Degrees);
      Put_Unsigned_8 (D, Pos + 47, V.Horizon_Ignore_Sticks);
      Put_Unsigned_8 (D, Pos + 48, V.Anti_Gravity_Gain);
      Put_Unsigned_16 (D, Pos + 49, V.Yaw_Rate_Accel_Limit);
      Put_Unsigned_16 (D, Pos + 51, V.Rate_Accel_Limit);
      Put_Unsigned_16 (D, Pos + 53, V.Crash_Dthreshold);
      Put_Unsigned_16 (D, Pos + 55, V.Crash_Gthreshold);
      Put_Unsigned_16 (D, Pos + 57, V.Crash_Setpoint_Threshold);
      Put_Unsigned_16 (D, Pos + 59, V.Crash_Time);
      Put_Unsigned_16 (D, Pos + 61, V.Crash_Delay);
      Put_Unsigned_8 (D, Pos + 63, V.Crash_Recovery_Angle);
      Put_Unsigned_8 (D, Pos + 64, V.Crash_Recovery_Rate);
      Put_Unsigned_16 (D, Pos + 65, V.Crash_Limit_Yaw);
      Put_Unsigned_16 (D, Pos + 67, V.Iterm_Limit);
      Put_Unsigned_16 (D, Pos + 69, V.Dterm_Lpf2_Static_Hz);
      Put_Unsigned_8 (D, Pos + 71, V.Crash_Recovery);
      Put_Unsigned_8 (D, Pos + 72, V.Throttle_Boost);
      Put_Unsigned_8 (D, Pos + 73, V.Throttle_Boost_Cutoff);
      Put_Unsigned_8 (D, Pos + 74, V.Iterm_Rotation);
      Put_Unsigned_8 (D, Pos + 75, V.Iterm_Relax_Type);
      Put_Unsigned_8 (D, Pos + 76, V.Iterm_Relax_Cutoff);
      Put_Unsigned_8 (D, Pos + 77, V.Iterm_Relax);
      Put_Unsigned_8 (D, Pos + 78, V.Acro_Trainer_Angle_Limit);
      Put_Unsigned_8 (D, Pos + 79, V.Acro_Trainer_Debug_Axis);
      Put_Unsigned_8 (D, Pos + 80, V.Acro_Trainer_Gain);
      Put_Unsigned_16 (D, Pos + 81, V.Acro_Trainer_Lookahead_Ms);
      Put_Unsigned_8 (D, Pos + 83, V.Dterm_Lpf2_Type);
      Put_Unsigned_16 (D, Pos + 84, V.Dterm_Lpf1_Dyn_Min_Hz);
      Put_Unsigned_16 (D, Pos + 86, V.Dterm_Lpf1_Dyn_Max_Hz);
      Put_Unsigned_8 (D, Pos + 88, V.Launch_Control_Mode);
      Put_Unsigned_8 (D, Pos + 89, V.Launch_Control_Throttle_Percent);
      Put_Unsigned_8 (D, Pos + 90, V.Launch_Control_Angle_Limit);
      Put_Unsigned_8 (D, Pos + 91, V.Launch_Control_Gain);
      Put_Unsigned_8 (D, Pos + 92, V.Launch_Control_Allow_Trigger_Reset);
      Put_Unsigned_8 (D, Pos + 93, V.Thrust_Linearization);
      Put_Bytes_3 (D, Pos + 94, V.D_Max);
      Put_Unsigned_8 (D, Pos + 97, V.D_Max_Gain);
      Put_Unsigned_8 (D, Pos + 98, V.D_Max_Advance);
      Put_Unsigned_8 (D, Pos + 99, V.Motor_Output_Limit);
      Put_Integer_8 (D, Pos + 100, V.Auto_Profile_Cell_Count);
      Put_Bytes_9 (D, Pos + 101, V.Profile_Name);
      Put_Unsigned_8 (D, Pos + 110, V.Dyn_Idle_Min_Rpm);
      Put_Unsigned_8 (D, Pos + 111, V.Dyn_Idle_P_Gain);
      Put_Unsigned_8 (D, Pos + 112, V.Dyn_Idle_I_Gain);
      Put_Unsigned_8 (D, Pos + 113, V.Dyn_Idle_D_Gain);
      Put_Unsigned_8 (D, Pos + 114, V.Dyn_Idle_Max_Increase);
      Put_Unsigned_8 (D, Pos + 115, V.Feedforward_Transition);
      Put_Unsigned_8 (D, Pos + 116, V.Feedforward_Averaging);
      Put_Unsigned_8 (D, Pos + 117, V.Feedforward_Smooth_Factor);
      Put_Unsigned_8 (D, Pos + 118, V.Feedforward_Jitter_Factor);
      Put_Unsigned_8 (D, Pos + 119, V.Feedforward_Boost);
      Put_Unsigned_8 (D, Pos + 120, V.Feedforward_Max_Rate_Limit);
      Put_Unsigned_8 (D, Pos + 121, V.Feedforward_Yaw_Hold_Gain);
      Put_Unsigned_8 (D, Pos + 122, V.Feedforward_Yaw_Hold_Time);
      Put_Unsigned_8 (D, Pos + 123, V.Dterm_Lpf1_Dyn_Expo);
      Put_Unsigned_8 (D, Pos + 124, V.Level_Race_Mode);
      Put_Unsigned_8 (D, Pos + 125, V.Vbat_Sag_Compensation);
      Put_Unsigned_8 (D, Pos + 126, V.Simplified_Pids_Mode);
      Put_Unsigned_8 (D, Pos + 127, V.Simplified_Master_Multiplier);
      Put_Unsigned_8 (D, Pos + 128, V.Simplified_Roll_Pitch_Ratio);
      Put_Unsigned_8 (D, Pos + 129, V.Simplified_I_Gain);
      Put_Unsigned_8 (D, Pos + 130, V.Simplified_D_Gain);
      Put_Unsigned_8 (D, Pos + 131, V.Simplified_Pi_Gain);
      Put_Unsigned_8 (D, Pos + 132, V.Simplified_D_Max_Gain);
      Put_Unsigned_8 (D, Pos + 133, V.Simplified_Feedforward_Gain);
      Put_Unsigned_8 (D, Pos + 134, V.Simplified_Dterm_Filter);
      Put_Unsigned_8 (D, Pos + 135, V.Simplified_Dterm_Filter_Multiplier);
      Put_Unsigned_8 (D, Pos + 136, V.Simplified_Pitch_Pi_Gain);
      Put_Unsigned_8 (D, Pos + 137, V.Anti_Gravity_Cutoff_Hz);
      Put_Unsigned_8 (D, Pos + 138, V.Anti_Gravity_P_Gain);
      Put_Unsigned_8 (D, Pos + 139, V.Tpa_Mode);
      Put_Unsigned_8 (D, Pos + 140, V.Tpa_Rate);
      Put_Unsigned_16 (D, Pos + 141, V.Tpa_Breakpoint);
      Put_Unsigned_8 (D, Pos + 143, V.Angle_Feedforward_Smoothing_Ms);
      Put_Unsigned_8 (D, Pos + 144, V.Angle_Earth_Ref);
      Put_Unsigned_16 (D, Pos + 145, V.Horizon_Delay_Ms);
      Put_Integer_8 (D, Pos + 147, V.Tpa_Low_Rate);
      Put_Unsigned_16 (D, Pos + 148, V.Tpa_Low_Breakpoint);
      Put_Unsigned_8 (D, Pos + 150, V.Tpa_Low_Always);
      Put_Unsigned_8 (D, Pos + 151, V.Ez_Landing_Threshold);
      Put_Unsigned_8 (D, Pos + 152, V.Ez_Landing_Limit);
      Put_Unsigned_8 (D, Pos + 153, V.Ez_Landing_Speed);
      Put_Unsigned_8 (D, Pos + 154, V.Landing_Disarm_Threshold);
      Put_Unsigned_16_List_3 (D, Pos + 155, V.Spa_Center);
      Put_Unsigned_16_List_3 (D, Pos + 161, V.Spa_Width);
      Put_Bytes_3 (D, Pos + 167, V.Spa_Mode);
      Put_Unsigned_8 (D, Pos + 170, V.Tpa_Curve_Type);
      Put_Unsigned_8 (D, Pos + 171, V.Tpa_Curve_Stall_Throttle);
      Put_Unsigned_16 (D, Pos + 172, V.Tpa_Curve_Pid_Thr0);
      Put_Unsigned_16 (D, Pos + 174, V.Tpa_Curve_Pid_Thr100);
      Put_Integer_8 (D, Pos + 176, V.Tpa_Curve_Expo);
      Put_Unsigned_8 (D, Pos + 177, V.Tpa_Speed_Type);
      Put_Unsigned_16 (D, Pos + 178, V.Tpa_Speed_Basic_Delay);
      Put_Unsigned_16 (D, Pos + 180, V.Tpa_Speed_Basic_Gravity);
      Put_Unsigned_16 (D, Pos + 182, V.Tpa_Speed_Adv_Prop_Pitch);
      Put_Unsigned_16 (D, Pos + 184, V.Tpa_Speed_Adv_Mass);
      Put_Unsigned_16 (D, Pos + 186, V.Tpa_Speed_Adv_Drag_K);
      Put_Unsigned_16 (D, Pos + 188, V.Tpa_Speed_Adv_Thrust);
      Put_Unsigned_16 (D, Pos + 190, V.Tpa_Speed_Max_Voltage);
      Put_Integer_16 (D, Pos + 192, V.Tpa_Speed_Pitch_Offset);
      Put_Unsigned_8 (D, Pos + 194, V.Yaw_Type);
      Put_Integer_16 (D, Pos + 195, V.Angle_Pitch_Offset);
      Put_Unsigned_8 (D, Pos + 197, V.Chirp_Lag_Freq_Hz);
      Put_Unsigned_8 (D, Pos + 198, V.Chirp_Lead_Freq_Hz);
      Put_Unsigned_16 (D, Pos + 199, V.Chirp_Amplitude_Roll);
      Put_Unsigned_16 (D, Pos + 201, V.Chirp_Amplitude_Pitch);
      Put_Unsigned_16 (D, Pos + 203, V.Chirp_Amplitude_Yaw);
      Put_Unsigned_16 (D, Pos + 205, V.Chirp_Frequency_Start_Deci_Hz);
      Put_Unsigned_16 (D, Pos + 207, V.Chirp_Frequency_End_Deci_Hz);
      Put_Unsigned_8 (D, Pos + 209, V.Chirp_Time_Seconds);
      Put_Unsigned_8 (D, Pos + 210, V.Chirp_Repeat);
   end Put_Pid_Profile_Record;

   procedure Get_Pid_Profile_Record (D : Data; Pos : Natural; V : in out Pid_Profile_Record)
     with Pre => Pos <= Data_Size - 211
   is
   begin
      V.Yaw_Lowpass_Hz := Get_Unsigned_16 (D, Pos + 0);
      V.Dterm_Lpf1_Static_Hz := Get_Unsigned_16 (D, Pos + 2);
      V.Dterm_Notch_Hz := Get_Unsigned_16 (D, Pos + 4);
      V.Dterm_Notch_Cutoff := Get_Unsigned_16 (D, Pos + 6);
      Get_Pidf_Record_List_5 (D, Pos + 8, V.Pid);
      V.Dterm_Lpf1_Type := Get_Unsigned_8 (D, Pos + 38);
      V.Iterm_Windup := Get_Unsigned_8 (D, Pos + 39);
      V.Pid_Sum_Limit := Get_Unsigned_16 (D, Pos + 40);
      V.Pid_Sum_Limit_Yaw := Get_Unsigned_16 (D, Pos + 42);
      V.Pid_At_Min_Throttle := Get_Unsigned_8 (D, Pos + 44);
      V.Angle_Limit := Get_Unsigned_8 (D, Pos + 45);
      V.Horizon_Limit_Degrees := Get_Unsigned_8 (D, Pos + 46);
      V.Horizon_Ignore_Sticks := Get_Unsigned_8 (D, Pos + 47);
      V.Anti_Gravity_Gain := Get_Unsigned_8 (D, Pos + 48);
      V.Yaw_Rate_Accel_Limit := Get_Unsigned_16 (D, Pos + 49);
      V.Rate_Accel_Limit := Get_Unsigned_16 (D, Pos + 51);
      V.Crash_Dthreshold := Get_Unsigned_16 (D, Pos + 53);
      V.Crash_Gthreshold := Get_Unsigned_16 (D, Pos + 55);
      V.Crash_Setpoint_Threshold := Get_Unsigned_16 (D, Pos + 57);
      V.Crash_Time := Get_Unsigned_16 (D, Pos + 59);
      V.Crash_Delay := Get_Unsigned_16 (D, Pos + 61);
      V.Crash_Recovery_Angle := Get_Unsigned_8 (D, Pos + 63);
      V.Crash_Recovery_Rate := Get_Unsigned_8 (D, Pos + 64);
      V.Crash_Limit_Yaw := Get_Unsigned_16 (D, Pos + 65);
      V.Iterm_Limit := Get_Unsigned_16 (D, Pos + 67);
      V.Dterm_Lpf2_Static_Hz := Get_Unsigned_16 (D, Pos + 69);
      V.Crash_Recovery := Get_Unsigned_8 (D, Pos + 71);
      V.Throttle_Boost := Get_Unsigned_8 (D, Pos + 72);
      V.Throttle_Boost_Cutoff := Get_Unsigned_8 (D, Pos + 73);
      V.Iterm_Rotation := Get_Unsigned_8 (D, Pos + 74);
      V.Iterm_Relax_Type := Get_Unsigned_8 (D, Pos + 75);
      V.Iterm_Relax_Cutoff := Get_Unsigned_8 (D, Pos + 76);
      V.Iterm_Relax := Get_Unsigned_8 (D, Pos + 77);
      V.Acro_Trainer_Angle_Limit := Get_Unsigned_8 (D, Pos + 78);
      V.Acro_Trainer_Debug_Axis := Get_Unsigned_8 (D, Pos + 79);
      V.Acro_Trainer_Gain := Get_Unsigned_8 (D, Pos + 80);
      V.Acro_Trainer_Lookahead_Ms := Get_Unsigned_16 (D, Pos + 81);
      V.Dterm_Lpf2_Type := Get_Unsigned_8 (D, Pos + 83);
      V.Dterm_Lpf1_Dyn_Min_Hz := Get_Unsigned_16 (D, Pos + 84);
      V.Dterm_Lpf1_Dyn_Max_Hz := Get_Unsigned_16 (D, Pos + 86);
      V.Launch_Control_Mode := Get_Unsigned_8 (D, Pos + 88);
      V.Launch_Control_Throttle_Percent := Get_Unsigned_8 (D, Pos + 89);
      V.Launch_Control_Angle_Limit := Get_Unsigned_8 (D, Pos + 90);
      V.Launch_Control_Gain := Get_Unsigned_8 (D, Pos + 91);
      V.Launch_Control_Allow_Trigger_Reset := Get_Unsigned_8 (D, Pos + 92);
      V.Thrust_Linearization := Get_Unsigned_8 (D, Pos + 93);
      Get_Bytes_3 (D, Pos + 94, V.D_Max);
      V.D_Max_Gain := Get_Unsigned_8 (D, Pos + 97);
      V.D_Max_Advance := Get_Unsigned_8 (D, Pos + 98);
      V.Motor_Output_Limit := Get_Unsigned_8 (D, Pos + 99);
      V.Auto_Profile_Cell_Count := Get_Integer_8 (D, Pos + 100);
      Get_Bytes_9 (D, Pos + 101, V.Profile_Name);
      V.Dyn_Idle_Min_Rpm := Get_Unsigned_8 (D, Pos + 110);
      V.Dyn_Idle_P_Gain := Get_Unsigned_8 (D, Pos + 111);
      V.Dyn_Idle_I_Gain := Get_Unsigned_8 (D, Pos + 112);
      V.Dyn_Idle_D_Gain := Get_Unsigned_8 (D, Pos + 113);
      V.Dyn_Idle_Max_Increase := Get_Unsigned_8 (D, Pos + 114);
      V.Feedforward_Transition := Get_Unsigned_8 (D, Pos + 115);
      V.Feedforward_Averaging := Get_Unsigned_8 (D, Pos + 116);
      V.Feedforward_Smooth_Factor := Get_Unsigned_8 (D, Pos + 117);
      V.Feedforward_Jitter_Factor := Get_Unsigned_8 (D, Pos + 118);
      V.Feedforward_Boost := Get_Unsigned_8 (D, Pos + 119);
      V.Feedforward_Max_Rate_Limit := Get_Unsigned_8 (D, Pos + 120);
      V.Feedforward_Yaw_Hold_Gain := Get_Unsigned_8 (D, Pos + 121);
      V.Feedforward_Yaw_Hold_Time := Get_Unsigned_8 (D, Pos + 122);
      V.Dterm_Lpf1_Dyn_Expo := Get_Unsigned_8 (D, Pos + 123);
      V.Level_Race_Mode := Get_Unsigned_8 (D, Pos + 124);
      V.Vbat_Sag_Compensation := Get_Unsigned_8 (D, Pos + 125);
      V.Simplified_Pids_Mode := Get_Unsigned_8 (D, Pos + 126);
      V.Simplified_Master_Multiplier := Get_Unsigned_8 (D, Pos + 127);
      V.Simplified_Roll_Pitch_Ratio := Get_Unsigned_8 (D, Pos + 128);
      V.Simplified_I_Gain := Get_Unsigned_8 (D, Pos + 129);
      V.Simplified_D_Gain := Get_Unsigned_8 (D, Pos + 130);
      V.Simplified_Pi_Gain := Get_Unsigned_8 (D, Pos + 131);
      V.Simplified_D_Max_Gain := Get_Unsigned_8 (D, Pos + 132);
      V.Simplified_Feedforward_Gain := Get_Unsigned_8 (D, Pos + 133);
      V.Simplified_Dterm_Filter := Get_Unsigned_8 (D, Pos + 134);
      V.Simplified_Dterm_Filter_Multiplier := Get_Unsigned_8 (D, Pos + 135);
      V.Simplified_Pitch_Pi_Gain := Get_Unsigned_8 (D, Pos + 136);
      V.Anti_Gravity_Cutoff_Hz := Get_Unsigned_8 (D, Pos + 137);
      V.Anti_Gravity_P_Gain := Get_Unsigned_8 (D, Pos + 138);
      V.Tpa_Mode := Get_Unsigned_8 (D, Pos + 139);
      V.Tpa_Rate := Get_Unsigned_8 (D, Pos + 140);
      V.Tpa_Breakpoint := Get_Unsigned_16 (D, Pos + 141);
      V.Angle_Feedforward_Smoothing_Ms := Get_Unsigned_8 (D, Pos + 143);
      V.Angle_Earth_Ref := Get_Unsigned_8 (D, Pos + 144);
      V.Horizon_Delay_Ms := Get_Unsigned_16 (D, Pos + 145);
      V.Tpa_Low_Rate := Get_Integer_8 (D, Pos + 147);
      V.Tpa_Low_Breakpoint := Get_Unsigned_16 (D, Pos + 148);
      V.Tpa_Low_Always := Get_Unsigned_8 (D, Pos + 150);
      V.Ez_Landing_Threshold := Get_Unsigned_8 (D, Pos + 151);
      V.Ez_Landing_Limit := Get_Unsigned_8 (D, Pos + 152);
      V.Ez_Landing_Speed := Get_Unsigned_8 (D, Pos + 153);
      V.Landing_Disarm_Threshold := Get_Unsigned_8 (D, Pos + 154);
      Get_Unsigned_16_List_3 (D, Pos + 155, V.Spa_Center);
      Get_Unsigned_16_List_3 (D, Pos + 161, V.Spa_Width);
      Get_Bytes_3 (D, Pos + 167, V.Spa_Mode);
      V.Tpa_Curve_Type := Get_Unsigned_8 (D, Pos + 170);
      V.Tpa_Curve_Stall_Throttle := Get_Unsigned_8 (D, Pos + 171);
      V.Tpa_Curve_Pid_Thr0 := Get_Unsigned_16 (D, Pos + 172);
      V.Tpa_Curve_Pid_Thr100 := Get_Unsigned_16 (D, Pos + 174);
      V.Tpa_Curve_Expo := Get_Integer_8 (D, Pos + 176);
      V.Tpa_Speed_Type := Get_Unsigned_8 (D, Pos + 177);
      V.Tpa_Speed_Basic_Delay := Get_Unsigned_16 (D, Pos + 178);
      V.Tpa_Speed_Basic_Gravity := Get_Unsigned_16 (D, Pos + 180);
      V.Tpa_Speed_Adv_Prop_Pitch := Get_Unsigned_16 (D, Pos + 182);
      V.Tpa_Speed_Adv_Mass := Get_Unsigned_16 (D, Pos + 184);
      V.Tpa_Speed_Adv_Drag_K := Get_Unsigned_16 (D, Pos + 186);
      V.Tpa_Speed_Adv_Thrust := Get_Unsigned_16 (D, Pos + 188);
      V.Tpa_Speed_Max_Voltage := Get_Unsigned_16 (D, Pos + 190);
      V.Tpa_Speed_Pitch_Offset := Get_Integer_16 (D, Pos + 192);
      V.Yaw_Type := Get_Unsigned_8 (D, Pos + 194);
      V.Angle_Pitch_Offset := Get_Integer_16 (D, Pos + 195);
      V.Chirp_Lag_Freq_Hz := Get_Unsigned_8 (D, Pos + 197);
      V.Chirp_Lead_Freq_Hz := Get_Unsigned_8 (D, Pos + 198);
      V.Chirp_Amplitude_Roll := Get_Unsigned_16 (D, Pos + 199);
      V.Chirp_Amplitude_Pitch := Get_Unsigned_16 (D, Pos + 201);
      V.Chirp_Amplitude_Yaw := Get_Unsigned_16 (D, Pos + 203);
      V.Chirp_Frequency_Start_Deci_Hz := Get_Unsigned_16 (D, Pos + 205);
      V.Chirp_Frequency_End_Deci_Hz := Get_Unsigned_16 (D, Pos + 207);
      V.Chirp_Time_Seconds := Get_Unsigned_8 (D, Pos + 209);
      V.Chirp_Repeat := Get_Unsigned_8 (D, Pos + 210);
   end Get_Pid_Profile_Record;

   procedure Put_Pid_Profile_Record_List_4 (D : in out Data; Pos : Natural; V : Pid_Profile_Record_List_4)
     with Pre => Pos <= Data_Size - 844
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 844);
         Put_Pid_Profile_Record (D, Pos + I * 211, V (V'First + I));
      end loop;
   end Put_Pid_Profile_Record_List_4;

   procedure Get_Pid_Profile_Record_List_4 (D : Data; Pos : Natural; V : in out Pid_Profile_Record_List_4)
     with Pre => Pos <= Data_Size - 844
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 844);
         Get_Pid_Profile_Record (D, Pos + I * 211, V (V'First + I));
      end loop;
   end Get_Pid_Profile_Record_List_4;

   procedure Put_Position_Config_Record (D : in out Data; Pos : Natural; V : Position_Config_Record)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Altitude_Source);
      Put_Unsigned_8 (D, Pos + 1, V.Altitude_Prefer_Baro);
      Put_Unsigned_16 (D, Pos + 2, V.Altitude_Lpf);
      Put_Unsigned_16 (D, Pos + 4, V.Altitude_D_Lpf);
      Put_Unsigned_16 (D, Pos + 6, V.Rangefinder_Max_Range_Cm);
   end Put_Position_Config_Record;

   procedure Get_Position_Config_Record (D : Data; Pos : Natural; V : in out Position_Config_Record)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      V.Altitude_Source := Get_Unsigned_8 (D, Pos + 0);
      V.Altitude_Prefer_Baro := Get_Unsigned_8 (D, Pos + 1);
      V.Altitude_Lpf := Get_Unsigned_16 (D, Pos + 2);
      V.Altitude_D_Lpf := Get_Unsigned_16 (D, Pos + 4);
      V.Rangefinder_Max_Range_Cm := Get_Unsigned_16 (D, Pos + 6);
   end Get_Position_Config_Record;

   procedure Put_Servo_Dev_Config_Record (D : in out Data; Pos : Natural; V : Servo_Dev_Config_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Servo_Center_Pulse);
      Put_Unsigned_16 (D, Pos + 2, V.Servo_Pwm_Rate);
      Put_Bytes_8 (D, Pos + 4, V.Io_Tags);
   end Put_Servo_Dev_Config_Record;

   procedure Get_Servo_Dev_Config_Record (D : Data; Pos : Natural; V : in out Servo_Dev_Config_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      V.Servo_Center_Pulse := Get_Unsigned_16 (D, Pos + 0);
      V.Servo_Pwm_Rate := Get_Unsigned_16 (D, Pos + 2);
      Get_Bytes_8 (D, Pos + 4, V.Io_Tags);
   end Get_Servo_Dev_Config_Record;

   procedure Put_Servo_Config_Record (D : in out Data; Pos : Natural; V : Servo_Config_Record)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      Put_Servo_Dev_Config_Record (D, Pos + 0, V.Dev);
      Put_Unsigned_16 (D, Pos + 12, V.Servo_Lowpass_Freq);
      Put_Unsigned_8 (D, Pos + 14, V.Tri_Unarmed_Servo);
      Put_Unsigned_8 (D, Pos + 15, V.Channel_Forwarding_Start_Channel);
   end Put_Servo_Config_Record;

   procedure Get_Servo_Config_Record (D : Data; Pos : Natural; V : in out Servo_Config_Record)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      Get_Servo_Dev_Config_Record (D, Pos + 0, V.Dev);
      V.Servo_Lowpass_Freq := Get_Unsigned_16 (D, Pos + 12);
      V.Tri_Unarmed_Servo := Get_Unsigned_8 (D, Pos + 14);
      V.Channel_Forwarding_Start_Channel := Get_Unsigned_8 (D, Pos + 15);
   end Get_Servo_Config_Record;

   procedure Put_Servo_Mixer_Record (D : in out Data; Pos : Natural; V : Servo_Mixer_Record)
     with Pre => Pos <= Data_Size - 7
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Target_Channel);
      Put_Unsigned_8 (D, Pos + 1, V.Input_Source);
      Put_Integer_8 (D, Pos + 2, V.Rate);
      Put_Unsigned_8 (D, Pos + 3, V.Speed);
      Put_Integer_8 (D, Pos + 4, V.Min);
      Put_Integer_8 (D, Pos + 5, V.Max);
      Put_Unsigned_8 (D, Pos + 6, V.Box);
   end Put_Servo_Mixer_Record;

   procedure Get_Servo_Mixer_Record (D : Data; Pos : Natural; V : in out Servo_Mixer_Record)
     with Pre => Pos <= Data_Size - 7
   is
   begin
      V.Target_Channel := Get_Unsigned_8 (D, Pos + 0);
      V.Input_Source := Get_Unsigned_8 (D, Pos + 1);
      V.Rate := Get_Integer_8 (D, Pos + 2);
      V.Speed := Get_Unsigned_8 (D, Pos + 3);
      V.Min := Get_Integer_8 (D, Pos + 4);
      V.Max := Get_Integer_8 (D, Pos + 5);
      V.Box := Get_Unsigned_8 (D, Pos + 6);
   end Get_Servo_Mixer_Record;

   procedure Put_Servo_Mixer_Record_List_16 (D : in out Data; Pos : Natural; V : Servo_Mixer_Record_List_16)
     with Pre => Pos <= Data_Size - 112
   is
   begin
      for I in 0 .. 15 loop
         pragma Loop_Invariant (Pos <= Data_Size - 112);
         Put_Servo_Mixer_Record (D, Pos + I * 7, V (V'First + I));
      end loop;
   end Put_Servo_Mixer_Record_List_16;

   procedure Get_Servo_Mixer_Record_List_16 (D : Data; Pos : Natural; V : in out Servo_Mixer_Record_List_16)
     with Pre => Pos <= Data_Size - 112
   is
   begin
      for I in 0 .. 15 loop
         pragma Loop_Invariant (Pos <= Data_Size - 112);
         Get_Servo_Mixer_Record (D, Pos + I * 7, V (V'First + I));
      end loop;
   end Get_Servo_Mixer_Record_List_16;

   procedure Put_Servo_Param_Record (D : in out Data; Pos : Natural; V : Servo_Param_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      Put_Unsigned_32 (D, Pos + 0, V.Reversed_Sources);
      Put_Integer_16 (D, Pos + 4, V.Min);
      Put_Integer_16 (D, Pos + 6, V.Max);
      Put_Integer_16 (D, Pos + 8, V.Middle);
      Put_Integer_8 (D, Pos + 10, V.Rate);
      Put_Integer_8 (D, Pos + 11, V.Forward_From_Channel);
   end Put_Servo_Param_Record;

   procedure Get_Servo_Param_Record (D : Data; Pos : Natural; V : in out Servo_Param_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      V.Reversed_Sources := Get_Unsigned_32 (D, Pos + 0);
      V.Min := Get_Integer_16 (D, Pos + 4);
      V.Max := Get_Integer_16 (D, Pos + 6);
      V.Middle := Get_Integer_16 (D, Pos + 8);
      V.Rate := Get_Integer_8 (D, Pos + 10);
      V.Forward_From_Channel := Get_Integer_8 (D, Pos + 11);
   end Get_Servo_Param_Record;

   procedure Put_Servo_Param_Record_List_8 (D : in out Data; Pos : Natural; V : Servo_Param_Record_List_8)
     with Pre => Pos <= Data_Size - 96
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 96);
         Put_Servo_Param_Record (D, Pos + I * 12, V (V'First + I));
      end loop;
   end Put_Servo_Param_Record_List_8;

   procedure Get_Servo_Param_Record_List_8 (D : Data; Pos : Natural; V : in out Servo_Param_Record_List_8)
     with Pre => Pos <= Data_Size - 96
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 96);
         Get_Servo_Param_Record (D, Pos + I * 12, V (V'First + I));
      end loop;
   end Get_Servo_Param_Record_List_8;

   procedure Put_Gimbal_Config_Record (D : in out Data; Pos : Natural; V : Gimbal_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Mode);
   end Put_Gimbal_Config_Record;

   procedure Get_Gimbal_Config_Record (D : Data; Pos : Natural; V : in out Gimbal_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      V.Mode := Get_Unsigned_8 (D, Pos + 0);
   end Get_Gimbal_Config_Record;

   procedure Put_Led_Strip_Config_Record (D : in out Data; Pos : Natural; V : Led_Strip_Config_Record)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Ledstrip_Visual_Beeper);
      Put_Unsigned_8 (D, Pos + 1, V.Io_Tag);
      Put_Unsigned_8 (D, Pos + 2, V.Ledstrip_Grb_Rgb);
      Put_Unsigned_8 (D, Pos + 3, V.Ledstrip_Profile);
      Put_Unsigned_8 (D, Pos + 4, V.Ledstrip_Race_Color);
      Put_Unsigned_8 (D, Pos + 5, V.Ledstrip_Beacon_Color);
      Put_Unsigned_16 (D, Pos + 6, V.Ledstrip_Beacon_Period_Ms);
      Put_Unsigned_8 (D, Pos + 8, V.Ledstrip_Beacon_Percent);
      Put_Unsigned_8 (D, Pos + 9, V.Ledstrip_Beacon_Armed_Only);
      Put_Unsigned_8 (D, Pos + 10, V.Ledstrip_Visual_Beeper_Color);
      Put_Unsigned_8 (D, Pos + 11, V.Ledstrip_Brightness);
      Put_Unsigned_16 (D, Pos + 12, V.Ledstrip_Rainbow_Delta);
      Put_Unsigned_16 (D, Pos + 14, V.Ledstrip_Rainbow_Freq);
   end Put_Led_Strip_Config_Record;

   procedure Get_Led_Strip_Config_Record (D : Data; Pos : Natural; V : in out Led_Strip_Config_Record)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      V.Ledstrip_Visual_Beeper := Get_Unsigned_8 (D, Pos + 0);
      V.Io_Tag := Get_Unsigned_8 (D, Pos + 1);
      V.Ledstrip_Grb_Rgb := Get_Unsigned_8 (D, Pos + 2);
      V.Ledstrip_Profile := Get_Unsigned_8 (D, Pos + 3);
      V.Ledstrip_Race_Color := Get_Unsigned_8 (D, Pos + 4);
      V.Ledstrip_Beacon_Color := Get_Unsigned_8 (D, Pos + 5);
      V.Ledstrip_Beacon_Period_Ms := Get_Unsigned_16 (D, Pos + 6);
      V.Ledstrip_Beacon_Percent := Get_Unsigned_8 (D, Pos + 8);
      V.Ledstrip_Beacon_Armed_Only := Get_Unsigned_8 (D, Pos + 9);
      V.Ledstrip_Visual_Beeper_Color := Get_Unsigned_8 (D, Pos + 10);
      V.Ledstrip_Brightness := Get_Unsigned_8 (D, Pos + 11);
      V.Ledstrip_Rainbow_Delta := Get_Unsigned_16 (D, Pos + 12);
      V.Ledstrip_Rainbow_Freq := Get_Unsigned_16 (D, Pos + 14);
   end Get_Led_Strip_Config_Record;

   procedure Put_Unsigned_32_List_32 (D : in out Data; Pos : Natural; V : Unsigned_32_List_32)
     with Pre => Pos <= Data_Size - 128
   is
   begin
      for I in 0 .. 31 loop
         pragma Loop_Invariant (Pos <= Data_Size - 128);
         Put_Unsigned_32 (D, Pos + I * 4, V (V'First + I));
      end loop;
   end Put_Unsigned_32_List_32;

   procedure Get_Unsigned_32_List_32 (D : Data; Pos : Natural; V : in out Unsigned_32_List_32)
     with Pre => Pos <= Data_Size - 128
   is
   begin
      for I in 0 .. 31 loop
         pragma Loop_Invariant (Pos <= Data_Size - 128);
         V (V'First + I) := Get_Unsigned_32 (D, Pos + I * 4);
      end loop;
   end Get_Unsigned_32_List_32;

   procedure Put_Hsv_Color_Record (D : in out Data; Pos : Natural; V : Hsv_Color_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.H);
      Put_Unsigned_8 (D, Pos + 2, V.S);
      Put_Unsigned_8 (D, Pos + 3, V.V);
   end Put_Hsv_Color_Record;

   procedure Get_Hsv_Color_Record (D : Data; Pos : Natural; V : in out Hsv_Color_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.H := Get_Unsigned_16 (D, Pos + 0);
      V.S := Get_Unsigned_8 (D, Pos + 2);
      V.V := Get_Unsigned_8 (D, Pos + 3);
   end Get_Hsv_Color_Record;

   procedure Put_Hsv_Color_Record_List_16 (D : in out Data; Pos : Natural; V : Hsv_Color_Record_List_16)
     with Pre => Pos <= Data_Size - 64
   is
   begin
      for I in 0 .. 15 loop
         pragma Loop_Invariant (Pos <= Data_Size - 64);
         Put_Hsv_Color_Record (D, Pos + I * 4, V (V'First + I));
      end loop;
   end Put_Hsv_Color_Record_List_16;

   procedure Get_Hsv_Color_Record_List_16 (D : Data; Pos : Natural; V : in out Hsv_Color_Record_List_16)
     with Pre => Pos <= Data_Size - 64
   is
   begin
      for I in 0 .. 15 loop
         pragma Loop_Invariant (Pos <= Data_Size - 64);
         Get_Hsv_Color_Record (D, Pos + I * 4, V (V'First + I));
      end loop;
   end Get_Hsv_Color_Record_List_16;

   procedure Put_Mode_Color_Indexes_Record (D : in out Data; Pos : Natural; V : Mode_Color_Indexes_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      Put_Bytes_6 (D, Pos + 0, V.Color);
   end Put_Mode_Color_Indexes_Record;

   procedure Get_Mode_Color_Indexes_Record (D : Data; Pos : Natural; V : in out Mode_Color_Indexes_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      Get_Bytes_6 (D, Pos + 0, V.Color);
   end Get_Mode_Color_Indexes_Record;

   procedure Put_Mode_Color_Indexes_Record_List_6 (D : in out Data; Pos : Natural; V : Mode_Color_Indexes_Record_List_6)
     with Pre => Pos <= Data_Size - 36
   is
   begin
      for I in 0 .. 5 loop
         pragma Loop_Invariant (Pos <= Data_Size - 36);
         Put_Mode_Color_Indexes_Record (D, Pos + I * 6, V (V'First + I));
      end loop;
   end Put_Mode_Color_Indexes_Record_List_6;

   procedure Get_Mode_Color_Indexes_Record_List_6 (D : Data; Pos : Natural; V : in out Mode_Color_Indexes_Record_List_6)
     with Pre => Pos <= Data_Size - 36
   is
   begin
      for I in 0 .. 5 loop
         pragma Loop_Invariant (Pos <= Data_Size - 36);
         Get_Mode_Color_Indexes_Record (D, Pos + I * 6, V (V'First + I));
      end loop;
   end Get_Mode_Color_Indexes_Record_List_6;

   procedure Put_Bytes_11 (D : in out Data; Pos : Natural; V : Bytes_11)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      for I in 0 .. 10 loop
         pragma Loop_Invariant (Pos <= Data_Size - 11);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_11;

   procedure Get_Bytes_11 (D : Data; Pos : Natural; V : in out Bytes_11)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      for I in 0 .. 10 loop
         pragma Loop_Invariant (Pos <= Data_Size - 11);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_11;

   procedure Put_Special_Color_Indexes_Record (D : in out Data; Pos : Natural; V : Special_Color_Indexes_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      Put_Bytes_11 (D, Pos + 0, V.Color);
   end Put_Special_Color_Indexes_Record;

   procedure Get_Special_Color_Indexes_Record (D : Data; Pos : Natural; V : in out Special_Color_Indexes_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      Get_Bytes_11 (D, Pos + 0, V.Color);
   end Get_Special_Color_Indexes_Record;

   procedure Put_Led_Strip_Status_Mode_Config_Record
     (D : in out Data; Pos : Natural; V : Led_Strip_Status_Mode_Config_Record)
     with Pre => Pos <= Data_Size - 240
   is
   begin
      Put_Unsigned_32_List_32 (D, Pos + 0, V.Led_Configs);
      Put_Hsv_Color_Record_List_16 (D, Pos + 128, V.Colors);
      Put_Mode_Color_Indexes_Record_List_6 (D, Pos + 192, V.Mode_Colors);
      Put_Special_Color_Indexes_Record (D, Pos + 228, V.Special_Colors);
      Put_Unsigned_8 (D, Pos + 239, V.Ledstrip_Aux_Channel);
   end Put_Led_Strip_Status_Mode_Config_Record;

   procedure Get_Led_Strip_Status_Mode_Config_Record
     (D : Data; Pos : Natural; V : in out Led_Strip_Status_Mode_Config_Record)
     with Pre => Pos <= Data_Size - 240
   is
   begin
      Get_Unsigned_32_List_32 (D, Pos + 0, V.Led_Configs);
      Get_Hsv_Color_Record_List_16 (D, Pos + 128, V.Colors);
      Get_Mode_Color_Indexes_Record_List_6 (D, Pos + 192, V.Mode_Colors);
      Get_Special_Color_Indexes_Record (D, Pos + 228, V.Special_Colors);
      V.Ledstrip_Aux_Channel := Get_Unsigned_8 (D, Pos + 239);
   end Get_Led_Strip_Status_Mode_Config_Record;

   procedure Put_Serial_Config_Record (D : in out Data; Pos : Natural; V : Serial_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Serial_Update_Rate_Hz);
      Put_Unsigned_8 (D, Pos + 2, V.Reboot_Character);
   end Put_Serial_Config_Record;

   procedure Get_Serial_Config_Record (D : Data; Pos : Natural; V : in out Serial_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Serial_Update_Rate_Hz := Get_Unsigned_16 (D, Pos + 0);
      V.Reboot_Character := Get_Unsigned_8 (D, Pos + 2);
   end Get_Serial_Config_Record;

   procedure Put_Transponder_Config_Record (D : in out Data; Pos : Natural; V : Transponder_Config_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Provider);
      Put_Unsigned_8 (D, Pos + 1, V.Reserved);
      Put_Bytes_9 (D, Pos + 2, V.Data);
      Put_Unsigned_8 (D, Pos + 11, V.Io_Tag);
   end Put_Transponder_Config_Record;

   procedure Get_Transponder_Config_Record (D : Data; Pos : Natural; V : in out Transponder_Config_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      V.Provider := Get_Unsigned_8 (D, Pos + 0);
      V.Reserved := Get_Unsigned_8 (D, Pos + 1);
      Get_Bytes_9 (D, Pos + 2, V.Data);
      V.Io_Tag := Get_Unsigned_8 (D, Pos + 11);
   end Get_Transponder_Config_Record;

   procedure Put_Vtx_Channel_Activation_Condition_Record
     (D : in out Data; Pos : Natural; V : Vtx_Channel_Activation_Condition_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Aux_Channel_Index);
      Put_Unsigned_8 (D, Pos + 1, V.Band);
      Put_Unsigned_8 (D, Pos + 2, V.Channel);
      Put_Unsigned_8 (D, Pos + 3, V.Power);
      Put_Channel_Range_Record (D, Pos + 4, V.Range_Value);
   end Put_Vtx_Channel_Activation_Condition_Record;

   procedure Get_Vtx_Channel_Activation_Condition_Record
     (D : Data; Pos : Natural; V : in out Vtx_Channel_Activation_Condition_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      V.Aux_Channel_Index := Get_Unsigned_8 (D, Pos + 0);
      V.Band := Get_Unsigned_8 (D, Pos + 1);
      V.Channel := Get_Unsigned_8 (D, Pos + 2);
      V.Power := Get_Unsigned_8 (D, Pos + 3);
      Get_Channel_Range_Record (D, Pos + 4, V.Range_Value);
   end Get_Vtx_Channel_Activation_Condition_Record;

   procedure Put_Vtx_Channel_Activation_Condition_Record_List_10
     (D : in out Data; Pos : Natural; V : Vtx_Channel_Activation_Condition_Record_List_10)
     with Pre => Pos <= Data_Size - 60
   is
   begin
      for I in 0 .. 9 loop
         pragma Loop_Invariant (Pos <= Data_Size - 60);
         Put_Vtx_Channel_Activation_Condition_Record (D, Pos + I * 6, V (V'First + I));
      end loop;
   end Put_Vtx_Channel_Activation_Condition_Record_List_10;

   procedure Get_Vtx_Channel_Activation_Condition_Record_List_10
     (D : Data; Pos : Natural; V : in out Vtx_Channel_Activation_Condition_Record_List_10)
     with Pre => Pos <= Data_Size - 60
   is
   begin
      for I in 0 .. 9 loop
         pragma Loop_Invariant (Pos <= Data_Size - 60);
         Get_Vtx_Channel_Activation_Condition_Record (D, Pos + I * 6, V (V'First + I));
      end loop;
   end Get_Vtx_Channel_Activation_Condition_Record_List_10;

   procedure Put_Vtx_Config_Record (D : in out Data; Pos : Natural; V : Vtx_Config_Record)
     with Pre => Pos <= Data_Size - 61
   is
   begin
      Put_Vtx_Channel_Activation_Condition_Record_List_10 (D, Pos + 0, V.Vtx_Channel_Activation_Conditions);
      Put_Unsigned_8 (D, Pos + 60, V.Half_Duplex);
   end Put_Vtx_Config_Record;

   procedure Get_Vtx_Config_Record (D : Data; Pos : Natural; V : in out Vtx_Config_Record)
     with Pre => Pos <= Data_Size - 61
   is
   begin
      Get_Vtx_Channel_Activation_Condition_Record_List_10 (D, Pos + 0, V.Vtx_Channel_Activation_Conditions);
      V.Half_Duplex := Get_Unsigned_8 (D, Pos + 60);
   end Get_Vtx_Config_Record;

   procedure Put_Vtx_Settings_Config_Record (D : in out Data; Pos : Natural; V : Vtx_Settings_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Band);
      Put_Unsigned_8 (D, Pos + 1, V.Channel);
      Put_Unsigned_8 (D, Pos + 2, V.Power);
      Put_Unsigned_16 (D, Pos + 3, V.Freq);
      Put_Unsigned_16 (D, Pos + 5, V.Pit_Mode_Freq);
      Put_Unsigned_8 (D, Pos + 7, V.Low_Power_Disarm);
      Put_Unsigned_8 (D, Pos + 8, V.Softserial_Alt);
      Put_Unsigned_8 (D, Pos + 9, V.Vtx_Type);
      Put_Integer_8 (D, Pos + 10, V.Vtx_Uart);
   end Put_Vtx_Settings_Config_Record;

   procedure Get_Vtx_Settings_Config_Record (D : Data; Pos : Natural; V : in out Vtx_Settings_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      V.Band := Get_Unsigned_8 (D, Pos + 0);
      V.Channel := Get_Unsigned_8 (D, Pos + 1);
      V.Power := Get_Unsigned_8 (D, Pos + 2);
      V.Freq := Get_Unsigned_16 (D, Pos + 3);
      V.Pit_Mode_Freq := Get_Unsigned_16 (D, Pos + 5);
      V.Low_Power_Disarm := Get_Unsigned_8 (D, Pos + 7);
      V.Softserial_Alt := Get_Unsigned_8 (D, Pos + 8);
      V.Vtx_Type := Get_Unsigned_8 (D, Pos + 9);
      V.Vtx_Uart := Get_Integer_8 (D, Pos + 10);
   end Get_Vtx_Settings_Config_Record;

   procedure Put_Osd_Custom_Text_Config_Record (D : in out Data; Pos : Natural; V : Osd_Custom_Text_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Terminator);
   end Put_Osd_Custom_Text_Config_Record;

   procedure Get_Osd_Custom_Text_Config_Record (D : Data; Pos : Natural; V : in out Osd_Custom_Text_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      V.Terminator := Get_Unsigned_8 (D, Pos + 0);
   end Get_Osd_Custom_Text_Config_Record;

   procedure Put_Unsigned_16_List_2 (D : in out Data; Pos : Natural; V : Unsigned_16_List_2)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 1 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         Put_Unsigned_16 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Unsigned_16_List_2;

   procedure Get_Unsigned_16_List_2 (D : Data; Pos : Natural; V : in out Unsigned_16_List_2)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 1 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         V (V'First + I) := Get_Unsigned_16 (D, Pos + I * 2);
      end loop;
   end Get_Unsigned_16_List_2;

   procedure Put_Bytes_17 (D : in out Data; Pos : Natural; V : Bytes_17)
     with Pre => Pos <= Data_Size - 17
   is
   begin
      for I in 0 .. 16 loop
         pragma Loop_Invariant (Pos <= Data_Size - 17);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_17;

   procedure Get_Bytes_17 (D : Data; Pos : Natural; V : in out Bytes_17)
     with Pre => Pos <= Data_Size - 17
   is
   begin
      for I in 0 .. 16 loop
         pragma Loop_Invariant (Pos <= Data_Size - 17);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_17;

   procedure Put_Bytes_17_List_3 (D : in out Data; Pos : Natural; V : Bytes_17_List_3)
     with Pre => Pos <= Data_Size - 51
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 51);
         Put_Bytes_17 (D, Pos + I * 17, V (V'First + I));
      end loop;
   end Put_Bytes_17_List_3;

   procedure Get_Bytes_17_List_3 (D : Data; Pos : Natural; V : in out Bytes_17_List_3)
     with Pre => Pos <= Data_Size - 51
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 51);
         Get_Bytes_17 (D, Pos + I * 17, V (V'First + I));
      end loop;
   end Get_Bytes_17_List_3;

   procedure Put_Integer_8_List_4 (D : in out Data; Pos : Natural; V : Integer_8_List_4)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         Put_Integer_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Integer_8_List_4;

   procedure Get_Integer_8_List_4 (D : Data; Pos : Natural; V : in out Integer_8_List_4)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         V (V'First + I) := Get_Integer_8 (D, Pos + I * 1);
      end loop;
   end Get_Integer_8_List_4;

   procedure Put_Osd_Config_Record (D : in out Data; Pos : Natural; V : Osd_Config_Record)
     with Pre => Pos <= Data_Size - 115
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Cap_Alarm);
      Put_Unsigned_16 (D, Pos + 2, V.Alt_Alarm);
      Put_Unsigned_8 (D, Pos + 4, V.Rssi_Alarm);
      Put_Unsigned_8 (D, Pos + 5, V.Units);
      Put_Unsigned_16_List_2 (D, Pos + 6, V.Timers);
      Put_Unsigned_32 (D, Pos + 10, V.Enabled_Warnings);
      Put_Unsigned_8 (D, Pos + 14, V.Ah_Max_Pitch);
      Put_Unsigned_8 (D, Pos + 15, V.Ah_Max_Roll);
      Put_Unsigned_32 (D, Pos + 16, V.Enabled_Stats);
      Put_Unsigned_8 (D, Pos + 20, V.Esc_Temp_Alarm);
      Put_Integer_16 (D, Pos + 21, V.Esc_Rpm_Alarm);
      Put_Integer_16 (D, Pos + 23, V.Esc_Current_Alarm);
      Put_Unsigned_8 (D, Pos + 25, V.Core_Temp_Alarm);
      Put_Unsigned_8 (D, Pos + 26, V.Ah_Invert);
      Put_Unsigned_8 (D, Pos + 27, V.Osd_Profile_Index);
      Put_Unsigned_8 (D, Pos + 28, V.Overlay_Radio_Mode);
      Put_Bytes_17_List_3 (D, Pos + 29, V.Profile);
      Put_Unsigned_16 (D, Pos + 80, V.Link_Quality_Alarm);
      Put_Integer_16 (D, Pos + 82, V.Rssi_Dbm_Alarm);
      Put_Integer_16 (D, Pos + 84, V.Rsnr_Alarm);
      Put_Unsigned_8 (D, Pos + 86, V.Gps_Sats_Show_Pdop);
      Put_Integer_8_List_4 (D, Pos + 87, V.Rc_Channels);
      Put_Unsigned_8 (D, Pos + 91, V.Display_Port_Device);
      Put_Unsigned_16 (D, Pos + 92, V.Distance_Alarm);
      Put_Unsigned_8 (D, Pos + 94, V.Logo_On_Arming);
      Put_Unsigned_8 (D, Pos + 95, V.Logo_On_Arming_Duration);
      Put_Unsigned_8 (D, Pos + 96, V.Camera_Frame_Width);
      Put_Unsigned_8 (D, Pos + 97, V.Camera_Frame_Height);
      Put_Unsigned_16 (D, Pos + 98, V.Framerate_Hz);
      Put_Unsigned_8 (D, Pos + 100, V.Cms_Background_Type);
      Put_Unsigned_8 (D, Pos + 101, V.Stat_Show_Cell_Value);
      Put_Unsigned_8 (D, Pos + 102, V.Osd_Craftname_Msgs);
      Put_Unsigned_8 (D, Pos + 103, V.Aux_Channel);
      Put_Unsigned_16 (D, Pos + 104, V.Aux_Scale);
      Put_Unsigned_8 (D, Pos + 106, V.Aux_Symbol);
      Put_Unsigned_8 (D, Pos + 107, V.Canvas_Cols);
      Put_Unsigned_8 (D, Pos + 108, V.Canvas_Rows);
      Put_Unsigned_8 (D, Pos + 109, V.Osd_Use_Quick_Menu);
      Put_Unsigned_8 (D, Pos + 110, V.Osd_Show_Spec_Prearm);
      Put_Unsigned_8 (D, Pos + 111, V.Arming_Logo);
      Put_Integer_8 (D, Pos + 112, V.Osd_Uart);
      Put_Integer_8 (D, Pos + 113, V.Osd_Custom_Text_Uart);
      Put_Unsigned_8 (D, Pos + 114, V.Osd_Custom_Text_Baud);
   end Put_Osd_Config_Record;

   procedure Get_Osd_Config_Record (D : Data; Pos : Natural; V : in out Osd_Config_Record)
     with Pre => Pos <= Data_Size - 115
   is
   begin
      V.Cap_Alarm := Get_Unsigned_16 (D, Pos + 0);
      V.Alt_Alarm := Get_Unsigned_16 (D, Pos + 2);
      V.Rssi_Alarm := Get_Unsigned_8 (D, Pos + 4);
      V.Units := Get_Unsigned_8 (D, Pos + 5);
      Get_Unsigned_16_List_2 (D, Pos + 6, V.Timers);
      V.Enabled_Warnings := Get_Unsigned_32 (D, Pos + 10);
      V.Ah_Max_Pitch := Get_Unsigned_8 (D, Pos + 14);
      V.Ah_Max_Roll := Get_Unsigned_8 (D, Pos + 15);
      V.Enabled_Stats := Get_Unsigned_32 (D, Pos + 16);
      V.Esc_Temp_Alarm := Get_Unsigned_8 (D, Pos + 20);
      V.Esc_Rpm_Alarm := Get_Integer_16 (D, Pos + 21);
      V.Esc_Current_Alarm := Get_Integer_16 (D, Pos + 23);
      V.Core_Temp_Alarm := Get_Unsigned_8 (D, Pos + 25);
      V.Ah_Invert := Get_Unsigned_8 (D, Pos + 26);
      V.Osd_Profile_Index := Get_Unsigned_8 (D, Pos + 27);
      V.Overlay_Radio_Mode := Get_Unsigned_8 (D, Pos + 28);
      Get_Bytes_17_List_3 (D, Pos + 29, V.Profile);
      V.Link_Quality_Alarm := Get_Unsigned_16 (D, Pos + 80);
      V.Rssi_Dbm_Alarm := Get_Integer_16 (D, Pos + 82);
      V.Rsnr_Alarm := Get_Integer_16 (D, Pos + 84);
      V.Gps_Sats_Show_Pdop := Get_Unsigned_8 (D, Pos + 86);
      Get_Integer_8_List_4 (D, Pos + 87, V.Rc_Channels);
      V.Display_Port_Device := Get_Unsigned_8 (D, Pos + 91);
      V.Distance_Alarm := Get_Unsigned_16 (D, Pos + 92);
      V.Logo_On_Arming := Get_Unsigned_8 (D, Pos + 94);
      V.Logo_On_Arming_Duration := Get_Unsigned_8 (D, Pos + 95);
      V.Camera_Frame_Width := Get_Unsigned_8 (D, Pos + 96);
      V.Camera_Frame_Height := Get_Unsigned_8 (D, Pos + 97);
      V.Framerate_Hz := Get_Unsigned_16 (D, Pos + 98);
      V.Cms_Background_Type := Get_Unsigned_8 (D, Pos + 100);
      V.Stat_Show_Cell_Value := Get_Unsigned_8 (D, Pos + 101);
      V.Osd_Craftname_Msgs := Get_Unsigned_8 (D, Pos + 102);
      V.Aux_Channel := Get_Unsigned_8 (D, Pos + 103);
      V.Aux_Scale := Get_Unsigned_16 (D, Pos + 104);
      V.Aux_Symbol := Get_Unsigned_8 (D, Pos + 106);
      V.Canvas_Cols := Get_Unsigned_8 (D, Pos + 107);
      V.Canvas_Rows := Get_Unsigned_8 (D, Pos + 108);
      V.Osd_Use_Quick_Menu := Get_Unsigned_8 (D, Pos + 109);
      V.Osd_Show_Spec_Prearm := Get_Unsigned_8 (D, Pos + 110);
      V.Arming_Logo := Get_Unsigned_8 (D, Pos + 111);
      V.Osd_Uart := Get_Integer_8 (D, Pos + 112);
      V.Osd_Custom_Text_Uart := Get_Integer_8 (D, Pos + 113);
      V.Osd_Custom_Text_Baud := Get_Unsigned_8 (D, Pos + 114);
   end Get_Osd_Config_Record;

   procedure Put_Unsigned_16_List_99 (D : in out Data; Pos : Natural; V : Unsigned_16_List_99)
     with Pre => Pos <= Data_Size - 198
   is
   begin
      for I in 0 .. 98 loop
         pragma Loop_Invariant (Pos <= Data_Size - 198);
         Put_Unsigned_16 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Unsigned_16_List_99;

   procedure Get_Unsigned_16_List_99 (D : Data; Pos : Natural; V : in out Unsigned_16_List_99)
     with Pre => Pos <= Data_Size - 198
   is
   begin
      for I in 0 .. 98 loop
         pragma Loop_Invariant (Pos <= Data_Size - 198);
         V (V'First + I) := Get_Unsigned_16 (D, Pos + I * 2);
      end loop;
   end Get_Unsigned_16_List_99;

   procedure Put_Osd_Element_Config_Record (D : in out Data; Pos : Natural; V : Osd_Element_Config_Record)
     with Pre => Pos <= Data_Size - 198
   is
   begin
      Put_Unsigned_16_List_99 (D, Pos + 0, V.Item_Pos);
   end Put_Osd_Element_Config_Record;

   procedure Get_Osd_Element_Config_Record (D : Data; Pos : Natural; V : in out Osd_Element_Config_Record)
     with Pre => Pos <= Data_Size - 198
   is
   begin
      Get_Unsigned_16_List_99 (D, Pos + 0, V.Item_Pos);
   end Get_Osd_Element_Config_Record;

   procedure Put_Adc_Channel_Config_T_Record (D : in out Data; Pos : Natural; V : Adc_Channel_Config_T_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Boolean (D, Pos + 0, V.Enabled);
      Put_Unsigned_8 (D, Pos + 1, V.Io_Tag);
      Put_Integer_8 (D, Pos + 2, V.Device);
   end Put_Adc_Channel_Config_T_Record;

   procedure Get_Adc_Channel_Config_T_Record (D : Data; Pos : Natural; V : in out Adc_Channel_Config_T_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Enabled := Get_Boolean (D, Pos + 0);
      V.Io_Tag := Get_Unsigned_8 (D, Pos + 1);
      V.Device := Get_Integer_8 (D, Pos + 2);
   end Get_Adc_Channel_Config_T_Record;

   procedure Put_Adc_Config_Record (D : in out Data; Pos : Natural; V : Adc_Config_Record)
     with Pre => Pos <= Data_Size - 19
   is
   begin
      Put_Adc_Channel_Config_T_Record (D, Pos + 0, V.Vbat);
      Put_Adc_Channel_Config_T_Record (D, Pos + 3, V.Rssi);
      Put_Adc_Channel_Config_T_Record (D, Pos + 6, V.Current);
      Put_Adc_Channel_Config_T_Record (D, Pos + 9, V.External1);
      Put_Integer_8 (D, Pos + 12, V.Device);
      Put_Unsigned_16 (D, Pos + 13, V.Vref_Int_Calibration);
      Put_Unsigned_16 (D, Pos + 15, V.Temp_Sensor_Calibration1);
      Put_Unsigned_16 (D, Pos + 17, V.Temp_Sensor_Calibration2);
   end Put_Adc_Config_Record;

   procedure Get_Adc_Config_Record (D : Data; Pos : Natural; V : in out Adc_Config_Record)
     with Pre => Pos <= Data_Size - 19
   is
   begin
      Get_Adc_Channel_Config_T_Record (D, Pos + 0, V.Vbat);
      Get_Adc_Channel_Config_T_Record (D, Pos + 3, V.Rssi);
      Get_Adc_Channel_Config_T_Record (D, Pos + 6, V.Current);
      Get_Adc_Channel_Config_T_Record (D, Pos + 9, V.External1);
      V.Device := Get_Integer_8 (D, Pos + 12);
      V.Vref_Int_Calibration := Get_Unsigned_16 (D, Pos + 13);
      V.Temp_Sensor_Calibration1 := Get_Unsigned_16 (D, Pos + 15);
      V.Temp_Sensor_Calibration2 := Get_Unsigned_16 (D, Pos + 17);
   end Get_Adc_Config_Record;

   procedure Put_Alt_Hold_Config_Record (D : in out Data; Pos : Natural; V : Alt_Hold_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Climb_Rate);
      Put_Unsigned_8 (D, Pos + 1, V.Deadband);
   end Put_Alt_Hold_Config_Record;

   procedure Get_Alt_Hold_Config_Record (D : Data; Pos : Natural; V : in out Alt_Hold_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      V.Climb_Rate := Get_Unsigned_8 (D, Pos + 0);
      V.Deadband := Get_Unsigned_8 (D, Pos + 1);
   end Get_Alt_Hold_Config_Record;

   procedure Put_Autopilot_Config_Record (D : in out Data; Pos : Natural; V : Autopilot_Config_Record)
     with Pre => Pos <= Data_Size - 79
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Landing_Altitude_M);
      Put_Unsigned_16 (D, Pos + 1, V.Hover_Throttle);
      Put_Unsigned_16 (D, Pos + 3, V.Throttle_Min);
      Put_Unsigned_16 (D, Pos + 5, V.Throttle_Max);
      Put_Unsigned_8 (D, Pos + 7, V.Altitude_P);
      Put_Unsigned_8 (D, Pos + 8, V.Altitude_I);
      Put_Unsigned_8 (D, Pos + 9, V.Altitude_D);
      Put_Unsigned_8 (D, Pos + 10, V.Altitude_A);
      Put_Unsigned_8 (D, Pos + 11, V.Altitude_F);
      Put_Unsigned_8 (D, Pos + 12, V.Position_P);
      Put_Unsigned_8 (D, Pos + 13, V.Position_I);
      Put_Unsigned_8 (D, Pos + 14, V.Position_D);
      Put_Unsigned_8 (D, Pos + 15, V.Position_A);
      Put_Unsigned_8 (D, Pos + 16, V.Position_F);
      Put_Unsigned_8 (D, Pos + 17, V.Position_Cutoff);
      Put_Unsigned_8 (D, Pos + 18, V.Stop_Threshold);
      Put_Unsigned_8 (D, Pos + 19, V.Max_Angle);
      Put_Unsigned_8 (D, Pos + 20, V.Velocity_Drag_Coeff);
      Put_Unsigned_16 (D, Pos + 21, V.Max_Velocity);
      Put_Unsigned_16 (D, Pos + 23, V.Waypoint_Arrival_Radius);
      Put_Unsigned_16 (D, Pos + 25, V.Waypoint_Hold_Radius);
      Put_Unsigned_16 (D, Pos + 27, V.Stick_Deadband);
      Put_Unsigned_16 (D, Pos + 29, V.Throttle_Deadband);
      Put_Unsigned_16 (D, Pos + 31, V.Nav_Corner_Speed);
      Put_Unsigned_16 (D, Pos + 33, V.Nav_Corner_Delta_V);
      Put_Unsigned_16 (D, Pos + 35, V.Nav_Decel);
      Put_Unsigned_16 (D, Pos + 37, V.Nav_Accel);
      Put_Unsigned_8 (D, Pos + 39, V.Nav_Carrot_Lead_Time);
      Put_Unsigned_16 (D, Pos + 40, V.Nav_Carrot_Lead_Max);
      Put_Unsigned_16 (D, Pos + 42, V.Nav_Preturn_Dist);
      Put_Unsigned_8 (D, Pos + 44, V.Yaw_Mode);
      Put_Unsigned_8 (D, Pos + 45, V.Yaw_P);
      Put_Unsigned_8 (D, Pos + 46, V.Max_Yaw_Rate);
      Put_Unsigned_16 (D, Pos + 47, V.Min_Forward_Velocity);
      Put_Unsigned_8 (D, Pos + 49, V.Velocity_Buildup_Max_Pitch);
      Put_Unsigned_8 (D, Pos + 50, V.Max_Turn_Rate);
      Put_Unsigned_16 (D, Pos + 51, V.Hold_Orbit_Radius);
      Put_Unsigned_16 (D, Pos + 53, V.Hold_Figure8_Width);
      Put_Unsigned_8 (D, Pos + 55, V.Landing_Descent_Rate);
      Put_Unsigned_8 (D, Pos + 56, V.Landing_Detection_Time);
      Put_Unsigned_8 (D, Pos + 57, V.Landing_Spiral_Enable);
      Put_Unsigned_16 (D, Pos + 58, V.Landing_Spiral_Radius);
      Put_Unsigned_8 (D, Pos + 60, V.Landing_Spiral_Rate);
      Put_Unsigned_8 (D, Pos + 61, V.Landing_Velocity_Threshold);
      Put_Unsigned_16 (D, Pos + 62, V.Landing_Throttle_Threshold);
      Put_Unsigned_8 (D, Pos + 64, V.L1_Enable);
      Put_Unsigned_16 (D, Pos + 65, V.L1_Period);
      Put_Unsigned_16 (D, Pos + 67, V.L1_Min_Lookahead);
      Put_Unsigned_16 (D, Pos + 69, V.L1_Max_Lookahead);
      Put_Unsigned_16 (D, Pos + 71, V.L1_Max_Cross_Track_Error);
      Put_Unsigned_8 (D, Pos + 73, V.L1_Turn_Rate);
      Put_Unsigned_8 (D, Pos + 74, V.Min_Nav_Altitude_M);
      Put_Unsigned_8 (D, Pos + 75, V.Rx_Loss_Policy);
      Put_Unsigned_16 (D, Pos + 76, V.Max_Distance_From_Home_M);
      Put_Unsigned_8 (D, Pos + 78, V.Geofence_Action);
   end Put_Autopilot_Config_Record;

   procedure Get_Autopilot_Config_Record (D : Data; Pos : Natural; V : in out Autopilot_Config_Record)
     with Pre => Pos <= Data_Size - 79
   is
   begin
      V.Landing_Altitude_M := Get_Unsigned_8 (D, Pos + 0);
      V.Hover_Throttle := Get_Unsigned_16 (D, Pos + 1);
      V.Throttle_Min := Get_Unsigned_16 (D, Pos + 3);
      V.Throttle_Max := Get_Unsigned_16 (D, Pos + 5);
      V.Altitude_P := Get_Unsigned_8 (D, Pos + 7);
      V.Altitude_I := Get_Unsigned_8 (D, Pos + 8);
      V.Altitude_D := Get_Unsigned_8 (D, Pos + 9);
      V.Altitude_A := Get_Unsigned_8 (D, Pos + 10);
      V.Altitude_F := Get_Unsigned_8 (D, Pos + 11);
      V.Position_P := Get_Unsigned_8 (D, Pos + 12);
      V.Position_I := Get_Unsigned_8 (D, Pos + 13);
      V.Position_D := Get_Unsigned_8 (D, Pos + 14);
      V.Position_A := Get_Unsigned_8 (D, Pos + 15);
      V.Position_F := Get_Unsigned_8 (D, Pos + 16);
      V.Position_Cutoff := Get_Unsigned_8 (D, Pos + 17);
      V.Stop_Threshold := Get_Unsigned_8 (D, Pos + 18);
      V.Max_Angle := Get_Unsigned_8 (D, Pos + 19);
      V.Velocity_Drag_Coeff := Get_Unsigned_8 (D, Pos + 20);
      V.Max_Velocity := Get_Unsigned_16 (D, Pos + 21);
      V.Waypoint_Arrival_Radius := Get_Unsigned_16 (D, Pos + 23);
      V.Waypoint_Hold_Radius := Get_Unsigned_16 (D, Pos + 25);
      V.Stick_Deadband := Get_Unsigned_16 (D, Pos + 27);
      V.Throttle_Deadband := Get_Unsigned_16 (D, Pos + 29);
      V.Nav_Corner_Speed := Get_Unsigned_16 (D, Pos + 31);
      V.Nav_Corner_Delta_V := Get_Unsigned_16 (D, Pos + 33);
      V.Nav_Decel := Get_Unsigned_16 (D, Pos + 35);
      V.Nav_Accel := Get_Unsigned_16 (D, Pos + 37);
      V.Nav_Carrot_Lead_Time := Get_Unsigned_8 (D, Pos + 39);
      V.Nav_Carrot_Lead_Max := Get_Unsigned_16 (D, Pos + 40);
      V.Nav_Preturn_Dist := Get_Unsigned_16 (D, Pos + 42);
      V.Yaw_Mode := Get_Unsigned_8 (D, Pos + 44);
      V.Yaw_P := Get_Unsigned_8 (D, Pos + 45);
      V.Max_Yaw_Rate := Get_Unsigned_8 (D, Pos + 46);
      V.Min_Forward_Velocity := Get_Unsigned_16 (D, Pos + 47);
      V.Velocity_Buildup_Max_Pitch := Get_Unsigned_8 (D, Pos + 49);
      V.Max_Turn_Rate := Get_Unsigned_8 (D, Pos + 50);
      V.Hold_Orbit_Radius := Get_Unsigned_16 (D, Pos + 51);
      V.Hold_Figure8_Width := Get_Unsigned_16 (D, Pos + 53);
      V.Landing_Descent_Rate := Get_Unsigned_8 (D, Pos + 55);
      V.Landing_Detection_Time := Get_Unsigned_8 (D, Pos + 56);
      V.Landing_Spiral_Enable := Get_Unsigned_8 (D, Pos + 57);
      V.Landing_Spiral_Radius := Get_Unsigned_16 (D, Pos + 58);
      V.Landing_Spiral_Rate := Get_Unsigned_8 (D, Pos + 60);
      V.Landing_Velocity_Threshold := Get_Unsigned_8 (D, Pos + 61);
      V.Landing_Throttle_Threshold := Get_Unsigned_16 (D, Pos + 62);
      V.L1_Enable := Get_Unsigned_8 (D, Pos + 64);
      V.L1_Period := Get_Unsigned_16 (D, Pos + 65);
      V.L1_Min_Lookahead := Get_Unsigned_16 (D, Pos + 67);
      V.L1_Max_Lookahead := Get_Unsigned_16 (D, Pos + 69);
      V.L1_Max_Cross_Track_Error := Get_Unsigned_16 (D, Pos + 71);
      V.L1_Turn_Rate := Get_Unsigned_8 (D, Pos + 73);
      V.Min_Nav_Altitude_M := Get_Unsigned_8 (D, Pos + 74);
      V.Rx_Loss_Policy := Get_Unsigned_8 (D, Pos + 75);
      V.Max_Distance_From_Home_M := Get_Unsigned_16 (D, Pos + 76);
      V.Geofence_Action := Get_Unsigned_8 (D, Pos + 78);
   end Get_Autopilot_Config_Record;

   procedure Put_Beeper_Dev_Config_Record (D : in out Data; Pos : Natural; V : Beeper_Dev_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Io_Tag);
      Put_Unsigned_8 (D, Pos + 1, V.Is_Inverted);
      Put_Unsigned_8 (D, Pos + 2, V.Is_Open_Drain);
      Put_Unsigned_16 (D, Pos + 3, V.Frequency);
   end Put_Beeper_Dev_Config_Record;

   procedure Get_Beeper_Dev_Config_Record (D : Data; Pos : Natural; V : in out Beeper_Dev_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Io_Tag := Get_Unsigned_8 (D, Pos + 0);
      V.Is_Inverted := Get_Unsigned_8 (D, Pos + 1);
      V.Is_Open_Drain := Get_Unsigned_8 (D, Pos + 2);
      V.Frequency := Get_Unsigned_16 (D, Pos + 3);
   end Get_Beeper_Dev_Config_Record;

   procedure Put_Beeper_Config_Record (D : in out Data; Pos : Natural; V : Beeper_Config_Record)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      Put_Unsigned_32 (D, Pos + 0, V.Beeper_Off_Flags);
      Put_Unsigned_8 (D, Pos + 4, V.Dshot_Beacon_Tone);
      Put_Unsigned_32 (D, Pos + 5, V.Dshot_Beacon_Off_Flags);
   end Put_Beeper_Config_Record;

   procedure Get_Beeper_Config_Record (D : Data; Pos : Natural; V : in out Beeper_Config_Record)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      V.Beeper_Off_Flags := Get_Unsigned_32 (D, Pos + 0);
      V.Dshot_Beacon_Tone := Get_Unsigned_8 (D, Pos + 4);
      V.Dshot_Beacon_Off_Flags := Get_Unsigned_32 (D, Pos + 5);
   end Get_Beeper_Config_Record;

   procedure Put_Bytes_32 (D : in out Data; Pos : Natural; V : Bytes_32)
     with Pre => Pos <= Data_Size - 32
   is
   begin
      for I in 0 .. 31 loop
         pragma Loop_Invariant (Pos <= Data_Size - 32);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_32;

   procedure Get_Bytes_32 (D : Data; Pos : Natural; V : in out Bytes_32)
     with Pre => Pos <= Data_Size - 32
   is
   begin
      for I in 0 .. 31 loop
         pragma Loop_Invariant (Pos <= Data_Size - 32);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_32;

   procedure Put_Bytes_5 (D : in out Data; Pos : Natural; V : Bytes_5)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      for I in 0 .. 4 loop
         pragma Loop_Invariant (Pos <= Data_Size - 5);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_5;

   procedure Get_Bytes_5 (D : Data; Pos : Natural; V : in out Bytes_5)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      for I in 0 .. 4 loop
         pragma Loop_Invariant (Pos <= Data_Size - 5);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_5;

   procedure Put_Bytes_21 (D : in out Data; Pos : Natural; V : Bytes_21)
     with Pre => Pos <= Data_Size - 21
   is
   begin
      for I in 0 .. 20 loop
         pragma Loop_Invariant (Pos <= Data_Size - 21);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_21;

   procedure Get_Bytes_21 (D : Data; Pos : Natural; V : in out Bytes_21)
     with Pre => Pos <= Data_Size - 21
   is
   begin
      for I in 0 .. 20 loop
         pragma Loop_Invariant (Pos <= Data_Size - 21);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_21;

   procedure Put_Board_Config_Record (D : in out Data; Pos : Natural; V : Board_Config_Record)
     with Pre => Pos <= Data_Size - 60
   is
   begin
      Put_Bytes_32 (D, Pos + 0, V.Signature);
      Put_Bytes_5 (D, Pos + 32, V.Manufacturer_Id);
      Put_Bytes_21 (D, Pos + 37, V.Board_Name);
      Put_Unsigned_8 (D, Pos + 58, V.Board_Information_Set);
      Put_Unsigned_8 (D, Pos + 59, V.Signature_Set);
   end Put_Board_Config_Record;

   procedure Get_Board_Config_Record (D : Data; Pos : Natural; V : in out Board_Config_Record)
     with Pre => Pos <= Data_Size - 60
   is
   begin
      Get_Bytes_32 (D, Pos + 0, V.Signature);
      Get_Bytes_5 (D, Pos + 32, V.Manufacturer_Id);
      Get_Bytes_21 (D, Pos + 37, V.Board_Name);
      V.Board_Information_Set := Get_Unsigned_8 (D, Pos + 58);
      V.Signature_Set := Get_Unsigned_8 (D, Pos + 59);
   end Get_Board_Config_Record;

   procedure Put_I2c_Config_Record (D : in out Data; Pos : Natural; V : I2c_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Io_Tag_Scl);
      Put_Unsigned_8 (D, Pos + 1, V.Io_Tag_Sda);
      Put_Boolean (D, Pos + 2, V.Pull_Up);
      Put_Unsigned_16 (D, Pos + 3, V.Clock_Speed);
   end Put_I2c_Config_Record;

   procedure Get_I2c_Config_Record (D : Data; Pos : Natural; V : in out I2c_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Io_Tag_Scl := Get_Unsigned_8 (D, Pos + 0);
      V.Io_Tag_Sda := Get_Unsigned_8 (D, Pos + 1);
      V.Pull_Up := Get_Boolean (D, Pos + 2);
      V.Clock_Speed := Get_Unsigned_16 (D, Pos + 3);
   end Get_I2c_Config_Record;

   procedure Put_I2c_Config_Record_List_3 (D : in out Data; Pos : Natural; V : I2c_Config_Record_List_3)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 15);
         Put_I2c_Config_Record (D, Pos + I * 5, V (V'First + I));
      end loop;
   end Put_I2c_Config_Record_List_3;

   procedure Get_I2c_Config_Record_List_3 (D : Data; Pos : Natural; V : in out I2c_Config_Record_List_3)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 15);
         Get_I2c_Config_Record (D, Pos + I * 5, V (V'First + I));
      end loop;
   end Get_I2c_Config_Record_List_3;

   procedure Put_Spi_Pin_Config_Record (D : in out Data; Pos : Natural; V : Spi_Pin_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Io_Tag_Sck);
      Put_Unsigned_8 (D, Pos + 1, V.Io_Tag_Miso);
      Put_Unsigned_8 (D, Pos + 2, V.Io_Tag_Mosi);
      Put_Integer_8 (D, Pos + 3, V.Tx_Dmaopt);
      Put_Integer_8 (D, Pos + 4, V.Rx_Dmaopt);
   end Put_Spi_Pin_Config_Record;

   procedure Get_Spi_Pin_Config_Record (D : Data; Pos : Natural; V : in out Spi_Pin_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Io_Tag_Sck := Get_Unsigned_8 (D, Pos + 0);
      V.Io_Tag_Miso := Get_Unsigned_8 (D, Pos + 1);
      V.Io_Tag_Mosi := Get_Unsigned_8 (D, Pos + 2);
      V.Tx_Dmaopt := Get_Integer_8 (D, Pos + 3);
      V.Rx_Dmaopt := Get_Integer_8 (D, Pos + 4);
   end Get_Spi_Pin_Config_Record;

   procedure Put_Spi_Pin_Config_Record_List_3 (D : in out Data; Pos : Natural; V : Spi_Pin_Config_Record_List_3)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 15);
         Put_Spi_Pin_Config_Record (D, Pos + I * 5, V (V'First + I));
      end loop;
   end Put_Spi_Pin_Config_Record_List_3;

   procedure Get_Spi_Pin_Config_Record_List_3 (D : Data; Pos : Natural; V : in out Spi_Pin_Config_Record_List_3)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 15);
         Get_Spi_Pin_Config_Record (D, Pos + I * 5, V (V'First + I));
      end loop;
   end Get_Spi_Pin_Config_Record_List_3;

   procedure Put_Dashboard_Config_Record (D : in out Data; Pos : Natural; V : Dashboard_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Integer_32 (D, Pos + 0, V.Device);
      Put_Unsigned_8 (D, Pos + 4, V.Address);
   end Put_Dashboard_Config_Record;

   procedure Get_Dashboard_Config_Record (D : Data; Pos : Natural; V : in out Dashboard_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Device := Get_Integer_32 (D, Pos + 0);
      V.Address := Get_Unsigned_8 (D, Pos + 4);
   end Get_Dashboard_Config_Record;

   procedure Put_Bytes_4 (D : in out Data; Pos : Natural; V : Bytes_4)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_4;

   procedure Get_Bytes_4 (D : Data; Pos : Natural; V : in out Bytes_4)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_4;

   procedure Put_Display_Port_Profile_Record (D : in out Data; Pos : Natural; V : Display_Port_Profile_Record)
     with Pre => Pos <= Data_Size - 10
   is
   begin
      Put_Integer_8 (D, Pos + 0, V.Col_Adjust);
      Put_Integer_8 (D, Pos + 1, V.Row_Adjust);
      Put_Boolean (D, Pos + 2, V.Invert);
      Put_Unsigned_8 (D, Pos + 3, V.Black_Brightness);
      Put_Unsigned_8 (D, Pos + 4, V.White_Brightness);
      Put_Bytes_4 (D, Pos + 5, V.Font_Selection);
      Put_Unsigned_8 (D, Pos + 9, V.Use_Device_Blink);
   end Put_Display_Port_Profile_Record;

   procedure Get_Display_Port_Profile_Record (D : Data; Pos : Natural; V : in out Display_Port_Profile_Record)
     with Pre => Pos <= Data_Size - 10
   is
   begin
      V.Col_Adjust := Get_Integer_8 (D, Pos + 0);
      V.Row_Adjust := Get_Integer_8 (D, Pos + 1);
      V.Invert := Get_Boolean (D, Pos + 2);
      V.Black_Brightness := Get_Unsigned_8 (D, Pos + 3);
      V.White_Brightness := Get_Unsigned_8 (D, Pos + 4);
      Get_Bytes_4 (D, Pos + 5, V.Font_Selection);
      V.Use_Device_Blink := Get_Unsigned_8 (D, Pos + 9);
   end Get_Display_Port_Profile_Record;

   procedure Put_Dyn_Notch_Config_Record (D : in out Data; Pos : Natural; V : Dyn_Notch_Config_Record)
     with Pre => Pos <= Data_Size - 7
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Dyn_Notch_Min_Hz);
      Put_Unsigned_16 (D, Pos + 2, V.Dyn_Notch_Max_Hz);
      Put_Unsigned_16 (D, Pos + 4, V.Dyn_Notch_Q);
      Put_Unsigned_8 (D, Pos + 6, V.Dyn_Notch_Count);
   end Put_Dyn_Notch_Config_Record;

   procedure Get_Dyn_Notch_Config_Record (D : Data; Pos : Natural; V : in out Dyn_Notch_Config_Record)
     with Pre => Pos <= Data_Size - 7
   is
   begin
      V.Dyn_Notch_Min_Hz := Get_Unsigned_16 (D, Pos + 0);
      V.Dyn_Notch_Max_Hz := Get_Unsigned_16 (D, Pos + 2);
      V.Dyn_Notch_Q := Get_Unsigned_16 (D, Pos + 4);
      V.Dyn_Notch_Count := Get_Unsigned_8 (D, Pos + 6);
   end Get_Dyn_Notch_Config_Record;

   procedure Put_Flash_Config_Record (D : in out Data; Pos : Natural; V : Flash_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Cs_Tag);
      Put_Unsigned_8 (D, Pos + 1, V.Spi_Device);
      Put_Unsigned_8 (D, Pos + 2, V.Quad_Spi_Device);
      Put_Unsigned_8 (D, Pos + 3, V.Octo_Spi_Device);
   end Put_Flash_Config_Record;

   procedure Get_Flash_Config_Record (D : Data; Pos : Natural; V : in out Flash_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Cs_Tag := Get_Unsigned_8 (D, Pos + 0);
      V.Spi_Device := Get_Unsigned_8 (D, Pos + 1);
      V.Quad_Spi_Device := Get_Unsigned_8 (D, Pos + 2);
      V.Octo_Spi_Device := Get_Unsigned_8 (D, Pos + 3);
   end Get_Flash_Config_Record;

   procedure Put_Flight_Plan_Config_Record_Waypoints_Record
     (D : in out Data; Pos : Natural; V : Flight_Plan_Config_Record_Waypoints_Record)
     with Pre => Pos <= Data_Size - 21
   is
   begin
      Put_Integer_32 (D, Pos + 0, V.Latitude);
      Put_Integer_32 (D, Pos + 4, V.Longitude);
      Put_Integer_32 (D, Pos + 8, V.Altitude);
      Put_Unsigned_16 (D, Pos + 12, V.Speed);
      Put_Unsigned_16 (D, Pos + 14, V.Duration);
      Put_Unsigned_16 (D, Pos + 16, V.Vert_Rate);
      Put_Unsigned_8 (D, Pos + 18, V.Type_Value);
      Put_Unsigned_8 (D, Pos + 19, V.Pattern);
      Put_Unsigned_8 (D, Pos + 20, V.Yaw_Behaviour);
   end Put_Flight_Plan_Config_Record_Waypoints_Record;

   procedure Get_Flight_Plan_Config_Record_Waypoints_Record
     (D : Data; Pos : Natural; V : in out Flight_Plan_Config_Record_Waypoints_Record)
     with Pre => Pos <= Data_Size - 21
   is
   begin
      V.Latitude := Get_Integer_32 (D, Pos + 0);
      V.Longitude := Get_Integer_32 (D, Pos + 4);
      V.Altitude := Get_Integer_32 (D, Pos + 8);
      V.Speed := Get_Unsigned_16 (D, Pos + 12);
      V.Duration := Get_Unsigned_16 (D, Pos + 14);
      V.Vert_Rate := Get_Unsigned_16 (D, Pos + 16);
      V.Type_Value := Get_Unsigned_8 (D, Pos + 18);
      V.Pattern := Get_Unsigned_8 (D, Pos + 19);
      V.Yaw_Behaviour := Get_Unsigned_8 (D, Pos + 20);
   end Get_Flight_Plan_Config_Record_Waypoints_Record;

   procedure Put_Flight_Plan_Config_Record_Waypoints_Record_List_30
     (D : in out Data; Pos : Natural; V : Flight_Plan_Config_Record_Waypoints_Record_List_30)
     with Pre => Pos <= Data_Size - 630
   is
   begin
      for I in 0 .. 29 loop
         pragma Loop_Invariant (Pos <= Data_Size - 630);
         Put_Flight_Plan_Config_Record_Waypoints_Record (D, Pos + I * 21, V (V'First + I));
      end loop;
   end Put_Flight_Plan_Config_Record_Waypoints_Record_List_30;

   procedure Get_Flight_Plan_Config_Record_Waypoints_Record_List_30
     (D : Data; Pos : Natural; V : in out Flight_Plan_Config_Record_Waypoints_Record_List_30)
     with Pre => Pos <= Data_Size - 630
   is
   begin
      for I in 0 .. 29 loop
         pragma Loop_Invariant (Pos <= Data_Size - 630);
         Get_Flight_Plan_Config_Record_Waypoints_Record (D, Pos + I * 21, V (V'First + I));
      end loop;
   end Get_Flight_Plan_Config_Record_Waypoints_Record_List_30;

   procedure Put_Flight_Plan_Config_Record (D : in out Data; Pos : Natural; V : Flight_Plan_Config_Record)
     with Pre => Pos <= Data_Size - 631
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Waypoint_Count);
      Put_Flight_Plan_Config_Record_Waypoints_Record_List_30 (D, Pos + 1, V.Waypoints);
   end Put_Flight_Plan_Config_Record;

   procedure Get_Flight_Plan_Config_Record (D : Data; Pos : Natural; V : in out Flight_Plan_Config_Record)
     with Pre => Pos <= Data_Size - 631
   is
   begin
      V.Waypoint_Count := Get_Unsigned_8 (D, Pos + 0);
      Get_Flight_Plan_Config_Record_Waypoints_Record_List_30 (D, Pos + 1, V.Waypoints);
   end Get_Flight_Plan_Config_Record;

   procedure Put_Gimbal_Track_Config_Record (D : in out Data; Pos : Natural; V : Gimbal_Track_Config_Record)
     with Pre => Pos <= Data_Size - 18
   is
   begin
      Put_Integer_8 (D, Pos + 0, V.Gimbal_Roll_Rc_Gain);
      Put_Integer_8 (D, Pos + 1, V.Gimbal_Pitch_Rc_Thr_Gain);
      Put_Integer_8 (D, Pos + 2, V.Gimbal_Pitch_Rc_Low_Gain);
      Put_Integer_8 (D, Pos + 3, V.Gimbal_Pitch_Rc_High_Gain);
      Put_Integer_8 (D, Pos + 4, V.Gimbal_Yaw_Rc_Gain);
      Put_Integer_8 (D, Pos + 5, V.Gimbal_Roll_Gain);
      Put_Integer_8 (D, Pos + 6, V.Gimbal_Roll_Offset);
      Put_Integer_8 (D, Pos + 7, V.Gimbal_Roll_Limit);
      Put_Integer_8 (D, Pos + 8, V.Gimbal_Pitch_Gain);
      Put_Integer_8 (D, Pos + 9, V.Gimbal_Pitch_Offset);
      Put_Integer_8 (D, Pos + 10, V.Gimbal_Pitch_Low_Limit);
      Put_Integer_8 (D, Pos + 11, V.Gimbal_Pitch_High_Limit);
      Put_Integer_8 (D, Pos + 12, V.Gimbal_Yaw_Gain);
      Put_Integer_8 (D, Pos + 13, V.Gimbal_Yaw_Offset);
      Put_Integer_8 (D, Pos + 14, V.Gimbal_Yaw_Limit);
      Put_Integer_8 (D, Pos + 15, V.Gimbal_Stabilisation);
      Put_Integer_8 (D, Pos + 16, V.Gimbal_Sensitivity);
      Put_Integer_8 (D, Pos + 17, V.Gimbal_Uart);
   end Put_Gimbal_Track_Config_Record;

   procedure Get_Gimbal_Track_Config_Record (D : Data; Pos : Natural; V : in out Gimbal_Track_Config_Record)
     with Pre => Pos <= Data_Size - 18
   is
   begin
      V.Gimbal_Roll_Rc_Gain := Get_Integer_8 (D, Pos + 0);
      V.Gimbal_Pitch_Rc_Thr_Gain := Get_Integer_8 (D, Pos + 1);
      V.Gimbal_Pitch_Rc_Low_Gain := Get_Integer_8 (D, Pos + 2);
      V.Gimbal_Pitch_Rc_High_Gain := Get_Integer_8 (D, Pos + 3);
      V.Gimbal_Yaw_Rc_Gain := Get_Integer_8 (D, Pos + 4);
      V.Gimbal_Roll_Gain := Get_Integer_8 (D, Pos + 5);
      V.Gimbal_Roll_Offset := Get_Integer_8 (D, Pos + 6);
      V.Gimbal_Roll_Limit := Get_Integer_8 (D, Pos + 7);
      V.Gimbal_Pitch_Gain := Get_Integer_8 (D, Pos + 8);
      V.Gimbal_Pitch_Offset := Get_Integer_8 (D, Pos + 9);
      V.Gimbal_Pitch_Low_Limit := Get_Integer_8 (D, Pos + 10);
      V.Gimbal_Pitch_High_Limit := Get_Integer_8 (D, Pos + 11);
      V.Gimbal_Yaw_Gain := Get_Integer_8 (D, Pos + 12);
      V.Gimbal_Yaw_Offset := Get_Integer_8 (D, Pos + 13);
      V.Gimbal_Yaw_Limit := Get_Integer_8 (D, Pos + 14);
      V.Gimbal_Stabilisation := Get_Integer_8 (D, Pos + 15);
      V.Gimbal_Sensitivity := Get_Integer_8 (D, Pos + 16);
      V.Gimbal_Uart := Get_Integer_8 (D, Pos + 17);
   end Get_Gimbal_Track_Config_Record;

   procedure Put_Gps_Lap_Timer_Config_Record (D : in out Data; Pos : Natural; V : Gps_Lap_Timer_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      Put_Integer_32 (D, Pos + 0, V.Gate_Lat);
      Put_Integer_32 (D, Pos + 4, V.Gate_Lon);
      Put_Unsigned_16 (D, Pos + 8, V.Minimum_Lap_Time_Seconds);
      Put_Unsigned_8 (D, Pos + 10, V.Gate_Tolerance_M);
   end Put_Gps_Lap_Timer_Config_Record;

   procedure Get_Gps_Lap_Timer_Config_Record (D : Data; Pos : Natural; V : in out Gps_Lap_Timer_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      V.Gate_Lat := Get_Integer_32 (D, Pos + 0);
      V.Gate_Lon := Get_Integer_32 (D, Pos + 4);
      V.Minimum_Lap_Time_Seconds := Get_Unsigned_16 (D, Pos + 8);
      V.Gate_Tolerance_M := Get_Unsigned_8 (D, Pos + 10);
   end Get_Gps_Lap_Timer_Config_Record;

   procedure Put_Bytes_65 (D : in out Data; Pos : Natural; V : Bytes_65)
     with Pre => Pos <= Data_Size - 65
   is
   begin
      for I in 0 .. 64 loop
         pragma Loop_Invariant (Pos <= Data_Size - 65);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_65;

   procedure Get_Bytes_65 (D : Data; Pos : Natural; V : in out Bytes_65)
     with Pre => Pos <= Data_Size - 65
   is
   begin
      for I in 0 .. 64 loop
         pragma Loop_Invariant (Pos <= Data_Size - 65);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_65;

   procedure Put_Gps_Config_Record (D : in out Data; Pos : Natural; V : Gps_Config_Record)
     with Pre => Pos <= Data_Size - 80
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Provider);
      Put_Unsigned_8 (D, Pos + 1, V.Sbas_Mode);
      Put_Unsigned_8 (D, Pos + 2, V.Auto_Config);
      Put_Unsigned_8 (D, Pos + 3, V.Auto_Baud);
      Put_Unsigned_8 (D, Pos + 4, V.Gps_Ublox_Acquire_Model);
      Put_Unsigned_8 (D, Pos + 5, V.Gps_Ublox_Flight_Model);
      Put_Unsigned_8 (D, Pos + 6, V.Gps_Update_Rate_Hz);
      Put_Boolean (D, Pos + 7, V.Gps_Ublox_Use_Galileo);
      Put_Boolean (D, Pos + 8, V.Gps_Set_Home_Point_Once);
      Put_Boolean (D, Pos + 9, V.Gps_Use_3d_Speed);
      Put_Boolean (D, Pos + 10, V.Sbas_Integrity);
      Put_Unsigned_8 (D, Pos + 11, V.Gps_Ublox_Utc_Standard);
      Put_Boolean (D, Pos + 12, V.Gps_Ublox_Enable_Ana);
      Put_Bytes_65 (D, Pos + 13, V.Nmea_Custom_Commands);
      Put_Integer_8 (D, Pos + 78, V.Gps_Uart);
      Put_Unsigned_8 (D, Pos + 79, V.Gps_Baud);
   end Put_Gps_Config_Record;

   procedure Get_Gps_Config_Record (D : Data; Pos : Natural; V : in out Gps_Config_Record)
     with Pre => Pos <= Data_Size - 80
   is
   begin
      V.Provider := Get_Unsigned_8 (D, Pos + 0);
      V.Sbas_Mode := Get_Unsigned_8 (D, Pos + 1);
      V.Auto_Config := Get_Unsigned_8 (D, Pos + 2);
      V.Auto_Baud := Get_Unsigned_8 (D, Pos + 3);
      V.Gps_Ublox_Acquire_Model := Get_Unsigned_8 (D, Pos + 4);
      V.Gps_Ublox_Flight_Model := Get_Unsigned_8 (D, Pos + 5);
      V.Gps_Update_Rate_Hz := Get_Unsigned_8 (D, Pos + 6);
      V.Gps_Ublox_Use_Galileo := Get_Boolean (D, Pos + 7);
      V.Gps_Set_Home_Point_Once := Get_Boolean (D, Pos + 8);
      V.Gps_Use_3d_Speed := Get_Boolean (D, Pos + 9);
      V.Sbas_Integrity := Get_Boolean (D, Pos + 10);
      V.Gps_Ublox_Utc_Standard := Get_Unsigned_8 (D, Pos + 11);
      V.Gps_Ublox_Enable_Ana := Get_Boolean (D, Pos + 12);
      Get_Bytes_65 (D, Pos + 13, V.Nmea_Custom_Commands);
      V.Gps_Uart := Get_Integer_8 (D, Pos + 78);
      V.Gps_Baud := Get_Unsigned_8 (D, Pos + 79);
   end Get_Gps_Config_Record;

   procedure Put_Gps_Rescue_Record (D : in out Data; Pos : Natural; V : Gps_Rescue_Record)
     with Pre => Pos <= Data_Size - 19
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Min_Start_Dist_M);
      Put_Unsigned_8 (D, Pos + 2, V.Altitude_Mode);
      Put_Unsigned_16 (D, Pos + 3, V.Initial_Climb_M);
      Put_Unsigned_16 (D, Pos + 5, V.Ascend_Rate);
      Put_Unsigned_16 (D, Pos + 7, V.Return_Altitude_M);
      Put_Unsigned_16 (D, Pos + 9, V.Ground_Speed_Cm_S);
      Put_Unsigned_16 (D, Pos + 11, V.Descent_Distance_M);
      Put_Unsigned_16 (D, Pos + 13, V.Descend_Rate);
      Put_Unsigned_8 (D, Pos + 15, V.Sanity_Checks);
      Put_Unsigned_8 (D, Pos + 16, V.Min_Sats);
      Put_Unsigned_8 (D, Pos + 17, V.Allow_Arming_Without_Fix);
      Put_Unsigned_8 (D, Pos + 18, V.Yaw_P);
   end Put_Gps_Rescue_Record;

   procedure Get_Gps_Rescue_Record (D : Data; Pos : Natural; V : in out Gps_Rescue_Record)
     with Pre => Pos <= Data_Size - 19
   is
   begin
      V.Min_Start_Dist_M := Get_Unsigned_16 (D, Pos + 0);
      V.Altitude_Mode := Get_Unsigned_8 (D, Pos + 2);
      V.Initial_Climb_M := Get_Unsigned_16 (D, Pos + 3);
      V.Ascend_Rate := Get_Unsigned_16 (D, Pos + 5);
      V.Return_Altitude_M := Get_Unsigned_16 (D, Pos + 7);
      V.Ground_Speed_Cm_S := Get_Unsigned_16 (D, Pos + 9);
      V.Descent_Distance_M := Get_Unsigned_16 (D, Pos + 11);
      V.Descend_Rate := Get_Unsigned_16 (D, Pos + 13);
      V.Sanity_Checks := Get_Unsigned_8 (D, Pos + 15);
      V.Min_Sats := Get_Unsigned_8 (D, Pos + 16);
      V.Allow_Arming_Without_Fix := Get_Unsigned_8 (D, Pos + 17);
      V.Yaw_P := Get_Unsigned_8 (D, Pos + 18);
   end Get_Gps_Rescue_Record;

   procedure Put_Integer_16_List_3 (D : in out Data; Pos : Natural; V : Integer_16_List_3)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 6);
         Put_Integer_16 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Integer_16_List_3;

   procedure Get_Integer_16_List_3 (D : Data; Pos : Natural; V : in out Integer_16_List_3)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 6);
         V (V'First + I) := Get_Integer_16 (D, Pos + I * 2);
      end loop;
   end Get_Integer_16_List_3;

   procedure Put_Gyro_Device_Config_Record (D : in out Data; Pos : Natural; V : Gyro_Device_Config_Record)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      Put_Integer_8 (D, Pos + 0, V.Index);
      Put_Unsigned_8 (D, Pos + 1, V.Bus_Type);
      Put_Unsigned_8 (D, Pos + 2, V.Spi_Bus);
      Put_Unsigned_8 (D, Pos + 3, V.Csn_Tag);
      Put_Unsigned_8 (D, Pos + 4, V.I2c_Bus);
      Put_Unsigned_8 (D, Pos + 5, V.I2c_Address);
      Put_Unsigned_8 (D, Pos + 6, V.Exti_Tag);
      Put_Unsigned_8 (D, Pos + 7, V.Alignment);
      Put_Integer_16_List_3 (D, Pos + 8, V.Custom_Alignment);
      Put_Unsigned_8 (D, Pos + 14, V.Clk_In);
   end Put_Gyro_Device_Config_Record;

   procedure Get_Gyro_Device_Config_Record (D : Data; Pos : Natural; V : in out Gyro_Device_Config_Record)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      V.Index := Get_Integer_8 (D, Pos + 0);
      V.Bus_Type := Get_Unsigned_8 (D, Pos + 1);
      V.Spi_Bus := Get_Unsigned_8 (D, Pos + 2);
      V.Csn_Tag := Get_Unsigned_8 (D, Pos + 3);
      V.I2c_Bus := Get_Unsigned_8 (D, Pos + 4);
      V.I2c_Address := Get_Unsigned_8 (D, Pos + 5);
      V.Exti_Tag := Get_Unsigned_8 (D, Pos + 6);
      V.Alignment := Get_Unsigned_8 (D, Pos + 7);
      Get_Integer_16_List_3 (D, Pos + 8, V.Custom_Alignment);
      V.Clk_In := Get_Unsigned_8 (D, Pos + 14);
   end Get_Gyro_Device_Config_Record;

   procedure Put_Gyro_Device_Config_Record_List_1 (D : in out Data; Pos : Natural; V : Gyro_Device_Config_Record_List_1)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      for I in 0 .. 0 loop
         pragma Loop_Invariant (Pos <= Data_Size - 15);
         Put_Gyro_Device_Config_Record (D, Pos + I * 15, V (V'First + I));
      end loop;
   end Put_Gyro_Device_Config_Record_List_1;

   procedure Get_Gyro_Device_Config_Record_List_1 (D : Data; Pos : Natural; V : in out Gyro_Device_Config_Record_List_1)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      for I in 0 .. 0 loop
         pragma Loop_Invariant (Pos <= Data_Size - 15);
         Get_Gyro_Device_Config_Record (D, Pos + I * 15, V (V'First + I));
      end loop;
   end Get_Gyro_Device_Config_Record_List_1;

   procedure Put_Max7456_Config_Record (D : in out Data; Pos : Natural; V : Max7456_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Clock_Config);
      Put_Unsigned_8 (D, Pos + 1, V.Cs_Tag);
      Put_Unsigned_8 (D, Pos + 2, V.Spi_Device);
      Put_Boolean (D, Pos + 3, V.Pre_Init_Opu);
   end Put_Max7456_Config_Record;

   procedure Get_Max7456_Config_Record (D : Data; Pos : Natural; V : in out Max7456_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Clock_Config := Get_Unsigned_8 (D, Pos + 0);
      V.Cs_Tag := Get_Unsigned_8 (D, Pos + 1);
      V.Spi_Device := Get_Unsigned_8 (D, Pos + 2);
      V.Pre_Init_Opu := Get_Boolean (D, Pos + 3);
   end Get_Max7456_Config_Record;

   procedure Put_Mco_Config_Record (D : in out Data; Pos : Natural; V : Mco_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Enabled);
      Put_Unsigned_8 (D, Pos + 1, V.Source);
      Put_Unsigned_8 (D, Pos + 2, V.Divider);
   end Put_Mco_Config_Record;

   procedure Get_Mco_Config_Record (D : Data; Pos : Natural; V : in out Mco_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Enabled := Get_Unsigned_8 (D, Pos + 0);
      V.Source := Get_Unsigned_8 (D, Pos + 1);
      V.Divider := Get_Unsigned_8 (D, Pos + 2);
   end Get_Mco_Config_Record;

   procedure Put_Mco_Config_Record_List_2 (D : in out Data; Pos : Natural; V : Mco_Config_Record_List_2)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      for I in 0 .. 1 loop
         pragma Loop_Invariant (Pos <= Data_Size - 6);
         Put_Mco_Config_Record (D, Pos + I * 3, V (V'First + I));
      end loop;
   end Put_Mco_Config_Record_List_2;

   procedure Get_Mco_Config_Record_List_2 (D : Data; Pos : Natural; V : in out Mco_Config_Record_List_2)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      for I in 0 .. 1 loop
         pragma Loop_Invariant (Pos <= Data_Size - 6);
         Get_Mco_Config_Record (D, Pos + I * 3, V (V'First + I));
      end loop;
   end Get_Mco_Config_Record_List_2;

   procedure Put_Motor_Dev_Config_Record (D : in out Data; Pos : Natural; V : Motor_Dev_Config_Record)
     with Pre => Pos <= Data_Size - 27
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Motor_Pwm_Rate);
      Put_Unsigned_8 (D, Pos + 2, V.Motor_Protocol);
      Put_Unsigned_8 (D, Pos + 3, V.Motor_Inversion);
      Put_Unsigned_8 (D, Pos + 4, V.Use_Continuous_Update);
      Put_Unsigned_8 (D, Pos + 5, V.Use_Burst_Dshot);
      Put_Unsigned_8 (D, Pos + 6, V.Use_Dshot_Telemetry);
      Put_Unsigned_8 (D, Pos + 7, V.Use_Dshot_Edt);
      Put_Bytes_8 (D, Pos + 8, V.Io_Tags);
      Put_Unsigned_8 (D, Pos + 16, V.Motor_Transport_Protocol);
      Put_Unsigned_8 (D, Pos + 17, V.Use_Dshot_Bitbang);
      Put_Unsigned_8 (D, Pos + 18, V.Use_Dshot_Bitbanged_Timer);
      Put_Bytes_8 (D, Pos + 19, V.Motor_Output_Reordering);
   end Put_Motor_Dev_Config_Record;

   procedure Get_Motor_Dev_Config_Record (D : Data; Pos : Natural; V : in out Motor_Dev_Config_Record)
     with Pre => Pos <= Data_Size - 27
   is
   begin
      V.Motor_Pwm_Rate := Get_Unsigned_16 (D, Pos + 0);
      V.Motor_Protocol := Get_Unsigned_8 (D, Pos + 2);
      V.Motor_Inversion := Get_Unsigned_8 (D, Pos + 3);
      V.Use_Continuous_Update := Get_Unsigned_8 (D, Pos + 4);
      V.Use_Burst_Dshot := Get_Unsigned_8 (D, Pos + 5);
      V.Use_Dshot_Telemetry := Get_Unsigned_8 (D, Pos + 6);
      V.Use_Dshot_Edt := Get_Unsigned_8 (D, Pos + 7);
      Get_Bytes_8 (D, Pos + 8, V.Io_Tags);
      V.Motor_Transport_Protocol := Get_Unsigned_8 (D, Pos + 16);
      V.Use_Dshot_Bitbang := Get_Unsigned_8 (D, Pos + 17);
      V.Use_Dshot_Bitbanged_Timer := Get_Unsigned_8 (D, Pos + 18);
      Get_Bytes_8 (D, Pos + 19, V.Motor_Output_Reordering);
   end Get_Motor_Dev_Config_Record;

   procedure Put_Motor_Config_Record (D : in out Data; Pos : Natural; V : Motor_Config_Record)
     with Pre => Pos <= Data_Size - 36
   is
   begin
      Put_Motor_Dev_Config_Record (D, Pos + 0, V.Dev);
      Put_Unsigned_16 (D, Pos + 27, V.Motor_Idle);
      Put_Unsigned_16 (D, Pos + 29, V.Maxthrottle);
      Put_Unsigned_16 (D, Pos + 31, V.Mincommand);
      Put_Unsigned_16 (D, Pos + 33, V.Kv);
      Put_Unsigned_8 (D, Pos + 35, V.Motor_Pole_Count);
   end Put_Motor_Config_Record;

   procedure Get_Motor_Config_Record (D : Data; Pos : Natural; V : in out Motor_Config_Record)
     with Pre => Pos <= Data_Size - 36
   is
   begin
      Get_Motor_Dev_Config_Record (D, Pos + 0, V.Dev);
      V.Motor_Idle := Get_Unsigned_16 (D, Pos + 27);
      V.Maxthrottle := Get_Unsigned_16 (D, Pos + 29);
      V.Mincommand := Get_Unsigned_16 (D, Pos + 31);
      V.Kv := Get_Unsigned_16 (D, Pos + 33);
      V.Motor_Pole_Count := Get_Unsigned_8 (D, Pos + 35);
   end Get_Motor_Config_Record;

   procedure Put_Integer_8_List_3 (D : in out Data; Pos : Natural; V : Integer_8_List_3)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 3);
         Put_Integer_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Integer_8_List_3;

   procedure Get_Integer_8_List_3 (D : Data; Pos : Natural; V : in out Integer_8_List_3)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 3);
         V (V'First + I) := Get_Integer_8 (D, Pos + I * 1);
      end loop;
   end Get_Integer_8_List_3;

   procedure Put_Msp_Config_Record (D : in out Data; Pos : Natural; V : Msp_Config_Record)
     with Pre => Pos <= Data_Size - 7
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Half_Duplex);
      Put_Integer_8_List_3 (D, Pos + 1, V.Msp_Uart);
      Put_Bytes_3 (D, Pos + 4, V.Msp_Baud);
   end Put_Msp_Config_Record;

   procedure Get_Msp_Config_Record (D : Data; Pos : Natural; V : in out Msp_Config_Record)
     with Pre => Pos <= Data_Size - 7
   is
   begin
      V.Half_Duplex := Get_Unsigned_8 (D, Pos + 0);
      Get_Integer_8_List_3 (D, Pos + 1, V.Msp_Uart);
      Get_Bytes_3 (D, Pos + 4, V.Msp_Baud);
   end Get_Msp_Config_Record;

   procedure Put_Osd_Nav_Map_Config_Record (D : in out Data; Pos : Natural; V : Osd_Nav_Map_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Mode);
      Put_Unsigned_8 (D, Pos + 1, V.Centre);
      Put_Unsigned_16 (D, Pos + 2, V.Min_Scale_M);
   end Put_Osd_Nav_Map_Config_Record;

   procedure Get_Osd_Nav_Map_Config_Record (D : Data; Pos : Natural; V : in out Osd_Nav_Map_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Mode := Get_Unsigned_8 (D, Pos + 0);
      V.Centre := Get_Unsigned_8 (D, Pos + 1);
      V.Min_Scale_M := Get_Unsigned_16 (D, Pos + 2);
   end Get_Osd_Nav_Map_Config_Record;

   procedure Put_Bytes_17_List_4 (D : in out Data; Pos : Natural; V : Bytes_17_List_4)
     with Pre => Pos <= Data_Size - 68
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 68);
         Put_Bytes_17 (D, Pos + I * 17, V (V'First + I));
      end loop;
   end Put_Bytes_17_List_4;

   procedure Get_Bytes_17_List_4 (D : Data; Pos : Natural; V : in out Bytes_17_List_4)
     with Pre => Pos <= Data_Size - 68
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 68);
         Get_Bytes_17 (D, Pos + I * 17, V (V'First + I));
      end loop;
   end Get_Bytes_17_List_4;

   procedure Put_Pilot_Config_Record (D : in out Data; Pos : Natural; V : Pilot_Config_Record)
     with Pre => Pos <= Data_Size - 102
   is
   begin
      Put_Bytes_17 (D, Pos + 0, V.Craft_Name);
      Put_Bytes_17 (D, Pos + 17, V.Pilot_Name);
      Put_Bytes_17_List_4 (D, Pos + 34, V.Message);
   end Put_Pilot_Config_Record;

   procedure Get_Pilot_Config_Record (D : Data; Pos : Natural; V : in out Pilot_Config_Record)
     with Pre => Pos <= Data_Size - 102
   is
   begin
      Get_Bytes_17 (D, Pos + 0, V.Craft_Name);
      Get_Bytes_17 (D, Pos + 17, V.Pilot_Name);
      Get_Bytes_17_List_4 (D, Pos + 34, V.Message);
   end Get_Pilot_Config_Record;

   procedure Put_Pinio_Box_Config_Record (D : in out Data; Pos : Natural; V : Pinio_Box_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Bytes_4 (D, Pos + 0, V.Permanent_Id);
   end Put_Pinio_Box_Config_Record;

   procedure Get_Pinio_Box_Config_Record (D : Data; Pos : Natural; V : in out Pinio_Box_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Get_Bytes_4 (D, Pos + 0, V.Permanent_Id);
   end Get_Pinio_Box_Config_Record;

   procedure Put_Pinio_Config_Record (D : in out Data; Pos : Natural; V : Pinio_Config_Record)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      Put_Bytes_4 (D, Pos + 0, V.Io_Tag);
      Put_Bytes_4 (D, Pos + 4, V.Config);
   end Put_Pinio_Config_Record;

   procedure Get_Pinio_Config_Record (D : Data; Pos : Natural; V : in out Pinio_Config_Record)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      Get_Bytes_4 (D, Pos + 0, V.Io_Tag);
      Get_Bytes_4 (D, Pos + 4, V.Config);
   end Get_Pinio_Config_Record;

   procedure Put_Pin_Pull_Up_Down_Config_Record (D : in out Data; Pos : Natural; V : Pin_Pull_Up_Down_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Io_Tag);
   end Put_Pin_Pull_Up_Down_Config_Record;

   procedure Get_Pin_Pull_Up_Down_Config_Record (D : Data; Pos : Natural; V : in out Pin_Pull_Up_Down_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      V.Io_Tag := Get_Unsigned_8 (D, Pos + 0);
   end Get_Pin_Pull_Up_Down_Config_Record;

   procedure Put_Pin_Pull_Up_Down_Config_Record_List_4
     (D : in out Data; Pos : Natural; V : Pin_Pull_Up_Down_Config_Record_List_4)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         Put_Pin_Pull_Up_Down_Config_Record (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Pin_Pull_Up_Down_Config_Record_List_4;

   procedure Get_Pin_Pull_Up_Down_Config_Record_List_4
     (D : Data; Pos : Natural; V : in out Pin_Pull_Up_Down_Config_Record_List_4)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         Get_Pin_Pull_Up_Down_Config_Record (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Get_Pin_Pull_Up_Down_Config_Record_List_4;

   procedure Put_Pos_Hold_Config_Record (D : in out Data; Pos : Natural; V : Pos_Hold_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Deadband);
      Put_Unsigned_8 (D, Pos + 1, V.Position_Source);
      Put_Unsigned_8 (D, Pos + 2, V.Opticalflow_Quality_Min);
      Put_Unsigned_16 (D, Pos + 3, V.Opticalflow_Max_Range);
   end Put_Pos_Hold_Config_Record;

   procedure Get_Pos_Hold_Config_Record (D : Data; Pos : Natural; V : in out Pos_Hold_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Deadband := Get_Unsigned_8 (D, Pos + 0);
      V.Position_Source := Get_Unsigned_8 (D, Pos + 1);
      V.Opticalflow_Quality_Min := Get_Unsigned_8 (D, Pos + 2);
      V.Opticalflow_Max_Range := Get_Unsigned_16 (D, Pos + 3);
   end Get_Pos_Hold_Config_Record;

   procedure Put_Rcdevice_Config_Record (D : in out Data; Pos : Natural; V : Rcdevice_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Init_Device_Attempts);
      Put_Unsigned_32 (D, Pos + 1, V.Init_Device_Attempt_Interval);
      Put_Unsigned_32 (D, Pos + 5, V.Feature);
      Put_Unsigned_8 (D, Pos + 9, V.Protocol_Version);
      Put_Integer_8 (D, Pos + 10, V.Rcdevice_Uart);
   end Put_Rcdevice_Config_Record;

   procedure Get_Rcdevice_Config_Record (D : Data; Pos : Natural; V : in out Rcdevice_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      V.Init_Device_Attempts := Get_Unsigned_8 (D, Pos + 0);
      V.Init_Device_Attempt_Interval := Get_Unsigned_32 (D, Pos + 1);
      V.Feature := Get_Unsigned_32 (D, Pos + 5);
      V.Protocol_Version := Get_Unsigned_8 (D, Pos + 9);
      V.Rcdevice_Uart := Get_Integer_8 (D, Pos + 10);
   end Get_Rcdevice_Config_Record;

   procedure Put_Rpm_Filter_Config_Record (D : in out Data; Pos : Natural; V : Rpm_Filter_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Rpm_Filter_Harmonics);
      Put_Bytes_3 (D, Pos + 1, V.Rpm_Filter_Weights);
      Put_Unsigned_8 (D, Pos + 4, V.Rpm_Filter_Min_Hz);
      Put_Unsigned_16 (D, Pos + 5, V.Rpm_Filter_Fade_Range_Hz);
      Put_Unsigned_16 (D, Pos + 7, V.Rpm_Filter_Q);
      Put_Unsigned_16 (D, Pos + 9, V.Rpm_Filter_Lpf_Hz);
   end Put_Rpm_Filter_Config_Record;

   procedure Get_Rpm_Filter_Config_Record (D : Data; Pos : Natural; V : in out Rpm_Filter_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      V.Rpm_Filter_Harmonics := Get_Unsigned_8 (D, Pos + 0);
      Get_Bytes_3 (D, Pos + 1, V.Rpm_Filter_Weights);
      V.Rpm_Filter_Min_Hz := Get_Unsigned_8 (D, Pos + 4);
      V.Rpm_Filter_Fade_Range_Hz := Get_Unsigned_16 (D, Pos + 5);
      V.Rpm_Filter_Q := Get_Unsigned_16 (D, Pos + 7);
      V.Rpm_Filter_Lpf_Hz := Get_Unsigned_16 (D, Pos + 9);
   end Get_Rpm_Filter_Config_Record;

   procedure Put_Rx_Config_Record (D : in out Data; Pos : Natural; V : Rx_Config_Record)
     with Pre => Pos <= Data_Size - 51
   is
   begin
      Put_Bytes_8 (D, Pos + 0, V.Rcmap);
      Put_Unsigned_8 (D, Pos + 8, V.Serialrx_Provider);
      Put_Unsigned_8 (D, Pos + 9, V.Serialrx_Inverted);
      Put_Unsigned_8 (D, Pos + 10, V.Half_Duplex);
      Put_Unsigned_8 (D, Pos + 11, V.Spektrum_Bind_Pin_Override_Io_Tag);
      Put_Unsigned_8 (D, Pos + 12, V.Spektrum_Bind_Plug_Io_Tag);
      Put_Unsigned_8 (D, Pos + 13, V.Spektrum_Sat_Bind);
      Put_Unsigned_8 (D, Pos + 14, V.Spektrum_Sat_Bind_Autoreset);
      Put_Unsigned_8 (D, Pos + 15, V.Rssi_Channel);
      Put_Unsigned_8 (D, Pos + 16, V.Rssi_Scale);
      Put_Unsigned_8 (D, Pos + 17, V.Rssi_Invert);
      Put_Unsigned_16 (D, Pos + 18, V.Midrc);
      Put_Unsigned_16 (D, Pos + 20, V.Mincheck);
      Put_Unsigned_16 (D, Pos + 22, V.Maxcheck);
      Put_Unsigned_8 (D, Pos + 24, V.Fpv_Cam_Angle_Degrees);
      Put_Unsigned_8 (D, Pos + 25, V.Air_Mode_Activate_Threshold);
      Put_Unsigned_16 (D, Pos + 26, V.Rx_Min_Usec);
      Put_Unsigned_16 (D, Pos + 28, V.Rx_Max_Usec);
      Put_Unsigned_8 (D, Pos + 30, V.Max_Aux_Channel);
      Put_Unsigned_8 (D, Pos + 31, V.Rssi_Src_Frame_Errors);
      Put_Integer_8 (D, Pos + 32, V.Rssi_Offset);
      Put_Unsigned_8 (D, Pos + 33, V.Rc_Smoothing);
      Put_Unsigned_8 (D, Pos + 34, V.Rc_Smoothing_Setpoint_Cutoff);
      Put_Unsigned_8 (D, Pos + 35, V.Rc_Smoothing_Throttle_Cutoff);
      Put_Unsigned_8 (D, Pos + 36, V.Rc_Smoothing_Debug_Axis);
      Put_Unsigned_8 (D, Pos + 37, V.Rc_Smoothing_Auto_Factor_Rpy);
      Put_Unsigned_8 (D, Pos + 38, V.Rc_Smoothing_Auto_Factor_Throttle);
      Put_Unsigned_8 (D, Pos + 39, V.Rssi_Src_Frame_Lpf_Period);
      Put_Unsigned_8 (D, Pos + 40, V.Rssi_Smoothing);
      Put_Unsigned_8 (D, Pos + 41, V.Srxl2_Unit_Id);
      Put_Unsigned_8 (D, Pos + 42, V.Srxl2_Baud_Fast);
      Put_Unsigned_8 (D, Pos + 43, V.Sbus_Baud_Fast);
      Put_Unsigned_32 (D, Pos + 44, V.Msp_Override_Channels_Mask);
      Put_Unsigned_8 (D, Pos + 48, V.Msp_Override_Failsafe);
      Put_Unsigned_8 (D, Pos + 49, V.Crsf_Use_Negotiated_Baud);
      Put_Integer_8 (D, Pos + 50, V.Rx_Uart);
   end Put_Rx_Config_Record;

   procedure Get_Rx_Config_Record (D : Data; Pos : Natural; V : in out Rx_Config_Record)
     with Pre => Pos <= Data_Size - 51
   is
   begin
      Get_Bytes_8 (D, Pos + 0, V.Rcmap);
      V.Serialrx_Provider := Get_Unsigned_8 (D, Pos + 8);
      V.Serialrx_Inverted := Get_Unsigned_8 (D, Pos + 9);
      V.Half_Duplex := Get_Unsigned_8 (D, Pos + 10);
      V.Spektrum_Bind_Pin_Override_Io_Tag := Get_Unsigned_8 (D, Pos + 11);
      V.Spektrum_Bind_Plug_Io_Tag := Get_Unsigned_8 (D, Pos + 12);
      V.Spektrum_Sat_Bind := Get_Unsigned_8 (D, Pos + 13);
      V.Spektrum_Sat_Bind_Autoreset := Get_Unsigned_8 (D, Pos + 14);
      V.Rssi_Channel := Get_Unsigned_8 (D, Pos + 15);
      V.Rssi_Scale := Get_Unsigned_8 (D, Pos + 16);
      V.Rssi_Invert := Get_Unsigned_8 (D, Pos + 17);
      V.Midrc := Get_Unsigned_16 (D, Pos + 18);
      V.Mincheck := Get_Unsigned_16 (D, Pos + 20);
      V.Maxcheck := Get_Unsigned_16 (D, Pos + 22);
      V.Fpv_Cam_Angle_Degrees := Get_Unsigned_8 (D, Pos + 24);
      V.Air_Mode_Activate_Threshold := Get_Unsigned_8 (D, Pos + 25);
      V.Rx_Min_Usec := Get_Unsigned_16 (D, Pos + 26);
      V.Rx_Max_Usec := Get_Unsigned_16 (D, Pos + 28);
      V.Max_Aux_Channel := Get_Unsigned_8 (D, Pos + 30);
      V.Rssi_Src_Frame_Errors := Get_Unsigned_8 (D, Pos + 31);
      V.Rssi_Offset := Get_Integer_8 (D, Pos + 32);
      V.Rc_Smoothing := Get_Unsigned_8 (D, Pos + 33);
      V.Rc_Smoothing_Setpoint_Cutoff := Get_Unsigned_8 (D, Pos + 34);
      V.Rc_Smoothing_Throttle_Cutoff := Get_Unsigned_8 (D, Pos + 35);
      V.Rc_Smoothing_Debug_Axis := Get_Unsigned_8 (D, Pos + 36);
      V.Rc_Smoothing_Auto_Factor_Rpy := Get_Unsigned_8 (D, Pos + 37);
      V.Rc_Smoothing_Auto_Factor_Throttle := Get_Unsigned_8 (D, Pos + 38);
      V.Rssi_Src_Frame_Lpf_Period := Get_Unsigned_8 (D, Pos + 39);
      V.Rssi_Smoothing := Get_Unsigned_8 (D, Pos + 40);
      V.Srxl2_Unit_Id := Get_Unsigned_8 (D, Pos + 41);
      V.Srxl2_Baud_Fast := Get_Unsigned_8 (D, Pos + 42);
      V.Sbus_Baud_Fast := Get_Unsigned_8 (D, Pos + 43);
      V.Msp_Override_Channels_Mask := Get_Unsigned_32 (D, Pos + 44);
      V.Msp_Override_Failsafe := Get_Unsigned_8 (D, Pos + 48);
      V.Crsf_Use_Negotiated_Baud := Get_Unsigned_8 (D, Pos + 49);
      V.Rx_Uart := Get_Integer_8 (D, Pos + 50);
   end Get_Rx_Config_Record;

   procedure Put_Pwm_Config_Record (D : in out Data; Pos : Natural; V : Pwm_Config_Record)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      Put_Bytes_8 (D, Pos + 0, V.Io_Tags);
      Put_Unsigned_8 (D, Pos + 8, V.Input_Filtering_Mode);
   end Put_Pwm_Config_Record;

   procedure Get_Pwm_Config_Record (D : Data; Pos : Natural; V : in out Pwm_Config_Record)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      Get_Bytes_8 (D, Pos + 0, V.Io_Tags);
      V.Input_Filtering_Mode := Get_Unsigned_8 (D, Pos + 8);
   end Get_Pwm_Config_Record;

   procedure Put_Ppm_Config_Record (D : in out Data; Pos : Natural; V : Ppm_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Io_Tag);
   end Put_Ppm_Config_Record;

   procedure Get_Ppm_Config_Record (D : Data; Pos : Natural; V : in out Ppm_Config_Record)
     with Pre => Pos <= Data_Size - 1
   is
   begin
      V.Io_Tag := Get_Unsigned_8 (D, Pos + 0);
   end Get_Ppm_Config_Record;

   procedure Put_Bytes_50 (D : in out Data; Pos : Natural; V : Bytes_50)
     with Pre => Pos <= Data_Size - 50
   is
   begin
      for I in 0 .. 49 loop
         pragma Loop_Invariant (Pos <= Data_Size - 50);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_50;

   procedure Get_Bytes_50 (D : Data; Pos : Natural; V : in out Bytes_50)
     with Pre => Pos <= Data_Size - 50
   is
   begin
      for I in 0 .. 49 loop
         pragma Loop_Invariant (Pos <= Data_Size - 50);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_50;

   procedure Put_Rx_Cc2500_Spi_Config_Record (D : in out Data; Pos : Natural; V : Rx_Cc2500_Spi_Config_Record)
     with Pre => Pos <= Data_Size - 61
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Auto_Bind);
      Put_Bytes_3 (D, Pos + 1, V.Bind_Tx_Id);
      Put_Integer_8 (D, Pos + 4, V.Bind_Offset);
      Put_Bytes_50 (D, Pos + 5, V.Bind_Hop_Data);
      Put_Unsigned_8 (D, Pos + 55, V.Rx_Num);
      Put_Unsigned_8 (D, Pos + 56, V.A1_Source);
      Put_Unsigned_8 (D, Pos + 57, V.Chip_Detect_Enabled);
      Put_Unsigned_8 (D, Pos + 58, V.Tx_En_Io_Tag);
      Put_Unsigned_8 (D, Pos + 59, V.Lna_En_Io_Tag);
      Put_Unsigned_8 (D, Pos + 60, V.Ant_Sel_Io_Tag);
   end Put_Rx_Cc2500_Spi_Config_Record;

   procedure Get_Rx_Cc2500_Spi_Config_Record (D : Data; Pos : Natural; V : in out Rx_Cc2500_Spi_Config_Record)
     with Pre => Pos <= Data_Size - 61
   is
   begin
      V.Auto_Bind := Get_Unsigned_8 (D, Pos + 0);
      Get_Bytes_3 (D, Pos + 1, V.Bind_Tx_Id);
      V.Bind_Offset := Get_Integer_8 (D, Pos + 4);
      Get_Bytes_50 (D, Pos + 5, V.Bind_Hop_Data);
      V.Rx_Num := Get_Unsigned_8 (D, Pos + 55);
      V.A1_Source := Get_Unsigned_8 (D, Pos + 56);
      V.Chip_Detect_Enabled := Get_Unsigned_8 (D, Pos + 57);
      V.Tx_En_Io_Tag := Get_Unsigned_8 (D, Pos + 58);
      V.Lna_En_Io_Tag := Get_Unsigned_8 (D, Pos + 59);
      V.Ant_Sel_Io_Tag := Get_Unsigned_8 (D, Pos + 60);
   end Get_Rx_Cc2500_Spi_Config_Record;

   procedure Put_Rx_Express_Lrs_Spi_Config_Record (D : in out Data; Pos : Natural; V : Rx_Express_Lrs_Spi_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Reset_Io_Tag);
      Put_Unsigned_8 (D, Pos + 1, V.Busy_Io_Tag);
      Put_Bytes_6 (D, Pos + 2, V.Uid);
      Put_Unsigned_8 (D, Pos + 8, V.Domain);
      Put_Unsigned_8 (D, Pos + 9, V.Rate_Index);
      Put_Unsigned_8 (D, Pos + 10, V.Model_Id);
   end Put_Rx_Express_Lrs_Spi_Config_Record;

   procedure Get_Rx_Express_Lrs_Spi_Config_Record (D : Data; Pos : Natural; V : in out Rx_Express_Lrs_Spi_Config_Record)
     with Pre => Pos <= Data_Size - 11
   is
   begin
      V.Reset_Io_Tag := Get_Unsigned_8 (D, Pos + 0);
      V.Busy_Io_Tag := Get_Unsigned_8 (D, Pos + 1);
      Get_Bytes_6 (D, Pos + 2, V.Uid);
      V.Domain := Get_Unsigned_8 (D, Pos + 8);
      V.Rate_Index := Get_Unsigned_8 (D, Pos + 9);
      V.Model_Id := Get_Unsigned_8 (D, Pos + 10);
   end Get_Rx_Express_Lrs_Spi_Config_Record;

   procedure Put_Rx_Spi_Config_Record (D : in out Data; Pos : Natural; V : Rx_Spi_Config_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Rx_Spi_Protocol);
      Put_Unsigned_32 (D, Pos + 1, V.Rx_Spi_Id);
      Put_Unsigned_8 (D, Pos + 5, V.Rx_Spi_Rf_Channel_Count);
      Put_Unsigned_8 (D, Pos + 6, V.Csn_Tag);
      Put_Unsigned_8 (D, Pos + 7, V.Spibus);
      Put_Unsigned_8 (D, Pos + 8, V.Bind_Io_Tag);
      Put_Unsigned_8 (D, Pos + 9, V.Led_Io_Tag);
      Put_Unsigned_8 (D, Pos + 10, V.Led_Inversion);
      Put_Unsigned_8 (D, Pos + 11, V.Exti_Io_Tag);
   end Put_Rx_Spi_Config_Record;

   procedure Get_Rx_Spi_Config_Record (D : Data; Pos : Natural; V : in out Rx_Spi_Config_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      V.Rx_Spi_Protocol := Get_Unsigned_8 (D, Pos + 0);
      V.Rx_Spi_Id := Get_Unsigned_32 (D, Pos + 1);
      V.Rx_Spi_Rf_Channel_Count := Get_Unsigned_8 (D, Pos + 5);
      V.Csn_Tag := Get_Unsigned_8 (D, Pos + 6);
      V.Spibus := Get_Unsigned_8 (D, Pos + 7);
      V.Bind_Io_Tag := Get_Unsigned_8 (D, Pos + 8);
      V.Led_Io_Tag := Get_Unsigned_8 (D, Pos + 9);
      V.Led_Inversion := Get_Unsigned_8 (D, Pos + 10);
      V.Exti_Io_Tag := Get_Unsigned_8 (D, Pos + 11);
   end Get_Rx_Spi_Config_Record;

   procedure Put_Scheduler_Config_Record (D : in out Data; Pos : Natural; V : Scheduler_Config_Record)
     with Pre => Pos <= Data_Size - 7
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Rx_Relax_Determinism);
      Put_Unsigned_16 (D, Pos + 2, V.Osd_Relax_Determinism);
      Put_Unsigned_16 (D, Pos + 4, V.Cpu_Late_Percentage_Limit);
      Put_Unsigned_8 (D, Pos + 6, V.Debug_Task);
   end Put_Scheduler_Config_Record;

   procedure Get_Scheduler_Config_Record (D : Data; Pos : Natural; V : in out Scheduler_Config_Record)
     with Pre => Pos <= Data_Size - 7
   is
   begin
      V.Rx_Relax_Determinism := Get_Unsigned_16 (D, Pos + 0);
      V.Osd_Relax_Determinism := Get_Unsigned_16 (D, Pos + 2);
      V.Cpu_Late_Percentage_Limit := Get_Unsigned_16 (D, Pos + 4);
      V.Debug_Task := Get_Unsigned_8 (D, Pos + 6);
   end Get_Scheduler_Config_Record;

   procedure Put_Sdcard_Config_Record (D : in out Data; Pos : Natural; V : Sdcard_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Integer_8 (D, Pos + 0, V.Device);
      Put_Unsigned_8 (D, Pos + 1, V.Card_Detect_Tag);
      Put_Unsigned_8 (D, Pos + 2, V.Chip_Select_Tag);
      Put_Unsigned_8 (D, Pos + 3, V.Card_Detect_Inverted);
      Put_Unsigned_8 (D, Pos + 4, V.Mode);
   end Put_Sdcard_Config_Record;

   procedure Get_Sdcard_Config_Record (D : Data; Pos : Natural; V : in out Sdcard_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Device := Get_Integer_8 (D, Pos + 0);
      V.Card_Detect_Tag := Get_Unsigned_8 (D, Pos + 1);
      V.Chip_Select_Tag := Get_Unsigned_8 (D, Pos + 2);
      V.Card_Detect_Inverted := Get_Unsigned_8 (D, Pos + 3);
      V.Mode := Get_Unsigned_8 (D, Pos + 4);
   end Get_Sdcard_Config_Record;

   procedure Put_Serial_Uart_Config_Record (D : in out Data; Pos : Natural; V : Serial_Uart_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      Put_Integer_8 (D, Pos + 0, V.Tx_Dmaopt);
      Put_Integer_8 (D, Pos + 1, V.Rx_Dmaopt);
   end Put_Serial_Uart_Config_Record;

   procedure Get_Serial_Uart_Config_Record (D : Data; Pos : Natural; V : in out Serial_Uart_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      V.Tx_Dmaopt := Get_Integer_8 (D, Pos + 0);
      V.Rx_Dmaopt := Get_Integer_8 (D, Pos + 1);
   end Get_Serial_Uart_Config_Record;

   procedure Put_Serial_Uart_Config_Record_List_6 (D : in out Data; Pos : Natural; V : Serial_Uart_Config_Record_List_6)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      for I in 0 .. 5 loop
         pragma Loop_Invariant (Pos <= Data_Size - 12);
         Put_Serial_Uart_Config_Record (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Serial_Uart_Config_Record_List_6;

   procedure Get_Serial_Uart_Config_Record_List_6 (D : Data; Pos : Natural; V : in out Serial_Uart_Config_Record_List_6)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      for I in 0 .. 5 loop
         pragma Loop_Invariant (Pos <= Data_Size - 12);
         Get_Serial_Uart_Config_Record (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Get_Serial_Uart_Config_Record_List_6;

   procedure Put_Stats_Config_Record (D : in out Data; Pos : Natural; V : Stats_Config_Record)
     with Pre => Pos <= Data_Size - 18
   is
   begin
      Put_Unsigned_32 (D, Pos + 0, V.Stats_Total_Flights);
      Put_Unsigned_32 (D, Pos + 4, V.Stats_Total_Time_S);
      Put_Unsigned_32 (D, Pos + 8, V.Stats_Total_Dist_M);
      Put_Integer_8 (D, Pos + 12, V.Stats_Min_Armed_Time_S);
      Put_Unsigned_32 (D, Pos + 13, V.Stats_Mah_Used);
      Put_Unsigned_8 (D, Pos + 17, V.Stats_Save_Move_Limit);
   end Put_Stats_Config_Record;

   procedure Get_Stats_Config_Record (D : Data; Pos : Natural; V : in out Stats_Config_Record)
     with Pre => Pos <= Data_Size - 18
   is
   begin
      V.Stats_Total_Flights := Get_Unsigned_32 (D, Pos + 0);
      V.Stats_Total_Time_S := Get_Unsigned_32 (D, Pos + 4);
      V.Stats_Total_Dist_M := Get_Unsigned_32 (D, Pos + 8);
      V.Stats_Min_Armed_Time_S := Get_Integer_8 (D, Pos + 12);
      V.Stats_Mah_Used := Get_Unsigned_32 (D, Pos + 13);
      V.Stats_Save_Move_Limit := Get_Unsigned_8 (D, Pos + 17);
   end Get_Stats_Config_Record;

   procedure Put_Usb_Dev_Record (D : in out Data; Pos : Natural; V : Usb_Dev_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Type_Value);
      Put_Unsigned_8 (D, Pos + 1, V.Msc_Button_Pin);
      Put_Unsigned_8 (D, Pos + 2, V.Msc_Button_Use_Pullup);
      Put_Unsigned_8 (D, Pos + 3, V.Detect_Pin);
   end Put_Usb_Dev_Record;

   procedure Get_Usb_Dev_Record (D : Data; Pos : Natural; V : in out Usb_Dev_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Type_Value := Get_Unsigned_8 (D, Pos + 0);
      V.Msc_Button_Pin := Get_Unsigned_8 (D, Pos + 1);
      V.Msc_Button_Use_Pullup := Get_Unsigned_8 (D, Pos + 2);
      V.Detect_Pin := Get_Unsigned_8 (D, Pos + 3);
   end Get_Usb_Dev_Record;

   procedure Put_Vcd_Profile_Record (D : in out Data; Pos : Natural; V : Vcd_Profile_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Video_System);
      Put_Integer_8 (D, Pos + 1, V.H_Offset);
      Put_Integer_8 (D, Pos + 2, V.V_Offset);
   end Put_Vcd_Profile_Record;

   procedure Get_Vcd_Profile_Record (D : Data; Pos : Natural; V : in out Vcd_Profile_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Video_System := Get_Unsigned_8 (D, Pos + 0);
      V.H_Offset := Get_Integer_8 (D, Pos + 1);
      V.V_Offset := Get_Integer_8 (D, Pos + 2);
   end Get_Vcd_Profile_Record;

   procedure Put_Vtx_Io_Config_Record (D : in out Data; Pos : Natural; V : Vtx_Io_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Cs_Tag);
      Put_Unsigned_8 (D, Pos + 1, V.Power_Tag);
      Put_Unsigned_8 (D, Pos + 2, V.Data_Tag);
      Put_Unsigned_8 (D, Pos + 3, V.Clock_Tag);
      Put_Unsigned_8 (D, Pos + 4, V.Spi_Device);
   end Put_Vtx_Io_Config_Record;

   procedure Get_Vtx_Io_Config_Record (D : Data; Pos : Natural; V : in out Vtx_Io_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Cs_Tag := Get_Unsigned_8 (D, Pos + 0);
      V.Power_Tag := Get_Unsigned_8 (D, Pos + 1);
      V.Data_Tag := Get_Unsigned_8 (D, Pos + 2);
      V.Clock_Tag := Get_Unsigned_8 (D, Pos + 3);
      V.Spi_Device := Get_Unsigned_8 (D, Pos + 4);
   end Get_Vtx_Io_Config_Record;

   procedure Put_Unsigned_16_List_8 (D : in out Data; Pos : Natural; V : Unsigned_16_List_8)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 16);
         Put_Unsigned_16 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Unsigned_16_List_8;

   procedure Get_Unsigned_16_List_8 (D : Data; Pos : Natural; V : in out Unsigned_16_List_8)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 16);
         V (V'First + I) := Get_Unsigned_16 (D, Pos + I * 2);
      end loop;
   end Get_Unsigned_16_List_8;

   procedure Put_Unsigned_16_List_8_List_8 (D : in out Data; Pos : Natural; V : Unsigned_16_List_8_List_8)
     with Pre => Pos <= Data_Size - 128
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 128);
         Put_Unsigned_16_List_8 (D, Pos + I * 16, V (V'First + I));
      end loop;
   end Put_Unsigned_16_List_8_List_8;

   procedure Get_Unsigned_16_List_8_List_8 (D : Data; Pos : Natural; V : in out Unsigned_16_List_8_List_8)
     with Pre => Pos <= Data_Size - 128
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 128);
         Get_Unsigned_16_List_8 (D, Pos + I * 16, V (V'First + I));
      end loop;
   end Get_Unsigned_16_List_8_List_8;

   procedure Put_Bytes_9_List_8 (D : in out Data; Pos : Natural; V : Bytes_9_List_8)
     with Pre => Pos <= Data_Size - 72
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 72);
         Put_Bytes_9 (D, Pos + I * 9, V (V'First + I));
      end loop;
   end Put_Bytes_9_List_8;

   procedure Get_Bytes_9_List_8 (D : Data; Pos : Natural; V : in out Bytes_9_List_8)
     with Pre => Pos <= Data_Size - 72
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 72);
         Get_Bytes_9 (D, Pos + I * 9, V (V'First + I));
      end loop;
   end Get_Bytes_9_List_8;

   procedure Put_Bytes_2 (D : in out Data; Pos : Natural; V : Bytes_2)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      for I in 0 .. 1 loop
         pragma Loop_Invariant (Pos <= Data_Size - 2);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_2;

   procedure Get_Bytes_2 (D : Data; Pos : Natural; V : in out Bytes_2)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      for I in 0 .. 1 loop
         pragma Loop_Invariant (Pos <= Data_Size - 2);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_2;

   procedure Put_Bytes_2_List_8 (D : in out Data; Pos : Natural; V : Bytes_2_List_8)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 16);
         Put_Bytes_2 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Bytes_2_List_8;

   procedure Get_Bytes_2_List_8 (D : Data; Pos : Natural; V : in out Bytes_2_List_8)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 16);
         Get_Bytes_2 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Get_Bytes_2_List_8;

   procedure Put_Boolean_List_8 (D : in out Data; Pos : Natural; V : Boolean_List_8)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 8);
         Put_Boolean (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Boolean_List_8;

   procedure Get_Boolean_List_8 (D : Data; Pos : Natural; V : in out Boolean_List_8)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 8);
         V (V'First + I) := Get_Boolean (D, Pos + I * 1);
      end loop;
   end Get_Boolean_List_8;

   procedure Put_Bytes_4_List_8 (D : in out Data; Pos : Natural; V : Bytes_4_List_8)
     with Pre => Pos <= Data_Size - 32
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 32);
         Put_Bytes_4 (D, Pos + I * 4, V (V'First + I));
      end loop;
   end Put_Bytes_4_List_8;

   procedure Get_Bytes_4_List_8 (D : Data; Pos : Natural; V : in out Bytes_4_List_8)
     with Pre => Pos <= Data_Size - 32
   is
   begin
      for I in 0 .. 7 loop
         pragma Loop_Invariant (Pos <= Data_Size - 32);
         Get_Bytes_4 (D, Pos + I * 4, V (V'First + I));
      end loop;
   end Get_Bytes_4_List_8;

   procedure Put_Vtx_Table_Config_Record (D : in out Data; Pos : Natural; V : Vtx_Table_Config_Record)
     with Pre => Pos <= Data_Size - 283
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Bands);
      Put_Unsigned_8 (D, Pos + 1, V.Channels);
      Put_Unsigned_16_List_8_List_8 (D, Pos + 2, V.Frequency);
      Put_Bytes_9_List_8 (D, Pos + 130, V.Band_Names);
      Put_Bytes_8 (D, Pos + 202, V.Band_Letters);
      Put_Bytes_2_List_8 (D, Pos + 210, V.Channel_Names);
      Put_Boolean_List_8 (D, Pos + 226, V.Is_Factory_Band);
      Put_Unsigned_8 (D, Pos + 234, V.Power_Levels);
      Put_Unsigned_16_List_8 (D, Pos + 235, V.Power_Values);
      Put_Bytes_4_List_8 (D, Pos + 251, V.Power_Labels);
   end Put_Vtx_Table_Config_Record;

   procedure Get_Vtx_Table_Config_Record (D : Data; Pos : Natural; V : in out Vtx_Table_Config_Record)
     with Pre => Pos <= Data_Size - 283
   is
   begin
      V.Bands := Get_Unsigned_8 (D, Pos + 0);
      V.Channels := Get_Unsigned_8 (D, Pos + 1);
      Get_Unsigned_16_List_8_List_8 (D, Pos + 2, V.Frequency);
      Get_Bytes_9_List_8 (D, Pos + 130, V.Band_Names);
      Get_Bytes_8 (D, Pos + 202, V.Band_Letters);
      Get_Bytes_2_List_8 (D, Pos + 210, V.Channel_Names);
      Get_Boolean_List_8 (D, Pos + 226, V.Is_Factory_Band);
      V.Power_Levels := Get_Unsigned_8 (D, Pos + 234);
      Get_Unsigned_16_List_8 (D, Pos + 235, V.Power_Values);
      Get_Bytes_4_List_8 (D, Pos + 251, V.Power_Labels);
   end Get_Vtx_Table_Config_Record;

   procedure Put_Fly_Sky_Config_Record (D : in out Data; Pos : Natural; V : Fly_Sky_Config_Record)
     with Pre => Pos <= Data_Size - 20
   is
   begin
      Put_Unsigned_32 (D, Pos + 0, V.Tx_Id);
      Put_Bytes_16 (D, Pos + 4, V.Rf_Channel_Map);
   end Put_Fly_Sky_Config_Record;

   procedure Get_Fly_Sky_Config_Record (D : Data; Pos : Natural; V : in out Fly_Sky_Config_Record)
     with Pre => Pos <= Data_Size - 20
   is
   begin
      V.Tx_Id := Get_Unsigned_32 (D, Pos + 0);
      Get_Bytes_16 (D, Pos + 4, V.Rf_Channel_Map);
   end Get_Fly_Sky_Config_Record;

   procedure Put_Spektrum_Config_Record (D : in out Data; Pos : Natural; V : Spektrum_Config_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Protocol);
      Put_Bytes_4 (D, Pos + 1, V.Mfg_Id);
      Put_Unsigned_8 (D, Pos + 5, V.Num_Channels);
   end Put_Spektrum_Config_Record;

   procedure Get_Spektrum_Config_Record (D : Data; Pos : Natural; V : in out Spektrum_Config_Record)
     with Pre => Pos <= Data_Size - 6
   is
   begin
      V.Protocol := Get_Unsigned_8 (D, Pos + 0);
      Get_Bytes_4 (D, Pos + 1, V.Mfg_Id);
      V.Num_Channels := Get_Unsigned_8 (D, Pos + 5);
   end Get_Spektrum_Config_Record;

   procedure Put_Rx_Channel_Range_Config_Record (D : in out Data; Pos : Natural; V : Rx_Channel_Range_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Min);
      Put_Unsigned_16 (D, Pos + 2, V.Max);
   end Put_Rx_Channel_Range_Config_Record;

   procedure Get_Rx_Channel_Range_Config_Record (D : Data; Pos : Natural; V : in out Rx_Channel_Range_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Min := Get_Unsigned_16 (D, Pos + 0);
      V.Max := Get_Unsigned_16 (D, Pos + 2);
   end Get_Rx_Channel_Range_Config_Record;

   procedure Put_Rx_Channel_Range_Config_Record_List_4
     (D : in out Data; Pos : Natural; V : Rx_Channel_Range_Config_Record_List_4)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 16);
         Put_Rx_Channel_Range_Config_Record (D, Pos + I * 4, V (V'First + I));
      end loop;
   end Put_Rx_Channel_Range_Config_Record_List_4;

   procedure Get_Rx_Channel_Range_Config_Record_List_4
     (D : Data; Pos : Natural; V : in out Rx_Channel_Range_Config_Record_List_4)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 16);
         Get_Rx_Channel_Range_Config_Record (D, Pos + I * 4, V (V'First + I));
      end loop;
   end Get_Rx_Channel_Range_Config_Record_List_4;

   procedure Put_Rx_Failsafe_Channel_Config_Record
     (D : in out Data; Pos : Natural; V : Rx_Failsafe_Channel_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Mode);
      Put_Unsigned_8 (D, Pos + 1, V.Step);
   end Put_Rx_Failsafe_Channel_Config_Record;

   procedure Get_Rx_Failsafe_Channel_Config_Record
     (D : Data; Pos : Natural; V : in out Rx_Failsafe_Channel_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      V.Mode := Get_Unsigned_8 (D, Pos + 0);
      V.Step := Get_Unsigned_8 (D, Pos + 1);
   end Get_Rx_Failsafe_Channel_Config_Record;

   procedure Put_Rx_Failsafe_Channel_Config_Record_List_18
     (D : in out Data; Pos : Natural; V : Rx_Failsafe_Channel_Config_Record_List_18)
     with Pre => Pos <= Data_Size - 36
   is
   begin
      for I in 0 .. 17 loop
         pragma Loop_Invariant (Pos <= Data_Size - 36);
         Put_Rx_Failsafe_Channel_Config_Record (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Rx_Failsafe_Channel_Config_Record_List_18;

   procedure Get_Rx_Failsafe_Channel_Config_Record_List_18
     (D : Data; Pos : Natural; V : in out Rx_Failsafe_Channel_Config_Record_List_18)
     with Pre => Pos <= Data_Size - 36
   is
   begin
      for I in 0 .. 17 loop
         pragma Loop_Invariant (Pos <= Data_Size - 36);
         Get_Rx_Failsafe_Channel_Config_Record (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Get_Rx_Failsafe_Channel_Config_Record_List_18;

   procedure Put_Integer_16_List_4 (D : in out Data; Pos : Natural; V : Integer_16_List_4)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 8);
         Put_Integer_16 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Integer_16_List_4;

   procedure Get_Integer_16_List_4 (D : Data; Pos : Natural; V : in out Integer_16_List_4)
     with Pre => Pos <= Data_Size - 8
   is
   begin
      for I in 0 .. 3 loop
         pragma Loop_Invariant (Pos <= Data_Size - 8);
         V (V'First + I) := Get_Integer_16 (D, Pos + I * 2);
      end loop;
   end Get_Integer_16_List_4;

   procedure Put_Integer_16_List_2 (D : in out Data; Pos : Natural; V : Integer_16_List_2)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 1 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         Put_Integer_16 (D, Pos + I * 2, V (V'First + I));
      end loop;
   end Put_Integer_16_List_2;

   procedure Get_Integer_16_List_2 (D : Data; Pos : Natural; V : in out Integer_16_List_2)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      for I in 0 .. 1 loop
         pragma Loop_Invariant (Pos <= Data_Size - 4);
         V (V'First + I) := Get_Integer_16 (D, Pos + I * 2);
      end loop;
   end Get_Integer_16_List_2;

   procedure Put_Accelerometer_Config_Record (D : in out Data; Pos : Natural; V : Accelerometer_Config_Record)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Acc_Lpf_Hz);
      Put_Unsigned_8 (D, Pos + 2, V.Acc_Hardware);
      Put_Boolean (D, Pos + 3, V.Acc_High_Fsr);
      Put_Integer_16_List_4 (D, Pos + 4, V.Acc_Zero);
      Put_Integer_16_List_2 (D, Pos + 12, V.Accelerometer_Trims);
   end Put_Accelerometer_Config_Record;

   procedure Get_Accelerometer_Config_Record (D : Data; Pos : Natural; V : in out Accelerometer_Config_Record)
     with Pre => Pos <= Data_Size - 16
   is
   begin
      V.Acc_Lpf_Hz := Get_Unsigned_16 (D, Pos + 0);
      V.Acc_Hardware := Get_Unsigned_8 (D, Pos + 2);
      V.Acc_High_Fsr := Get_Boolean (D, Pos + 3);
      Get_Integer_16_List_4 (D, Pos + 4, V.Acc_Zero);
      Get_Integer_16_List_2 (D, Pos + 12, V.Accelerometer_Trims);
   end Get_Accelerometer_Config_Record;

   procedure Put_Barometer_Config_Record (D : in out Data; Pos : Natural; V : Barometer_Config_Record)
     with Pre => Pos <= Data_Size - 10
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Baro_Bus_Type);
      Put_Unsigned_8 (D, Pos + 1, V.Baro_Spi_Device);
      Put_Unsigned_8 (D, Pos + 2, V.Baro_Spi_Csn);
      Put_Unsigned_8 (D, Pos + 3, V.Baro_I2c_Device);
      Put_Unsigned_8 (D, Pos + 4, V.Baro_I2c_Address);
      Put_Unsigned_8 (D, Pos + 5, V.Baro_Hardware);
      Put_Unsigned_8 (D, Pos + 6, V.Baro_Eoc_Tag);
      Put_Unsigned_8 (D, Pos + 7, V.Baro_Xclr_Tag);
      Put_Integer_16 (D, Pos + 8, V.Baro_Temp_Drift_Cm_Per10_C);
   end Put_Barometer_Config_Record;

   procedure Get_Barometer_Config_Record (D : Data; Pos : Natural; V : in out Barometer_Config_Record)
     with Pre => Pos <= Data_Size - 10
   is
   begin
      V.Baro_Bus_Type := Get_Unsigned_8 (D, Pos + 0);
      V.Baro_Spi_Device := Get_Unsigned_8 (D, Pos + 1);
      V.Baro_Spi_Csn := Get_Unsigned_8 (D, Pos + 2);
      V.Baro_I2c_Device := Get_Unsigned_8 (D, Pos + 3);
      V.Baro_I2c_Address := Get_Unsigned_8 (D, Pos + 4);
      V.Baro_Hardware := Get_Unsigned_8 (D, Pos + 5);
      V.Baro_Eoc_Tag := Get_Unsigned_8 (D, Pos + 6);
      V.Baro_Xclr_Tag := Get_Unsigned_8 (D, Pos + 7);
      V.Baro_Temp_Drift_Cm_Per10_C := Get_Integer_16 (D, Pos + 8);
   end Get_Barometer_Config_Record;

   procedure Put_Battery_Profile_Record (D : in out Data; Pos : Natural; V : Battery_Profile_Record)
     with Pre => Pos <= Data_Size - 21
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Vbatmaxcellvoltage);
      Put_Unsigned_16 (D, Pos + 2, V.Vbatmincellvoltage);
      Put_Unsigned_16 (D, Pos + 4, V.Vbatwarningcellvoltage);
      Put_Unsigned_16 (D, Pos + 6, V.Vbatfullcellvoltage);
      Put_Unsigned_16 (D, Pos + 8, V.Battery_Capacity);
      Put_Unsigned_8 (D, Pos + 10, V.Force_Battery_Cell_Count);
      Put_Unsigned_8 (D, Pos + 11, V.Consumption_Warning_Percentage);
      Put_Bytes_9 (D, Pos + 12, V.Profile_Name);
   end Put_Battery_Profile_Record;

   procedure Get_Battery_Profile_Record (D : Data; Pos : Natural; V : in out Battery_Profile_Record)
     with Pre => Pos <= Data_Size - 21
   is
   begin
      V.Vbatmaxcellvoltage := Get_Unsigned_16 (D, Pos + 0);
      V.Vbatmincellvoltage := Get_Unsigned_16 (D, Pos + 2);
      V.Vbatwarningcellvoltage := Get_Unsigned_16 (D, Pos + 4);
      V.Vbatfullcellvoltage := Get_Unsigned_16 (D, Pos + 6);
      V.Battery_Capacity := Get_Unsigned_16 (D, Pos + 8);
      V.Force_Battery_Cell_Count := Get_Unsigned_8 (D, Pos + 10);
      V.Consumption_Warning_Percentage := Get_Unsigned_8 (D, Pos + 11);
      Get_Bytes_9 (D, Pos + 12, V.Profile_Name);
   end Get_Battery_Profile_Record;

   procedure Put_Battery_Profile_Record_List_3 (D : in out Data; Pos : Natural; V : Battery_Profile_Record_List_3)
     with Pre => Pos <= Data_Size - 63
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 63);
         Put_Battery_Profile_Record (D, Pos + I * 21, V (V'First + I));
      end loop;
   end Put_Battery_Profile_Record_List_3;

   procedure Get_Battery_Profile_Record_List_3 (D : Data; Pos : Natural; V : in out Battery_Profile_Record_List_3)
     with Pre => Pos <= Data_Size - 63
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 63);
         Get_Battery_Profile_Record (D, Pos + I * 21, V (V'First + I));
      end loop;
   end Get_Battery_Profile_Record_List_3;

   procedure Put_Battery_Config_Record (D : in out Data; Pos : Natural; V : Battery_Config_Record)
     with Pre => Pos <= Data_Size - 14
   is
   begin
      Put_Unsigned_16 (D, Pos + 0, V.Vbatnotpresentcellvoltage);
      Put_Unsigned_8 (D, Pos + 2, V.Lvc_Percentage);
      Put_Unsigned_8 (D, Pos + 3, V.Voltage_Meter_Source);
      Put_Unsigned_8 (D, Pos + 4, V.Current_Meter_Source);
      Put_Boolean (D, Pos + 5, V.Use_V_Bat_Alerts);
      Put_Boolean (D, Pos + 6, V.Use_Consumption_Alerts);
      Put_Unsigned_8 (D, Pos + 7, V.Vbathysteresis);
      Put_Unsigned_8 (D, Pos + 8, V.Vbat_Display_Lpf_Period);
      Put_Unsigned_8 (D, Pos + 9, V.Ibat_Lpf_Period);
      Put_Unsigned_8 (D, Pos + 10, V.Vbat_Duration_For_Warning);
      Put_Unsigned_8 (D, Pos + 11, V.Vbat_Duration_For_Critical);
      Put_Unsigned_8 (D, Pos + 12, V.Vbat_Sag_Lpf_Period);
      Put_Boolean (D, Pos + 13, V.Is_Battery_Continue_Enabled);
   end Put_Battery_Config_Record;

   procedure Get_Battery_Config_Record (D : Data; Pos : Natural; V : in out Battery_Config_Record)
     with Pre => Pos <= Data_Size - 14
   is
   begin
      V.Vbatnotpresentcellvoltage := Get_Unsigned_16 (D, Pos + 0);
      V.Lvc_Percentage := Get_Unsigned_8 (D, Pos + 2);
      V.Voltage_Meter_Source := Get_Unsigned_8 (D, Pos + 3);
      V.Current_Meter_Source := Get_Unsigned_8 (D, Pos + 4);
      V.Use_V_Bat_Alerts := Get_Boolean (D, Pos + 5);
      V.Use_Consumption_Alerts := Get_Boolean (D, Pos + 6);
      V.Vbathysteresis := Get_Unsigned_8 (D, Pos + 7);
      V.Vbat_Display_Lpf_Period := Get_Unsigned_8 (D, Pos + 8);
      V.Ibat_Lpf_Period := Get_Unsigned_8 (D, Pos + 9);
      V.Vbat_Duration_For_Warning := Get_Unsigned_8 (D, Pos + 10);
      V.Vbat_Duration_For_Critical := Get_Unsigned_8 (D, Pos + 11);
      V.Vbat_Sag_Lpf_Period := Get_Unsigned_8 (D, Pos + 12);
      V.Is_Battery_Continue_Enabled := Get_Boolean (D, Pos + 13);
   end Get_Battery_Config_Record;

   procedure Put_Board_Alignment_Record (D : in out Data; Pos : Natural; V : Board_Alignment_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      Put_Integer_32 (D, Pos + 0, V.Roll_Degrees);
      Put_Integer_32 (D, Pos + 4, V.Pitch_Degrees);
      Put_Integer_32 (D, Pos + 8, V.Yaw_Degrees);
   end Put_Board_Alignment_Record;

   procedure Get_Board_Alignment_Record (D : Data; Pos : Natural; V : in out Board_Alignment_Record)
     with Pre => Pos <= Data_Size - 12
   is
   begin
      V.Roll_Degrees := Get_Integer_32 (D, Pos + 0);
      V.Pitch_Degrees := Get_Integer_32 (D, Pos + 4);
      V.Yaw_Degrees := Get_Integer_32 (D, Pos + 8);
   end Get_Board_Alignment_Record;

   procedure Put_Compass_Config_Record (D : in out Data; Pos : Natural; V : Compass_Config_Record)
     with Pre => Pos <= Data_Size - 22
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Mag_Alignment);
      Put_Unsigned_8 (D, Pos + 1, V.Mag_Hardware);
      Put_Unsigned_8 (D, Pos + 2, V.Mag_Bus_Type);
      Put_Unsigned_8 (D, Pos + 3, V.Mag_I2c_Device);
      Put_Unsigned_8 (D, Pos + 4, V.Mag_I2c_Address);
      Put_Unsigned_8 (D, Pos + 5, V.Mag_Spi_Device);
      Put_Unsigned_8 (D, Pos + 6, V.Mag_Spi_Csn);
      Put_Unsigned_8 (D, Pos + 7, V.Interrupt_Tag);
      Put_Integer_16_List_4 (D, Pos + 8, V.Mag_Zero);
      Put_Integer_16_List_3 (D, Pos + 16, V.Mag_Custom_Alignment);
   end Put_Compass_Config_Record;

   procedure Get_Compass_Config_Record (D : Data; Pos : Natural; V : in out Compass_Config_Record)
     with Pre => Pos <= Data_Size - 22
   is
   begin
      V.Mag_Alignment := Get_Unsigned_8 (D, Pos + 0);
      V.Mag_Hardware := Get_Unsigned_8 (D, Pos + 1);
      V.Mag_Bus_Type := Get_Unsigned_8 (D, Pos + 2);
      V.Mag_I2c_Device := Get_Unsigned_8 (D, Pos + 3);
      V.Mag_I2c_Address := Get_Unsigned_8 (D, Pos + 4);
      V.Mag_Spi_Device := Get_Unsigned_8 (D, Pos + 5);
      V.Mag_Spi_Csn := Get_Unsigned_8 (D, Pos + 6);
      V.Interrupt_Tag := Get_Unsigned_8 (D, Pos + 7);
      Get_Integer_16_List_4 (D, Pos + 8, V.Mag_Zero);
      Get_Integer_16_List_3 (D, Pos + 16, V.Mag_Custom_Alignment);
   end Get_Compass_Config_Record;

   procedure Put_Current_Sensor_Adc_Config_Record (D : in out Data; Pos : Natural; V : Current_Sensor_Adc_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Integer_16 (D, Pos + 0, V.Scale);
      Put_Integer_16 (D, Pos + 2, V.Offset);
   end Put_Current_Sensor_Adc_Config_Record;

   procedure Get_Current_Sensor_Adc_Config_Record (D : Data; Pos : Natural; V : in out Current_Sensor_Adc_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Scale := Get_Integer_16 (D, Pos + 0);
      V.Offset := Get_Integer_16 (D, Pos + 2);
   end Get_Current_Sensor_Adc_Config_Record;

   procedure Put_Current_Sensor_Virtual_Config_Record
     (D : in out Data; Pos : Natural; V : Current_Sensor_Virtual_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Integer_16 (D, Pos + 0, V.Scale);
      Put_Unsigned_16 (D, Pos + 2, V.Offset);
   end Put_Current_Sensor_Virtual_Config_Record;

   procedure Get_Current_Sensor_Virtual_Config_Record
     (D : Data; Pos : Natural; V : in out Current_Sensor_Virtual_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Scale := Get_Integer_16 (D, Pos + 0);
      V.Offset := Get_Unsigned_16 (D, Pos + 2);
   end Get_Current_Sensor_Virtual_Config_Record;

   procedure Put_Esc_Sensor_Config_Record (D : in out Data; Pos : Natural; V : Esc_Sensor_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Half_Duplex);
      Put_Unsigned_16 (D, Pos + 1, V.Offset);
      Put_Integer_8 (D, Pos + 3, V.Esc_Sensor_Uart);
   end Put_Esc_Sensor_Config_Record;

   procedure Get_Esc_Sensor_Config_Record (D : Data; Pos : Natural; V : in out Esc_Sensor_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Half_Duplex := Get_Unsigned_8 (D, Pos + 0);
      V.Offset := Get_Unsigned_16 (D, Pos + 1);
      V.Esc_Sensor_Uart := Get_Integer_8 (D, Pos + 3);
   end Get_Esc_Sensor_Config_Record;

   procedure Put_Gyro_Config_Record (D : in out Data; Pos : Natural; V : Gyro_Config_Record)
     with Pre => Pos <= Data_Size - 35
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Gyro_Movement_Calibration_Threshold);
      Put_Unsigned_8 (D, Pos + 1, V.Gyro_Hardware_Lpf);
      Put_Unsigned_8 (D, Pos + 2, V.Gyro_High_Fsr);
      Put_Unsigned_16 (D, Pos + 3, V.Gyro_Lpf1_Static_Hz);
      Put_Unsigned_16 (D, Pos + 5, V.Gyro_Lpf2_Static_Hz);
      Put_Unsigned_16 (D, Pos + 7, V.Gyro_Soft_Notch_Hz_1);
      Put_Unsigned_16 (D, Pos + 9, V.Gyro_Soft_Notch_Cutoff_1);
      Put_Unsigned_16 (D, Pos + 11, V.Gyro_Soft_Notch_Hz_2);
      Put_Unsigned_16 (D, Pos + 13, V.Gyro_Soft_Notch_Cutoff_2);
      Put_Integer_16 (D, Pos + 15, V.Gyro_Offset_Yaw);
      Put_Unsigned_8 (D, Pos + 17, V.Check_Overflow);
      Put_Unsigned_8 (D, Pos + 18, V.Gyro_Lpf1_Type);
      Put_Unsigned_8 (D, Pos + 19, V.Gyro_Lpf2_Type);
      Put_Unsigned_8 (D, Pos + 20, V.Yaw_Spin_Recovery);
      Put_Integer_16 (D, Pos + 21, V.Yaw_Spin_Threshold);
      Put_Unsigned_16 (D, Pos + 23, V.Gyro_Calibration_Duration);
      Put_Unsigned_16 (D, Pos + 25, V.Gyro_Lpf1_Dyn_Min_Hz);
      Put_Unsigned_16 (D, Pos + 27, V.Gyro_Lpf1_Dyn_Max_Hz);
      Put_Unsigned_8 (D, Pos + 29, V.Gyro_Filter_Debug_Axis);
      Put_Unsigned_8 (D, Pos + 30, V.Gyros_Detected);
      Put_Unsigned_8 (D, Pos + 31, V.Gyro_Lpf1_Dyn_Expo);
      Put_Unsigned_8 (D, Pos + 32, V.Simplified_Gyro_Filter);
      Put_Unsigned_8 (D, Pos + 33, V.Simplified_Gyro_Filter_Multiplier);
      Put_Unsigned_8 (D, Pos + 34, V.Gyro_Enabled_Bitmask);
   end Put_Gyro_Config_Record;

   procedure Get_Gyro_Config_Record (D : Data; Pos : Natural; V : in out Gyro_Config_Record)
     with Pre => Pos <= Data_Size - 35
   is
   begin
      V.Gyro_Movement_Calibration_Threshold := Get_Unsigned_8 (D, Pos + 0);
      V.Gyro_Hardware_Lpf := Get_Unsigned_8 (D, Pos + 1);
      V.Gyro_High_Fsr := Get_Unsigned_8 (D, Pos + 2);
      V.Gyro_Lpf1_Static_Hz := Get_Unsigned_16 (D, Pos + 3);
      V.Gyro_Lpf2_Static_Hz := Get_Unsigned_16 (D, Pos + 5);
      V.Gyro_Soft_Notch_Hz_1 := Get_Unsigned_16 (D, Pos + 7);
      V.Gyro_Soft_Notch_Cutoff_1 := Get_Unsigned_16 (D, Pos + 9);
      V.Gyro_Soft_Notch_Hz_2 := Get_Unsigned_16 (D, Pos + 11);
      V.Gyro_Soft_Notch_Cutoff_2 := Get_Unsigned_16 (D, Pos + 13);
      V.Gyro_Offset_Yaw := Get_Integer_16 (D, Pos + 15);
      V.Check_Overflow := Get_Unsigned_8 (D, Pos + 17);
      V.Gyro_Lpf1_Type := Get_Unsigned_8 (D, Pos + 18);
      V.Gyro_Lpf2_Type := Get_Unsigned_8 (D, Pos + 19);
      V.Yaw_Spin_Recovery := Get_Unsigned_8 (D, Pos + 20);
      V.Yaw_Spin_Threshold := Get_Integer_16 (D, Pos + 21);
      V.Gyro_Calibration_Duration := Get_Unsigned_16 (D, Pos + 23);
      V.Gyro_Lpf1_Dyn_Min_Hz := Get_Unsigned_16 (D, Pos + 25);
      V.Gyro_Lpf1_Dyn_Max_Hz := Get_Unsigned_16 (D, Pos + 27);
      V.Gyro_Filter_Debug_Axis := Get_Unsigned_8 (D, Pos + 29);
      V.Gyros_Detected := Get_Unsigned_8 (D, Pos + 30);
      V.Gyro_Lpf1_Dyn_Expo := Get_Unsigned_8 (D, Pos + 31);
      V.Simplified_Gyro_Filter := Get_Unsigned_8 (D, Pos + 32);
      V.Simplified_Gyro_Filter_Multiplier := Get_Unsigned_8 (D, Pos + 33);
      V.Gyro_Enabled_Bitmask := Get_Unsigned_8 (D, Pos + 34);
   end Get_Gyro_Config_Record;

   procedure Put_Opticalflow_Config_Record (D : in out Data; Pos : Natural; V : Opticalflow_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Opticalflow_Hardware);
      Put_Unsigned_16 (D, Pos + 1, V.Rotation);
      Put_Unsigned_8 (D, Pos + 3, V.Flip_X);
      Put_Integer_8 (D, Pos + 4, V.Opticalflow_Uart);
   end Put_Opticalflow_Config_Record;

   procedure Get_Opticalflow_Config_Record (D : Data; Pos : Natural; V : in out Opticalflow_Config_Record)
     with Pre => Pos <= Data_Size - 5
   is
   begin
      V.Opticalflow_Hardware := Get_Unsigned_8 (D, Pos + 0);
      V.Rotation := Get_Unsigned_16 (D, Pos + 1);
      V.Flip_X := Get_Unsigned_8 (D, Pos + 3);
      V.Opticalflow_Uart := Get_Integer_8 (D, Pos + 4);
   end Get_Opticalflow_Config_Record;

   procedure Put_Pitot_Config_Record (D : in out Data; Pos : Natural; V : Pitot_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Pitot_Bus_Type);
      Put_Unsigned_8 (D, Pos + 1, V.Pitot_I2c_Device);
      Put_Unsigned_8 (D, Pos + 2, V.Pitot_I2c_Address);
      Put_Unsigned_8 (D, Pos + 3, V.Pitot_Hardware);
   end Put_Pitot_Config_Record;

   procedure Get_Pitot_Config_Record (D : Data; Pos : Natural; V : in out Pitot_Config_Record)
     with Pre => Pos <= Data_Size - 4
   is
   begin
      V.Pitot_Bus_Type := Get_Unsigned_8 (D, Pos + 0);
      V.Pitot_I2c_Device := Get_Unsigned_8 (D, Pos + 1);
      V.Pitot_I2c_Address := Get_Unsigned_8 (D, Pos + 2);
      V.Pitot_Hardware := Get_Unsigned_8 (D, Pos + 3);
   end Get_Pitot_Config_Record;

   procedure Put_Rangefinder_Config_Record (D : in out Data; Pos : Natural; V : Rangefinder_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Rangefinder_Hardware);
      Put_Integer_8 (D, Pos + 1, V.Rangefinder_Uart);
   end Put_Rangefinder_Config_Record;

   procedure Get_Rangefinder_Config_Record (D : Data; Pos : Natural; V : in out Rangefinder_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      V.Rangefinder_Hardware := Get_Unsigned_8 (D, Pos + 0);
      V.Rangefinder_Uart := Get_Integer_8 (D, Pos + 1);
   end Get_Rangefinder_Config_Record;

   procedure Put_Sonar_Config_Record (D : in out Data; Pos : Natural; V : Sonar_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Trigger_Tag);
      Put_Unsigned_8 (D, Pos + 1, V.Echo_Tag);
   end Put_Sonar_Config_Record;

   procedure Get_Sonar_Config_Record (D : Data; Pos : Natural; V : in out Sonar_Config_Record)
     with Pre => Pos <= Data_Size - 2
   is
   begin
      V.Trigger_Tag := Get_Unsigned_8 (D, Pos + 0);
      V.Echo_Tag := Get_Unsigned_8 (D, Pos + 1);
   end Get_Sonar_Config_Record;

   procedure Put_Voltage_Sensor_Adc_Config_Record (D : in out Data; Pos : Natural; V : Voltage_Sensor_Adc_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Vbatscale);
      Put_Unsigned_8 (D, Pos + 1, V.Vbatresdivval);
      Put_Unsigned_8 (D, Pos + 2, V.Vbatresdivmultiplier);
   end Put_Voltage_Sensor_Adc_Config_Record;

   procedure Get_Voltage_Sensor_Adc_Config_Record (D : Data; Pos : Natural; V : in out Voltage_Sensor_Adc_Config_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Vbatscale := Get_Unsigned_8 (D, Pos + 0);
      V.Vbatresdivval := Get_Unsigned_8 (D, Pos + 1);
      V.Vbatresdivmultiplier := Get_Unsigned_8 (D, Pos + 2);
   end Get_Voltage_Sensor_Adc_Config_Record;

   procedure Put_Voltage_Sensor_Adc_Config_Record_List_1
     (D : in out Data; Pos : Natural; V : Voltage_Sensor_Adc_Config_Record_List_1)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      for I in 0 .. 0 loop
         pragma Loop_Invariant (Pos <= Data_Size - 3);
         Put_Voltage_Sensor_Adc_Config_Record (D, Pos + I * 3, V (V'First + I));
      end loop;
   end Put_Voltage_Sensor_Adc_Config_Record_List_1;

   procedure Get_Voltage_Sensor_Adc_Config_Record_List_1
     (D : Data; Pos : Natural; V : in out Voltage_Sensor_Adc_Config_Record_List_1)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      for I in 0 .. 0 loop
         pragma Loop_Invariant (Pos <= Data_Size - 3);
         Get_Voltage_Sensor_Adc_Config_Record (D, Pos + I * 3, V (V'First + I));
      end loop;
   end Get_Voltage_Sensor_Adc_Config_Record_List_1;

   procedure Put_Bytes_15 (D : in out Data; Pos : Natural; V : Bytes_15)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      for I in 0 .. 14 loop
         pragma Loop_Invariant (Pos <= Data_Size - 15);
         Put_Unsigned_8 (D, Pos + I * 1, V (V'First + I));
      end loop;
   end Put_Bytes_15;

   procedure Get_Bytes_15 (D : Data; Pos : Natural; V : in out Bytes_15)
     with Pre => Pos <= Data_Size - 15
   is
   begin
      for I in 0 .. 14 loop
         pragma Loop_Invariant (Pos <= Data_Size - 15);
         V (V'First + I) := Get_Unsigned_8 (D, Pos + I * 1);
      end loop;
   end Get_Bytes_15;

   procedure Put_Telemetry_Provider_Record (D : in out Data; Pos : Natural; V : Telemetry_Provider_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      Put_Unsigned_8 (D, Pos + 0, V.Protocol);
      Put_Integer_8 (D, Pos + 1, V.Uart);
      Put_Unsigned_8 (D, Pos + 2, V.Baud);
   end Put_Telemetry_Provider_Record;

   procedure Get_Telemetry_Provider_Record (D : Data; Pos : Natural; V : in out Telemetry_Provider_Record)
     with Pre => Pos <= Data_Size - 3
   is
   begin
      V.Protocol := Get_Unsigned_8 (D, Pos + 0);
      V.Uart := Get_Integer_8 (D, Pos + 1);
      V.Baud := Get_Unsigned_8 (D, Pos + 2);
   end Get_Telemetry_Provider_Record;

   procedure Put_Telemetry_Provider_Record_List_3 (D : in out Data; Pos : Natural; V : Telemetry_Provider_Record_List_3)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 9);
         Put_Telemetry_Provider_Record (D, Pos + I * 3, V (V'First + I));
      end loop;
   end Put_Telemetry_Provider_Record_List_3;

   procedure Get_Telemetry_Provider_Record_List_3 (D : Data; Pos : Natural; V : in out Telemetry_Provider_Record_List_3)
     with Pre => Pos <= Data_Size - 9
   is
   begin
      for I in 0 .. 2 loop
         pragma Loop_Invariant (Pos <= Data_Size - 9);
         Get_Telemetry_Provider_Record (D, Pos + I * 3, V (V'First + I));
      end loop;
   end Get_Telemetry_Provider_Record_List_3;

   procedure Put_Telemetry_Config_Record (D : in out Data; Pos : Natural; V : Telemetry_Config_Record)
     with Pre => Pos <= Data_Size - 50
   is
   begin
      Put_Integer_16 (D, Pos + 0, V.Gps_No_Fix_Latitude);
      Put_Integer_16 (D, Pos + 2, V.Gps_No_Fix_Longitude);
      Put_Unsigned_8 (D, Pos + 4, V.Telemetry_Inverted);
      Put_Unsigned_8 (D, Pos + 5, V.Half_Duplex);
      Put_Unsigned_8 (D, Pos + 6, V.Frsky_Coordinate_Format);
      Put_Unsigned_8 (D, Pos + 7, V.Frsky_Unit);
      Put_Unsigned_8 (D, Pos + 8, V.Frsky_Vfas_Precision);
      Put_Unsigned_8 (D, Pos + 9, V.Hott_Alarm_Sound_Interval);
      Put_Unsigned_8 (D, Pos + 10, V.Pid_Values_As_Telemetry);
      Put_Unsigned_8 (D, Pos + 11, V.Report_Cell_Voltage);
      Put_Bytes_15 (D, Pos + 12, V.Flysky_Sensors);
      Put_Unsigned_16 (D, Pos + 27, V.Mavlink_Mah_As_Heading_Divisor);
      Put_Unsigned_32 (D, Pos + 29, V.Disabled_Sensors);
      Put_Unsigned_8 (D, Pos + 33, V.Mavlink_Min_Txbuff);
      Put_Unsigned_8 (D, Pos + 34, V.Mavlink_Extended_Status_Rate);
      Put_Unsigned_8 (D, Pos + 35, V.Mavlink_Rc_Channels_Rate);
      Put_Unsigned_8 (D, Pos + 36, V.Mavlink_Position_Rate);
      Put_Unsigned_8 (D, Pos + 37, V.Mavlink_Extra1_Rate);
      Put_Unsigned_8 (D, Pos + 38, V.Mavlink_Extra2_Rate);
      Put_Unsigned_8 (D, Pos + 39, V.Mavlink_Extra3_Rate);
      Put_Unsigned_8 (D, Pos + 40, V.Crsf_Tlm_Accgyro);
      Put_Telemetry_Provider_Record_List_3 (D, Pos + 41, V.Providers);
   end Put_Telemetry_Config_Record;

   procedure Get_Telemetry_Config_Record (D : Data; Pos : Natural; V : in out Telemetry_Config_Record)
     with Pre => Pos <= Data_Size - 50
   is
   begin
      V.Gps_No_Fix_Latitude := Get_Integer_16 (D, Pos + 0);
      V.Gps_No_Fix_Longitude := Get_Integer_16 (D, Pos + 2);
      V.Telemetry_Inverted := Get_Unsigned_8 (D, Pos + 4);
      V.Half_Duplex := Get_Unsigned_8 (D, Pos + 5);
      V.Frsky_Coordinate_Format := Get_Unsigned_8 (D, Pos + 6);
      V.Frsky_Unit := Get_Unsigned_8 (D, Pos + 7);
      V.Frsky_Vfas_Precision := Get_Unsigned_8 (D, Pos + 8);
      V.Hott_Alarm_Sound_Interval := Get_Unsigned_8 (D, Pos + 9);
      V.Pid_Values_As_Telemetry := Get_Unsigned_8 (D, Pos + 10);
      V.Report_Cell_Voltage := Get_Unsigned_8 (D, Pos + 11);
      Get_Bytes_15 (D, Pos + 12, V.Flysky_Sensors);
      V.Mavlink_Mah_As_Heading_Divisor := Get_Unsigned_16 (D, Pos + 27);
      V.Disabled_Sensors := Get_Unsigned_32 (D, Pos + 29);
      V.Mavlink_Min_Txbuff := Get_Unsigned_8 (D, Pos + 33);
      V.Mavlink_Extended_Status_Rate := Get_Unsigned_8 (D, Pos + 34);
      V.Mavlink_Rc_Channels_Rate := Get_Unsigned_8 (D, Pos + 35);
      V.Mavlink_Position_Rate := Get_Unsigned_8 (D, Pos + 36);
      V.Mavlink_Extra1_Rate := Get_Unsigned_8 (D, Pos + 37);
      V.Mavlink_Extra2_Rate := Get_Unsigned_8 (D, Pos + 38);
      V.Mavlink_Extra3_Rate := Get_Unsigned_8 (D, Pos + 39);
      V.Crsf_Tlm_Accgyro := Get_Unsigned_8 (D, Pos + 40);
      Get_Telemetry_Provider_Record_List_3 (D, Pos + 41, V.Providers);
   end Get_Telemetry_Config_Record;

   procedure Encode (C : Configuration; D : out Data) is
   begin
      D := (others => 0);
      Put_Blackbox_Config_Record (D, 0, C.Blackbox_Config);
      Put_Time_Config_Record (D, 10, C.Time_Config);
      Put_System_Config_Record (D, 12, C.System_Config);
      Put_Feature_Config_Record (D, 29, C.Feature_Config);
      Put_Status_Led_Config_Record (D, 33, C.Status_Led_Config);
      Put_Serial_Pin_Config_Record (D, 37, C.Serial_Pin_Config);
      Put_Control_Rate_Config_Record_List_4 (D, 59, C.Control_Rate_Profiles);
      Put_Throttle_Correction_Config_Record (D, 183, C.Throttle_Correction_Config);
      Put_Adjustment_Range_Record_List_30 (D, 186, C.Adjustment_Ranges);
      Put_Rc_Controls_Config_Record (D, 456, C.Rc_Controls_Config);
      Put_Arming_Config_Record (D, 459, C.Arming_Config);
      Put_Flight3_D_Config_Record (D, 462, C.Flight3_D_Config);
      Put_Mode_Activation_Condition_Record_List_20 (D, 475, C.Mode_Activation_Conditions);
      Put_Mode_Activation_Config_Record (D, 595, C.Mode_Activation_Config);
      Put_Failsafe_Config_Record (D, 659, C.Failsafe_Config);
      Put_Imu_Config_Record (D, 670, C.Imu_Config);
      Put_Mixer_Config_Record (D, 678, C.Mixer_Config);
      Put_Motor_Mixer_Record_List_8 (D, 693, C.Custom_Motor_Mixer);
      Put_Tricopter_Mixer_Config_Record (D, 821, C.Tricopter_Mixer_Config);
      Put_Pid_Config_Record (D, 822, C.Pid_Config);
      Put_Pid_Profile_Record_List_4 (D, 827, C.Pid_Profiles);
      Put_Position_Config_Record (D, 1671, C.Position_Config);
      Put_Servo_Config_Record (D, 1679, C.Servo_Config);
      Put_Servo_Mixer_Record_List_16 (D, 1695, C.Custom_Servo_Mixers);
      Put_Servo_Param_Record_List_8 (D, 1807, C.Servo_Params);
      Put_Gimbal_Config_Record (D, 1903, C.Gimbal_Config);
      Put_Led_Strip_Config_Record (D, 1904, C.Led_Strip_Config);
      Put_Led_Strip_Status_Mode_Config_Record (D, 1920, C.Led_Strip_Status_Mode_Config);
      Put_Serial_Config_Record (D, 2160, C.Serial_Config);
      Put_Transponder_Config_Record (D, 2163, C.Transponder_Config);
      Put_Vtx_Config_Record (D, 2175, C.Vtx_Config);
      Put_Vtx_Settings_Config_Record (D, 2236, C.Vtx_Settings_Config);
      Put_Osd_Custom_Text_Config_Record (D, 2247, C.Osd_Custom_Text_Config);
      Put_Osd_Config_Record (D, 2248, C.Osd_Config);
      Put_Osd_Element_Config_Record (D, 2363, C.Osd_Element_Config);
      Put_Adc_Config_Record (D, 2561, C.Adc_Config);
      Put_Alt_Hold_Config_Record (D, 2580, C.Alt_Hold_Config);
      Put_Autopilot_Config_Record (D, 2582, C.Autopilot_Config);
      Put_Beeper_Dev_Config_Record (D, 2661, C.Beeper_Dev_Config);
      Put_Beeper_Config_Record (D, 2666, C.Beeper_Config);
      Put_Board_Config_Record (D, 2675, C.Board_Config);
      Put_I2c_Config_Record_List_3 (D, 2735, C.I2c_Config);
      Put_Spi_Pin_Config_Record_List_3 (D, 2750, C.Spi_Pin_Config);
      Put_Dashboard_Config_Record (D, 2765, C.Dashboard_Config);
      Put_Display_Port_Profile_Record (D, 2770, C.Display_Port_Profile_Msp);
      Put_Display_Port_Profile_Record (D, 2780, C.Display_Port_Profile_Max7456);
      Put_Dyn_Notch_Config_Record (D, 2790, C.Dyn_Notch_Config);
      Put_Flash_Config_Record (D, 2797, C.Flash_Config);
      Put_Flight_Plan_Config_Record (D, 2801, C.Flight_Plan_Config);
      Put_Gimbal_Track_Config_Record (D, 3432, C.Gimbal_Track_Config);
      Put_Gps_Lap_Timer_Config_Record (D, 3450, C.Gps_Lap_Timer_Config);
      Put_Gps_Config_Record (D, 3461, C.Gps_Config);
      Put_Gps_Rescue_Record (D, 3541, C.Gps_Rescue_Config);
      Put_Gyro_Device_Config_Record_List_1 (D, 3560, C.Gyro_Device_Config);
      Put_Max7456_Config_Record (D, 3575, C.Max7456_Config);
      Put_Mco_Config_Record_List_2 (D, 3579, C.Mco_Config);
      Put_Motor_Config_Record (D, 3585, C.Motor_Config);
      Put_Msp_Config_Record (D, 3621, C.Msp_Config);
      Put_Osd_Nav_Map_Config_Record (D, 3628, C.Osd_Nav_Map_Config);
      Put_Pilot_Config_Record (D, 3632, C.Pilot_Config);
      Put_Pinio_Box_Config_Record (D, 3734, C.Pinio_Box_Config);
      Put_Pinio_Config_Record (D, 3738, C.Pinio_Config);
      Put_Pin_Pull_Up_Down_Config_Record_List_4 (D, 3746, C.Pin_Pullup_Config);
      Put_Pin_Pull_Up_Down_Config_Record_List_4 (D, 3750, C.Pin_Pulldown_Config);
      Put_Pos_Hold_Config_Record (D, 3754, C.Pos_Hold_Config);
      Put_Rcdevice_Config_Record (D, 3759, C.Rcdevice_Config);
      Put_Rpm_Filter_Config_Record (D, 3770, C.Rpm_Filter_Config);
      Put_Rx_Config_Record (D, 3781, C.Rx_Config);
      Put_Pwm_Config_Record (D, 3832, C.Pwm_Config);
      Put_Ppm_Config_Record (D, 3841, C.Ppm_Config);
      Put_Rx_Cc2500_Spi_Config_Record (D, 3842, C.Rx_Cc2500_Spi_Config);
      Put_Rx_Express_Lrs_Spi_Config_Record (D, 3903, C.Rx_Express_Lrs_Spi_Config);
      Put_Rx_Spi_Config_Record (D, 3914, C.Rx_Spi_Config);
      Put_Scheduler_Config_Record (D, 3926, C.Scheduler_Config);
      Put_Sdcard_Config_Record (D, 3933, C.Sdcard_Config);
      Put_Serial_Uart_Config_Record_List_6 (D, 3938, C.Serial_Uart_Config);
      Put_Stats_Config_Record (D, 3950, C.Stats_Config);
      Put_Usb_Dev_Record (D, 3968, C.Usb_Dev_Config);
      Put_Vcd_Profile_Record (D, 3972, C.Vcd_Profile);
      Put_Vtx_Io_Config_Record (D, 3975, C.Vtx_Io_Config);
      Put_Vtx_Table_Config_Record (D, 3980, C.Vtx_Table_Config);
      Put_Fly_Sky_Config_Record (D, 4263, C.Fly_Sky_Config);
      Put_Spektrum_Config_Record (D, 4283, C.Spektrum_Config);
      Put_Rx_Channel_Range_Config_Record_List_4 (D, 4289, C.Rx_Channel_Range_Configs);
      Put_Rx_Failsafe_Channel_Config_Record_List_18 (D, 4305, C.Rx_Failsafe_Channel_Configs);
      Put_Accelerometer_Config_Record (D, 4341, C.Accelerometer_Config);
      Put_Barometer_Config_Record (D, 4357, C.Barometer_Config);
      Put_Battery_Profile_Record_List_3 (D, 4367, C.Battery_Profiles);
      Put_Battery_Config_Record (D, 4430, C.Battery_Config);
      Put_Board_Alignment_Record (D, 4444, C.Board_Alignment);
      Put_Compass_Config_Record (D, 4456, C.Compass_Config);
      Put_Current_Sensor_Adc_Config_Record (D, 4478, C.Current_Sensor_Adc_Config);
      Put_Current_Sensor_Virtual_Config_Record (D, 4482, C.Current_Sensor_Virtual_Config);
      Put_Esc_Sensor_Config_Record (D, 4486, C.Esc_Sensor_Config);
      Put_Gyro_Config_Record (D, 4490, C.Gyro_Config);
      Put_Opticalflow_Config_Record (D, 4525, C.Opticalflow_Config);
      Put_Pitot_Config_Record (D, 4530, C.Pitot_Config);
      Put_Rangefinder_Config_Record (D, 4534, C.Rangefinder_Config);
      Put_Sonar_Config_Record (D, 4536, C.Sonar_Config);
      Put_Voltage_Sensor_Adc_Config_Record_List_1 (D, 4538, C.Voltage_Sensor_Adc_Config);
      Put_Telemetry_Config_Record (D, 4541, C.Telemetry_Config);
   end Encode;

   procedure Decode (D : Data; C : in out Configuration) is
   begin
      Get_Blackbox_Config_Record (D, 0, C.Blackbox_Config);
      Get_Time_Config_Record (D, 10, C.Time_Config);
      Get_System_Config_Record (D, 12, C.System_Config);
      Get_Feature_Config_Record (D, 29, C.Feature_Config);
      Get_Status_Led_Config_Record (D, 33, C.Status_Led_Config);
      Get_Serial_Pin_Config_Record (D, 37, C.Serial_Pin_Config);
      Get_Control_Rate_Config_Record_List_4 (D, 59, C.Control_Rate_Profiles);
      Get_Throttle_Correction_Config_Record (D, 183, C.Throttle_Correction_Config);
      Get_Adjustment_Range_Record_List_30 (D, 186, C.Adjustment_Ranges);
      Get_Rc_Controls_Config_Record (D, 456, C.Rc_Controls_Config);
      Get_Arming_Config_Record (D, 459, C.Arming_Config);
      Get_Flight3_D_Config_Record (D, 462, C.Flight3_D_Config);
      Get_Mode_Activation_Condition_Record_List_20 (D, 475, C.Mode_Activation_Conditions);
      Get_Mode_Activation_Config_Record (D, 595, C.Mode_Activation_Config);
      Get_Failsafe_Config_Record (D, 659, C.Failsafe_Config);
      Get_Imu_Config_Record (D, 670, C.Imu_Config);
      Get_Mixer_Config_Record (D, 678, C.Mixer_Config);
      Get_Motor_Mixer_Record_List_8 (D, 693, C.Custom_Motor_Mixer);
      Get_Tricopter_Mixer_Config_Record (D, 821, C.Tricopter_Mixer_Config);
      Get_Pid_Config_Record (D, 822, C.Pid_Config);
      Get_Pid_Profile_Record_List_4 (D, 827, C.Pid_Profiles);
      Get_Position_Config_Record (D, 1671, C.Position_Config);
      Get_Servo_Config_Record (D, 1679, C.Servo_Config);
      Get_Servo_Mixer_Record_List_16 (D, 1695, C.Custom_Servo_Mixers);
      Get_Servo_Param_Record_List_8 (D, 1807, C.Servo_Params);
      Get_Gimbal_Config_Record (D, 1903, C.Gimbal_Config);
      Get_Led_Strip_Config_Record (D, 1904, C.Led_Strip_Config);
      Get_Led_Strip_Status_Mode_Config_Record (D, 1920, C.Led_Strip_Status_Mode_Config);
      Get_Serial_Config_Record (D, 2160, C.Serial_Config);
      Get_Transponder_Config_Record (D, 2163, C.Transponder_Config);
      Get_Vtx_Config_Record (D, 2175, C.Vtx_Config);
      Get_Vtx_Settings_Config_Record (D, 2236, C.Vtx_Settings_Config);
      Get_Osd_Custom_Text_Config_Record (D, 2247, C.Osd_Custom_Text_Config);
      Get_Osd_Config_Record (D, 2248, C.Osd_Config);
      Get_Osd_Element_Config_Record (D, 2363, C.Osd_Element_Config);
      Get_Adc_Config_Record (D, 2561, C.Adc_Config);
      Get_Alt_Hold_Config_Record (D, 2580, C.Alt_Hold_Config);
      Get_Autopilot_Config_Record (D, 2582, C.Autopilot_Config);
      Get_Beeper_Dev_Config_Record (D, 2661, C.Beeper_Dev_Config);
      Get_Beeper_Config_Record (D, 2666, C.Beeper_Config);
      Get_Board_Config_Record (D, 2675, C.Board_Config);
      Get_I2c_Config_Record_List_3 (D, 2735, C.I2c_Config);
      Get_Spi_Pin_Config_Record_List_3 (D, 2750, C.Spi_Pin_Config);
      Get_Dashboard_Config_Record (D, 2765, C.Dashboard_Config);
      Get_Display_Port_Profile_Record (D, 2770, C.Display_Port_Profile_Msp);
      Get_Display_Port_Profile_Record (D, 2780, C.Display_Port_Profile_Max7456);
      Get_Dyn_Notch_Config_Record (D, 2790, C.Dyn_Notch_Config);
      Get_Flash_Config_Record (D, 2797, C.Flash_Config);
      Get_Flight_Plan_Config_Record (D, 2801, C.Flight_Plan_Config);
      Get_Gimbal_Track_Config_Record (D, 3432, C.Gimbal_Track_Config);
      Get_Gps_Lap_Timer_Config_Record (D, 3450, C.Gps_Lap_Timer_Config);
      Get_Gps_Config_Record (D, 3461, C.Gps_Config);
      Get_Gps_Rescue_Record (D, 3541, C.Gps_Rescue_Config);
      Get_Gyro_Device_Config_Record_List_1 (D, 3560, C.Gyro_Device_Config);
      Get_Max7456_Config_Record (D, 3575, C.Max7456_Config);
      Get_Mco_Config_Record_List_2 (D, 3579, C.Mco_Config);
      Get_Motor_Config_Record (D, 3585, C.Motor_Config);
      Get_Msp_Config_Record (D, 3621, C.Msp_Config);
      Get_Osd_Nav_Map_Config_Record (D, 3628, C.Osd_Nav_Map_Config);
      Get_Pilot_Config_Record (D, 3632, C.Pilot_Config);
      Get_Pinio_Box_Config_Record (D, 3734, C.Pinio_Box_Config);
      Get_Pinio_Config_Record (D, 3738, C.Pinio_Config);
      Get_Pin_Pull_Up_Down_Config_Record_List_4 (D, 3746, C.Pin_Pullup_Config);
      Get_Pin_Pull_Up_Down_Config_Record_List_4 (D, 3750, C.Pin_Pulldown_Config);
      Get_Pos_Hold_Config_Record (D, 3754, C.Pos_Hold_Config);
      Get_Rcdevice_Config_Record (D, 3759, C.Rcdevice_Config);
      Get_Rpm_Filter_Config_Record (D, 3770, C.Rpm_Filter_Config);
      Get_Rx_Config_Record (D, 3781, C.Rx_Config);
      Get_Pwm_Config_Record (D, 3832, C.Pwm_Config);
      Get_Ppm_Config_Record (D, 3841, C.Ppm_Config);
      Get_Rx_Cc2500_Spi_Config_Record (D, 3842, C.Rx_Cc2500_Spi_Config);
      Get_Rx_Express_Lrs_Spi_Config_Record (D, 3903, C.Rx_Express_Lrs_Spi_Config);
      Get_Rx_Spi_Config_Record (D, 3914, C.Rx_Spi_Config);
      Get_Scheduler_Config_Record (D, 3926, C.Scheduler_Config);
      Get_Sdcard_Config_Record (D, 3933, C.Sdcard_Config);
      Get_Serial_Uart_Config_Record_List_6 (D, 3938, C.Serial_Uart_Config);
      Get_Stats_Config_Record (D, 3950, C.Stats_Config);
      Get_Usb_Dev_Record (D, 3968, C.Usb_Dev_Config);
      Get_Vcd_Profile_Record (D, 3972, C.Vcd_Profile);
      Get_Vtx_Io_Config_Record (D, 3975, C.Vtx_Io_Config);
      Get_Vtx_Table_Config_Record (D, 3980, C.Vtx_Table_Config);
      Get_Fly_Sky_Config_Record (D, 4263, C.Fly_Sky_Config);
      Get_Spektrum_Config_Record (D, 4283, C.Spektrum_Config);
      Get_Rx_Channel_Range_Config_Record_List_4 (D, 4289, C.Rx_Channel_Range_Configs);
      Get_Rx_Failsafe_Channel_Config_Record_List_18 (D, 4305, C.Rx_Failsafe_Channel_Configs);
      Get_Accelerometer_Config_Record (D, 4341, C.Accelerometer_Config);
      Get_Barometer_Config_Record (D, 4357, C.Barometer_Config);
      Get_Battery_Profile_Record_List_3 (D, 4367, C.Battery_Profiles);
      Get_Battery_Config_Record (D, 4430, C.Battery_Config);
      Get_Board_Alignment_Record (D, 4444, C.Board_Alignment);
      Get_Compass_Config_Record (D, 4456, C.Compass_Config);
      Get_Current_Sensor_Adc_Config_Record (D, 4478, C.Current_Sensor_Adc_Config);
      Get_Current_Sensor_Virtual_Config_Record (D, 4482, C.Current_Sensor_Virtual_Config);
      Get_Esc_Sensor_Config_Record (D, 4486, C.Esc_Sensor_Config);
      Get_Gyro_Config_Record (D, 4490, C.Gyro_Config);
      Get_Opticalflow_Config_Record (D, 4525, C.Opticalflow_Config);
      Get_Pitot_Config_Record (D, 4530, C.Pitot_Config);
      Get_Rangefinder_Config_Record (D, 4534, C.Rangefinder_Config);
      Get_Sonar_Config_Record (D, 4536, C.Sonar_Config);
      Get_Voltage_Sensor_Adc_Config_Record_List_1 (D, 4538, C.Voltage_Sensor_Adc_Config);
      Get_Telemetry_Config_Record (D, 4541, C.Telemetry_Config);
   end Decode;

end Adaflight.Config_Codec;
