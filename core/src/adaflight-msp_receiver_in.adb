with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;
with Adaflight.MSP_Box;
with Adaflight.Modes;
with Adaflight.Adjustments;

package body Adaflight.MSP_Receiver_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   Mode_Range_Count       : constant := 20;
   Adjustment_Range_Count : constant := 30;
   Channel_Count          : constant := 18;
   Stick_Channel_Count    : constant := 4;
   Function_Count         : constant := Adjustments.Function_Kind'Pos (Adjustments.Function_Kind'Last) + 1;

   --  A slot, then the mode by its permanent id, its aux channel and steps,
   --  and while bytes remain its logic and linked mode; the command line's
   --  aux bounds hold the channel, the steps and the logic.
   procedure Set_Mode_Range (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Slot      : constant Integer_64 := U8 (Request, 0);
      Has_Logic : constant Boolean := Request'Length > 5;
      Found     : Boolean;
      Mode      : Modes.Box;
      Linked    : Modes.Box := Modes.Box'First;
   begin
      if Slot >= Mode_Range_Count then
         R := Error;
         return;
      end if;
      MSP_Box.Find_By_Permanent_Id (Byte (U8 (Request, 1)), Found, Mode);
      if not Found
        or else U8 (Request, 2) >= Modes.Aux_Channel_Count
        or else U8 (Request, 3) > Modes.Max_Range_Step
        or else U8 (Request, 4) > Modes.Max_Range_Step
      then
         R := Error;
         return;
      end if;
      if Has_Logic then
         MSP_Box.Find_By_Permanent_Id (Byte (U8 (Request, 6)), Found, Linked);
         if U8 (Request, 5) > 1 or else not Found then
            R := Error;
            return;
         end if;
      end if;
      declare
         M : Mode_Activation_Condition_Record renames C.Mode_Activation_Conditions (Natural (Slot));
      begin
         M.Mode_Id := Modes.Box'Pos (Mode);
         M.Aux_Channel_Index := Byte (U8 (Request, 2));
         M.Range_Value.Start_Step := Byte (U8 (Request, 3));
         M.Range_Value.End_Step := Byte (U8 (Request, 4));
         if Has_Logic then
            M.Mode_Logic := Byte (U8 (Request, 5));
            M.Linked_To := Modes.Box'Pos (Linked);
         end if;
      end;
      E.Modes_Init := True;
      R := Ack;
   end Set_Mode_Range;

   --  A slot, a deprecated byte, the aux channel, steps, function and switch
   --  channel, and the center and scale when four bytes remain; the command
   --  line's adjrange bounds hold the channels, steps and function.
   procedure Set_Adjustment_Range
     (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Slot : constant Integer_64 := U8 (Request, 0);
   begin
      if Slot >= Adjustment_Range_Count
        or else U8 (Request, 2) >= Modes.Aux_Channel_Count
        or else U8 (Request, 3) > Modes.Max_Range_Step
        or else U8 (Request, 4) > Modes.Max_Range_Step
        or else U8 (Request, 5) >= Function_Count
        or else U8 (Request, 6) >= Modes.Aux_Channel_Count
      then
         R := Error;
         return;
      end if;
      declare
         A : Adjustment_Range_Record renames C.Adjustment_Ranges (Natural (Slot));
      begin
         A.Aux_Channel_Index := Byte (U8 (Request, 2));
         A.Range_Value.Start_Step := Byte (U8 (Request, 3));
         A.Range_Value.End_Step := Byte (U8 (Request, 4));
         A.Adjustment_Config := Byte (U8 (Request, 5));
         A.Aux_Switch_Channel_Index := Byte (U8 (Request, 6));
         if Request'Length - 7 >= 4 then
            A.Adjustment_Center := Interfaces.Unsigned_16 (U16 (Request, 7));
            A.Adjustment_Scale := Interfaces.Unsigned_16 (U16 (Request, 9));
         end if;
      end;
      E.Adjustments_Reset := True;
      R := Ack;
   end Set_Adjustment_Range;

   --  Whether a stick smoothing setting the request writes changes, which
   --  the reference marks as needing a restart.
   function Changes (C : Configuration; S : Setting; V : Integer_64) return Boolean is
     (Get (C, S) /= V)
     with Pre => Profile_Count (S) >= 1 and then Element_Count (S) >= 1;

   --  The receiver provider, stick limits and satellite binding, then each
   --  group the request's length reaches: the pulse limits, the air mode
   --  threshold from its pulse, the SPI receiver with its id and channel
   --  count, which no setting names, the camera angle, the stick smoothing
   --  cutoffs and throttle factor, the USB device type, the smoothing factor
   --  held to its bounds, the smoothing switch, and the ExpressLRS id and
   --  model.
   procedure Set_Rx_Config (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Length  : constant Natural := Request'Length;
      Offset  : Offset_Range := 8;
      Has_Spi : Boolean := False;
      Spi_At  : Offset_Range := 0;
      Reboot  : Boolean := False;
      P       : Plan;
   begin
      Add (P, Serialrx_Provider, U8 (Request, 0), 0);
      Add (P, Max_Check, U16 (Request, 1), 0);
      Add (P, Mid_Rc, U16 (Request, 3), 0);
      Add (P, Min_Check, U16 (Request, 5), 0);
      Add (P, Spektrum_Sat_Bind, U8 (Request, 7), 0);
      if Length - Offset >= 4 then
         Add (P, Rx_Min_Usec, U16 (Request, Offset), 0);
         Add (P, Rx_Max_Usec, U16 (Request, Offset + 2), 0);
         Offset := Offset + 4;
      end if;
      if Length - Offset >= 4 then
         Add (P, Airmode_Start_Throttle_Percent, (U16 (Request, Offset + 2) - 1_000) / 10, 0);
         Offset := Offset + 4;
      end if;
      if Length - Offset >= 6 then
         Add (P, Rx_Spi_Protocol, U8 (Request, Offset), 0);
         Has_Spi := True;
         Spi_At := Offset;
         Offset := Offset + 6;
      end if;
      if Length - Offset >= 1 then
         Add (P, Fpv_Mix_Degrees, U8 (Request, Offset), 0);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 6 then
         Add (P, Rc_Smoothing_Setpoint_Cutoff, U8 (Request, Offset + 2), 0);
         Add (P, Rc_Smoothing_Throttle_Cutoff, U8 (Request, Offset + 3), 0);
         Add (P, Rc_Smoothing_Auto_Factor_Throttle, U8 (Request, Offset + 4), 0);
         Reboot := Changes (C, Rc_Smoothing_Setpoint_Cutoff, U8 (Request, Offset + 2))
           or else Changes (C, Rc_Smoothing_Throttle_Cutoff, U8 (Request, Offset + 3))
           or else Changes (C, Rc_Smoothing_Auto_Factor_Throttle, U8 (Request, Offset + 4));
         Offset := Offset + 6;
      end if;
      if Length - Offset >= 1 then
         Add (P, Usb_Hid_Cdc, U8 (Request, Offset), 0);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 1 then
         Add (P, Rc_Smoothing_Auto_Factor, Integer_64'Min (U8 (Request, Offset), 250), 0);
         Reboot := Reboot or else Changes (C, Rc_Smoothing_Auto_Factor, Integer_64'Min (U8 (Request, Offset), 250));
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 1 then
         Add (P, Rc_Smoothing, U8 (Request, Offset), 0);
         Reboot := Reboot or else Changes (C, Rc_Smoothing, U8 (Request, Offset));
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 6 then
         for J in 0 .. 5 loop
            pragma Loop_Invariant (P.Count = P.Count'Loop_Entry + J and then Fits (P));
            Add (P, Expresslrs_Uid, U8 (Request, Offset + J), 0, J);
         end loop;
         Offset := Offset + 6;
      end if;
      if Length - Offset >= 1 then
         Add (P, Expresslrs_Model_Id, U8 (Request, Offset), 0);
      end if;
      if not Valid (P) then
         R := Error;
         return;
      end if;
      Apply (C, P);
      if Has_Spi then
         C.Rx_Spi_Config.Rx_Spi_Id := Interfaces.Unsigned_32 (U32 (Request, Spi_At + 1));
         C.Rx_Spi_Config.Rx_Spi_Rf_Channel_Count := Byte (U8 (Request, Spi_At + 5));
      end if;
      E.Reboot_Required := Reboot;
      R := Ack;
   end Set_Rx_Config;

   --  A channel, its failsafe mode, which the command line's rxfail bounds
   --  to automatic or hold for a stick and hold or set for an aux channel,
   --  and its value as a step from the pulse held to the pulse limits.
   procedure Set_Rxfail_Config (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Channel : constant Integer_64 := U8 (Request, 0);
      Mode    : constant Integer_64 := U8 (Request, 1);
      Pulse   : constant Integer_64 := Integer_64'Max (750, Integer_64'Min (2_250, U16 (Request, 2)));
   begin
      if Channel >= Channel_Count
        or else (if Channel < Stick_Channel_Count then Mode > 1 else Mode not in 1 .. 2)
      then
         R := Error;
         return;
      end if;
      C.Rx_Failsafe_Channel_Configs (Natural (Channel)).Mode := Byte (Mode);
      C.Rx_Failsafe_Channel_Configs (Natural (Channel)).Step := Byte ((Pulse - 750) / 25);
      R := Ack;
   end Set_Rxfail_Config;

   --  Eight channel positions, each a distinct one of the eight, as the
   --  command line's map takes them.
   procedure Set_Rx_Map (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
   begin
      if (for some J in 0 .. 7 => U8 (Request, J) > 7
            or else (for some K in 0 .. 7 => K /= J and then U8 (Request, J) = U8 (Request, K)))
      then
         R := Error;
         return;
      end if;
      for J in 0 .. 7 loop
         C.Rx_Config.Rcmap (J) := Byte (U8 (Request, J));
      end loop;
      R := Ack;
   end Set_Rx_Map;

   --  A request of planned writes, checked together.
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

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
   is
      P : Plan;
   begin
      E := No_Effects;
      case Command is
         when Set_Mode_Range_Command =>
            Set_Mode_Range (C, Request, R, E);
         when Set_Adjustment_Range_Command =>
            Set_Adjustment_Range (C, Request, R, E);
         when Set_Rx_Config_Command =>
            Set_Rx_Config (C, Request, R, E);
         when Set_Failsafe_Config_Command =>
            Add (P, Failsafe_Delay, U8 (Request, 0), 0);
            Add (P, Failsafe_Landing_Time, U8 (Request, 1), 0);
            Add (P, Failsafe_Throttle, U16 (Request, 2), 0);
            Add (P, Failsafe_Switch_Mode, U8 (Request, 4), 0);
            Add (P, Failsafe_Throttle_Low_Delay, U16 (Request, 5), 0);
            Add (P, Failsafe_Procedure, U8 (Request, 7), 0);
            Set_Fields (C, P, R);
         when Set_Rxfail_Config_Command =>
            Set_Rxfail_Config (C, Request, R);
         when Set_RSSI_Config_Command =>
            Add (P, Rssi_Channel, S8 (Request, 0), 0);
            Set_Fields (C, P, R);
         when Set_Rx_Map_Command =>
            Set_Rx_Map (C, Request, R);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Receiver_In;
