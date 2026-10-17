with Adaflight.Clock;

package body Adaflight.MT_Sensor with SPARK_Mode is
   use type Interfaces.Integer_64;

   function Detect (Hardware : Interfaces.Unsigned_8) return Device is
   begin
      case Hardware is
         when MTF01 =>
            return (Present => True, Delay_Ms => 10, Max_Range_Cm => 800);
         when MTF02 =>
            return (Present => True, Delay_Ms => 20, Max_Range_Cm => 250);
         when MTF01P =>
            return (Present => True, Delay_Ms => 10, Max_Range_Cm => 1200);
         when MTF02P =>
            return (Present => True, Delay_Ms => 20, Max_Range_Cm => 600);
         when others =>
            return (Present => False, Delay_Ms => 0, Max_Range_Cm => 0);
      end case;
   end Detect;

   procedure Range_Receive (S : in out State; Distance_Mm : Interfaces.Integer_32; Now_Us : Interfaces.Unsigned_32) is
   begin
      S.Distance_Mm := Distance_Mm;
      S.Range_Time_Us := Now_Us;
      S.Range_New := True;
   end Range_Receive;

   procedure Range_Read (S : in out State; Distance : out Rangefinder.Reading) is
   begin
      if S.Range_New then
         S.Range_New := False;
         if S.Distance_Mm >= 0 then
            Distance := Interfaces.Integer_32'Min (S.Distance_Mm / 10, Rangefinder.Reading'Last);
         else
            Distance := Rangefinder.Out_Of_Range;
         end if;
      else
         Distance := Rangefinder.No_New_Data;
      end if;
   end Range_Read;

   procedure Flow_Receive
     (S : in out State; Quality : Interfaces.Unsigned_8; Motion_X, Motion_Y : Interfaces.Integer_32;
      Now_Us : Interfaces.Unsigned_32)
   is
      subtype Interval is Float range 1.0E-6 .. 1.0;
      Limit : constant := 1.0E6;

      --  A motion over the interval, held to the optical flow readings'
      --  bound.
      function Rate (Motion : Interfaces.Integer_32; Dt : Interval) return Optical_Flow.Flow_Rate is
         (Float'Max (-Limit, Float'Min (Limit, Float (Motion) / 200.0 / Dt)));

      Diff : constant Interfaces.Unsigned_32 := Now_Us - S.Flow.Time_Stamp_Us;
      Dt_S : constant Float := Float (Diff) / 1.0E6;
   begin
      if not S.Conf.Present then
         return;
      end if;
      declare
         Dt_Valid    : constant Boolean := Dt_S > 0.0 and then Dt_S < 1.0;
         Range_Valid : constant Boolean := S.Distance_Mm >= Flow_Min_Range_Mm;
         Fresh       : constant Boolean :=
           Interfaces.Integer_64 (Clock.Elapsed (Now_Us, S.Range_Time_Us))
             <= 5_000 * Interfaces.Integer_64 (S.Conf.Delay_Ms);
      begin
         S.Flow.Time_Stamp_Us := Now_Us;
         S.Dt_Valid := Dt_Valid;
         S.Range_Valid := Range_Valid and then Fresh;
         S.Flow_Valid := Dt_Valid;
         if Dt_Valid then
            pragma Assert (Diff >= 1);
            S.Flow.Flow_X := Rate (Motion_X, Dt_S);
            S.Flow.Flow_Y := Rate (Motion_Y, Dt_S);
            S.Flow.Quality := Interfaces.Integer_16 (Natural (Quality) * 100 / 255);
         else
            S.Flow.Flow_X := 0.0;
            S.Flow.Flow_Y := 0.0;
            S.Flow.Quality := 0;
         end if;
         if not Range_Valid then
            S.Flow.Quality := Optical_Flow.Out_Of_Range;
         elsif not Fresh then
            S.Flow.Quality := Optical_Flow.Hardware_Failure;
         end if;
      end;
   end Flow_Receive;

end Adaflight.MT_Sensor;
