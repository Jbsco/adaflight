with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Feature_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   Motor_Count : constant := 8;

   --  The beeper conditions, then the beacon's tone when a byte remains and
   --  the beacon conditions when four bytes remain.
   procedure Set_Beeper_Config (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Length      : constant Natural := Request'Length;
      Beeper_Off  : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (U32 (Request, 0));
      Offset      : Offset_Range := 4;
      Has_Beacon  : Boolean := False;
      Beacon_Off  : Interfaces.Unsigned_32 := 0;
      P           : Plan;
   begin
      if Length - Offset >= 1 then
         Add (P, Beeper_Dshot_Beacon_Tone, U8 (Request, Offset), 0);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 4 then
         Has_Beacon := True;
         Beacon_Off := Interfaces.Unsigned_32 (U32 (Request, Offset));
      end if;
      if (Beeper_Off and not Beeper_Allowed) /= 0
        or else (Beacon_Off and not Beacon_Allowed) /= 0
        or else not Valid (P)
      then
         R := Error;
         return;
      end if;
      C.Beeper_Config.Beeper_Off_Flags := Beeper_Off;
      Apply (C, P);
      if Has_Beacon then
         C.Beeper_Config.Dshot_Beacon_Off_Flags := Beacon_Off;
      end if;
      R := Ack;
   end Set_Beeper_Config;

   --  A count, then that many motor positions up to eight; the motors past
   --  the count keep their own place. A request without the count or with
   --  fewer positions than it names is an error.
   procedure Set_Motor_Output_Reordering (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Count : constant Integer_64 := U8 (Request, 0);
      P     : Plan;
   begin
      if Request'Length < 1 or else Integer_64 (Request'Length) - 1 < Integer_64'Min (Count, Motor_Count) then
         R := Error;
         return;
      end if;
      for I in 0 .. Motor_Count - 1 loop
         pragma Loop_Invariant (P.Count = I and then Fits (P));
         Add (P, Motor_Output_Reordering,
              (if Integer_64 (I) < Count then U8 (Request, 1 + I) else Integer_64 (I)), 0, I);
      end loop;
      Apply (C, P);
      R := Ack;
   end Set_Motor_Output_Reordering;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result)
   is
   begin
      case Command is
         when Set_Feature_Config_Command =>
            if (Interfaces.Unsigned_32 (U32 (Request, 0)) and not Named_Features) /= 0 then
               R := Error;
               return;
            end if;
            C.Feature_Config.Enabled_Features := Interfaces.Unsigned_32 (U32 (Request, 0));
            R := Ack;
         when Set_Beeper_Config_Command =>
            Set_Beeper_Config (C, Request, R);
         when Set_Motor_Output_Reordering_Command =>
            Set_Motor_Output_Reordering (C, Request, R);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Feature_In;
