--  The build options a configurator reads from the build information reply
--  and the options command: the reference's option numbers for the
--  receivers, the telemetry, the features and the motor protocols a build
--  contains, in the reference's order. A board selects the options its
--  image drives, those of the features a build leaves out off, and the list
--  names every one of them, since a configurator hides the tabs and the
--  motor protocols a nonempty list leaves out.
with Interfaces; use Interfaces;

package Adaflight.Build_Options with SPARK_Mode, Pure is

   --  The options in the reference's order.
   type Option is
     (Serial_RX_CRSF, Serial_RX_FPORT, Serial_RX_GHST, Serial_RX_IBus, Serial_RX_Jeti_EX_Bus, Serial_RX_MAVLink,
      RX_PPM, Serial_RX_SBUS, Serial_RX_Spektrum, Serial_RX_SRXL2, Serial_RX_SUMD, Serial_RX_SUMH, Serial_RX_XBus,
      Telemetry_FrSky_Hub, Telemetry_HoTT, Telemetry_IBus_Extended, Telemetry_LTM, Telemetry_MAVLink,
      Telemetry_SmartPort, Telemetry_SRXL,
      Acro_Trainer, AKK_SmartAudio, Altitude_Hold, Battery_Continue, Camera_Control, Chirp, Dashboard, DroneCAN,
      EMFAT_Tools, ESC_Serial_SimonK, Flight_Plan, GPS, LED_Strip, LED_Strip_64, Mag, Optical_Flow, OSD_SD, OSD_HD,
      FrSky_OSD, PINIO, Position_Hold, Race_Pro, Rangefinder, Soft_Serial, Servos, VTX, Wing,
      Brushed, DroneCAN_ESC, DShot, MultiShot, OneShot, ProShot, PWM_Output);

   --  An option's number in the build information.
   function Number (O : Option) return Unsigned_16 is
     (case O is
         when Serial_RX_CRSF          => 4097,
         when Serial_RX_FPORT         => 4098,
         when Serial_RX_GHST          => 4099,
         when Serial_RX_IBus          => 4100,
         when Serial_RX_Jeti_EX_Bus   => 4101,
         when Serial_RX_MAVLink       => 4109,
         when RX_PPM                  => 4102,
         when Serial_RX_SBUS          => 4103,
         when Serial_RX_Spektrum      => 4104,
         when Serial_RX_SRXL2         => 4105,
         when Serial_RX_SUMD          => 4106,
         when Serial_RX_SUMH          => 4107,
         when Serial_RX_XBus          => 4108,
         when Telemetry_FrSky_Hub     => 12301,
         when Telemetry_HoTT          => 12302,
         when Telemetry_IBus_Extended => 12303,
         when Telemetry_LTM           => 12304,
         when Telemetry_MAVLink       => 12305,
         when Telemetry_SmartPort     => 12306,
         when Telemetry_SRXL          => 12307,
         when Acro_Trainer            => 16404,
         when AKK_SmartAudio          => 16405,
         when Altitude_Hold           => 16422,
         when Battery_Continue        => 16406,
         when Camera_Control          => 16407,
         when Chirp                   => 16426,
         when Dashboard               => 16408,
         when DroneCAN                => 16430,
         when EMFAT_Tools             => 16409,
         when ESC_Serial_SimonK       => 16410,
         when Flight_Plan             => 16427,
         when GPS                     => 16412,
         when LED_Strip               => 16413,
         when LED_Strip_64            => 16414,
         when Mag                     => 16415,
         when Optical_Flow            => 16428,
         when OSD_SD                  => 16416,
         when OSD_HD                  => 16417,
         when FrSky_OSD               => 16411,
         when PINIO                   => 16418,
         when Position_Hold           => 16425,
         when Race_Pro                => 16419,
         when Rangefinder             => 16429,
         when Soft_Serial             => 16423,
         when Servos                  => 16420,
         when VTX                     => 16421,
         when Wing                    => 16424,
         when Brushed                 => 8230,
         when DroneCAN_ESC            => 8236,
         when DShot                   => 8231,
         when MultiShot               => 8232,
         when OneShot                 => 8233,
         when ProShot                 => 8234,
         when PWM_Output              => 8235);

   type Selection is array (Option) of Boolean;

   --  The room the build information reply and the command line keep.
   Max_Options : constant := 64;
   type Number_List is array (1 .. Max_Options) of Unsigned_16;
   type List is record
      Numbers : Number_List := (others => 0);
      Length  : Natural range 0 .. Max_Options := 0;
   end record;

   --  The numbers of the selected options in the reference's order.
   function In_Order (S : Selection) return List
     with Post => In_Order'Result.Length <= Option'Pos (Option'Last) + 1;

end Adaflight.Build_Options;
