with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Battery_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   Battery_Meter_Id : constant := 10;
   Virtual_Meter_Id : constant := 80;

   --  A plan of writes, checked together.
   procedure Set_Fields (C : in out Configuration; Fields : Plan; R : out Result)
     with Pre  => Fits (Fields),
          Post => (if R = Error then C = C'Old)
   is
   begin
      if not Valid (Fields) then
         R := Error;
         return;
      end if;
      Apply (C, Fields);
      R := Ack;
   end Set_Fields;

   --  The cell voltages in tenths of a volt and the capacity, the voltage and
   --  current meter sources, then the voltages in hundredths when six bytes
   --  remain. Fewer than seven bytes, or a minimum above the warning or a
   --  warning above the maximum, is an error.
   procedure Set_Battery_Config (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Battery_Profile_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Profile  : constant Natural := Natural (C.System_Config.Active_Battery_Profile);
      Minimum  : Integer_64 := U8 (Request, 0) * 10;
      Maximum  : Integer_64 := U8 (Request, 1) * 10;
      Warning  : Integer_64 := U8 (Request, 2) * 10;
      P        : Plan;
   begin
      if Request'Length < 7 then
         R := Error;
         return;
      end if;
      if Request'Length - 7 >= 6 then
         Minimum := U16 (Request, 7);
         Maximum := U16 (Request, 9);
         Warning := U16 (Request, 11);
      end if;
      if Minimum > Warning or else Warning > Maximum then
         R := Error;
         return;
      end if;
      Add (P, Battery_Meter, U8 (Request, 5), 0);
      Add (P, Current_Meter, U8 (Request, 6), 0);
      Add (P, Vbat_Min_Cell_Voltage, Minimum, Profile);
      Add (P, Vbat_Max_Cell_Voltage, Maximum, Profile);
      Add (P, Vbat_Warning_Cell_Voltage, Warning, Profile);
      Add (P, Bat_Capacity, U16 (Request, 3), Profile);
      Set_Fields (C, P, R);
   end Set_Battery_Config;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result)
   is
      P : Plan;
   begin
      case Command is
         when Set_Battery_Config_Command =>
            Set_Battery_Config (C, Request, R);
         when Set_Current_Meter_Config_Command =>
            if U8 (Request, 0) = Battery_Meter_Id then
               Add (P, Ibata_Scale, S16 (Request, 1), 0);
               Add (P, Ibata_Offset, S16 (Request, 3), 0);
            elsif U8 (Request, 0) = Virtual_Meter_Id then
               Add (P, Ibatv_Scale, S16 (Request, 1), 0);
               Add (P, Ibatv_Offset, U16 (Request, 3), 0);
            end if;
            Set_Fields (C, P, R);
         when Set_Voltage_Meter_Config_Command =>
            if U8 (Request, 0) = Battery_Meter_Id then
               Add (P, Vbat_Scale, U8 (Request, 1), 0);
               Add (P, Vbat_Divider, U8 (Request, 2), 0);
               Add (P, Vbat_Multiplier, U8 (Request, 3), 0);
            end if;
            Set_Fields (C, P, R);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Battery_In;
