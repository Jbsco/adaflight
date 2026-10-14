with Adaflight.Clock;

package body Adaflight.Scheduler with SPARK_Mode is
   use type Interfaces.Integer_64;

   Moving_Sum_Count    : constant := 8;
   Exec_Time_Shift     : constant := 7;
   Defer_Mask          : constant Unsigned_32 := 7;
   Start_Loop_Min_Us   : constant := 1;
   Start_Loop_Max_Us   : constant := 12;
   Start_Loop_Down     : constant := 50;
   Start_Loop_Up       : constant := 1;
   Guard_Min_Us        : constant := 3;
   Guard_Max_Us        : constant := 6;
   Guard_Down          : constant := 50;
   Guard_Up            : constant := 1;
   Check_Guard_Us      : constant := 2;
   Age_Expedite_Count  : constant := 1;
   Age_Expedite_Scale  : constant Float := 0.9;
   Gyro_Rate_Count     : constant := 25_000;
   Gyro_Lock_Count     : constant := 50;
   Failsafe_Period_Ms  : constant := 10;

   --  The reference's two-way casts between the signed and the unsigned
   --  32-bit counts, which keep the bit pattern.
   function To_Signed (U : Unsigned_32) return Integer_32 is (Clock.Elapsed (U, 0));

   function To_Unsigned (I : Integer_32) return Unsigned_32 is
     (if I < 0 then Unsigned_32 (Interfaces.Integer_64 (I) + 2 ** 32) else Unsigned_32 (I));

   function Static (Id : Task_Id) return Static_Priority is (Defaults (Id).Priority);

   function Contains (S : State; Id : Task_Id) return Boolean is
     (for some Q in 0 .. S.Queue_Size - 1 => S.Queue (Q) = Id);

   --  A task joins the queue ahead of the first task of a lower static
   --  priority, so equal priorities keep their order of arrival.
   procedure Queue_Add (S : in out State; Id : Task_Id)
     with Post => S.Queue_Size >= S.Queue_Size'Old
   is
   begin
      if S.Queue_Size = Task_Count or else Contains (S, Id) then
         return;
      end if;
      for Q in 0 .. S.Queue_Size loop
         if Q = S.Queue_Size or else Static (S.Queue (Q)) < Static (Id) then
            for J in reverse Q + 1 .. S.Queue_Size loop
               S.Queue (J) := S.Queue (J - 1);
            end loop;
            S.Queue (Q) := Id;
            S.Queue_Size := S.Queue_Size + 1;
            return;
         end if;
      end loop;
   end Queue_Add;

   procedure Queue_Remove (S : in out State; Id : Task_Id) is
   begin
      for Q in 0 .. S.Queue_Size - 1 loop
         if S.Queue (Q) = Id then
            for J in Q .. S.Queue_Size - 2 loop
               S.Queue (J) := S.Queue (J + 1);
            end loop;
            S.Queue_Size := S.Queue_Size - 1;
            return;
         end if;
      end loop;
   end Queue_Remove;

   function Gyro_Period_Cycles (S : State; C : Settings) return Integer_32 is
     (To_Signed (Micros_To_Cycles (C, To_Unsigned (S.Tasks (Gyro).Period))));

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; Now_Cycles : Cycles) is
      One_Us : constant Unsigned_32 := Micros_To_Cycles (C, 1);
   begin
      S := (Tasks => (others => <>), Queue => (others => System), Queue_Size => 0,
            Checks => <>, Pass => <>, others => <>);
      for T in Task_Id loop
         S.Tasks (T).Period := (if T in Gyro | Filter | PID then C.Gyro_Period_Us else Defaults (T).Period);
      end loop;
      Queue_Add (S, System);
      S.Loop_Start_Min := To_Signed (Micros_To_Cycles (C, Start_Loop_Min_Us));
      S.Loop_Start_Max := To_Signed (Micros_To_Cycles (C, Start_Loop_Max_Us));
      S.Loop_Start_Cycles := S.Loop_Start_Min;
      S.Loop_Start_Down := One_Us / Start_Loop_Down;
      S.Loop_Start_Up := One_Us / Start_Loop_Up;
      S.Guard_Min := To_Signed (Micros_To_Cycles (C, Guard_Min_Us));
      S.Guard_Max := To_Signed (Micros_To_Cycles (C, Guard_Max_Us));
      S.Guard_Cycles := S.Guard_Min;
      S.Guard_Down := One_Us / Guard_Down;
      S.Guard_Up := One_Us / Guard_Up;
      S.Desired_Period_Cycles := Gyro_Period_Cycles (S, C);
      S.Last_Target_Cycles := Now_Cycles;
   end Init;

   -----------------
   -- Enable_Gyro --
   -----------------

   procedure Enable_Gyro (S : in out State) is
   begin
      S.Gyro_Enabled := True;
   end Enable_Gyro;

   ----------------------
   -- Set_Task_Enabled --
   ----------------------

   procedure Set_Task_Enabled (S : in out State; Id : Task_Id; Enabled : Boolean) is
   begin
      if Enabled then
         Queue_Add (S, Id);
      else
         Queue_Remove (S, Id);
      end if;
   end Set_Task_Enabled;

   -------------
   -- Enabled --
   -------------

   function Enabled (S : State; Id : Task_Id) return Boolean is (Contains (S, Id));

   ----------------
   -- Reschedule --
   ----------------

   procedure Reschedule (S : in out State; C : Settings; Id : Task_Id; New_Period_Us : Time_Delta) is
   begin
      S.Tasks (Id).Period := Time_Delta'Max (C.Delay_Limit_Us, New_Period_Us);
      if Id = Gyro then
         S.Desired_Period_Cycles := Gyro_Period_Cycles (S, C);
      end if;
   end Reschedule;

   ------------------
   -- Current_Task --
   ------------------

   function Current_Task (S : State) return Task_Id is (S.Current);

   ----------------------------
   -- Ignore_Task_State_Time --
   ----------------------------

   procedure Ignore_Task_State_Time (S : in out State) is
   begin
      S.Ignore_Exec_Rate := True;
      S.Ignore_Exec_Time := True;
   end Ignore_Task_State_Time;

   procedure Ignore_Task_Exec_Rate (S : in out State) is
   begin
      S.Ignore_Exec_Rate := True;
   end Ignore_Task_Exec_Rate;

   procedure Ignore_Task_Exec_Time (S : in out State) is
   begin
      S.Ignore_Exec_Time := True;
   end Ignore_Task_Exec_Time;

   ---------------------------
   -- Reset_Task_Statistics --
   ---------------------------

   procedure Reset_Task_Statistics (S : in out State; Id : Task_Id) is
   begin
      S.Tasks (Id).Anticipated := 0;
      S.Tasks (Id).Moving_Sum_Delta := 0;
      S.Tasks (Id).Total_Exec_Us := 0;
      S.Tasks (Id).Max_Exec_Us := 0;
      S.Tasks (Id).Max_States_Exec_Us := 0;
   end Reset_Task_Statistics;

   procedure Reset_Task_Max_Execution_Time (S : in out State; Id : Task_Id) is
   begin
      S.Tasks (Id).Max_Exec_Us := 0;
      S.Tasks (Id).Max_States_Exec_Us := 0;
   end Reset_Task_Max_Execution_Time;

   procedure Reset_Check_Max_Execution_Time (S : in out State) is
   begin
      S.Checks.Max_Exec_Us := 0;
   end Reset_Check_Max_Execution_Time;

   -------------------------
   -- Set_Next_State_Time --
   -------------------------

   procedure Set_Next_State_Time (S : in out State; Next_Us : Time_Delta) is
   begin
      S.Next_State_Time := Next_Us;
   end Set_Next_State_Time;

   function Next_State_Time (S : State) return Time_Delta is
     (Time_Delta (Interfaces.Shift_Right (S.Tasks (S.Current).Anticipated, Exec_Time_Shift)));

   -----------------
   -- System_Load --
   -----------------

   procedure System_Load (S : in out State; Now_Us : Time_Us) is
      Delta_Us : constant Time_Delta := Clock.Elapsed (Now_Us, S.Load_Last_Us);
   begin
      if Delta_Us /= 0 then
         S.Average_Load_Percent :=
           Natural ((100 * S.Total_Exec_Us / To_Unsigned (Delta_Us)) mod 65_536);
         S.Total_Exec_Us := 0;
         S.Load_Last_Us := Now_Us;
      else
         Ignore_Task_Exec_Time (S);
      end if;
   end System_Load;

   ---------------------------
   -- Cycle_Time_Multiplier --
   ---------------------------

   function Cycle_Time_Multiplier (S : State; C : Settings) return Float is
      Configured : constant Float range 0.0 .. 4.3e9 :=
        Float (Micros_To_Cycles (C, To_Unsigned (S.Tasks (Gyro).Period)));
      Period     : constant Integer_32 range 1 .. Integer_32'Last := S.Desired_Period_Cycles;
      Measured   : constant Float := Float (Period);
   begin
      pragma Assert (Measured >= 1.0);
      pragma Assert (Measured <= 2.2e9);
      return Configured / Measured;
   end Cycle_Time_Multiplier;

   ----------------
   -- Begin_Pass --
   ----------------

   procedure Begin_Pass (S : in out State; Now_Cycles : Cycles; Poll : out Boolean) is
   begin
      S.Pass := (others => <>);
      Poll := False;
      if S.Gyro_Enabled then
         S.Pass.Now_Cycles := Now_Cycles;
         S.Pass.Next_Target := S.Last_Target_Cycles + To_Unsigned (S.Desired_Period_Cycles);
         S.Pass.Remaining := Clock.Elapsed (S.Pass.Next_Target, Now_Cycles);
         if S.Desired_Period_Cycles > 0 and then S.Pass.Remaining < -S.Desired_Period_Cycles then
            declare
               Period  : constant Interfaces.Integer_64 := Interfaces.Integer_64 (S.Desired_Period_Cycles);
               Skipped : constant Interfaces.Integer_64 :=
                 Period * (1 + Interfaces.Integer_64 (S.Pass.Remaining) / (-Period));
            begin
               S.Pass.Next_Target := S.Pass.Next_Target + Unsigned_32 (Skipped mod 2 ** 32);
            end;
            S.Pass.Remaining := Clock.Elapsed (S.Pass.Next_Target, Now_Cycles);
         end if;
         if S.Pass.Remaining < S.Loop_Start_Min and then S.Loop_Start_Cycles < S.Loop_Start_Max then
            S.Loop_Start_Cycles := To_Signed (To_Unsigned (S.Loop_Start_Cycles) + S.Loop_Start_Up);
         end if;
         if S.Pass.Remaining < S.Loop_Start_Cycles then
            if S.Loop_Start_Cycles > S.Loop_Start_Min then
               S.Loop_Start_Cycles := To_Signed (To_Unsigned (S.Loop_Start_Cycles) - S.Loop_Start_Down);
            end if;
            Poll := True;
         end if;
      end if;
   end Begin_Pass;

   -------------------
   -- Execute_Begin --
   -------------------

   procedure Execute_Begin (S : in out State; Id : Task_Id; Now_Us : Time_Us) is
   begin
      S.Has_Current := True;
      S.Current := Id;
      S.Ignore_Exec_Rate := False;
      S.Ignore_Exec_Time := False;
      S.Next_State_Time := -1;
      S.Tasks (Id).Last_Executed_Us := Now_Us;
      S.Tasks (Id).Last_Desired_Us := S.Tasks (Id).Last_Desired_Us + To_Unsigned (S.Tasks (Id).Period);
      S.Tasks (Id).Dynamic := 0;
      S.Pass.Current_Time_Us := Now_Us;
   end Execute_Begin;

   -----------------
   -- Execute_End --
   -----------------

   procedure Execute_End (S : in out State; Before_Us : Time_Us; After_Us : Time_Us) is
      Id       : constant Task_Id := S.Current;
      Now      : constant Time_Us := S.Pass.Current_Time_Us;
      Duration : constant Unsigned_32 := After_Us - Before_Us;
   begin
      S.Total_Exec_Us := S.Total_Exec_Us + Duration;
      if not S.Ignore_Exec_Time then
         S.Tasks (Id).Exec_Since_States := S.Tasks (Id).Exec_Since_States + Duration;
      end if;
      S.Tasks (Id).Moving_Sum_Exec :=
        S.Tasks (Id).Moving_Sum_Exec + (Duration * 10 - S.Tasks (Id).Moving_Sum_Exec / Moving_Sum_Count);
      if not S.Ignore_Exec_Rate then
         declare
            Delta_State : constant Unsigned_32 := Now - S.Tasks (Id).Last_Stats_Us;
         begin
            S.Tasks (Id).Latest_Delta_Us := To_Signed (Delta_State);
            S.Tasks (Id).Moving_Sum_Delta :=
              S.Tasks (Id).Moving_Sum_Delta
              + (To_Unsigned (S.Tasks (Id).Latest_Delta_Us) * 10 - S.Tasks (Id).Moving_Sum_Delta / Moving_Sum_Count);
            S.Tasks (Id).Last_Stats_Us := Now;
            S.Tasks (Id).Moving_Sum_States_Exec :=
              S.Tasks (Id).Moving_Sum_States_Exec
              + (S.Tasks (Id).Exec_Since_States * 10 - S.Tasks (Id).Moving_Sum_States_Exec / Moving_Sum_Count);
            S.Tasks (Id).Max_States_Exec_Us :=
              Unsigned_32'Max (S.Tasks (Id).Max_States_Exec_Us, S.Tasks (Id).Exec_Since_States);
            S.Tasks (Id).Exec_Since_States := 0;
         end;
      end if;
      if S.Next_State_Time /= -1 then
         S.Tasks (Id).Anticipated := Interfaces.Shift_Left (To_Unsigned (S.Next_State_Time), Exec_Time_Shift);
      elsif not S.Ignore_Exec_Time then
         if Duration > Interfaces.Shift_Right (S.Tasks (Id).Anticipated, Exec_Time_Shift) then
            S.Tasks (Id).Anticipated := Interfaces.Shift_Left (Duration, Exec_Time_Shift);
         elsif S.Tasks (Id).Anticipated > 1 then
            S.Tasks (Id).Anticipated := S.Tasks (Id).Anticipated - 1;
         end if;
      end if;
      if not S.Ignore_Exec_Time then
         S.Tasks (Id).Max_Exec_Us := Unsigned_32'Max (S.Tasks (Id).Max_Exec_Us, Duration);
      end if;
      S.Tasks (Id).Total_Exec_Us := S.Tasks (Id).Total_Exec_Us + Duration;
   end Execute_End;

   ------------------
   -- Failsafe_Due --
   ------------------

   function Failsafe_Due (S : State; Now_Ms : Time_Ms) return Boolean is
     (Clock.Elapsed (Now_Ms, S.Last_Failsafe_Ms) > Failsafe_Period_Ms);

   procedure Failsafe_Checked (S : in out State; Now_Ms : Time_Ms) is
   begin
      S.Last_Failsafe_Ms := Now_Ms;
   end Failsafe_Checked;

   ------------------
   -- End_Realtime --
   ------------------

   procedure End_Realtime (S : in out State; Now_Cycles : Cycles; G : Gyro_Status) is
   begin
      S.Pass.First_Opportunity := True;
      S.Pass.Now_Cycles := Now_Cycles;
      S.Last_Target_Cycles := S.Pass.Next_Target;
      if G.Interrupts then
         if S.Rate_Count_End = 0 then
            S.Rate_Count_End := G.Detected + Gyro_Rate_Count;
            S.Rate_Start_Cycles := To_Signed (Now_Cycles);
         end if;
         if G.Detected >= S.Rate_Count_End then
            S.Desired_Period_Cycles :=
              To_Signed ((Now_Cycles - To_Unsigned (S.Rate_Start_Cycles)) / Gyro_Rate_Count);
            S.Rate_Start_Cycles := To_Signed (Now_Cycles);
            S.Rate_Count_End := S.Rate_Count_End + Gyro_Rate_Count;
         end if;
         if S.Desired_Period_Cycles /= 0 then
            declare
               Skew : Integer_32 := Clock.Elapsed (S.Pass.Next_Target, G.Sync_Cycles) rem S.Desired_Period_Cycles;
            begin
               if Skew > S.Desired_Period_Cycles / 2 then
                  Skew := To_Signed (To_Unsigned (Skew) - To_Unsigned (S.Desired_Period_Cycles));
               end if;
               S.Skew_Sum := To_Signed (To_Unsigned (S.Skew_Sum) + To_Unsigned (Skew));
            end;
         end if;
         if S.Lock_Count_End = 0 then
            S.Lock_Count_End := G.Detected + Gyro_Lock_Count;
         end if;
         if G.Detected >= S.Lock_Count_End then
            S.Lock_Count_End := S.Lock_Count_End + Gyro_Lock_Count;
            S.Last_Target_Cycles := S.Last_Target_Cycles - To_Unsigned (S.Skew_Sum / Gyro_Lock_Count);
            S.Skew_Sum := 0;
         end if;
      end if;
   end End_Realtime;

   ---------------------
   -- Begin_Selection --
   ---------------------

   procedure Begin_Selection (
      S          : in out State;
      C          : Settings;
      Now_Cycles : Cycles;
      Now_Us     : Time_Us;
      Proceed    : out Boolean
   ) is
   begin
      S.Pass.Now_Cycles := Now_Cycles;
      S.Pass.Remaining := Clock.Elapsed (S.Pass.Next_Target, Now_Cycles);
      Proceed := not S.Gyro_Enabled
        or else S.Pass.Remaining > To_Signed (Micros_To_Cycles (C, Check_Guard_Us));
      S.Pass.Current_Time_Us := Now_Us;
   end Begin_Selection;

   ------------
   -- Queued --
   ------------

   function Queued (S : State; Q : Queue_Index) return Task_Id is (S.Queue (Q));

   function Needs_Check (S : State; Q : Queue_Index) return Boolean is
     (Static (S.Queue (Q)) /= Realtime and then Defaults (S.Queue (Q)).Has_Check
      and then S.Tasks (S.Queue (Q)).Dynamic = 0);

   function Check_Delta (S : State; Q : Queue_Index) return Time_Delta is
     (Clock.Elapsed (S.Pass.Current_Time_Us, S.Tasks (S.Queue (Q)).Last_Executed_Us));

   --------------
   -- Consider --
   --------------

   procedure Consider (
      S            : in out State;
      C            : Settings;
      Q            : Queue_Index;
      Check_Result : Boolean;
      Check_End_Us : Time_Us
   ) is
      Id  : constant Task_Id := S.Queue (Q);
      A   : constant Attributes := Defaults (Id);
      Now : constant Time_Us := S.Pass.Current_Time_Us;
   begin
      if A.Priority = Realtime then
         return;
      end if;
      if A.Has_Check then
         if S.Tasks (Id).Dynamic > 0 then
            S.Tasks (Id).Age_Periods :=
              Natural
                ((1 + Interfaces.Integer_64 (Clock.Elapsed (Now, S.Tasks (Id).Last_Signaled_Us) / S.Tasks (Id).Period))
                 mod 65_536);
            S.Tasks (Id).Dynamic := (1 + A.Priority * S.Tasks (Id).Age_Periods) mod 65_536;
         elsif Check_Result then
            declare
               Check_Us : constant Unsigned_32 := Check_End_Us - Now;
            begin
               S.Checks.Moving_Sum_Exec_Us :=
                 S.Checks.Moving_Sum_Exec_Us + (Check_Us - S.Checks.Moving_Sum_Exec_Us / Moving_Sum_Count);
               S.Checks.Moving_Sum_Delta_Us :=
                 S.Checks.Moving_Sum_Delta_Us
                 + (To_Unsigned (S.Tasks (Id).Latest_Delta_Us) - S.Checks.Moving_Sum_Delta_Us / Moving_Sum_Count);
               S.Checks.Total_Exec_Us := S.Checks.Total_Exec_Us + Check_Us;
               S.Checks.Max_Exec_Us := Unsigned_32'Max (S.Checks.Max_Exec_Us, Check_Us);
            end;
            S.Tasks (Id).Last_Signaled_Us := Now;
            S.Tasks (Id).Age_Periods := 1;
            S.Tasks (Id).Dynamic := 1 + A.Priority;
         else
            S.Tasks (Id).Age_Periods := 0;
         end if;
      else
         S.Tasks (Id).Age_Periods :=
           Natural ((Clock.Elapsed (Now, S.Tasks (Id).Last_Executed_Us) / S.Tasks (Id).Period) mod 65_536);
         if S.Tasks (Id).Age_Periods > 0 then
            S.Tasks (Id).Dynamic := (1 + A.Priority * S.Tasks (Id).Age_Periods) mod 65_536;
         end if;
      end if;
      if S.Tasks (Id).Dynamic > S.Pass.Selected_Dynamic then
         declare
            Required_Us : constant Unsigned_32 := Interfaces.Shift_Right (S.Tasks (Id).Anticipated, Exec_Time_Shift);
            Required    : constant Integer_32 :=
              To_Signed (Micros_To_Cycles (C, Required_Us) + S.Check_Cycles + To_Unsigned (S.Guard_Cycles));
         begin
            if Required < S.Pass.Remaining
              or else (S.Schedule_Count and Defer_Mask) = 0
              or else Id = Serial
            then
               S.Pass.Selected_Dynamic := S.Tasks (Id).Dynamic;
               S.Pass.Selected := True;
               S.Pass.Selected_Task := Id;
            end if;
         end;
      end if;
   end Consider;

   -------------------
   -- End_Selection --
   -------------------

   procedure End_Selection (S : in out State; Now_Cycles : Cycles; Selected : out Boolean) is
   begin
      S.Check_Cycles := Now_Cycles - S.Pass.Now_Cycles;
      Selected := S.Pass.Selected;
   end End_Selection;

   -------------
   -- Confirm --
   -------------

   procedure Confirm (S : in out State; C : Settings; Now_Cycles : Cycles; Run : out Boolean) is
      Id          : constant Task_Id := S.Pass.Selected_Task;
      Required_Us : constant Unsigned_32 := Interfaces.Shift_Right (S.Tasks (Id).Anticipated, Exec_Time_Shift);
      Required    : Integer_32 := To_Signed (Micros_To_Cycles (C, Required_Us));
   begin
      S.Pass.Now_Cycles := Now_Cycles;
      S.Pass.Remaining := Clock.Elapsed (S.Pass.Next_Target, Now_Cycles);
      Required := To_Signed (To_Unsigned (Required) + To_Unsigned (S.Guard_Cycles));
      if not S.Gyro_Enabled or else S.Pass.First_Opportunity or else Required < S.Pass.Remaining then
         S.Pass.Anticipated_End := Now_Cycles + To_Unsigned (Required);
         Run := True;
      else
         Run := False;
         declare
            Expedite : Boolean := S.Tasks (Id).Age_Periods > Age_Expedite_Count;
         begin
            if not Expedite and then Id = OSD and then C.OSD_Relax /= 0 then
               S.Skipped_OSD := (S.Skipped_OSD + 1) mod 256;
               Expedite := S.Skipped_OSD > C.OSD_Relax;
            end if;
            if not Expedite and then Id = Rx and then C.Rx_Relax /= 0 then
               S.Skipped_Rx := (S.Skipped_Rx + 1) mod 256;
               Expedite := S.Skipped_Rx > C.Rx_Relax;
            end if;
            if Expedite then
               declare
                  Scaled : constant Float range 0.0 .. 3.9e9 := Float (S.Tasks (Id).Anticipated) * Age_Expedite_Scale;
               begin
                  S.Tasks (Id).Anticipated := Unsigned_32 (Float'Truncation (Scaled));
               end;
            end if;
         end;
      end if;
   end Confirm;

   ------------------------
   -- Run_Selected_Begin --
   ------------------------

   procedure Run_Selected_Begin (S : in out State) is
   begin
      Execute_Begin (S, S.Pass.Selected_Task, S.Pass.Current_Time_Us);
   end Run_Selected_Begin;

   ---------------
   -- After_Run --
   ---------------

   procedure After_Run (S : in out State; Now_Cycles : Cycles) is
      Overdue : constant Integer_32 := Clock.Elapsed (Now_Cycles, S.Pass.Anticipated_End);
   begin
      if S.Current = Rx then
         S.Skipped_Rx := 0;
      elsif S.Current = OSD then
         S.Skipped_OSD := 0;
      end if;
      if Overdue > 0 or else -Interfaces.Integer_64 (Overdue) < Interfaces.Integer_64 (S.Guard_Min) then
         if S.Guard_Cycles < S.Guard_Max then
            S.Guard_Cycles := To_Signed (To_Unsigned (S.Guard_Cycles) + S.Guard_Up);
         end if;
      elsif S.Guard_Cycles > S.Guard_Min then
         S.Guard_Cycles := To_Signed (To_Unsigned (S.Guard_Cycles) - S.Guard_Down);
      end if;
   end After_Run;

   --------------
   -- End_Pass --
   --------------

   procedure End_Pass (S : in out State) is
   begin
      S.Schedule_Count := S.Schedule_Count + 1;
   end End_Pass;

end Adaflight.Scheduler;
