with Adaflight.Float_Bits;
with Adaflight.Powers;

package body Adaflight.MAVLink_Mission with SPARK_Mode is

   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;
   subtype Integer_64 is Interfaces.Integer_64;

   Id_Set_Current  : constant := 41;
   Id_Current      : constant := 42;
   Id_Request_List : constant := 43;
   Id_Count        : constant := 44;
   Id_Clear_All    : constant := 45;
   Id_Item_Reached : constant := 46;
   Id_Ack          : constant := 47;
   Id_Request_Int  : constant := 51;
   Id_Item_Int     : constant := 73;

   Type_Mission : constant := 0;
   Type_Fence   : constant := 1;
   Type_All     : constant := 255;

   Accepted_Result    : constant := 0;
   Error_Result       : constant := 1;
   Unsupported_Frame  : constant := 2;
   Unsupported        : constant := 3;
   No_Space           : constant := 4;
   Invalid            : constant := 5;
   Invalid_Param1     : constant := 6;
   Invalid_Param2     : constant := 7;
   Invalid_Param5_X   : constant := 10;
   Invalid_Param6_Y   : constant := 11;
   Invalid_Param7     : constant := 12;
   Invalid_Sequence   : constant := 13;
   Denied             : constant := 14;
   Cancelled          : constant := 15;

   Cmd_Waypoint      : constant := 16;
   Cmd_Loiter_Unlim  : constant := 17;
   Cmd_Loiter_Turns  : constant := 18;
   Cmd_Loiter_Time   : constant := 19;
   Cmd_Return        : constant := 20;
   Cmd_Land          : constant := 21;
   Cmd_Takeoff       : constant := 22;
   Cmd_Land_Local    : constant := 23;
   Cmd_Takeoff_Local : constant := 24;
   Cmd_Follow        : constant := 25;
   Cmd_Change_Alt    : constant := 30;
   Cmd_Loiter_To_Alt : constant := 31;
   Cmd_Spline        : constant := 82;
   Cmd_VTOL_Takeoff  : constant := 84;
   Cmd_VTOL_Land     : constant := 85;
   Cmd_Delay         : constant := 93;
   Cmd_Payload_Place : constant := 94;
   Cmd_Yaw_Speed     : constant := 213;

   Frame_Global         : constant := 0;
   Frame_Relative       : constant := 3;
   Frame_Global_Int     : constant := 5;
   Frame_Relative_Int   : constant := 6;

   --  The fields of a received payload, little endian.
   function U8 (Msg : MAVLink.Message; At_Byte : MAVLink.Payload_Index) return Unsigned_8 is
     (Unsigned_8 (Msg.Payload (At_Byte)));
   function U16 (Msg : MAVLink.Message; At_Byte : MAVLink.Payload_Index) return Unsigned_16 is
     (Unsigned_16 (Msg.Payload (At_Byte)) or Interfaces.Shift_Left (Unsigned_16 (Msg.Payload (At_Byte + 1)), 8))
     with Pre => At_Byte <= MAVLink.Max_Payload - 2;
   function U32 (Msg : MAVLink.Message; At_Byte : MAVLink.Payload_Index) return Unsigned_32 is
     (Unsigned_32 (Msg.Payload (At_Byte)) or Interfaces.Shift_Left (Unsigned_32 (Msg.Payload (At_Byte + 1)), 8)
      or Interfaces.Shift_Left (Unsigned_32 (Msg.Payload (At_Byte + 2)), 16)
      or Interfaces.Shift_Left (Unsigned_32 (Msg.Payload (At_Byte + 3)), 24))
     with Pre => At_Byte <= MAVLink.Max_Payload - 4;
   function I32 (Bits : Unsigned_32) return Integer_32 is
     (if Bits >= 2 ** 31 then Integer_32 (Integer_64 (Bits) - 2 ** 32) else Integer_32 (Bits));

   function Is_Finite (Bits : Unsigned_32) return Boolean is
     ((Interfaces.Shift_Right (Bits, 23) and 16#FF#) /= 16#FF#);
   function Is_NaN (Bits : Unsigned_32) return Boolean is
     (not Is_Finite (Bits) and then (Bits and 16#7F_FFFF#) /= 0);

   --  A finite float from its bits: the mantissa with its leading bit,
   --  scaled by the exponent's power of two in exact steps, with the sign.
   function From_Bits (Bits : Unsigned_32) return Float
     with Pre => Is_Finite (Bits)
   is
      Exponent  : constant Natural := Natural (Interfaces.Shift_Right (Bits, 23) and 16#FF#);
      Fraction  : constant Float := Float (Bits and 16#7F_FFFF#) * 2.0 ** (-23);
      Magnitude : Float;
   begin
      if Exponent = 0 then
         Magnitude := Fraction * Powers.Power_Of_Two (-125) * 0.5;
      elsif Exponent = 1 then
         Magnitude := (1.0 + Fraction) * Powers.Power_Of_Two (-125) * 0.5;
      elsif Exponent = 254 then
         Magnitude := (1.0 + Fraction) * Powers.Power_Of_Two (126) * 2.0;
      else
         Magnitude := (1.0 + Fraction) * Powers.Power_Of_Two (Exponent - 127);
      end if;
      return (if (Bits and 16#8000_0000#) /= 0 then -Magnitude else Magnitude);
   end From_Bits;

   --  A float to the integer type as C converts it, toward zero, saturated
   --  where C leaves the conversion undefined.
   function To_Integer_32 (X : Float) return Integer_32 is
     (if X >= 2.0 ** 31 then Integer_32'Last
      elsif X <= -2.0 ** 31 then Integer_32'First
      else Integer_32 (Float'Truncation (X)));

   --  A duration in tenths of a second, saturated at the field's maximum.
   function Saturated (Ds : Float) return Unsigned_16 is
     (if Ds >= 65_535.0 then Unsigned_16'Last else Unsigned_16 (Float'Truncation (Ds)))
     with Pre => Ds >= 0.0;

   procedure Frame (Seq : in out Unsigned_8; O : in out Output; Id : MAVLink_Frames.Message_Id; CRC_Extra : Unsigned_8;
                    P : MAVLink_Frames.Payload; Max_Len : Positive)
     with Pre => Max_Len <= MAVLink_Frames.Max_Payload
   is
      Length : Natural := O.Length;
   begin
      MAVLink_Frames.Frame (Seq, O.Data, Length, Id, CRC_Extra, P, Max_Len);
      O.Length := Length;
   end Frame;

   procedure Send_Ack (Seq : in out Unsigned_8; O : in out Output; Sys, Comp, Mission_Type, Result : Unsigned_8) is
      P : MAVLink_Frames.Payload := (others => 0);
   begin
      MAVLink_Frames.Put_U8 (P, 0, Sys);
      MAVLink_Frames.Put_U8 (P, 1, Comp);
      MAVLink_Frames.Put_U8 (P, 2, Result);
      MAVLink_Frames.Put_U8 (P, 3, Mission_Type);
      Frame (Seq, O, Id_Ack, 153, P, 8);
   end Send_Ack;

   procedure Send_Request_Int (Seq : in out Unsigned_8; O : in out Output; Sys, Comp, Mission_Type : Unsigned_8;
                               Item : Unsigned_16)
   is
      P : MAVLink_Frames.Payload := (others => 0);
   begin
      MAVLink_Frames.Put_U16 (P, 0, Item);
      MAVLink_Frames.Put_U8 (P, 2, Sys);
      MAVLink_Frames.Put_U8 (P, 3, Comp);
      MAVLink_Frames.Put_U8 (P, 4, Mission_Type);
      Frame (Seq, O, Id_Request_Int, 196, P, 5);
   end Send_Request_Int;

   procedure Send_Count (Seq : in out Unsigned_8; O : in out Output; Sys, Comp, Mission_Type : Unsigned_8;
                         Count : Unsigned_16)
   is
      P : MAVLink_Frames.Payload := (others => 0);
   begin
      MAVLink_Frames.Put_U16 (P, 0, Count);
      MAVLink_Frames.Put_U8 (P, 2, Sys);
      MAVLink_Frames.Put_U8 (P, 3, Comp);
      MAVLink_Frames.Put_U8 (P, 4, Mission_Type);
      Frame (Seq, O, Id_Count, 221, P, 9);
   end Send_Count;

   procedure Send_Item_Int
     (Seq  : in out Unsigned_8;
      O    : in out Output;
      Sys, Comp : Unsigned_8;
      Item : Unsigned_16;
      Command : Unsigned_16;
      Current : Unsigned_8;
      Param1_Bits, Param2_Bits, Param3_Bits : Unsigned_32;
      X, Y : Integer_32;
      Z_Bits : Unsigned_32;
      Mission_Type : Unsigned_8)
   is
      P : MAVLink_Frames.Payload := (others => 0);
   begin
      MAVLink_Frames.Put_U32 (P, 0, Param1_Bits);
      MAVLink_Frames.Put_U32 (P, 4, Param2_Bits);
      MAVLink_Frames.Put_U32 (P, 8, Param3_Bits);
      MAVLink_Frames.Put_U32 (P, 16, Unsigned_32'Mod (X));
      MAVLink_Frames.Put_U32 (P, 20, Unsigned_32'Mod (Y));
      MAVLink_Frames.Put_U32 (P, 24, Z_Bits);
      MAVLink_Frames.Put_U16 (P, 28, Item);
      MAVLink_Frames.Put_U16 (P, 30, Command);
      MAVLink_Frames.Put_U8 (P, 32, Sys);
      MAVLink_Frames.Put_U8 (P, 33, Comp);
      MAVLink_Frames.Put_U8 (P, 34, Frame_Global_Int);
      MAVLink_Frames.Put_U8 (P, 35, Current);
      MAVLink_Frames.Put_U8 (P, 36, 1);
      MAVLink_Frames.Put_U8 (P, 37, Mission_Type);
      Frame (Seq, O, Id_Item_Int, 38, P, 38);
   end Send_Item_Int;

   --  The current item, the plan's size, the mission's state and mode.
   procedure Send_Current (P : Flight_Plan.Plan; I : Inputs; Seq : in out Unsigned_8; O : in out Output) is
      Total  : constant Unsigned_16 := Unsigned_16 (P.Count);
      Active : constant Boolean := I.Executor.Active;
      Item   : constant Unsigned_16 :=
        (if Total > 0 and then Active and then not I.Executor.Injected
         then Unsigned_16 (I.Executor.Current_Index) else 0);
      Mode   : constant Unsigned_8 := (if Active then 1 else 2);
      Status : constant Unsigned_8 :=
        (if Total = 0 then 1 elsif not Active then 2 elsif I.Executor.Complete then 5 else 3);
      Pay    : MAVLink_Frames.Payload := (others => 0);
   begin
      MAVLink_Frames.Put_U16 (Pay, 0, Item);
      MAVLink_Frames.Put_U16 (Pay, 2, Total);
      MAVLink_Frames.Put_U8 (Pay, 4, Status);
      MAVLink_Frames.Put_U8 (Pay, 5, Mode);
      Frame (Seq, O, Id_Current, 28, Pay, 18);
   end Send_Current;

   --  One stored item for a download: a fence point as stored, or a
   --  waypoint in the command that carries its type.
   procedure Send_Mission_Item
     (M : State; P : Flight_Plan.Plan; I : Inputs; Sys, Comp : Unsigned_8; Item : Unsigned_16;
      Seq : in out Unsigned_8; O : in out Output)
     with Pre => (if M.Mission_Type = Type_Fence then Item < Max_Fence_Points else Item < Flight_Plan.Max_Waypoints)
   is
      use Flight_Plan;
   begin
      if M.Mission_Type = Type_Fence then
         declare
            F : Fence_Point renames M.Fence (Natural (Item));
         begin
            Send_Item_Int (Seq, O, Sys, Comp, Item, F.Command, 0, F.Param1_Bits, 0, 0, F.Latitude, F.Longitude, 0,
                           Type_Fence);
         end;
         return;
      end if;
      declare
         W       : Waypoint renames P.Waypoints (Natural (Item));
         Command : Unsigned_16;
         Param1  : Float := 0.0;
         Param2  : Float := 0.0;
         Param3  : Float := 0.0;
         X       : Integer_32 := W.Latitude;
         Y       : Integer_32 := W.Longitude;
         Z       : Float := Float (W.Altitude) * 0.01;
         Current : constant Unsigned_8 :=
           (if I.Executor.Active and then not I.Executor.Injected
              and then Item = Unsigned_16 (I.Executor.Current_Index) then 1 else 0);
      begin
         case W.Kind is
            when Type_Hold =>
               if W.Pattern = Pattern_Orbit then
                  Command := Cmd_Loiter_Turns;
                  Param1 := Float (W.Duration_Ds)
                    / Float (Flight_Plan_Nav.Orbit_Period_Ds (W.Speed, I.Radius, I.Max_Speed));
                  Param3 := Float (I.Radius) * 0.01;
               else
                  Command := Cmd_Loiter_Time;
                  Param1 := Float (W.Duration_Ds) * 0.1;
               end if;
            when Type_Land =>
               Command := Cmd_Land;
            when Type_Takeoff =>
               Command := Cmd_Takeoff;
            when Type_Alt_Change =>
               Command := Cmd_Change_Alt;
               Param1 := Float (W.Pattern);
               X := 0;
               Y := 0;
            when Type_Delay =>
               Command := Cmd_Delay;
               Param1 := Float (W.Duration_Ds) * 0.1;
               X := 0;
               Y := 0;
               Z := 0.0;
            when Type_Yaw_Rate =>
               Command := Cmd_Yaw_Speed;
               Param2 := Float (W.Speed);
               X := 0;
               Y := 0;
               Z := 0.0;
            when others =>
               Command := Cmd_Waypoint;
         end case;
         Send_Item_Int (Seq, O, Sys, Comp, Item, Command, Current, Float_Bits.Float_Bits (Param1),
                        Float_Bits.Float_Bits (Param2), Float_Bits.Float_Bits (Param3), X, Y,
                        Float_Bits.Float_Bits (Z), Type_Mission);
      end;
   end Send_Mission_Item;

   function Target_Is_Us (Sys, Comp : Unsigned_8) return Boolean is
     ((Sys = 0 or else Sys = MAVLink_Frames.System_Id) and then (Comp = 0 or else Comp = MAVLink_Frames.Component_Id));

   function Is_Partner (M : State; Msg : MAVLink.Message) return Boolean is
     (Unsigned_8 (Msg.Sysid) = M.Partner_Sys and then Unsigned_8 (Msg.Compid) = M.Partner_Comp);

   procedure Abort_Upload (M : in out State; Result : Unsigned_8; Seq : in out Unsigned_8; O : in out Output) is
   begin
      Send_Ack (Seq, O, M.Partner_Sys, M.Partner_Comp, M.Mission_Type, Result);
      M.Transfer := Idle;
   end Abort_Upload;

   --  The altitude of an item in its frame: absolute, or above a home that
   --  has its fix.
   procedure Decode_Altitude (Frame_Kind : Unsigned_8; Z_Bits : Unsigned_32; I : Inputs; Alt_Cm : out Integer_32;
                              Result : out Unsigned_8; Ok : out Boolean)
   is
   begin
      Alt_Cm := 0;
      Result := Accepted_Result;
      if not Is_Finite (Z_Bits) then
         Result := Invalid_Param7;
         Ok := False;
         return;
      end if;
      declare
         Z      : constant Float := From_Bits (Z_Bits);
         Scaled : constant Float := (if abs Z <= 1.0e36 then Z * 100.0 else Z);
      begin
         case Frame_Kind is
            when Frame_Global | Frame_Global_Int =>
               Alt_Cm := To_Integer_32 (Scaled);
               Ok := True;
            when Frame_Relative | Frame_Relative_Int =>
               if not I.Home_Fix then
                  Result := Invalid;
                  Ok := False;
                  return;
               end if;
               declare
                  Sum : constant Integer_64 := Integer_64 (To_Integer_32 (Scaled)) + Integer_64 (I.Home_Altitude_Cm);
               begin
                  Alt_Cm := Integer_32 (Integer_64'Max (Integer_64 (Integer_32'First),
                                                        Integer_64'Min (Integer_64 (Integer_32'Last), Sum)));
               end;
               Ok := True;
            when others =>
               Result := Unsupported_Frame;
               Ok := False;
         end case;
      end;
   end Decode_Altitude;

   --  A received item as a waypoint, or the reason it is refused. A return
   --  to launch in the last slot ends the plan instead.
   procedure Map_Item
     (Msg : MAVLink.Message; I : Inputs; Is_Last_Slot : Boolean; W : out Flight_Plan.Waypoint;
      Is_RTL : out Boolean; Result : out Unsigned_8; Ok : out Boolean)
   is
      use Flight_Plan;
      P1_Bits  : constant Unsigned_32 := U32 (Msg, 0);
      P2_Bits  : constant Unsigned_32 := U32 (Msg, 4);
      P3_Bits  : constant Unsigned_32 := U32 (Msg, 8);
      P4_Bits  : constant Unsigned_32 := U32 (Msg, 12);
      X        : constant Integer_32 := I32 (U32 (Msg, 16));
      Y        : constant Integer_32 := I32 (U32 (Msg, 20));
      Z_Bits   : constant Unsigned_32 := U32 (Msg, 24);
      Command  : constant Unsigned_16 := U16 (Msg, 30);
      Frame_Kind : constant Unsigned_8 := U8 (Msg, 34);
      Modifier : constant Boolean :=
        Command = Cmd_Change_Alt or else Command = Cmd_Delay or else Command = Cmd_Yaw_Speed;
      Alt_Cm   : Integer_32 := 0;
   begin
      W := (others => <>);
      Is_RTL := False;
      Result := Accepted_Result;
      Ok := False;
      if Command = Cmd_Return then
         if not Is_Last_Slot then
            Result := Unsupported;
            return;
         end if;
         Is_RTL := True;
         Ok := True;
         return;
      end if;
      if not Modifier then
         Decode_Altitude (Frame_Kind, Z_Bits, I, Alt_Cm, Result, Ok);
         if not Ok then
            return;
         end if;
         Ok := False;
         if X < -900_000_000 or else X > 900_000_000 then
            Result := Invalid_Param5_X;
            return;
         end if;
         if Y < -1_800_000_000 or else Y > 1_800_000_000 then
            Result := Invalid_Param6_Y;
            return;
         end if;
      end if;
      --  A waypoint's yaw may be NaN for the current heading.
      if not Is_Finite (P1_Bits) or else not Is_Finite (P2_Bits) or else not Is_Finite (P3_Bits)
        or else (not Is_Finite (P4_Bits) and then not (Command = Cmd_Waypoint and then Is_NaN (P4_Bits)))
      then
         Result := Invalid;
         return;
      end if;
      declare
         P1 : constant Float := From_Bits (P1_Bits);
         P2 : constant Float := From_Bits (P2_Bits);
      begin
         W.Latitude := (if Modifier then 0 else X);
         W.Longitude := (if Modifier then 0 else Y);
         W.Altitude := Alt_Cm;
         W.Speed := 0;
         W.Duration_Ds := 0;
         W.Pattern := Pattern_None;
         W.Vert_Rate := 0;
         W.Yaw_Behaviour := Yaw_Default;
         case Command is
            when Cmd_Waypoint | Cmd_Spline =>
               W.Kind := Type_Flyby;
               if P1 > 0.0 then
                  W.Duration_Ds := Saturated (if P1 <= 1.0e37 then P1 * 10.0 else P1);
               end if;
            when Cmd_Loiter_Time =>
               W.Kind := Type_Hold;
               if P1 > 0.0 then
                  W.Duration_Ds := Saturated (if P1 <= 1.0e37 then P1 * 10.0 else P1);
               end if;
            when Cmd_Loiter_Turns =>
               W.Kind := Type_Hold;
               W.Pattern := Pattern_Orbit;
               if P1 > 0.0 then
                  W.Duration_Ds := Saturated
                    (if P1 <= 1.0e33 then P1 * Float (Flight_Plan_Nav.Orbit_Period_Ds (W.Speed, I.Radius, I.Max_Speed))
                     else P1);
               end if;
            when Cmd_Loiter_Unlim =>
               W.Kind := Type_Hold;
               W.Duration_Ds := Unsigned_16'Last;
            when Cmd_Loiter_To_Alt | Cmd_Follow =>
               W.Kind := Type_Hold;
            when Cmd_Land | Cmd_VTOL_Land | Cmd_Land_Local | Cmd_Payload_Place =>
               W.Kind := Type_Land;
            when Cmd_Takeoff | Cmd_VTOL_Takeoff | Cmd_Takeoff_Local =>
               W.Kind := Type_Takeoff;
            when Cmd_Change_Alt =>
               if P1 < -0.5 or else P1 > 2.5 then
                  Result := Invalid_Param1;
                  return;
               end if;
               declare
                  Mod_Alt : Integer_32;
               begin
                  Decode_Altitude (Frame_Kind, Z_Bits, I, Mod_Alt, Result, Ok);
                  if not Ok then
                     return;
                  end if;
                  W.Kind := Type_Alt_Change;
                  W.Altitude := Mod_Alt;
                  --  The climb mode rounded to the nearest with a tie going
                  --  to the even one.
                  W.Pattern := (if P1 <= 0.5 then 0 elsif P1 < 1.5 then 1 else 2);
               end;
            when Cmd_Delay =>
               if P1 < 0.0 then
                  Result := Invalid_Param1;
                  return;
               end if;
               W.Kind := Type_Delay;
               W.Duration_Ds := Saturated (if P1 <= 1.0e37 then P1 * 10.0 else P1);
            when Cmd_Yaw_Speed =>
               if P2 < 0.0 then
                  Result := Invalid_Param2;
                  return;
               end if;
               W.Kind := Type_Yaw_Rate;
               W.Speed := Saturated (P2);
            when others =>
               Result := Unsupported;
               return;
         end case;
         Ok := True;
      end;
   end Map_Item;

   ----------
   -- Init --
   ----------

   procedure Init (M : out State) is
   begin
      M := (others => <>);
   end Init;

   ------------
   -- Handle --
   ------------

   procedure Handle
     (M       : in out State;
      P       : in out Flight_Plan.Plan;
      Msg     : MAVLink.Message;
      I       : Inputs;
      Seq     : in out Unsigned_8;
      O       : in out Output;
      Handled : out Boolean)
   is
      Sys  : constant Unsigned_8 := Unsigned_8 (Msg.Sysid);
      Comp : constant Unsigned_8 := Unsigned_8 (Msg.Compid);
   begin
      Handled := True;
      case Msg.Id is
         when Id_Request_List =>
            declare
               Mission_Type : constant Unsigned_8 := U8 (Msg, 2);
            begin
               if not Target_Is_Us (U8 (Msg, 0), U8 (Msg, 1)) then
                  return;
               end if;
               if Mission_Type /= Type_Mission and then Mission_Type /= Type_Fence then
                  Send_Ack (Seq, O, Sys, Comp, Mission_Type, Unsupported);
                  return;
               end if;
               declare
                  Count : constant Unsigned_16 :=
                    Unsigned_16 (if Mission_Type = Type_Fence then M.Fence_Count else P.Count);
               begin
                  M.Partner_Sys := Sys;
                  M.Partner_Comp := Comp;
                  M.Mission_Type := Mission_Type;
                  if Count = 0 then
                     Send_Count (Seq, O, Sys, Comp, Mission_Type, 0);
                     M.Transfer := Idle;
                     return;
                  end if;
                  M.Transfer := Sending;
                  M.Next_Seq := 0;
                  M.Total_Count := Count;
                  M.Last_Activity_Ms := I.Now_Ms;
                  Send_Count (Seq, O, Sys, Comp, Mission_Type, Count);
               end;
            end;

         when Id_Request_Int =>
            declare
               Item         : constant Unsigned_16 := U16 (Msg, 0);
               Mission_Type : constant Unsigned_8 := U8 (Msg, 4);
            begin
               if not Target_Is_Us (U8 (Msg, 2), U8 (Msg, 3)) then
                  return;
               end if;
               if M.Transfer /= Sending or else not Is_Partner (M, Msg) then
                  return;
               end if;
               if Mission_Type /= M.Mission_Type then
                  Send_Ack (Seq, O, Sys, Comp, Mission_Type, Unsupported);
                  M.Transfer := Idle;
                  return;
               end if;
               if Item /= M.Next_Seq and then not (M.Next_Seq > 0 and then Item = M.Next_Seq - 1) then
                  Send_Ack (Seq, O, Sys, Comp, M.Mission_Type, Invalid_Sequence);
                  M.Transfer := Idle;
                  return;
               end if;
               if Item >= M.Total_Count then
                  Send_Ack (Seq, O, Sys, Comp, M.Mission_Type, Invalid_Sequence);
                  M.Transfer := Idle;
                  return;
               end if;
               if (M.Mission_Type = Type_Fence and then Item >= Max_Fence_Points)
                 or else (M.Mission_Type /= Type_Fence and then Item >= Flight_Plan.Max_Waypoints)
               then
                  return;
               end if;
               Send_Mission_Item (M, P, I, Sys, Comp, Item, Seq, O);
               if Integer (Item) = Integer (M.Total_Count) - 1 then
                  M.Next_Seq := Item + 1;
               elsif Item = M.Next_Seq then
                  M.Next_Seq := M.Next_Seq + 1;
               end if;
               M.Last_Activity_Ms := I.Now_Ms;
            end;

         when Id_Count =>
            declare
               Count        : constant Unsigned_16 := U16 (Msg, 0);
               Mission_Type : constant Unsigned_8 := U8 (Msg, 4);
            begin
               if not Target_Is_Us (U8 (Msg, 2), U8 (Msg, 3)) then
                  return;
               end if;
               if Mission_Type = Type_Fence then
                  if Count > Max_Fence_Points then
                     Send_Ack (Seq, O, Sys, Comp, Type_Fence, No_Space);
                     return;
                  end if;
                  M.Fence_Count := 0;
                  if Count = 0 then
                     Send_Ack (Seq, O, Sys, Comp, Type_Fence, Accepted_Result);
                     M.Transfer := Idle;
                     return;
                  end if;
                  M.Transfer := Receiving;
                  M.Mission_Type := Type_Fence;
                  M.Next_Seq := 0;
                  M.Total_Count := Count;
                  M.Partner_Sys := Sys;
                  M.Partner_Comp := Comp;
                  M.Last_Activity_Ms := I.Now_Ms;
                  M.Retries := 0;
                  M.RTL_Terminator := False;
                  Send_Request_Int (Seq, O, Sys, Comp, Type_Fence, 0);
                  return;
               end if;
               if Mission_Type /= Type_Mission then
                  Send_Ack (Seq, O, Sys, Comp, Mission_Type, Unsupported);
                  return;
               end if;
               if I.Autopilot_Mode then
                  Send_Ack (Seq, O, Sys, Comp, Type_Mission, Denied);
                  return;
               end if;
               if Count > Flight_Plan.Max_Waypoints then
                  Send_Ack (Seq, O, Sys, Comp, Type_Mission, No_Space);
                  return;
               end if;
               if Count = 0 then
                  P.Count := 0;
                  O.Save_Config := True;
                  Send_Ack (Seq, O, Sys, Comp, Type_Mission, Accepted_Result);
                  M.Transfer := Idle;
                  return;
               end if;
               P.Count := 0;
               M.Transfer := Receiving;
               M.Mission_Type := Type_Mission;
               M.Next_Seq := 0;
               M.Total_Count := Count;
               M.Partner_Sys := Sys;
               M.Partner_Comp := Comp;
               M.Last_Activity_Ms := I.Now_Ms;
               M.Retries := 0;
               M.RTL_Terminator := False;
               Send_Request_Int (Seq, O, Sys, Comp, Type_Mission, 0);
            end;

         when Id_Item_Int =>
            declare
               Item         : constant Unsigned_16 := U16 (Msg, 28);
               Mission_Type : constant Unsigned_8 := U8 (Msg, 37);
            begin
               if not Target_Is_Us (U8 (Msg, 32), U8 (Msg, 33)) then
                  return;
               end if;
               if M.Transfer /= Receiving or else not Is_Partner (M, Msg) then
                  return;
               end if;
               if Mission_Type /= M.Mission_Type then
                  Abort_Upload (M, Unsupported, Seq, O);
                  return;
               end if;
               if Item /= M.Next_Seq then
                  Abort_Upload (M, Invalid_Sequence, Seq, O);
                  return;
               end if;
               if M.Mission_Type = Type_Fence then
                  declare
                     Command : constant Unsigned_16 := U16 (Msg, 30);
                  begin
                     if Command not in 5_000 .. 5_004 then
                        Abort_Upload (M, Unsupported, Seq, O);
                        return;
                     end if;
                     if Item < Max_Fence_Points then
                        M.Fence (Natural (Item)) :=
                          (Command => Command, Latitude => I32 (U32 (Msg, 16)), Longitude => I32 (U32 (Msg, 20)),
                           Param1_Bits => U32 (Msg, 0));
                     end if;
                  end;
                  M.Next_Seq := M.Next_Seq + 1;
                  M.Last_Activity_Ms := I.Now_Ms;
                  M.Retries := 0;
                  if M.Next_Seq < M.Total_Count then
                     Send_Request_Int (Seq, O, Sys, Comp, Type_Fence, M.Next_Seq);
                     return;
                  end if;
                  M.Fence_Count := Natural (Unsigned_16'Min (M.Total_Count, Max_Fence_Points));
                  Send_Ack (Seq, O, Sys, Comp, Type_Fence, Accepted_Result);
                  M.Transfer := Idle;
                  return;
               end if;
               declare
                  W      : Flight_Plan.Waypoint;
                  Is_RTL : Boolean;
                  Result : Unsigned_8;
                  Ok     : Boolean;
               begin
                  Map_Item (Msg, I, Integer (Item) = Integer (M.Total_Count) - 1, W, Is_RTL, Result, Ok);
                  if not Ok then
                     Abort_Upload (M, Result, Seq, O);
                     return;
                  end if;
                  if Is_RTL then
                     M.RTL_Terminator := True;
                  elsif Item < Flight_Plan.Max_Waypoints then
                     P.Waypoints (Natural (Item)) := W;
                  end if;
               end;
               M.Next_Seq := M.Next_Seq + 1;
               M.Last_Activity_Ms := I.Now_Ms;
               M.Retries := 0;
               if M.Next_Seq < M.Total_Count then
                  Send_Request_Int (Seq, O, Sys, Comp, Type_Mission, M.Next_Seq);
                  return;
               end if;
               declare
                  Final : constant Unsigned_16 := (if M.RTL_Terminator then M.Total_Count - 1 else M.Total_Count);
               begin
                  P.Count := Natural (Unsigned_16'Min (Final, Flight_Plan.Max_Waypoints));
               end;
               O.Save_Config := True;
               Send_Ack (Seq, O, Sys, Comp, Type_Mission, Accepted_Result);
               M.Transfer := Idle;
            end;

         when Id_Set_Current =>
            declare
               Item : constant Unsigned_16 := U16 (Msg, 0);
            begin
               if not Target_Is_Us (U8 (Msg, 2), U8 (Msg, 3)) then
                  return;
               end if;
               if Item > 255 then
                  Send_Ack (Seq, O, Sys, Comp, Type_Mission, Error_Result);
                  return;
               end if;
               O.Set_Current := True;
               O.Set_Current_Index := Unsigned_8 (Item);
               M.Set_Sys := Sys;
               M.Set_Comp := Comp;
            end;

         when Id_Clear_All =>
            declare
               Mission_Type  : constant Unsigned_8 := U8 (Msg, 2);
               Clear_Mission : constant Boolean := Mission_Type = Type_Mission or else Mission_Type = Type_All;
               Clear_Fence   : constant Boolean := Mission_Type = Type_Fence or else Mission_Type = Type_All;
            begin
               if not Target_Is_Us (U8 (Msg, 0), U8 (Msg, 1)) then
                  return;
               end if;
               if not Clear_Mission and then not Clear_Fence then
                  Send_Ack (Seq, O, Sys, Comp, Mission_Type, Unsupported);
                  return;
               end if;
               if Clear_Mission and then I.Autopilot_Mode then
                  Send_Ack (Seq, O, Sys, Comp, Mission_Type, Denied);
                  return;
               end if;
               if Clear_Fence then
                  M.Fence_Count := 0;
               end if;
               if Clear_Mission then
                  P.Count := 0;
                  O.Save_Config := True;
               end if;
               Send_Ack (Seq, O, Sys, Comp, Mission_Type, Accepted_Result);
               M.Transfer := Idle;
            end;

         when Id_Ack =>
            if not Target_Is_Us (U8 (Msg, 0), U8 (Msg, 1)) then
               return;
            end if;
            if M.Transfer = Sending and then Is_Partner (M, Msg) then
               M.Transfer := Idle;
            end if;

         when others =>
            Handled := False;
      end case;
   end Handle;

   --------------------------
   -- Complete_Set_Current --
   --------------------------

   procedure Complete_Set_Current
     (M        : State;
      P        : Flight_Plan.Plan;
      Accepted : Boolean;
      I        : Inputs;
      Seq      : in out Unsigned_8;
      O        : in out Output)
   is
   begin
      if not Accepted then
         Send_Ack (Seq, O, M.Set_Sys, M.Set_Comp, Type_Mission, Error_Result);
         return;
      end if;
      Send_Current (P, I, Seq, O);
   end Complete_Set_Current;

   ----------------------
   -- Waypoint_Reached --
   ----------------------

   procedure Waypoint_Reached (M : in out State; Index : Unsigned_8) is
   begin
      M.Pending_Reached := Integer (Index);
   end Waypoint_Reached;

   ------------
   -- Update --
   ------------

   procedure Update
     (M   : in out State;
      P   : Flight_Plan.Plan;
      I   : Inputs;
      Seq : in out Unsigned_8;
      O   : in out Output)
   is
   begin
      if M.Transfer = Receiving and then I.Now_Ms - M.Last_Activity_Ms >= Upload_Retry_Ms then
         if M.Retries >= Upload_Max_Retry then
            Abort_Upload (M, Cancelled, Seq, O);
         else
            M.Retries := M.Retries + 1;
            M.Last_Activity_Ms := I.Now_Ms;
            Send_Request_Int (Seq, O, M.Partner_Sys, M.Partner_Comp, M.Mission_Type, M.Next_Seq);
         end if;
      end if;
      if M.Transfer = Sending and then I.Now_Ms - M.Last_Activity_Ms >= Download_Idle_Ms then
         M.Transfer := Idle;
      end if;
      if M.Pending_Reached >= 0 then
         declare
            Pay : MAVLink_Frames.Payload := (others => 0);
         begin
            MAVLink_Frames.Put_U16 (Pay, 0, Unsigned_16 (M.Pending_Reached));
            Frame (Seq, O, Id_Item_Reached, 11, Pay, 2);
         end;
         M.Pending_Reached := -1;
      end if;
      if I.Now_Ms - M.Last_Current_Tx_Ms >= Current_Period_Ms then
         Send_Current (P, I, Seq, O);
         M.Last_Current_Tx_Ms := I.Now_Ms;
      end if;
   end Update;

end Adaflight.MAVLink_Mission;
