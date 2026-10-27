with Adaflight.STM32.Time;
package body Adaflight.STM32.RTC is
   package Core renames Adaflight.RTC;

   C            : Core.Clock;
   Zone_Setting : Core.Settings;

   procedure Set_Zone (Minutes : Interfaces.Integer_16) is
   begin
      Zone_Setting.Zone :=
        Interfaces.Integer_16'Max (Core.Zone_Minutes'First, Interfaces.Integer_16'Min (Core.Zone_Minutes'Last, Minutes));
   end Set_Zone;

   function Zone return Core.Zone_Minutes is (Zone_Setting.Zone);

   function Has_Time return Boolean is (Core.Has_Time (C));

   procedure Set_Ms (T : Interfaces.Integer_64) is
   begin
      if T in Core.Time then
         Core.Set (C, T, Adaflight.STM32.Time.Millis);
      end if;
   end Set_Ms;

   procedure Set_Date (D : Core.Date_Time) is
   begin
      if D.Month in 1 .. 12 then
         Core.Set_Date_Time (C, D, Adaflight.STM32.Time.Millis);
      end if;
   end Set_Date;

   procedure Date_Now (Valid : out Boolean; D : out Core.Date_Time) is
   begin
      Core.Get_Date_Time (C, Adaflight.STM32.Time.Millis, D, Valid);
      if not Valid then
         D := Core.Default_Date;
      end if;
   end Date_Now;

   procedure Local_Now (Valid : out Boolean; Local : out Adaflight.FAT.Clock_Reading) is
      D : Core.Date_Time;
      L : Core.Date_Time;
   begin
      Date_Now (Valid, D);
      Local := (others => <>);
      if Valid then
         L := Core.UTC_To_Local (D, Zone_Setting);
         Local := (Year => L.Year, Month => L.Month, Day => L.Day, Hours => L.Hours, Minutes => L.Minutes,
                   Seconds => L.Seconds);
      end if;
   end Local_Now;

   function Start_Text return String is
      D      : Core.Date_Time;
      Valid  : Boolean;
      OK     : Boolean;
      Text   : Core.Formatted;
      Length : Natural;
   begin
      Date_Now (Valid, D);
      Core.Format_Local (D, Zone_Setting, Text, Length, OK);
      return Text (1 .. Length);
   end Start_Text;

   function Clock_Values return Adaflight.MSP_Out.Clock_Values is
      D     : Core.Date_Time;
      Valid : Boolean;
   begin
      Date_Now (Valid, D);
      return (Valid => Valid, Year => D.Year, Month => D.Month, Day => D.Day, Hours => D.Hours, Minutes => D.Minutes,
              Seconds => D.Seconds, Millis => D.Millis);
   end Clock_Values;
end Adaflight.STM32.RTC;
