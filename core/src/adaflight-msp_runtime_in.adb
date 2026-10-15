with Adaflight.Maths;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Runtime_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   --  A 32-bit field read as a signed value.
   function S32 (Request : Byte_Array; Offset : Offset_Range) return Interfaces.Integer_32 is
     (Interfaces.Integer_32 (if U32 (Request, Offset) >= 2 ** 31 then U32 (Request, Offset) - 2 ** 32
                             else U32 (Request, Offset)))
     with Pre => Request'Length <= Max_Request and then Offset < Offset_Range'Last - 2;

   --  An MSP GPS sensor's solution: the time of week, the fix, the
   --  satellites, the accuracies scaled from centimeters to millimeters, the
   --  dilution of precision, the position and altitude, the ground speed as
   --  the length of the north and east velocities saturated at the field's
   --  last value, and the ground course within a turn in tenths of a degree.
   --  The instance, the week, the down velocity, the yaw and the date and
   --  time are read and left.
   procedure Set_Sensor_GPS (Request : Byte_Array; E : in out Effects)
     with Pre => Request'Length <= Max_Request
   is
      use type Interfaces.Unsigned_64;
      North : constant Integer_64 := Integer_64 (S32 (Request, 29));
      East  : constant Integer_64 := Integer_64 (S32 (Request, 33));
      Sum   : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64 (North * North) + Interfaces.Unsigned_64 (East * East);
      Speed : constant Float := Maths.Sqrt_Non_Negative (Float (Sum));
   begin
      E.Solution.Time_Ms := Interfaces.Unsigned_32 (U32 (Request, 3));
      E.Solution.Fix := U8 (Request, 7) /= 0;
      E.Solution.Satellites := Byte (U8 (Request, 8));
      E.Solution.H_Accuracy := Interfaces.Unsigned_32 (U16 (Request, 9) * 10);
      E.Solution.V_Accuracy := Interfaces.Unsigned_32 (U16 (Request, 11) * 10);
      E.Solution.S_Accuracy := Interfaces.Unsigned_32 (U16 (Request, 13) * 10);
      E.Solution.PDOP := Interfaces.Unsigned_16 (U16 (Request, 15));
      E.Solution.Longitude := S32 (Request, 17);
      E.Solution.Latitude := S32 (Request, 21);
      E.Solution.Altitude_Cm := S32 (Request, 25);
      E.Solution.Ground_Speed :=
        (if Speed < 65_535.0 then Interfaces.Unsigned_16 (Float'Truncation (Speed)) else Interfaces.Unsigned_16'Last);
      E.Solution.Ground_Course := Interfaces.Unsigned_16 (U16 (Request, 41) mod 36_000 / 10);
      E.GPS := True;
      E.GPS_Sensor := True;
   end Set_Sensor_GPS;

   procedure Process (Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result; E : out Effects) is
   begin
      E := No_Effects;
      R := Ack;
      case Command is
         when Set_Raw_RC_Command =>
            if Request'Length / 2 > MSP_Receiver.Channel_Count then
               R := Error;
               return;
            end if;
            E.Count := Request'Length / 2;
            for I in 0 .. E.Count - 1 loop
               E.Frame (I) := Natural (U16 (Request, 2 * I));
            end loop;
            E.RC_Frame := True;
         when Set_Raw_GPS_Command =>
            E.Solution.Fix := U8 (Request, 0) /= 0;
            E.Solution.Satellites := Byte (U8 (Request, 1));
            E.Solution.Latitude := S32 (Request, 2);
            E.Solution.Longitude := S32 (Request, 6);
            E.Solution.Altitude_Cm := Interfaces.Integer_32 (U16 (Request, 10) * 100);
            E.Solution.Ground_Speed := Interfaces.Unsigned_16 (U16 (Request, 12));
            E.GPS := True;
         when Sensor_GPS_Command =>
            Set_Sensor_GPS (Request, E);
         when Set_TX_Info_Command =>
            E.RSSI_Value := Byte (U8 (Request, 0));
            E.RSSI := True;
         when Set_RTC_Command =>
            E.Clock_Ms := Interfaces.Integer_64 (S32 (Request, 0)) * 1000 + U16 (Request, 4);
            E.Clock := True;
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Runtime_In;
