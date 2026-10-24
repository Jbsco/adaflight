package body Adaflight.Nooploop with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   Sync_0         : constant Byte := 16#57#;
   Sync_1         : constant Byte := 16#00#;
   Frame_Length   : constant := 16;
   Timeout_Ms     : constant := 200;
   Task_Period_Ms : constant := 10;
   Cone           : constant := 900;
   Baud           : constant := 115_200;
   Invalid_Status : constant Byte := 16#FF#;

   procedure Detect
     (D : in out Serial_Device; S : in out State; Hardware : Byte; Port : Interfaces.Integer_8; Found : out Boolean;
      Dev : out Device)
   is
      Range_Max : Range_Cm;
   begin
      Dev := (others => <>);
      Found := False;
      case Hardware is
         when Model_F =>
            Range_Max := 1000;
         when Model_FP | Model_F2P =>
            Range_Max := 1700;
         when Model_F2 | Model_F2MINI =>
            Range_Max := 500;
         when Model_F2PH =>
            Range_Max := 3300;
         when others =>
            return;
      end case;
      if Port = Port_None then
         return;
      end if;
      Open_Port (D, Port, Baud, S.Have_Port);
      if not S.Have_Port then
         return;
      end if;
      Dev := (Delay_Ms => Task_Period_Ms, Max_Range_Cm => Range_Max, Cone_Decidegrees => Cone,
              Cone_Extended_Decidegrees => Cone);
      S.Hardware := Hardware;
      S.Range_Min_Cm := 2;
      S.Range_Max_Cm := Range_Max;
      Found := True;
   end Detect;

   procedure Init (S : in out State) is
   begin
      S.Phase := Wait_Sync_0;
      S.Position := 0;
      S.Latest := No_New_Data;
      S.Has_New := False;
   end Init;

   --  The frame's reading, no new data for a wrong sum.
   function Process_Frame (S : State) return Reading is
      Sum         : Byte := 0;
      Distance_Mm : Interfaces.Integer_32;
   begin
      for I in 0 .. Frame_Length - 2 loop
         Sum := Sum + S.Frame (I);
      end loop;
      if Sum /= S.Frame (Frame_Length - 1) then
         return No_New_Data;
      end if;
      Distance_Mm :=
        Interfaces.Integer_32 (S.Frame (8)) + Interfaces.Integer_32 (S.Frame (9)) * 2 ** 8
        + Interfaces.Integer_32 (S.Frame (10)) * 2 ** 16;
      if Distance_Mm >= 2 ** 23 then
         return Out_Of_Range;
      end if;
      if Distance_Mm < Interfaces.Integer_32 (S.Range_Min_Cm) * 10
        or else Distance_Mm > Interfaces.Integer_32 (S.Range_Max_Cm) * 10
      then
         return Out_Of_Range;
      end if;
      if S.Frame (11) = Invalid_Status then
         return Out_Of_Range;
      end if;
      return Distance_Mm / 10;
   end Process_Frame;

   --  Whether more than the given milliseconds passed since a time, as a
   --  signed 32-bit difference.
   function Later_Than (Now : Interfaces.Unsigned_32; Since : Interfaces.Unsigned_32; Ms : Interfaces.Unsigned_32)
     return Boolean is
     (Now - Since < 2 ** 31 and then Now - Since > Ms)
     with Global => null;

   procedure Update (D : in out Serial_Device; S : in out State) is
      Now      : Interfaces.Unsigned_32;
      Waiting  : Natural;
      C        : Byte;
      Distance : Reading;
   begin
      Millis (D, Now);
      if not S.Have_Port then
         return;
      end if;
      if S.First_Update_Ms = 0 then
         S.First_Update_Ms := Now;
      end if;
      loop
         Bytes_Waiting (D, Waiting);
         exit when Waiting = 0;
         Read_Byte (D, C);
         case S.Phase is
            when Wait_Sync_0 =>
               if C = Sync_0 then
                  S.Frame (0) := C;
                  S.Phase := Wait_Sync_1;
               end if;
            when Wait_Sync_1 =>
               if C = Sync_1 then
                  S.Frame (1) := C;
                  S.Position := 2;
                  S.Phase := Reading_Frame;
               elsif C = Sync_0 then
                  S.Frame (0) := C;
               else
                  S.Phase := Wait_Sync_0;
               end if;
            when Reading_Frame =>
               if S.Position < Frame_Length then
                  S.Frame (S.Position) := C;
                  S.Position := S.Position + 1;
               end if;
               if S.Position = Frame_Length then
                  Distance := Process_Frame (S);
                  if Distance /= No_New_Data then
                     S.Latest := Distance;
                     S.Has_New := True;
                     S.Last_Frame_Ms := Now;
                  end if;
                  S.Phase := Wait_Sync_0;
                  S.Position := 0;
               end if;
         end case;
      end loop;
      if (S.Last_Frame_Ms /= 0 and then Later_Than (Now, S.Last_Frame_Ms, Timeout_Ms))
        or else (S.Last_Frame_Ms = 0 and then Later_Than (Now, S.First_Update_Ms, Timeout_Ms))
      then
         if Later_Than (Now, S.Last_Failure_Ms, Timeout_Ms) then
            if S.Latest /= Hardware_Failure then
               S.Latest := Hardware_Failure;
               S.Has_New := True;
            end if;
            S.Last_Failure_Ms := Now;
         end if;
      end if;
   end Update;

   procedure Read (S : in out State; Distance : out Reading) is
   begin
      if not S.Has_New then
         Distance := No_New_Data;
         return;
      end if;
      S.Has_New := False;
      Distance := S.Latest;
   end Read;

end Adaflight.Nooploop;
