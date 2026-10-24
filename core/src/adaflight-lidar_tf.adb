package body Adaflight.Lidar_TF with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Sync_Byte      : constant Byte := 16#59#;
   Frame_Length   : constant := 6;
   Timeout_Ms     : constant := 200;
   Reconf_Gap_Ms  : constant := 500;
   Task_Period_Ms : constant := 10;
   Cone           : constant := 900;
   Baud           : constant := 115_200;
   Integral_Time  : constant := 4;
   Reliability    : constant := 4;
   Confidence     : constant := 5;
   Out_Of_Range   : constant Reading := -1;
   Config_Command : constant Byte_Array (0 .. 7) := (16#42#, 16#57#, 16#02#, 0, 0, 0, 16#01#, 16#06#);

   procedure Configure (D : in out Serial_Device; S : State) is
   begin
      if S.Hardware = TFmini or else S.Hardware = TF02 then
         Write_Bytes (D, Config_Command);
      end if;
   end Configure;

   procedure Detect
     (D : in out Serial_Device; S : in out State; Hardware : Byte; Port : Interfaces.Integer_8; Found : out Boolean;
      Dev : out Device)
   is
      Range_Min, Range_Max : Interfaces.Unsigned_16;
   begin
      Dev := (others => <>);
      Found := False;
      case Hardware is
         when TFmini =>
            Range_Min := 40;
            Range_Max := 1200;
         when TF02 =>
            Range_Min := 40;
            Range_Max := 2200;
         when TFnova =>
            Range_Min := 10;
            Range_Max := 1400;
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
      S.Range_Min := Range_Min;
      S.Range_Max := Range_Max;
      Configure (D, S);
      Found := True;
   end Detect;

   procedure Init (S : in out State) is
   begin
      S.Phase := Wait_Start_1;
      S.Position := 0;
   end Init;

   procedure Process_Frame (S : in out State) is
      Distance : Interfaces.Unsigned_16 :=
        Interfaces.Unsigned_16 (S.Frame (0)) + Interfaces.Unsigned_16 (S.Frame (1)) * 256;
   begin
      S.Last_Distance := Distance;
      S.Last_Strength := Interfaces.Unsigned_16 (S.Frame (2)) + Interfaces.Unsigned_16 (S.Frame (3)) * 256;
      S.Last_Byte_4 := S.Frame (4);
      S.Last_Byte_5 := S.Frame (5);
      if Distance < S.Range_Min or else Distance > S.Range_Max then
         S.Value := Out_Of_Range;
         return;
      end if;
      case S.Hardware is
         when TFmini =>
            if S.Frame (Integral_Time) = 7 then
               Distance := Distance - 13;
            end if;
         when TF02 =>
            if S.Frame (Reliability) < 7 then
               S.Value := Out_Of_Range;
               return;
            end if;
         when TFnova =>
            if S.Frame (Confidence) < 90 then
               S.Value := Out_Of_Range;
               return;
            end if;
         when others =>
            S.Value := -2;
            return;
      end case;
      S.Value := Reading (Distance);
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
      Checksum : Byte;
   begin
      Millis (D, Now);
      if not S.Have_Port or else S.Hardware = 0 then
         return;
      end if;
      loop
         Bytes_Waiting (D, Waiting);
         exit when Waiting = 0;
         Read_Byte (D, C);
         case S.Phase is
            when Wait_Start_1 =>
               if C = Sync_Byte then
                  S.Phase := Wait_Start_2;
               end if;
            when Wait_Start_2 =>
               S.Phase := (if C = Sync_Byte then Reading_Payload else Wait_Start_1);
            when Reading_Payload =>
               if S.Position < Frame_Length then
                  S.Frame (S.Position) := C;
                  S.Position := S.Position + 1;
               end if;
               if S.Position = Frame_Length then
                  S.Phase := Wait_Checksum;
               end if;
            when Wait_Checksum =>
               Checksum := Sync_Byte + Sync_Byte;
               for I in S.Frame'Range loop
                  Checksum := Checksum + S.Frame (I);
               end loop;
               if C = Checksum then
                  Process_Frame (S);
                  S.Last_Frame_Ms := Now;
               else
                  S.Errors := S.Errors + 1;
               end if;
               S.Phase := Wait_Start_1;
               S.Position := 0;
         end case;
      end loop;
      if Later_Than (Now, S.Last_Frame_Ms, Timeout_Ms) and then Later_Than (Now, S.Last_Reconf_Ms, Reconf_Gap_Ms) then
         Configure (D, S);
         S.Last_Reconf_Ms := Now;
      end if;
   end Update;

end Adaflight.Lidar_TF;
