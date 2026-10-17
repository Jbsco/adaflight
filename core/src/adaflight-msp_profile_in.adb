with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Profile_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   Rate_Bit             : constant := 128;
   Battery_Bit          : constant := 64;
   PID_Profile_Count    : constant := 4;
   Rate_Profile_Count   : constant := 4;
   Battery_Profile_Count : constant := 3;

   --  An index within a count, or the first.
   function Within (Index : Integer_64; Count : Integer_64) return Byte is
     (if Index in 0 .. Count - 1 then Byte (Index) else 0)
     with Pre => Count in 1 .. 256;

   --  A battery profile when the battery bit is set, else a PID profile when
   --  the rate bit is clear and the board disarmed, else a rate profile.
   procedure Select_Profile (C : in out Configuration; Request : Byte_Array; Armed : Boolean; E : in out Effects)
     with Pre => Request'Length <= Max_Request
   is
      Value : constant Integer_64 := U8 (Request, 0);
   begin
      if Value mod (2 * Battery_Bit) >= Battery_Bit then
         C.System_Config.Active_Battery_Profile := Within (Value - Battery_Bit, Battery_Profile_Count);
         E.Battery_Profile := True;
      elsif Value < Rate_Bit then
         if not Armed then
            C.System_Config.Pid_Profile_Index := Within (Value, PID_Profile_Count);
            E.PID_Profile := True;
         end if;
      else
         C.System_Config.Active_Rate_Profile := Within (Value - Rate_Bit, Rate_Profile_Count);
         E.Rate_Profile := True;
      end if;
   end Select_Profile;

   --  A PID profile for kind 0 or a rate profile for kind 1, from a source
   --  onto a different destination, both within their list.
   procedure Copy_Profile (C : in out Configuration; Request : Byte_Array)
     with Pre => Request'Length <= Max_Request
   is
      Kind        : constant Integer_64 := U8 (Request, 0);
      Destination : constant Integer_64 := U8 (Request, 1);
      Source      : constant Integer_64 := U8 (Request, 2);
   begin
      if Kind = 0
        and then Destination < PID_Profile_Count
        and then Source < PID_Profile_Count
        and then Destination /= Source
      then
         C.Pid_Profiles (Natural (Destination)) := C.Pid_Profiles (Natural (Source));
      elsif Kind = 1
        and then Destination < Rate_Profile_Count
        and then Source < Rate_Profile_Count
        and then Destination /= Source
      then
         C.Control_Rate_Profiles (Natural (Destination)) := C.Control_Rate_Profiles (Natural (Source));
      end if;
   end Copy_Profile;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; Armed : Boolean;
      E : out Effects)
   is
   begin
      E := No_Effects;
      case Command is
         when Select_Setting_Command =>
            Select_Profile (C, Request, Armed, E);
         when Copy_Profile_Command =>
            Copy_Profile (C, Request);
         when others =>
            null;
      end case;
   end Process;

end Adaflight.MSP_Profile_In;
