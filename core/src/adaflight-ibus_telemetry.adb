with Adaflight.Maths;

package body Adaflight.IBus_Telemetry with SPARK_Mode is

   Temperature_Offset : constant := 400;
   Min_Sat_Count      : constant := 4;

   Cmd_Discover    : constant Unsigned_8 := 16#80#;
   Cmd_Sensor_Type : constant Unsigned_8 := 16#90#;
   Cmd_Measurement : constant Unsigned_8 := 16#A0#;

   Id_Temperature      : constant Unsigned_8 := 16#01#;
   Id_Rpm_Flysky       : constant Unsigned_8 := 16#02#;
   Id_External_Voltage : constant Unsigned_8 := 16#03#;
   Id_Cell             : constant Unsigned_8 := 16#04#;
   Id_Bat_Curr         : constant Unsigned_8 := 16#05#;
   Id_Fuel             : constant Unsigned_8 := 16#06#;
   Id_Rpm              : constant Unsigned_8 := 16#07#;
   Id_Cmp_Head         : constant Unsigned_8 := 16#08#;
   Id_Climb_Rate       : constant Unsigned_8 := 16#09#;
   Id_Cog              : constant Unsigned_8 := 16#0A#;
   Id_GPS_Status       : constant Unsigned_8 := 16#0B#;
   Id_Acc_X            : constant Unsigned_8 := 16#0C#;
   Id_Acc_Y            : constant Unsigned_8 := 16#0D#;
   Id_Acc_Z            : constant Unsigned_8 := 16#0E#;
   Id_Roll             : constant Unsigned_8 := 16#0F#;
   Id_Pitch            : constant Unsigned_8 := 16#10#;
   Id_Yaw              : constant Unsigned_8 := 16#11#;
   Id_Vertical_Speed   : constant Unsigned_8 := 16#12#;
   Id_Ground_Speed     : constant Unsigned_8 := 16#13#;
   Id_GPS_Dist         : constant Unsigned_8 := 16#14#;
   Id_Armed            : constant Unsigned_8 := 16#15#;
   Id_Flight_Mode      : constant Unsigned_8 := 16#16#;
   Id_Pres             : constant Unsigned_8 := 16#41#;
   Id_Odo1             : constant Unsigned_8 := 16#7C#;
   Id_Odo2             : constant Unsigned_8 := 16#7D#;
   Id_Spe              : constant Unsigned_8 := 16#7E#;
   Id_GPS_Lat          : constant Unsigned_8 := 16#80#;
   Id_GPS_Lon          : constant Unsigned_8 := 16#81#;
   Id_GPS_Alt          : constant Unsigned_8 := 16#82#;
   Id_Alt              : constant Unsigned_8 := 16#83#;
   Id_Alt_Max          : constant Unsigned_8 := 16#84#;
   Id_GPS_Full         : constant Unsigned_8 := 16#FD#;
   Id_Volt_Full        : constant Unsigned_8 := 16#F0#;
   Id_Acc_Full         : constant Unsigned_8 := 16#EF#;

   Max_Frame : constant := 33;
   subtype Frame_Bytes is Byte_Array (0 .. Max_Frame - 1);

   --  The low sixteen bits of an integer, as the reference narrows its
   --  values to a two byte sensor.
   function Wrap (I : Integer) return Unsigned_16 is (Unsigned_16 (I mod 65536));

   function To_U32 (I : Integer_32) return Unsigned_32 is
     (if I < 0 then Unsigned_32 (Interfaces.Integer_64 (I) + 2 ** 32) else Unsigned_32 (I));

   function Rounded (X : Float) return Integer is
     (Integer (Adaflight.Maths.Round_Half_Even (Float'Max (-(2.0 ** 24 - 1.0), Float'Min (2.0 ** 24 - 1.0, X)))));

   function Is_GPS_Id (Id : Unsigned_8) return Boolean is
     (Id in Id_GPS_Status | Id_Spe | Id_GPS_Lat | Id_GPS_Lon | Id_GPS_Alt | Id_Ground_Speed | Id_Odo1 | Id_Odo2
           | Id_GPS_Dist | Id_Cog);

   --  The bytes of a sensor: four for the pressure, the positions and the
   --  altitudes, the sum of the parts for a combined one, else two.
   function Simple_Length (Id : Unsigned_8) return Natural is
     (if Id = Id_Pres or else Id in Id_GPS_Lat .. Id_Alt_Max then 4 else 2);

   function Sensor_Length (Id : Unsigned_8) return Natural is
     (if Id = Id_GPS_Full then 14 elsif Id = Id_Volt_Full then 10 elsif Id = Id_Acc_Full then 12
      else Simple_Length (Id));

   --  The temperature in tenths of a degree offset by forty degrees, from
   --  the barometer when present, else from the gyro.
   function Temperature (Inp : Inputs) return Unsigned_16 is
      T : Unsigned_16;
   begin
      if Inp.Baro_Present then
         T := Wrap (Rounded (Float (Inp.Baro_Temperature) / 10.0));
      else
         T := Wrap (Integer (Inp.Gyro_Temperature) * 10);
      end if;
      return T + Temperature_Offset;
   end Temperature;

   function Fuel (Inp : Inputs) return Unsigned_16 is
     (if Inp.Capacity > 0 then Unsigned_16 (Inp.Percent)
      else Wrap (Integer (Integer_32'Max (0, Integer_32'Min (16#FFFF#, Inp.Mah_Drawn)))));

   --  The throttle while armed, zero with the motors stopped, else the
   --  battery capacity.
   function Rpm (Inp : Inputs) return Unsigned_16 is
     (if Inp.Armed then (if Inp.Throttle_Low and then Inp.Motor_Stop then 0
                         else Wrap (Integer (Float'Truncation (Inp.Throttle))))
      else Inp.Capacity);

   --  The mode code of the receiver's display, the last matching flag
   --  deciding.
   function Mode (Inp : Inputs) return Unsigned_16 is
      M : Unsigned_16 := 1;
   begin
      if Inp.Angle_Like then
         M := 0;
      end if;
      if Inp.Passthru then
         M := 3;
      end if;
      if Inp.Headfree_Or_Mag then
         M := 4;
      end if;
      if Inp.Horizon then
         M := 7;
      end if;
      if Inp.Failsafe then
         M := 9;
      end if;
      return M;
   end Mode;

   function Acc_Value (Component : Acceleration; Rec : Gravity_Scale) return Unsigned_16 is
      Scaled : constant Float := (Component * Rec) * 1000.0;
   begin
      return Wrap (Integer (Float'Truncation (Float'Max (-32768.0, Float'Min (32767.0, Scaled)))));
   end Acc_Value;

   procedure Put_16 (Buf : in out Frame_Bytes; At_Pos : Natural; V : Unsigned_16)
     with Pre => At_Pos <= Max_Frame - 2
   is
   begin
      Buf (At_Pos) := Byte (V and 16#FF#);
      Buf (At_Pos + 1) := Byte (Interfaces.Shift_Right (V, 8));
   end Put_16;

   procedure Put_32 (Buf : in out Frame_Bytes; At_Pos : Natural; V : Unsigned_32)
     with Pre => At_Pos <= Max_Frame - 4
   is
   begin
      Buf (At_Pos) := Byte (V and 16#FF#);
      Buf (At_Pos + 1) := Byte (Interfaces.Shift_Right (V, 8) and 16#FF#);
      Buf (At_Pos + 2) := Byte (Interfaces.Shift_Right (V, 16) and 16#FF#);
      Buf (At_Pos + 3) := Byte (Interfaces.Shift_Right (V, 24));
   end Put_32;

   --  A GPS value: zero without the GPS sensor or a fix, the status
   --  always carrying the fix type and the satellites.
   procedure GPS_Value (Inp : Inputs; Id : Unsigned_8; Buf : in out Frame_Bytes; At_Pos : Natural)
     with Pre => At_Pos <= Max_Frame - 4
   is
      Fix_Type : constant Unsigned_8 :=
        (if not Inp.Fix then 1 elsif Inp.Num_Sat < Min_Sat_Count then 2 else 3);
   begin
      if not Inp.GPS_Present or else not (Inp.Fix or else Id = Id_GPS_Status) then
         return;
      end if;
      if Id = Id_Spe then
         Put_16 (Buf, At_Pos, Wrap (Integer (Inp.Ground_Speed) * 36 / 100));
      elsif Id = Id_GPS_Lat then
         Put_32 (Buf, At_Pos, To_U32 (Inp.Lat));
      elsif Id = Id_GPS_Lon then
         Put_32 (Buf, At_Pos, To_U32 (Inp.Lon));
      elsif Id = Id_GPS_Alt then
         Put_32 (Buf, At_Pos, To_U32 (Inp.Alt_Cm));
      elsif Id = Id_Ground_Speed then
         Put_16 (Buf, At_Pos, Inp.Ground_Speed);
      elsif Id in Id_Odo1 | Id_Odo2 | Id_GPS_Dist then
         Put_16 (Buf, At_Pos, Inp.Distance_Home);
      elsif Id = Id_Cog then
         Put_16 (Buf, At_Pos, Wrap (Integer (Inp.Ground_Course) * 100));
      elsif Id = Id_GPS_Status then
         Buf (At_Pos) := Fix_Type;
         Buf (At_Pos + 1) := Inp.Num_Sat;
      end if;
   end GPS_Value;

   --  One simple sensor's value at its place in the frame, zero for an id
   --  the link does not know.
   procedure Simple_Value (C : Settings; Inp : Inputs; Id : Unsigned_8; Buf : in out Frame_Bytes; At_Pos : Natural)
     with Pre => At_Pos <= Max_Frame - 4
   is
   begin
      for I in 0 .. Simple_Length (Id) - 1 loop
         Buf (At_Pos + I) := 0;
      end loop;
      if Is_GPS_Id (Id) then
         GPS_Value (Inp, Id, Buf, At_Pos);
         return;
      end if;
      case Id is
         when Id_External_Voltage =>
            Put_16 (Buf, At_Pos, (if C.Report_Cell_Voltage then Inp.Cell_Cv else Inp.Voltage_Cv));
         when Id_Temperature =>
            Put_16 (Buf, At_Pos, Temperature (Inp));
         when Id_Rpm_Flysky =>
            Put_16 (Buf, At_Pos, Wrap (Integer (Float'Truncation (Inp.Throttle))));
         when Id_Fuel =>
            Put_16 (Buf, At_Pos, Fuel (Inp));
         when Id_Rpm =>
            Put_16 (Buf, At_Pos, Rpm (Inp));
         when Id_Flight_Mode =>
            Put_16 (Buf, At_Pos, Mode (Inp));
         when Id_Cell =>
            Put_16 (Buf, At_Pos, Inp.Cell_Cv);
         when Id_Bat_Curr =>
            Put_16 (Buf, At_Pos, Unsigned_16 (To_U32 (Inp.Amperage_Ca) and 16#FFFF#));
         when Id_Acc_X =>
            Put_16 (Buf, At_Pos, Acc_Value (Inp.Acc_X, C.Acc_1G_Rec));
         when Id_Acc_Y =>
            Put_16 (Buf, At_Pos, Acc_Value (Inp.Acc_Y, C.Acc_1G_Rec));
         when Id_Acc_Z =>
            Put_16 (Buf, At_Pos, Acc_Value (Inp.Acc_Z, C.Acc_1G_Rec));
         when Id_Roll =>
            Put_16 (Buf, At_Pos, Wrap (Integer (Inp.Roll) * 10));
         when Id_Pitch =>
            Put_16 (Buf, At_Pos, Wrap (Integer (Inp.Pitch) * 10));
         when Id_Yaw =>
            Put_16 (Buf, At_Pos, Wrap (Integer (Inp.Yaw) * 10));
         when Id_Armed =>
            Put_16 (Buf, At_Pos, (if Inp.Armed then 1 else 0));
         when Id_Cmp_Head =>
            Put_16 (Buf, At_Pos, Wrap (Integer (Inp.Yaw / 10)));
         when Id_Vertical_Speed | Id_Climb_Rate =>
            Put_16 (Buf, At_Pos, Wrap (Integer (Inp.Vario_Cms)));
         when Id_Alt | Id_Alt_Max =>
            Put_32 (Buf, At_Pos, To_U32 (Integer_32 (Float'Truncation (Inp.Baro_Altitude))));
         when Id_Pres =>
            Put_32 (Buf, At_Pos,
                    To_U32 (Inp.Baro_Pressure) or Interfaces.Shift_Left (Unsigned_32 (Temperature (Inp)), 19));
         when others =>
            null;
      end case;
   end Simple_Value;

   type Id_List is array (Positive range <>) of Unsigned_8;

   GPS_Parts  : constant Id_List := (Id_GPS_Status, Id_GPS_Lat, Id_GPS_Lon, Id_GPS_Alt);
   Volt_Parts : constant Id_List := (Id_External_Voltage, Id_Cell, Id_Bat_Curr, Id_Fuel, Id_Rpm);
   Acc_Parts  : constant Id_List := (Id_Acc_X, Id_Acc_Y, Id_Acc_Z, Id_Roll, Id_Pitch, Id_Yaw);

   --  The parts of a combined sensor in turn.
   procedure Parts (C : Settings; Inp : Inputs; L : Id_List; Buf : in out Frame_Bytes)
     with Pre => L'Length <= 6
   is
      Pos : Natural := 2;
   begin
      for I in L'Range loop
         pragma Loop_Invariant (Pos <= 2 + 4 * (I - L'First));
         Simple_Value (C, Inp, L (I), Buf, Pos);
         Pos := Pos + Simple_Length (L (I));
      end loop;
   end Parts;

   --  A sensor's value, a combined one as its parts in turn.
   procedure Set_Value (C : Settings; Inp : Inputs; Id : Unsigned_8; Buf : in out Frame_Bytes) is
   begin
      if Id = Id_GPS_Full then
         Parts (C, Inp, GPS_Parts, Buf);
      elsif Id = Id_Volt_Full then
         Parts (C, Inp, Volt_Parts, Buf);
      elsif Id = Id_Acc_Full then
         Parts (C, Inp, Acc_Parts, Buf);
      else
         Simple_Value (C, Inp, Id, Buf, 2);
      end if;
   end Set_Value;

   function Checksum (Buf : Frame_Bytes; Data_Size : Natural) return Unsigned_16
     with Pre => Data_Size <= Max_Frame
   is
      Sum : Unsigned_16 := 16#FFFF#;
   begin
      for I in 0 .. Data_Size - 1 loop
         Sum := Sum - Unsigned_16 (Buf (I));
      end loop;
      return Sum;
   end Checksum;

   --  The answer to the window: the discovery echo, the sensor's id and
   --  length, or its measurement, each with the checksum; nothing for an
   --  address outside the table or an unknown command.
   procedure Respond (L : in out Link; C : Settings; Inp : Inputs; O : in out Output; Sent : out Natural) is
      Address : constant Unsigned_8 := L.Window (1) and 16#0F#;
      Command : constant Unsigned_8 := L.Window (1) and 16#F0#;
      Buf     : Frame_Bytes := (others => 0);
      Length  : Natural;
      Index   : Unsigned_8;
   begin
      Sent := 0;
      if L.Base_Address = 0 and then Address /= 0 then
         L.Base_Address := Address;
      end if;
      if Address < L.Base_Address then
         return;
      end if;
      Index := Address - L.Base_Address;
      if Index >= Sensor_Count or else C.Sensors (Natural (Index)) = 0 then
         return;
      end if;
      declare
         Id : constant Unsigned_8 := C.Sensors (Natural (Index));
      begin
         if Command = Cmd_Discover then
            Length := 4;
            Buf (1) := Cmd_Discover or Address;
         elsif Command = Cmd_Sensor_Type then
            Length := 6;
            Buf (1) := Cmd_Sensor_Type or Address;
            Buf (2) := Id;
            Buf (3) := Unsigned_8 (Sensor_Length (Id));
         elsif Command = Cmd_Measurement then
            Length := 4 + Sensor_Length (Id);
            Buf (1) := Cmd_Measurement or Address;
            Set_Value (C, Inp, Id, Buf);
         else
            return;
         end if;
      end;
      Buf (0) := Unsigned_8 (Length);
      declare
         Sum : constant Unsigned_16 := Checksum (Buf, Length - 2);
      begin
         if O.Count + Length > Max_Output then
            return;
         end if;
         for I in 0 .. Length - 3 loop
            O.Tx (O.Count + I) := Buf (I);
         end loop;
         O.Tx (O.Count + Length - 2) := Byte (Sum and 16#FF#);
         O.Tx (O.Count + Length - 1) := Byte (Interfaces.Shift_Right (Sum, 8));
         O.Count := O.Count + Length;
      end;
      Sent := Length;
   end Respond;

   --  The window holds a request when its length byte is two to four and
   --  the checksum over that many bytes less two matches its last two
   --  bytes; the reference sums past the window for other length bytes
   --  (finding F80), so those never match here.
   function Request_Seen (W : Window_Bytes) return Boolean is
      Len : constant Natural := Natural (W (0));
      Sum : Unsigned_16 := 16#FFFF#;
   begin
      if Len not in 2 .. 4 then
         return False;
      end if;
      for I in 0 .. Len - 3 loop
         Sum := Sum - Unsigned_16 (W (I));
      end loop;
      return Byte (Interfaces.Shift_Right (Sum, 8)) = W (3) and then Byte (Sum and 16#FF#) = W (2);
   end Request_Seen;

   ------------
   -- Update --
   ------------

   procedure Update (L : in out Link; C : Settings; Inp : Inputs; Rx : Byte_Array; O : out Output) is
      Sent : Natural;
   begin
      O := (others => <>);
      for I in Rx'Range loop
         if L.Ignore > 0 then
            L.Ignore := L.Ignore - 1;
         else
            L.Window := L.Window (1 .. 3) & Rx (I);
            if Request_Seen (L.Window) then
               Respond (L, C, Inp, O, Sent);
               L.Ignore := L.Ignore + Unsigned_8 (Sent);
            end if;
         end if;
      end loop;
   end Update;

end Adaflight.IBus_Telemetry;
