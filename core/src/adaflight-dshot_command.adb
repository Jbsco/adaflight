package body Adaflight.DShot_Command with SPARK_Mode is

   procedure Set_Loop_Time (Q : in out Queue; Us : Loop_Time_Us) is
   begin
      Q.Loop_Us := Us;
   end Set_Loop_Time;

   procedure Streaming_Enabled (Q : in out Queue; F : Motor_Facts; Enabled : out Boolean) is
      Good_Delay : Boolean;
   begin
      if Q.First_Command then
         Good_Delay := F.Enable_Time_Ms /= 0 and then Elapsed_Ms (F.Now_Ms, F.Enable_Time_Ms) > Detection_Delay_Ms;
         if Good_Delay then
            Q.First_Command := False;
         end if;
      else
         Good_Delay := True;
      end if;
      Enabled := F.Enabled and then Good_Delay;
   end Streaming_Enabled;

   --  A blocking command needs the motors disabled, an inline one the
   --  streaming commands enabled.
   procedure Commands_Enabled (Q : in out Queue; F : Motor_Facts; Kind : Command_Type; Enabled : out Boolean)
     with Global => null;

   procedure Commands_Enabled (Q : in out Queue; F : Motor_Facts; Kind : Command_Type; Enabled : out Boolean) is
   begin
      case Kind is
         when Blocking =>
            Enabled := not F.Enabled;
         when Inline =>
            Streaming_Enabled (Q, F, Enabled);
      end case;
   end Commands_Enabled;

   procedure Write
     (Q           : in out Queue;
      F           : Motor_Facts;
      Index       : Unsigned_8;
      Motors      : Motor_Count;
      Command     : Unsigned_8;
      Kind        : Command_Type;
      Plan        : out Blocking_Plan)
   is
      Enabled     : Boolean;
      Repeats     : Unsigned_8 := 1;
      Delay_After : Unsigned_32 := Command_Delay_Us;
   begin
      Plan := (others => <>);
      if not F.DShot then
         return;
      end if;
      Commands_Enabled (Q, F, Kind, Enabled);
      if not Enabled or else Command > Max_Command or else Queue_Full (Q) then
         return;
      end if;
      case Command is
         when 7 | 8 | 9 | 10 | 12 | 20 | 21 | 13 | 14 =>
            Repeats := 10;
         when 1 .. 5 =>
            Delay_After := Beep_Delay_Us;
         when others =>
            null;
      end case;
      case Kind is
         when Blocking =>
            for I in 0 .. F.Count - 1 loop
               Q.Items (Q.Tail).Command (I) :=
                 (if Unsigned_8 (I) = Index or else Index = All_Motors then Command else Motor_Stop);
            end loop;
            Plan :=
              (Run => True, Repeats => Repeats, Delay_After_Us => Delay_After, Index => Index, Command => Command,
               Count => F.Count);
         when Inline =>
            declare
               H : constant Slot := Q.Head;
               C : Control renames Q.Items (H);
            begin
               Q.Head := Next (H);
               C.Repeats := Repeats;
               C.Delay_After_Us := Command_Delay_Us;
               for I in 0 .. Motors - 1 loop
                  C.Command (I) := (if Unsigned_8 (I) = Index or else Index = All_Motors then Command else Motor_Stop);
               end loop;
               if All_Idle (F) then
                  C.State := Start_Delay;
                  C.Cycle_Delay := Cycles_From_Time (Q, Initial_Delay_Us);
               else
                  C.State := Idle_Wait;
                  C.Cycle_Delay := 0;
               end if;
            end;
      end case;
   end Write;

   --  The queue's next entry after the current one ends, which goes out at
   --  once without the idle wait and the start delay; True when there is
   --  one.
   procedure Queue_Update (Q : in out Queue; Waiting : out Boolean)
     with Global => null;

   procedure Queue_Update (Q : in out Queue; Waiting : out Boolean) is
   begin
      Waiting := False;
      if not Queue_Empty (Q) then
         Q.Tail := Next (Q.Tail);
         if not Queue_Empty (Q) then
            Q.Items (Q.Tail).State := Active;
            Q.Items (Q.Tail).Cycle_Delay := 0;
            Waiting := True;
         end if;
      end if;
   end Queue_Update;

   procedure Output_Is_Enabled (Q : in out Queue; F : Motor_Facts; Enabled : out Boolean) is
      T       : constant Slot := Q.Tail;
      C       : Control renames Q.Items (T);
      Waiting : Boolean;
   begin
      Enabled := True;
      case C.State is
         when Idle_Wait =>
            if All_Idle (F) then
               C.State := Start_Delay;
               C.Cycle_Delay := Cycles_From_Time (Q, Initial_Delay_Us);
            end if;
            return;
         when Start_Delay =>
            if C.Cycle_Delay /= 0 then
               C.Cycle_Delay := C.Cycle_Delay - 1;
               Enabled := False;
               return;
            end if;
            C.State := Active;
            C.Cycle_Delay := 0;
         when Active | Post_Delay =>
            null;
      end case;
      if C.State = Active then
         if C.Cycle_Delay /= 0 then
            C.Cycle_Delay := C.Cycle_Delay - 1;
            Enabled := False;
            return;
         end if;
         C.Repeats := C.Repeats - 1;
         if C.Repeats /= 0 then
            C.Cycle_Delay := Cycles_From_Time (Q, Command_Delay_Us);
         else
            C.State := Post_Delay;
            C.Cycle_Delay := Cycles_From_Time (Q, C.Delay_After_Us);
            if not Is_Last (Q) and then C.Cycle_Delay > 0 then
               C.Cycle_Delay := C.Cycle_Delay - 1;
            end if;
         end if;
         return;
      end if;
      if C.Cycle_Delay /= 0 then
         C.Cycle_Delay := C.Cycle_Delay - 1;
         Enabled := False;
         return;
      end if;
      Queue_Update (Q, Waiting);
      if Waiting then
         Enabled := False;
      end if;
   end Output_Is_Enabled;

   procedure Command_Value (Q : Queue; Index : Motor_Index; Value : in out Unsigned_16; Request : in out Boolean) is
   begin
      if Is_Processing (Q) then
         Value := Unsigned_16 (Get_Current (Q, Index));
         if Value /= 0 then
            Request := True;
         end if;
      end if;
   end Command_Value;

   procedure Finish_Blocking (Q : in out Queue; Count : Motor_Count) is
   begin
      for I in 0 .. Count - 1 loop
         Q.Items (Q.Tail).Command (I) := Motor_Stop;
      end loop;
   end Finish_Blocking;

end Adaflight.DShot_Command;
