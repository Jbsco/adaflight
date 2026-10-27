with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Runtime;
with Adaflight.STM32.RTC;
with Adaflight.STM32.USART;
package body Adaflight.STM32.GPS is
   use type Interfaces.Unsigned_32;
   package SFM renames Adaflight.Serial_Feature_Map;
   package USART renames Adaflight.STM32.USART;

   Port_Ids : constant array (USART.Number) of SFM.Port_Id :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);

   Open     : Boolean := False;
   Which    : USART.Number := USART.UART4;
   Port     : USART.Port;
   Link     : Adaflight.GPS_Link.Link;
   Rx       : Adaflight.GPS_Frames.Receiver;
   Settings : Adaflight.GPS_Link.Settings;
   Solution_At : Interfaces.Unsigned_32 := 0;
   Input    : Byte_Array (0 .. 255);

   function Baud_Index_Of (B : Adaflight.GPS_Link.Baud_Rate) return SFM.Baud_Index is
     (case B is
         when Adaflight.GPS_Link.B_9600   => 1,
         when Adaflight.GPS_Link.B_19200  => 2,
         when Adaflight.GPS_Link.B_38400  => 3,
         when Adaflight.GPS_Link.B_57600  => 4,
         when Adaflight.GPS_Link.B_115200 => 5,
         when Adaflight.GPS_Link.B_230400 => 6);

   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Now_Ms : Interfaces.Unsigned_32)
   is
      Assigned : constant SFM.Assignments := Adaflight.Config_Fix.Serial_Assignments (Config);
   begin
      Open := False;
      if (Runtime_Features and Adaflight.Config_Fix.Feature_GPS) /= 0 then
         for N in USART.Number loop
            if (SFM.Function_Mask (Adaflight.Config_Fix.Serial_Options, Assigned, Port_Ids (N))
                and SFM.Function_GPS) /= 0
            then
               Which := N;
               Open := True;
               exit;
            end if;
         end loop;
      end if;
      Settings := Adaflight.Config_Runtime.GPS_Link_Settings_Of (Config.Gps_Config, Config.Gps_Rescue_Config, Open);
      Rx := (others => <>);
      Adaflight.GPS_Link.Init (Link, Rx, Settings, Now_Ms, Port_Opened => Open);
      if Open then
         Port.Which := Which;
         USART.Init (Which, Positive (Adaflight.GPS_Link.Rate_Of (Link.Port_Baud)));
      end if;
   end Init;

   function Enabled return Boolean is (Open);

   procedure Run (Now_Ms, Now_Us : Interfaces.Unsigned_32; Armed : Boolean; R : out Report) is
      Count    : Natural := 0;
      E        : Adaflight.GPS_Link.Events;
      Has_Time : Boolean;
   begin
      R := (others => <>);
      if not Open then
         return;
      end if;
      USART.Take (Which, Input, Count);
      Has_Time := Adaflight.STM32.RTC.Has_Time;
      Adaflight.GPS_Link.Update
        (Link, Rx, Settings, Now_Ms, Now_Us, Input (0 .. Count - 1), Tx_Empty => True, Armed => Armed,
         Clock_Has_Time => Has_Time, E => E);
      if E.Clock.Set then
         Adaflight.STM32.RTC.Set_Date
           ((Year => E.Clock.Year, Month => E.Clock.Month, Day => E.Clock.Day, Hours => E.Clock.Hours,
             Minutes => E.Clock.Minutes, Seconds => E.Clock.Seconds, Millis => E.Clock.Millis));
      end if;
      if E.Tx.Length > 0 then
         declare
            Out_Bytes : Byte_Array (0 .. E.Tx.Length - 1);
         begin
            for I in Out_Bytes'Range loop
               Out_Bytes (I) := E.Tx.Data (I);
            end loop;
            USART.Put (Port, Out_Bytes);
         end;
      end if;
      if E.Baud_Changed then
         USART.Init (Which, Positive (Adaflight.GPS_Link.Rate_Of (E.New_Baud)));
      end if;
      if E.Solutions > 0 then
         Solution_At := Now_Ms;
      end if;
      R := (Ready_Beep => E.Ready_Beep, Rate => E.Rate, Solutions => E.Solutions);
   end Run;

   function Current return Readings is
     ((Present             => Link.Sensor_Present,
       Fix                 => Rx.Fix,
       Fix_Home            => Link.Fix_Home,
       Fix_Ever            => Rx.Fix_Ever,
       Healthy             => Adaflight.GPS_Link.Healthy (Link),
       Satellites          => Rx.Sol.Num_Sat,
       Latitude            => Rx.Sol.Llh.Lat,
       Longitude           => Rx.Sol.Llh.Lon,
       Altitude_Cm         => Rx.Sol.Llh.Alt_Cm,
       Ground_Speed        => Rx.Sol.Ground_Speed,
       Speed_3D            => Rx.Sol.Speed_3d,
       Ground_Course       => Rx.Sol.Ground_Course,
       Velocity            => Rx.Sol.Velned,
       PDOP                => Rx.Sol.Dop.Pdop,
       HDOP                => Rx.Sol.Dop.Hdop,
       VDOP                => Rx.Sol.Dop.Vdop,
       Distance_To_Home_M  => Link.Distance_To_Home_M,
       Distance_To_Home_Cm => Link.Distance_To_Home_Cm,
       Direction_To_Home   => Link.Direction_To_Home,
       Distance_Flown_Cm   => Link.Distance_Flown_Cm,
       Time_Ms             => Rx.Sol.Time,
       Solution_Ms         => Solution_At,
       Use_3D_Speed        => Settings.Use_3D_Speed,
       Home                => Link.Home,
       In_View             => Rx.Num_Channels,
       Tick                => Link.Tick));

   function Link_State return Adaflight.GPS_Link.Link_State is (Link.State);

   function Platform return Adaflight.GPS_Frames.Platform is (Rx.UBX.Version);

   function Port_Baud return SFM.Baud_Index is (if Open then Baud_Index_Of (Link.Port_Baud) else SFM.Baud_Auto);

   function Satellite (I : Adaflight.GPS_Frames.Satellite_Index) return Adaflight.GPS_Frames.Satellite is
     (Rx.Sats (I));

   function Time return Adaflight.GPS_Frames.Date_Time is (Rx.Sol.Utc);
end Adaflight.STM32.GPS;
