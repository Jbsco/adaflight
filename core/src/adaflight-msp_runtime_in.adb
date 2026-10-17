with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Runtime_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   --  A 32-bit field read as a signed value.
   function S32 (Request : Byte_Array; Offset : Offset_Range) return Interfaces.Integer_32 is
     (Interfaces.Integer_32 (if U32 (Request, Offset) >= 2 ** 31 then U32 (Request, Offset) - 2 ** 32
                             else U32 (Request, Offset)))
     with Pre => Request'Length <= Max_Request and then Offset < Offset_Range'Last - 2;

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
            E.Solution :=
              (Fix          => U8 (Request, 0) /= 0,
               Satellites   => Byte (U8 (Request, 1)),
               Latitude     => S32 (Request, 2),
               Longitude    => S32 (Request, 6),
               Altitude_Cm  => Interfaces.Integer_32 (U16 (Request, 10) * 100),
               Ground_Speed => Interfaces.Unsigned_16 (U16 (Request, 12)));
            E.GPS := True;
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
