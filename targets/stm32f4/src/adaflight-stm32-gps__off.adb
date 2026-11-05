--  The GPS of a build without one: no link, no port, no fix and no home.
package body Adaflight.STM32.GPS is

   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Now_Ms : Interfaces.Unsigned_32) is null;

   function Enabled return Boolean is (False);

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (False);

   procedure Run (Now_Ms, Now_Us : Interfaces.Unsigned_32; Armed : Boolean; R : out Report) is
   begin
      R := (others => <>);
   end Run;

   function Current return Readings is
   begin
      return G : Readings;
   end Current;

   procedure Reset_Home is null;

   procedure Set_Home (Lat, Lon, Alt_Cm : Interfaces.Integer_32) is null;

   function Link_State return Adaflight.GPS_Link.Link_State is (Adaflight.GPS_Link.Unknown);

   function Platform return Adaflight.GPS_Frames.Platform is (Adaflight.GPS_Frames.Undefined);

   function Port_Baud return Adaflight.Serial_Feature_Map.Baud_Index is (0);

   function Satellite (I : Adaflight.GPS_Frames.Satellite_Index) return Adaflight.GPS_Frames.Satellite is
   begin
      return S : Adaflight.GPS_Frames.Satellite;
   end Satellite;

   function Time return Adaflight.GPS_Frames.Date_Time is
   begin
      return T : Adaflight.GPS_Frames.Date_Time;
   end Time;

end Adaflight.STM32.GPS;
