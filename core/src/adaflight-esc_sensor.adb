package body Adaflight.ESC_Sensor with SPARK_Mode is

   function Word (High, Low : Byte) return Unsigned_16 is
     (Interfaces.Shift_Left (Unsigned_16 (High), 8) or Unsigned_16 (Low));

   function To_Signed (W : Unsigned_16) return Integer_16 is
     (if W >= 2 ** 15 then -Integer_16 (not W) - 1 else Integer_16 (W));

   ----------
   -- Init --
   ----------

   procedure Init (E : in out Sensor) is
   begin
      for M in Motor_Index loop
         E.Data (M).Data_Age := Data_Invalid;
         pragma Loop_Invariant (for all K in Motor_Index'First .. M => E.Data (K).Data_Age = Data_Invalid);
      end loop;
   end Init;

   -------------
   -- Receive --
   -------------

   procedure Receive (E : in out Sensor; C : Byte) is
   begin
      if Frame_Complete (E) then
         return;
      end if;
      E.Frame (E.Position) := C;
      E.Position := E.Position + 1;
   end Receive;

   --------------
   -- Checksum --
   --------------

   function Checksum (F : Frame_Bytes) return Byte is
      C : Byte := 0;
   begin
      for I in Frame_Index'First .. Frame_Index'Last - 1 loop
         C := CRC8 (C, F (I), Frame_Polynomial);
      end loop;
      return C;
   end Checksum;

   --  The motor after this one, back to the first past the count.
   procedure Next_Motor (E : in out Sensor; Count : Motor_Count) is
   begin
      if E.Motor + 1 = Count or else E.Motor = Motor_Index'Last then
         E.Motor := 0;
      else
         E.Motor := E.Motor + 1;
      end if;
   end Next_Motor;

   procedure Age (E : in out Sensor; M : Motor_Index) is
   begin
      if E.Data (M).Data_Age < Data_Invalid then
         E.Data (M).Data_Age := E.Data (M).Data_Age + 1;
         E.Combined_Stale := True;
      end if;
   end Age;

   -------------
   -- Process --
   -------------

   procedure Process (E : in out Sensor; Now : Time_Us; Count : Motor_Count; Motors_Enabled : Boolean;
                      Request : out Boolean) is
      Now_Ms : constant Unsigned_32 := Now / 1000;
   begin
      Request := False;
      if not Motors_Enabled then
         return;
      end if;
      case E.State is
         when Startup =>
            if Now_Ms >= Boot_Time_Ms then
               E.State := Ready;
            end if;
         when Ready =>
            E.Trigger_Time_Ms := Now_Ms;
            E.Position := 0;
            E.Size := Frame_Size;
            Request := True;
            E.State := Pending;
         when Pending =>
            if Now_Ms < E.Trigger_Time_Ms + Request_Timeout_Ms then
               if Frame_Complete (E) then
                  if Checksum (E.Frame) = E.Frame (Frame_Index'Last) then
                     E.Data (E.Motor) :=
                       (Data_Age    => 0,
                        Temperature => Unsigned_8 (E.Frame (0)),
                        Voltage     => Word (E.Frame (1), E.Frame (2)),
                        Current     => Integer_32 (Word (E.Frame (3), E.Frame (4))),
                        Consumption => Integer_32 (Word (E.Frame (5), E.Frame (6))),
                        Rpm         => To_Signed (Word (E.Frame (7), E.Frame (8))));
                     E.Combined_Stale := True;
                     Next_Motor (E, Count);
                     E.State := Ready;
                  else
                     Age (E, E.Motor);
                     Next_Motor (E, Count);
                     E.State := Ready;
                  end if;
               end if;
            else
               Age (E, E.Motor);
               Next_Motor (E, Count);
               E.State := Ready;
            end if;
      end case;
   end Process;

   ----------------------
   -- Combined_Reading --
   ----------------------

   procedure Combined_Reading (E : in out Sensor; Count : Motor_Count; R : out Reading) is
      C : Reading;
   begin
      if E.Combined_Stale then
         C := (Data_Age => 0, Temperature => 0, Voltage => 0, Current => 0, Consumption => 0, Rpm => 0);
         for M in 0 .. Count - 1 loop
            pragma Loop_Invariant (abs C.Current <= Integer_32 (M) * 2 ** 27);
            pragma Loop_Invariant (abs C.Consumption <= Integer_32 (M) * 2 ** 27);
            C.Data_Age := Unsigned_8'Max (C.Data_Age, E.Data (M).Data_Age);
            C.Temperature := Unsigned_8'Max (C.Temperature, E.Data (M).Temperature);
            C.Voltage := C.Voltage + E.Data (M).Voltage;
            C.Current := C.Current + E.Data (M).Current;
            C.Consumption := C.Consumption + E.Data (M).Consumption;
            C.Rpm := To_Signed (Unsigned_16'Mod (Integer (C.Rpm) + Integer (E.Data (M).Rpm)));
         end loop;
         C.Voltage := C.Voltage / Unsigned_16 (Count);
         C.Rpm := C.Rpm / Integer_16 (Count);
         E.Combined := C;
         E.Combined_Stale := False;
      end if;
      R := E.Combined;
   end Combined_Reading;

   ------------------
   -- Set_External --
   ------------------

   procedure Set_External (E : in out Sensor; M : Motor_Index; R : Reading) is
   begin
      E.Data (M) := R;
      E.Data (M).Data_Age := 0;
      E.Combined_Stale := True;
   end Set_External;

   ------------------
   -- External_Age --
   ------------------

   procedure External_Age (E : in out Sensor; M : Motor_Index) is
   begin
      Age (E, M);
   end External_Age;

end Adaflight.ESC_Sensor;
