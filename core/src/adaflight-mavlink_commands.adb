with Adaflight.Float_Bits;
with Adaflight.Powers; use Adaflight.Powers;
with Adaflight.MAVLink_Frames; use Adaflight.MAVLink_Frames;

package body Adaflight.MAVLink_Commands with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;
   use type Adaflight.MAVLink.Framing;

   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_64 is Interfaces.Unsigned_64;

   Ping_Id                  : constant := 4;
   Timesync_Id              : constant := 111;
   Command_Long_Id          : constant := 76;
   Command_Int_Id           : constant := 75;
   Command_Ack_Id           : constant := 77;
   Autopilot_Version_Id     : constant := 148;
   Protocol_Version_Id      : constant := 300;
   Component_Information_Id : constant := 395;
   Available_Modes_Id       : constant := 435;
   Modes_Monitor_Id         : constant := 437;
   Message_Interval_Id      : constant := 244;

   Return_To_Launch_Command  : constant := 20;
   Set_Mode_Command          : constant := 176;
   Set_Home_Command          : constant := 179;
   Reboot_Command            : constant := 246;
   Arm_Disarm_Command        : constant := 400;
   Message_Interval_Command  : constant := 511;
   Request_Message_Command   : constant := 512;
   Capabilities_Command      : constant := 520;

   type Result is (Accepted, Temporarily_Rejected, Denied, Unsupported);

   Mode_Count : constant := 8;
   subtype Mode_Index is Positive range 1 .. Mode_Count;

   function Mode_Name (I : Mode_Index) return String is
     (case I is
        when 1 => "Acro", when 2 => "Angle", when 3 => "Horizon", when 4 => "Alt Hold", when 5 => "Pos Hold",
        when 6 => "Autopilot", when 7 => "RTL", when 8 => "Failsafe")
     with Post => Mode_Name'Result'First = 1 and then Mode_Name'Result'Length <= 9;

   Standard_Mode : constant array (Mode_Index) of Unsigned_8 := (0, 0, 0, 4, 1, 6, 5, 5);

   Mode_Box : constant array (Mode_Index range 2 .. 7) of Adaflight.Modes.Box :=
     (Adaflight.Modes.Angle, Adaflight.Modes.Horizon, Adaflight.Modes.Alt_Hold, Adaflight.Modes.Pos_Hold,
      Adaflight.Modes.Autopilot, Adaflight.Modes.GPS_Rescue);

   ------------------------------------------------------------------
   --  Payload fields, little-endian, from the parser's zero-filled frame.
   ------------------------------------------------------------------

   function Byte_At (M : Adaflight.MAVLink.Message; At_Byte : Adaflight.MAVLink.Payload_Index) return Unsigned_8 is
     (Unsigned_8 (M.Payload (At_Byte)));

   function U16_At (M : Adaflight.MAVLink.Message; At_Byte : Adaflight.MAVLink.Payload_Index) return Unsigned_16 is
     (Unsigned_16 (M.Payload (At_Byte)) or Interfaces.Shift_Left (Unsigned_16 (M.Payload (At_Byte + 1)), 8))
     with Pre => At_Byte <= Adaflight.MAVLink.Max_Payload - 2;

   function U32_At (M : Adaflight.MAVLink.Message; At_Byte : Adaflight.MAVLink.Payload_Index) return Unsigned_32 is
     (Unsigned_32 (M.Payload (At_Byte)) or Interfaces.Shift_Left (Unsigned_32 (M.Payload (At_Byte + 1)), 8)
      or Interfaces.Shift_Left (Unsigned_32 (M.Payload (At_Byte + 2)), 16)
      or Interfaces.Shift_Left (Unsigned_32 (M.Payload (At_Byte + 3)), 24))
     with Pre => At_Byte <= Adaflight.MAVLink.Max_Payload - 4;

   function U64_At (M : Adaflight.MAVLink.Message; At_Byte : Adaflight.MAVLink.Payload_Index) return Unsigned_64 is
     (Unsigned_64 (U32_At (M, At_Byte)) or Interfaces.Shift_Left (Unsigned_64 (U32_At (M, At_Byte + 4)), 32))
     with Pre => At_Byte <= Adaflight.MAVLink.Max_Payload - 8;

   function I32_At (M : Adaflight.MAVLink.Message; At_Byte : Adaflight.MAVLink.Payload_Index) return Integer_32 is
     (if U32_At (M, At_Byte) < 2 ** 31 then Integer_32 (U32_At (M, At_Byte))
      else Integer_32 (Interfaces.Integer_64 (U32_At (M, At_Byte)) - 2 ** 32))
     with Pre => At_Byte <= Adaflight.MAVLink.Max_Payload - 4;

   ------------------------------------------------------------------
   --  Float parameters.
   ------------------------------------------------------------------

   function Not_Finite (Bits : Unsigned_32) return Boolean is
     ((Interfaces.Shift_Right (Bits, 23) and 16#FF#) = 16#FF#);

   type Param_Class is (Number, Huge, Infinity, Not_A_Number);

   Mantissa_Unit : constant Float := 2.0 ** (-23);

   function Negative (Bits : Unsigned_32) return Boolean is ((Bits and 16#8000_0000#) /= 0);

   --  A float parameter's bits: the value it denotes below 2 ** 64 in
   --  magnitude, and the class of anything else.
   procedure Decode (Bits : Unsigned_32; F : out Float; Class : out Param_Class)
     with Global => null, Post => (if Class /= Number then F = 0.0)
   is
      E        : constant Natural := Natural (Interfaces.Shift_Right (Bits, 23) and 16#FF#);
      Fraction : constant Float := Float (Bits and 16#7F_FFFF#) * Mantissa_Unit;
      Mag      : Float;
   begin
      F := 0.0;
      if E = 16#FF# then
         Class := (if (Bits and 16#7F_FFFF#) /= 0 then Not_A_Number else Infinity);
      elsif E > 190 then
         Class := Huge;
      else
         Class := Number;
         if E = 0 then
            Mag := Fraction * Power_Of_Two (-125) * 0.5;
         elsif E = 1 then
            Mag := (1.0 + Fraction) * Power_Of_Two (-125) * 0.5;
         else
            Mag := (1.0 + Fraction) * Power_Of_Two (E - 127);
         end if;
         F := (if Negative (Bits) then -Mag else Mag);
      end if;
   end Decode;

   --  A parameter as a whole number up to Max: finite, not negative and not
   --  above Max, then truncated.
   procedure To_Unsigned (Bits : Unsigned_32; Max : Unsigned_32; V : out Unsigned_32; OK : out Boolean)
     with Global => null, Post => (if OK then V <= Max)
   is
      F     : Float;
      Class : Param_Class;
   begin
      Decode (Bits, F, Class);
      V := 0;
      OK := False;
      if Class /= Number or else F < 0.0 or else Long_Float (F) > Long_Float (Max) then
         return;
      end if;
      V := Unsigned_32 (Long_Float'Truncation (Long_Float (F)));
      OK := True;
   end To_Unsigned;

   --  The library's rounding to a whole number with halves away from zero,
   --  as the target computes it with a 32-bit result: past the range it
   --  saturates.
   function Round_Long (X : Float) return Integer_32 is
      W        : constant Unsigned_32 := Adaflight.Float_Bits.Float_Bits (X);
      E        : constant Integer := Integer (Interfaces.Shift_Right (W, 23) and 16#FF#) - 127;
      M        : constant Unsigned_32 := (W and 16#7F_FFFF#) or 16#80_0000#;
      R        : Unsigned_32;
   begin
      if E < -1 then
         return 0;
      elsif E = -1 then
         return (if Negative (W) then -1 else 1);
      elsif E >= 31 then
         return (if Negative (W) then Integer_32'First else Integer_32'Last);
      elsif E >= 23 then
         R := Interfaces.Shift_Left (M, E - 23);
      else
         R := Interfaces.Shift_Right (M + Interfaces.Shift_Right (16#40_0000#, E), 23 - E);
      end if;
      pragma Assert (R < 2 ** 31);
      return (if Negative (W) then -Integer_32 (R) else Integer_32 (R));
   end Round_Long;

   --  A parameter scaled and rounded as the handlers convert it; one past the
   --  range saturates.
   function Round_Scaled (Bits : Unsigned_32; Scale : Float) return Integer_32
     with Pre => Scale in 100.0 | 1.0E7
   is
      F     : Float;
      Class : Param_Class;
   begin
      Decode (Bits, F, Class);
      if Class /= Number or else abs F > 1.0E30 then
         return (if Negative (Bits) then Integer_32'First else Integer_32'Last);
      end if;
      return Round_Long (F * Scale);
   end Round_Scaled;

   --  The interval a set-interval command asks for, in milliseconds: off
   --  below zero, the setting's at zero, one under a millisecond.
   function Interval_Ms (Bits : Unsigned_32) return Unsigned_32 is
      F     : Float;
      Class : Param_Class;
      Q     : Float;
   begin
      Decode (Bits, F, Class);
      if Class = Not_A_Number then
         return 1;
      elsif Class /= Number then
         return (if Negative (Bits) then Adaflight.MAVLink_Telemetry.Disabled else Unsigned_32'Last);
      elsif F < 0.0 then
         return Adaflight.MAVLink_Telemetry.Disabled;
      elsif F = 0.0 then
         return 0;
      elsif F >= 1000.0 then
         Q := F / 1000.0;
         return (if Q >= 4_294_967_296.0 then Unsigned_32'Last else Unsigned_32 (Float'Truncation (Q)));
      else
         return 1;
      end if;
   end Interval_Ms;

   ------------------------------------------------------------------
   --  Replies.
   ------------------------------------------------------------------

   procedure Send_Ack
     (T : in out Adaflight.MAVLink_Telemetry.State; O : in out Output; Command : Unsigned_16; Res : Result;
      Sysid, Compid : Unsigned_8)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      Put_U16 (P, 0, Command);
      Put_U8 (P, 2, Unsigned_8 (Result'Pos (Res)));
      Put_U8 (P, 8, Sysid);
      Put_U8 (P, 9, Compid);
      Frame (T.Tx_Seq, O.Data, O.Length, Command_Ack_Id, 143, P, 10);
   end Send_Ack;

   procedure Send_Autopilot_Version (T : in out Adaflight.MAVLink_Telemetry.State; C : Settings; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      Put_U64 (P, 0, 8_192);
      Put_U64 (P, 8, Interfaces.Shift_Left (Unsigned_64 (C.UID (0)), 32) or Unsigned_64 (C.UID (1)));
      Put_U32
        (P, 16,
         Interfaces.Shift_Left (Unsigned_32 (C.Version_Year - 2000), 24)
         or Interfaces.Shift_Left (Unsigned_32 (C.Version_Month), 16)
         or Interfaces.Shift_Left (Unsigned_32 (C.Version_Patch), 8));
      for K in 0 .. 2 loop
         Put_U32 (P, 60 + 4 * K, C.UID (K));
      end loop;
      Frame (T.Tx_Seq, O.Data, O.Length, Autopilot_Version_Id, 178, P, 78);
   end Send_Autopilot_Version;

   procedure Send_Protocol_Version (T : in out Adaflight.MAVLink_Telemetry.State; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      Put_U16 (P, 0, 200);
      Put_U16 (P, 2, 100);
      Put_U16 (P, 4, 200);
      Frame (T.Tx_Seq, O.Data, O.Length, Protocol_Version_Id, 217, P, 22);
   end Send_Protocol_Version;

   procedure Send_Component_Information (T : in out Adaflight.MAVLink_Telemetry.State; Inp : Inputs; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      Put_U32 (P, 0, Inp.Now_Ms);
      Frame (T.Tx_Seq, O.Data, O.Length, Component_Information_Id, 0, P, 212);
   end Send_Component_Information;

   procedure Send_Available_Mode (T : in out Adaflight.MAVLink_Telemetry.State; I : Mode_Index; O : in out Output)
     with Global => null
   is
      P    : Payload := (others => 0);
      Name : constant String := Mode_Name (I);
   begin
      Put_U32 (P, 0, Unsigned_32 (I - 1));
      Put_U32 (P, 4, (if I = Mode_Count then 2 else 0));
      Put_U8 (P, 8, Mode_Count);
      Put_U8 (P, 9, Unsigned_8 (I));
      Put_U8 (P, 10, Standard_Mode (I));
      for K in Name'Range loop
         Put_U8 (P, 10 + K, Character'Pos (Name (K)));
      end loop;
      Frame (T.Tx_Seq, O.Data, O.Length, Available_Modes_Id, 134, P, 46);
   end Send_Available_Mode;

   procedure Send_Modes_Monitor (T : in out Adaflight.MAVLink_Telemetry.State; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      Put_U8 (P, 0, 1);
      Frame (T.Tx_Seq, O.Data, O.Length, Modes_Monitor_Id, 30, P, 1);
   end Send_Modes_Monitor;

   procedure Send_Message_Interval (T : in out Adaflight.MAVLink_Telemetry.State; Id : Unsigned_32; O : in out Output)
     with Global => null
   is
      P        : Payload := (others => 0);
      Interval : constant Integer_32 :=
        (if Id <= Unsigned_32 (Natural'Last) then Adaflight.MAVLink_Telemetry.Message_Interval_Us (T, Natural (Id))
         else 0);
   begin
      Put_U32
        (P, 0,
         (if Interval >= 0 then Unsigned_32 (Interval) else Unsigned_32 (Interfaces.Integer_64 (Interval) + 2 ** 32)));
      Put_U16 (P, 4, Unsigned_16 (Id mod 65_536));
      Frame (T.Tx_Seq, O.Data, O.Length, Message_Interval_Id, 95, P, 6);
   end Send_Message_Interval;

   ------------------------------------------------------------------
   --  Requests.
   ------------------------------------------------------------------

   procedure Add (R : in out Requests; Q : Request)
     with Global => null
   is
   begin
      if R.Count < Max_Requests then
         R.Count := R.Count + 1;
         R.List (R.Count) := Q;
      end if;
   end Add;

   procedure Clear_Overrides (R : in out Requests)
     with Global => null
   is
   begin
      Add (R, (Kind => Clear_Overrides, others => <>));
   end Clear_Overrides;

   procedure Set_Override (R : in out Requests; B : Adaflight.Modes.Box)
     with Global => null
   is
   begin
      Add (R, (Kind => Set_Override, Box => B, others => <>));
   end Set_Override;

   ------------------------------------------------------------------
   --  Commands.
   ------------------------------------------------------------------

   procedure Arm_Disarm (P1 : Unsigned_32; R : in out Requests; Res : out Result)
     with Global => null
   is
      Arm : Unsigned_32;
      OK  : Boolean;
   begin
      To_Unsigned (P1, 1, Arm, OK);
      if not OK then
         Res := Denied;
      elsif Arm = 0 then
         Add (R, (Kind => Disarm, others => <>));
         Res := Accepted;
      else
         Res := Unsupported;
      end if;
   end Arm_Disarm;

   procedure Set_Mode (P1, P2 : Unsigned_32; R : in out Requests; Res : out Result)
     with Global => null
   is
      Base, Custom : Unsigned_32;
      OK           : Boolean;
   begin
      To_Unsigned (P1, 16#FF#, Base, OK);
      if not OK then
         Res := Denied;
         return;
      end if;
      To_Unsigned (P2, Mode_Count - 1, Custom, OK);
      if not OK or else (Base and 1) = 0 then
         Res := Denied;
      elsif Custom = 0 then
         Clear_Overrides (R);
         Res := Accepted;
      elsif Custom in 1 .. 6 then
         Clear_Overrides (R);
         Set_Override (R, Mode_Box (Mode_Index (Custom + 1)));
         Res := Accepted;
      else
         Res := Denied;
      end if;
   end Set_Mode;

   procedure Return_To_Launch (Inp : Inputs; R : in out Requests; Res : out Result)
     with Global => null
   is
   begin
      if not Inp.Armed then
         Res := Temporarily_Rejected;
      else
         Clear_Overrides (R);
         Set_Override (R, Adaflight.Modes.GPS_Rescue);
         Res := Accepted;
      end if;
   end Return_To_Launch;

   procedure Set_Home
     (Inp : Inputs; P1 : Unsigned_32; Coords_Valid : Boolean; Lat, Lon, Alt : Integer_32; R : in out Requests;
      Res : out Result)
     with Global => null
   is
      Use_Current : Unsigned_32;
      OK          : Boolean;
   begin
      To_Unsigned (P1, 1, Use_Current, OK);
      if not OK then
         Res := Denied;
      elsif Use_Current = 1 then
         if not Inp.GPS_Fix then
            Res := Temporarily_Rejected;
         else
            Add (R, (Kind => Reset_Home, others => <>));
            Res := Accepted;
         end if;
      elsif not Coords_Valid or else (Lat = 0 and then Lon = 0) then
         Res := Denied;
      else
         Add (R, (Kind        => Set_Home,
                  Latitude    => Integer_32'Max (-900_000_000, Integer_32'Min (900_000_000, Lat)),
                  Longitude   => Integer_32'Max (-1_800_000_000, Integer_32'Min (1_800_000_000, Lon)),
                  Altitude_Cm => Alt,
                  others      => <>));
         Res := Accepted;
      end if;
   end Set_Home;

   procedure Reboot (S : in out State; Inp : Inputs; P1 : Unsigned_32; Res : out Result)
     with Global => null
   is
      Action : Unsigned_32;
      OK     : Boolean;
   begin
      if Inp.Armed then
         Res := Temporarily_Rejected;
         return;
      end if;
      To_Unsigned (P1, 3, Action, OK);
      if not OK then
         Res := Denied;
      elsif Action = 0 then
         Res := Accepted;
      elsif Action = 1 or else Action = 3 then
         S.To_Bootloader := Action = 3;
         S.Reboot_Pending := True;
         Res := Accepted;
      else
         Res := Unsupported;
      end if;
   end Reboot;

   --  The commands both command messages execute.
   procedure Execute
     (S            : in out State;
      Inp          : Inputs;
      Command      : Unsigned_16;
      P1, P2       : Unsigned_32;
      Coords_Valid : Boolean;
      Lat, Lon     : Integer_32;
      Alt          : Integer_32;
      R            : in out Requests;
      Res          : out Result)
     with Global => null
   is
   begin
      case Command is
         when Arm_Disarm_Command =>
            Arm_Disarm (P1, R, Res);
         when Set_Mode_Command =>
            Set_Mode (P1, P2, R, Res);
         when Return_To_Launch_Command =>
            Return_To_Launch (Inp, R, Res);
         when Set_Home_Command =>
            Set_Home (Inp, P1, Coords_Valid, Lat, Lon, Alt, R, Res);
         when Reboot_Command =>
            Reboot (S, Inp, P1, Res);
         when others =>
            Res := Unsupported;
      end case;
   end Execute;

   procedure Request_Message
     (T   : in out Adaflight.MAVLink_Telemetry.State;
      C   : Settings;
      Inp : Inputs;
      P1  : Unsigned_32;
      P2  : Unsigned_32;
      Sysid, Compid : Unsigned_8;
      O   : in out Output)
     with Global => null
   is
      Id, Arg : Unsigned_32;
      OK      : Boolean;
      Res     : Result := Accepted;
   begin
      To_Unsigned (P1, Unsigned_32'Last, Id, OK);
      if not OK then
         Send_Ack (T, O, Request_Message_Command, Denied, Sysid, Compid);
         return;
      end if;
      case Id is
         when Autopilot_Version_Id =>
            Send_Autopilot_Version (T, C, O);
         when Protocol_Version_Id =>
            Send_Protocol_Version (T, O);
         when Component_Information_Id =>
            Send_Component_Information (T, Inp, O);
         when Available_Modes_Id =>
            To_Unsigned (P2, Mode_Count, Arg, OK);
            if not OK or else Arg < 1 then
               Res := Denied;
            else
               Send_Available_Mode (T, Mode_Index (Arg), O);
            end if;
         when Modes_Monitor_Id =>
            Send_Modes_Monitor (T, O);
         when Message_Interval_Id =>
            To_Unsigned (P2, Unsigned_32'Last, Arg, OK);
            if not OK then
               Res := Denied;
            else
               Send_Message_Interval (T, Arg, O);
            end if;
         when others =>
            Res := Unsupported;
      end case;
      Send_Ack (T, O, Request_Message_Command, Res, Sysid, Compid);
   end Request_Message;

   procedure Set_Message_Interval
     (T     : in out Adaflight.MAVLink_Telemetry.State;
      TC    : Adaflight.MAVLink_Telemetry.Settings;
      P1    : Unsigned_32;
      P2    : Unsigned_32;
      Sysid, Compid : Unsigned_8;
      O     : in out Output)
     with Global => null
   is
      Id    : Unsigned_32;
      OK    : Boolean;
      Found : Boolean := False;
   begin
      To_Unsigned (P1, Unsigned_32'Last, Id, OK);
      if not OK then
         Send_Ack (T, O, Message_Interval_Command, Denied, Sysid, Compid);
         return;
      end if;
      if Id <= Unsigned_32 (Natural'Last) then
         Adaflight.MAVLink_Telemetry.Set_Message_Interval (T, TC, Natural (Id), Interval_Ms (P2), Found);
      end if;
      Send_Ack (T, O, Message_Interval_Command, (if Found then Accepted else Denied), Sysid, Compid);
   end Set_Message_Interval;

   --  A command addressed to this system or to every system.
   function For_Us (Target_System, Target_Component : Unsigned_8) return Boolean is
     ((Target_System = 0 or else Target_System = MAVLink_Frames.System_Id)
      and then (Target_Component = 0 or else Target_Component = MAVLink_Frames.Component_Id));

   procedure Command_Long
     (S   : in out State;
      T   : in out Adaflight.MAVLink_Telemetry.State;
      TC  : Adaflight.MAVLink_Telemetry.Settings;
      C   : Settings;
      Inp : Inputs;
      Msg : Adaflight.MAVLink.Message;
      O   : in out Output;
      R   : in out Requests)
     with Global => null
   is
      Command      : constant Unsigned_16 := U16_At (Msg, 28);
      Sysid        : constant Unsigned_8 := Unsigned_8 (Msg.Sysid);
      Compid       : constant Unsigned_8 := Unsigned_8 (Msg.Compid);
      P1           : constant Unsigned_32 := U32_At (Msg, 0);
      P2           : constant Unsigned_32 := U32_At (Msg, 4);
      Request      : Unsigned_32;
      OK           : Boolean;
      Coords_Valid : Boolean := False;
      Lat, Lon     : Integer_32 := 0;
      Alt          : Integer_32 := 0;
      Res          : Result;
   begin
      if not For_Us (Byte_At (Msg, 30), Byte_At (Msg, 31)) then
         return;
      end if;
      case Command is
         when Capabilities_Command =>
            To_Unsigned (P1, 1, Request, OK);
            if not OK then
               Send_Ack (T, O, Command, Denied, Sysid, Compid);
            else
               if Request = 1 then
                  Send_Autopilot_Version (T, C, O);
               end if;
               Send_Ack (T, O, Command, Accepted, Sysid, Compid);
            end if;
         when Request_Message_Command =>
            Request_Message (T, C, Inp, P1, P2, Sysid, Compid, O);
         when Message_Interval_Command =>
            Set_Message_Interval (T, TC, P1, P2, Sysid, Compid, O);
         when others =>
            if Command = Set_Home_Command and then not Not_Finite (U32_At (Msg, 16))
              and then not Not_Finite (U32_At (Msg, 20)) and then not Not_Finite (U32_At (Msg, 24))
            then
               Coords_Valid := True;
               Lat := Round_Scaled (U32_At (Msg, 16), 1.0E7);
               Lon := Round_Scaled (U32_At (Msg, 20), 1.0E7);
               Alt := Round_Scaled (U32_At (Msg, 24), 100.0);
            end if;
            Execute (S, Inp, Command, P1, P2, Coords_Valid, Lat, Lon, Alt, R, Res);
            Send_Ack (T, O, Command, Res, Sysid, Compid);
      end case;
   end Command_Long;

   procedure Command_Int
     (S   : in out State;
      T   : in out Adaflight.MAVLink_Telemetry.State;
      Inp : Inputs;
      Msg : Adaflight.MAVLink.Message;
      O   : in out Output;
      R   : in out Requests)
     with Global => null
   is
      Command : constant Unsigned_16 := U16_At (Msg, 28);
      Z       : constant Unsigned_32 := U32_At (Msg, 24);
      Res     : Result;
   begin
      if not For_Us (Byte_At (Msg, 30), Byte_At (Msg, 31)) then
         return;
      end if;
      Execute
        (S, Inp, Command, U32_At (Msg, 0), U32_At (Msg, 4), True, I32_At (Msg, 16), I32_At (Msg, 20),
         (if Not_Finite (Z) then 0 else Round_Scaled (Z, 100.0)), R, Res);
      Send_Ack (T, O, Command, Res, Unsigned_8 (Msg.Sysid), Unsigned_8 (Msg.Compid));
   end Command_Int;

   procedure Ping (T : in out Adaflight.MAVLink_Telemetry.State; Msg : Adaflight.MAVLink.Message; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      if Byte_At (Msg, 12) /= 0 or else Byte_At (Msg, 13) /= 0 then
         return;
      end if;
      Put_U64 (P, 0, U64_At (Msg, 0));
      Put_U32 (P, 8, U32_At (Msg, 8));
      Put_U8 (P, 12, Unsigned_8 (Msg.Sysid));
      Put_U8 (P, 13, Unsigned_8 (Msg.Compid));
      Frame (T.Tx_Seq, O.Data, O.Length, Ping_Id, 237, P, 14);
   end Ping;

   procedure Timesync
     (T : in out Adaflight.MAVLink_Telemetry.State; Inp : Inputs; Msg : Adaflight.MAVLink.Message; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      if U64_At (Msg, 0) /= 0 or else not For_Us (Byte_At (Msg, 16), Byte_At (Msg, 17)) then
         return;
      end if;
      Put_U64 (P, 0, Unsigned_64 (Inp.Now_Us) * 1000);
      Put_U64 (P, 8, U64_At (Msg, 8));
      Put_U8 (P, 16, Unsigned_8 (Msg.Sysid));
      Put_U8 (P, 17, Unsigned_8 (Msg.Compid));
      Frame (T.Tx_Seq, O.Data, O.Length, Timesync_Id, 34, P, 18);
   end Timesync;

   --------------
   -- Dispatch --
   --------------

   procedure Dispatch
     (S   : in out State;
      T   : in out Adaflight.MAVLink_Telemetry.State;
      TC  : Adaflight.MAVLink_Telemetry.Settings;
      C   : Settings;
      Inp : Inputs;
      Msg : Adaflight.MAVLink.Message;
      O   : in out Output;
      R   : in out Requests)
   is
   begin
      case Msg.Id is
         when Ping_Id =>
            Ping (T, Msg, O);
         when Timesync_Id =>
            Timesync (T, Inp, Msg, O);
         when Command_Long_Id =>
            Command_Long (S, T, TC, C, Inp, Msg, O, R);
         when Command_Int_Id =>
            Command_Int (S, T, Inp, Msg, O, R);
         when others =>
            null;
      end case;
   end Dispatch;

   ------------------
   -- Process_Port --
   ------------------

   procedure Process_Port
     (S        : in out State;
      T        : in out Adaflight.MAVLink_Telemetry.State;
      TC       : Adaflight.MAVLink_Telemetry.Settings;
      C        : Settings;
      Inp      : Inputs;
      Waiting  : Adaflight.MAVLink_Frames.Byte_Buffer;
      Consumed : out Natural;
      O        : out Output;
      R        : out Requests)
   is
      Count  : constant Natural := Natural'Min (Port_Budget, Waiting'Length);
      Framed : Adaflight.MAVLink.Framing;
   begin
      O := (others => <>);
      R := (others => <>);
      for K in 0 .. Count - 1 loop
         Adaflight.MAVLink.Parse_Byte (S.Port, Natural (Waiting (Waiting'First + K)), Framed);
         if Framed = Adaflight.MAVLink.OK then
            declare
               Msg : constant Adaflight.MAVLink.Message := S.Port.Received;
            begin
               Dispatch (S, T, TC, C, Inp, Msg, O, R);
            end;
         end if;
      end loop;
      Consumed := Count;
      if S.Reboot_Pending then
         S.Reboot_Pending := False;
         R.Reboot := (if S.To_Bootloader then Bootloader else Reset);
      end if;
   end Process_Port;

   -------------------
   -- Process_Queue --
   -------------------

   procedure Process_Queue
     (S   : in out State;
      T   : in out Adaflight.MAVLink_Telemetry.State;
      TC  : Adaflight.MAVLink_Telemetry.Settings;
      C   : Settings;
      Inp : Inputs;
      Rx  : in out Adaflight.MAVLink.State;
      O   : out Output;
      R   : out Requests)
   is
      Msg : Adaflight.MAVLink.Message;
      Got : Boolean;
   begin
      O := (others => <>);
      R := (others => <>);
      for K in 1 .. Queue_Budget loop
         Adaflight.MAVLink.Pop_Queue (Rx, Msg, Got);
         exit when not Got;
         Dispatch (S, T, TC, C, Inp, Msg, O, R);
      end loop;
   end Process_Queue;

end Adaflight.MAVLink_Commands;
