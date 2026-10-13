package body Adaflight.MSP_Serial_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;

   --  The port's baud rate of each class in the classes' order.
   procedure Write_Bauds (B : in out Byte_Array; S : in out Stream; V : Snapshot; Port : Target_Port)
     with Pre  => Fits (S, B) and then Remaining (S) >= 4,
          Post => S.Next = S.Next'Old + 4 and then S.Last = S.Last'Old
   is
      package SFM renames Adaflight.Serial_Feature_Map;
   begin
      for C in SFM.Baud_Class loop
         pragma Loop_Invariant
           (S.Next = S.Next'Loop_Entry + SFM.Baud_Class'Pos (C) and then S.Last = S.Last'Loop_Entry);
         Write_U8 (B, S, Byte (SFM.Port_Baud (V.Options, V.Assignments, Port, C)));
      end loop;
   end Write_Bauds;

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
      Start : constant Position := S.Next with Ghost;
   begin
      case Command is
         when CF_Serial_Config_Command =>
            for I in 1 .. V.Port_Count loop
               pragma Loop_Invariant (S.Next in Start .. Start + 7 * (I - 1) and then S.Last = S.Last'Loop_Entry);
               if V.Ports (I).Available then
                  Write_U8 (B, S, Byte (V.Ports (I).Port));
                  Write_U16 (B, S, 0);
                  Write_Bauds (B, S, V, V.Ports (I).Port);
               end if;
            end loop;
         when Common_Serial_Config_Command =>
            declare
               Count : Natural := 0;
            begin
               for I in 1 .. V.Port_Count loop
                  pragma Loop_Invariant (Count < I);
                  if V.Ports (I).Available then
                     Count := Count + 1;
                  end if;
               end loop;
               Write_U8 (B, S, Byte (Count));
            end;
            for I in 1 .. V.Port_Count loop
               pragma Loop_Invariant
                 (S.Next in Start + 1 .. Start + 1 + 9 * (I - 1) and then S.Last = S.Last'Loop_Entry);
               if V.Ports (I).Available then
                  Write_U8 (B, S, Byte (V.Ports (I).Port));
                  Write_U32 (B, S, 0);
                  Write_Bauds (B, S, V, V.Ports (I).Port);
               end if;
            end loop;
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Serial_Out;
