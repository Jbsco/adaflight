with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Blackbox_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_32;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; Log : Blackbox.Recorder;
      Loop_Time : Blackbox.Loop_Time_Us; R : out Result)
   is
      pragma Unreferenced (Command);
      Length   : constant Natural := Request'Length;
      Offset   : Offset_Range := 3;
      Ratio    : Interfaces.Unsigned_16;
      Rate     : Integer_64;
      Has_Mask : Boolean := False;
      Mask     : Interfaces.Unsigned_32 := 0;
      P        : Plan;
   begin
      if not Blackbox.May_Edit_Config (Log) then
         R := Ack;
         return;
      end if;
      Add (P, Blackbox_Device, U8 (Request, 0), 0);
      if Length - Offset >= 2 then
         Ratio := Interfaces.Unsigned_16 (U16 (Request, Offset));
         Offset := Offset + 2;
      else
         Ratio := Interfaces.Unsigned_16'Mod
           (Blackbox.P_Denominator
              (Log, Interfaces.Integer_32 (U8 (Request, 1)), Interfaces.Integer_32 (U8 (Request, 2))));
      end if;
      if Length - Offset >= 1 then
         Rate := Integer_64'Min (U8 (Request, Offset), Blackbox.Sample_Rate_Max);
         Offset := Offset + 1;
      else
         Rate := Integer_64 (Blackbox.Sample_Rate_For (Ratio, Loop_Time));
      end if;
      Add (P, Blackbox_Sample_Rate, Rate, 0);
      if Length - Offset >= 4 then
         Has_Mask := True;
         Mask := Interfaces.Unsigned_32 (U32 (Request, Offset));
      end if;
      if not Valid (P) or else (Mask and not Field_Bits) /= 0 then
         R := Error;
         return;
      end if;
      Apply (C, P);
      if Has_Mask then
         C.Blackbox_Config.Fields_Disabled_Mask := Mask;
      end if;
      R := Ack;
   end Process;

end Adaflight.MSP_Blackbox_In;
