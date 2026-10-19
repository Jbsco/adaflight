package body Adaflight.UPT1 with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;

   subtype I32 is Interfaces.Integer_32;
   subtype U32 is Interfaces.Unsigned_32;

   Header               : constant Byte := 16#FE#;
   Length_Byte          : constant Byte := 16#0A#;
   Footer               : constant Byte := 16#55#;
   Laser_Available      : constant Byte := 16#F5#;
   Baud                 : constant := 115_200;
   Startup_Bytes        : constant := 22;
   Range_Min_Mm         : constant := 25;
   Range_Max_Mm         : constant := 12_000;
   Flow_Min_Range_Mm    : constant := 80;
   Flow_Scale           : constant := 10_000.0;
   Max_Integration_Us   : constant := 1_000_000;
   Max_Invalid_Frames   : constant := 5;
   Cone                 : constant := 900;
   Config_Command       : constant Byte_Array (0 .. 21) :=
     (16#3C#, 16#73#, 16#65#, 16#74#, 16#20#, 16#70#, 16#72#, 16#6F#, 16#74#, 16#6F#, 16#63#, 16#6F#, 16#6C#,
      16#20#, 16#75#, 16#70#, 16#69#, 16#78#, 16#65#, 16#6C#, 16#73#, 16#3E#);

   function To_U32 (X : I32) return U32 is
     (if X >= 0 then U32 (X) else U32 (X + 2_147_483_647 + 1) + 2 ** 31)
     with Global => null;

   function To_I32 (U : U32) return I32 is
     (if U < 2 ** 31 then I32 (U) else I32 (U - 2 ** 31) - 2_147_483_647 - 1)
     with Global => null;

   function Wrap_Add (A : I32; B : I32) return I32 is (To_I32 (To_U32 (A) + To_U32 (B)))
     with Global => null;

   function Signed_16 (Low : Byte; High : Byte) return Interfaces.Integer_16 is
     (if High >= 128 then Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low) - 65_536)
      else Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low)))
     with Global => null;

   procedure Open (D : in out Serial_Device; S : in out State; Port : Interfaces.Integer_8; OK : out Boolean) is
   begin
      if S.Have_Port then
         OK := True;
         return;
      end if;
      if Port = Port_None then
         OK := False;
         return;
      end if;
      Open_Port (D, Port, Baud, S.Have_Port);
      OK := S.Have_Port;
   end Open;

   procedure Detect_Rangefinder
     (D : in out Serial_Device; S : in out State; Port : Interfaces.Integer_8; Found : out Boolean;
      Dev : out Rangefinder_Device)
   is
   begin
      Dev := (others => <>);
      Open (D, S, Port, Found);
      if Found then
         Dev := (Delay_Ms => 10, Max_Range_Cm => Range_Max_Mm / 10, Cone_Decidegrees => Cone,
                 Cone_Extended_Decidegrees => Cone);
      end if;
   end Detect_Rangefinder;

   procedure Detect_Flow
     (D : in out Serial_Device; S : in out State; Port : Interfaces.Integer_8; Found : out Boolean;
      Dev : out Flow_Device)
   is
   begin
      Dev := (others => <>);
      Open (D, S, Port, Found);
      if Found then
         Dev := (Delay_Ms => 20, Min_Range_Cm => Flow_Min_Range_Mm / 10, Min_Quality => 30, Gyro_Delay_Us => 60_000);
      end if;
   end Detect_Flow;

   procedure Init (S : in out State) is
   begin
      S.Phase := Wait_Reset;
      S.Position := 0;
      S.Value := Out_Of_Range;
   end Init;

   --  A whole frame: the reading, the laser distance with its time and the
   --  flow validity, with the frame's integrals added to the update's sums.
   procedure Take_Frame
     (D : in out Serial_Device; S : in out State; Sum_X : in out I32; Sum_Y : in out I32;
      Integration_Sum : in out U32; Flow_Frames : in out U32; Invalid_Frames : in out U32)
   is
      Flow_X       : constant Interfaces.Integer_16 := Signed_16 (S.Frame (0), S.Frame (1));
      Flow_Y       : constant Interfaces.Integer_16 := Signed_16 (S.Frame (2), S.Frame (3));
      Integration  : constant Interfaces.Unsigned_16 :=
        Interfaces.Unsigned_16 (S.Frame (4)) + Interfaces.Unsigned_16 (S.Frame (5)) * 256;
      Distance_Mm  : constant Interfaces.Unsigned_16 :=
        Interfaces.Unsigned_16 (S.Frame (6)) + Interfaces.Unsigned_16 (S.Frame (7)) * 256;
      Valid_Status : constant Byte := S.Frame (8);
      Confidence   : constant Byte := S.Frame (9);
      Laser_Valid  : constant Boolean := Valid_Status = Laser_Available;
      In_Range     : constant Boolean := Distance_Mm in Range_Min_Mm .. Range_Max_Mm;
      Range_Valid  : constant Boolean := Laser_Valid and then Distance_Mm in Flow_Min_Range_Mm .. Range_Max_Mm;
      Dt_Valid     : constant Boolean := Integration > 0;
   begin
      S.Debug.Distance_Mm := Distance_Mm;
      S.Debug.Confidence := Confidence;
      S.Debug.Flow_X := Flow_X;
      S.Debug.Flow_Y := Flow_Y;
      S.Debug.Valid_Status := Valid_Status;
      S.Debug.Integration_Us := Integration;
      if Laser_Valid and then In_Range then
         S.Value := I32 (Distance_Mm / 10);
         S.Debug.Reported := S.Value;
      else
         S.Value := Out_Of_Range;
         S.Debug.Reported := -99;
      end if;
      S.Has_New := True;
      S.Distance_Mm := (if Laser_Valid and then In_Range then I32 (Distance_Mm) else Out_Of_Range);
      Micros (D, S.Distance_Time_Us);
      S.Flow.Range_Valid := Range_Valid;
      S.Flow.Flow_Valid := Laser_Valid;
      S.Flow.Dt_Valid := Dt_Valid;
      if Laser_Valid and then Dt_Valid then
         Sum_X := Wrap_Add (Sum_X, I32 (Flow_X));
         Sum_Y := Wrap_Add (Sum_Y, I32 (Flow_Y));
         Integration_Sum := Integration_Sum + U32 (Integration);
         Flow_Frames := Flow_Frames + 1;
         S.Flow_Quality := (if Range_Valid then Confidence else 0);
      else
         Invalid_Frames := Invalid_Frames + 1;
      end if;
   end Take_Frame;

   procedure Update (D : in out Serial_Device; S : in out State) is
      Waiting         : Natural;
      C               : Byte;
      Checksum        : Byte;
      Sum_X           : I32 := 0;
      Sum_Y           : I32 := 0;
      Integration_Sum : U32 := 0;
      Flow_Frames     : U32 := 0;
      Invalid_Frames  : U32 := 0;
      New_Count       : U32;
   begin
      if not S.Have_Port then
         return;
      end if;
      loop
         Bytes_Waiting (D, Waiting);
         exit when Waiting = 0;
         Read_Byte (D, C);
         S.Byte_Count := S.Byte_Count + 1;
         S.Debug.Phase_Seen := S.Phase;
         case S.Phase is
            when Wait_Reset =>
               if S.Byte_Count >= Startup_Bytes then
                  Write_Bytes (D, Config_Command);
                  S.Phase := Wait_Header;
               end if;
            when Wait_Header =>
               if C = Header then
                  S.Phase := Wait_Length;
               end if;
            when Wait_Length =>
               if C = Length_Byte then
                  S.Phase := Reading_Data;
                  S.Position := 0;
               else
                  S.Phase := Wait_Header;
               end if;
            when Reading_Data =>
               if S.Position < S.Frame'Length then
                  S.Frame (S.Position) := C;
                  S.Position := S.Position + 1;
               end if;
               if S.Position = S.Frame'Length then
                  S.Phase := Wait_Checksum;
               end if;
            when Wait_Checksum =>
               Checksum := 0;
               for I in S.Frame'Range loop
                  Checksum := Checksum xor S.Frame (I);
               end loop;
               if C = Checksum then
                  S.Phase := Wait_Footer;
               else
                  S.Errors := S.Errors + 1;
                  S.Phase := Wait_Header;
                  S.Position := 0;
               end if;
            when Wait_Footer =>
               if C = Footer then
                  Take_Frame (D, S, Sum_X, Sum_Y, Integration_Sum, Flow_Frames, Invalid_Frames);
               else
                  S.Errors := S.Errors + 1;
               end if;
               S.Phase := Wait_Header;
               S.Position := 0;
         end case;
      end loop;
      if Flow_Frames > 0 and then Integration_Sum in 1 .. Max_Integration_Us then
         declare
            Dt : constant Float := Float (Integration_Sum) / 1.0E6;
         begin
            pragma Assert (Dt in 9.0E-7 .. 1.0);
            S.Invalid_Count := 0;
            Micros (D, S.Flow.Time_Stamp_Us);
            S.Flow.Rate_X := Float (Sum_X) / Flow_Scale / Dt;
            S.Flow.Rate_Y := Float (Sum_Y) / Flow_Scale / Dt;
            S.Flow.Quality := Interfaces.Integer_16 (S.Flow_Quality);
         end;
      elsif Invalid_Frames > 0 then
         New_Count := U32 (S.Invalid_Count) + Invalid_Frames;
         if New_Count > Max_Invalid_Frames then
            S.Invalid_Count := Max_Invalid_Frames;
            S.Flow.Rate_X := 0.0;
            S.Flow.Rate_Y := 0.0;
            S.Flow.Quality := 0;
         else
            S.Invalid_Count := Natural (New_Count);
         end if;
      end if;
   end Update;

   procedure Read (S : in out State; Distance : out Reading) is
   begin
      if S.Has_New then
         S.Has_New := False;
         Distance := S.Value;
      else
         Distance := No_New_Data;
      end if;
   end Read;

end Adaflight.UPT1;
