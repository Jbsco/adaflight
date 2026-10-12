package body Adaflight.LTM_Telemetry with SPARK_Mode is

   Min_Sat_Count : constant := 4;
   Rssi_Max      : constant := 1023;

   type Frame is record
      Out_Buf : Output;
      Crc     : Byte := 0;
   end record;

   procedure Start (F : in out Frame; Id : Character)
     with Pre  => F.Out_Buf.Count <= Max_Output - 3,
          Post => F.Out_Buf.Count = F.Out_Buf.Count'Old + 3
   is
   begin
      F.Crc := 0;
      F.Out_Buf.Data (F.Out_Buf.Count) := Character'Pos ('$');
      F.Out_Buf.Data (F.Out_Buf.Count + 1) := Character'Pos ('T');
      F.Out_Buf.Data (F.Out_Buf.Count + 2) := Character'Pos (Id);
      F.Out_Buf.Count := F.Out_Buf.Count + 3;
   end Start;

   procedure Put_8 (F : in out Frame; V : Unsigned_8)
     with Pre  => F.Out_Buf.Count <= Max_Output - 1,
          Post => F.Out_Buf.Count = F.Out_Buf.Count'Old + 1
   is
   begin
      F.Out_Buf.Data (F.Out_Buf.Count) := V;
      F.Out_Buf.Count := F.Out_Buf.Count + 1;
      F.Crc := F.Crc xor V;
   end Put_8;

   procedure Put_16 (F : in out Frame; V : Unsigned_16)
     with Pre  => F.Out_Buf.Count <= Max_Output - 2,
          Post => F.Out_Buf.Count = F.Out_Buf.Count'Old + 2
   is
   begin
      Put_8 (F, Unsigned_8 (V and 16#FF#));
      Put_8 (F, Unsigned_8 (Interfaces.Shift_Right (V, 8)));
   end Put_16;

   procedure Put_32 (F : in out Frame; V : Unsigned_32)
     with Pre  => F.Out_Buf.Count <= Max_Output - 4,
          Post => F.Out_Buf.Count = F.Out_Buf.Count'Old + 4
   is
   begin
      Put_16 (F, Unsigned_16 (V and 16#FFFF#));
      Put_16 (F, Unsigned_16 (Interfaces.Shift_Right (V, 16)));
   end Put_32;

   procedure Finish (F : in out Frame)
     with Pre  => F.Out_Buf.Count <= Max_Output - 1,
          Post => F.Out_Buf.Count = F.Out_Buf.Count'Old + 1
   is
   begin
      F.Out_Buf.Data (F.Out_Buf.Count) := F.Crc;
      F.Out_Buf.Count := F.Out_Buf.Count + 1;
   end Finish;

   function To_U16 (I : Integer_16) return Unsigned_16 is
     (if I < 0 then Unsigned_16 (Integer (I) + 2 ** 16) else Unsigned_16 (I));

   function To_U32 (I : Integer_32) return Unsigned_32 is
     (if I < 0 then Unsigned_32 (Interfaces.Integer_64 (I) + 2 ** 32) else Unsigned_32 (I));

   --  The attitude in whole degrees.
   procedure Attitude_Frame (F : in out Frame; Inp : Inputs)
     with Pre  => F.Out_Buf.Count <= Max_Output - 10,
          Post => F.Out_Buf.Count = F.Out_Buf.Count'Old + 10
   is
   begin
      Start (F, 'A');
      Put_16 (F, To_U16 (Inp.Pitch / 10));
      Put_16 (F, To_U16 (Inp.Roll / 10));
      Put_16 (F, To_U16 (Inp.Yaw / 10));
      Finish (F);
   end Attitude_Frame;

   --  The battery in millivolts, the charge drawn held to sixteen bits,
   --  the signal scaled to a byte, no airspeed, the mode and the state.
   procedure Status_Frame (F : in out Frame; Inp : Inputs)
     with Pre  => F.Out_Buf.Count <= Max_Output - 11,
          Post => F.Out_Buf.Count = F.Out_Buf.Count'Old + 11
   is
      Mode   : constant Unsigned_8 :=
        (if Inp.Passthru then 0
         elsif Inp.Headfree then 4
         elsif Inp.Angle then 2
         elsif Inp.Horizon then 3
         elsif Inp.Rescue then 13
         elsif Inp.Position_Hold then 9
         elsif Inp.Altitude_Hold then 8
         else 1);
      State  : constant Unsigned_8 := (if Inp.Armed then 1 else 0) or (if Inp.Failsafe then 2 else 0);
      Scaled : constant Integer := (255 * Integer (Inp.Rssi)) / Rssi_Max;
   begin
      Start (F, 'S');
      Put_16 (F, Inp.Voltage_Cv * 10);
      Put_16 (F, Unsigned_16 (Integer_32'Max (0, Integer_32'Min (65_535, Inp.Mah_Drawn))));
      Put_8 (F, Unsigned_8 (Integer'Max (0, Integer'Min (255, Scaled))));
      Put_8 (F, 0);
      Put_8 (F, Interfaces.Shift_Left (Mode, 2) or State);
      Finish (F);
   end Status_Frame;

   --  The position, the ground speed in metres per second, the altitude
   --  and the satellites with the fix type.
   procedure GPS_Frame (F : in out Frame; Inp : Inputs)
     with Pre  => F.Out_Buf.Count <= Max_Output - 18,
          Post => F.Out_Buf.Count <= F.Out_Buf.Count'Old + 18
   is
      Fix_Type : constant Unsigned_8 :=
        (if not Inp.Fix then 1 elsif Inp.Num_Sat < Min_Sat_Count then 2 else 3);
   begin
      if not Inp.GPS_Present then
         return;
      end if;
      Start (F, 'G');
      Put_32 (F, To_U32 (Inp.Lat));
      Put_32 (F, To_U32 (Inp.Lon));
      Put_8 (F, Unsigned_8 ((Inp.Ground_Speed / 100) and 16#FF#));
      Put_32 (F, To_U32 (Inp.Altitude_Cm));
      Put_8 (F, Interfaces.Shift_Left (Inp.Num_Sat, 2) or Fix_Type);
      Finish (F);
   end GPS_Frame;

   --  The home position without an altitude, the display always on, and
   --  the home fix.
   procedure Origin_Frame (F : in out Frame; Inp : Inputs)
     with Pre  => F.Out_Buf.Count <= Max_Output - 18,
          Post => F.Out_Buf.Count = F.Out_Buf.Count'Old + 18
   is
   begin
      Start (F, 'O');
      Put_32 (F, To_U32 (Inp.Home_Lat));
      Put_32 (F, To_U32 (Inp.Home_Lon));
      Put_32 (F, 0);
      Put_8 (F, 1);
      Put_8 (F, (if Inp.Fix_Home then 1 else 0));
      Finish (F);
   end Origin_Frame;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out Stream; Inp : Inputs; Now_Ms : Unsigned_32; Enabled : Boolean; O : out Output) is
      F : Frame;
   begin
      O := (others => <>);
      if not Enabled then
         return;
      end if;
      if Now_Ms - S.Last_Cycle_Ms >= Cycle_Ms then
         Attitude_Frame (F, Inp);
         if (S.Step and 1) /= 0 then
            GPS_Frame (F, Inp);
         else
            Status_Frame (F, Inp);
         end if;
         if S.Step = 0 then
            Origin_Frame (F, Inp);
         end if;
         S.Step := (S.Step + 1) mod 10;
         S.Last_Cycle_Ms := Now_Ms;
         O := F.Out_Buf;
      end if;
   end Update;

end Adaflight.LTM_Telemetry;
