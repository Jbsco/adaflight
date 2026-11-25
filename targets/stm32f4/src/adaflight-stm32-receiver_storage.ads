--  The storage of a serial receiver's frame and telemetry state, of the
--  SX1280 receiver's state and of the CC2500 families' state, which a boot
--  never uses together: a serial receiver's port opens only with the serial
--  receiver feature, and an SPI receiver starts only with the SPI one, one
--  family of one radio. A build without a radio keeps no room for it.
with Adaflight.Build_Features;
with Adaflight.Bytes;
with Adaflight.CRSF;
with Adaflight.CRSF_Display_Port;
with Adaflight.ExpressLRS_Receiver;
with Adaflight.FrSky_SPI;
with Adaflight.MSP_Telemetry;
with Adaflight.Redpine;
with Adaflight.SFHSS;
with Adaflight.SmartPort_Telemetry;
with Adaflight.SPI_Radio;
with Adaflight.SRXL_Telemetry;
with Adaflight.Stream_Buffers;
with Adaflight.STM32.USART;

package Adaflight.STM32.Receiver_Storage is

   MSP_Buffer_Size : constant := 96;

   subtype Answer_Bytes is Adaflight.Bytes.Byte_Array (0 .. Adaflight.MSP_Telemetry.Response_Buffer_Size - 1);

   type Serial_Side is record
      Proto      : Adaflight.CRSF.State;
      Out_Bytes  : Adaflight.Bytes.Byte_Array (0 .. 1_023);
      Out_Stream : Adaflight.Stream_Buffers.Stream;
      MSP_Frames : Adaflight.Bytes.Byte_Array (0 .. MSP_Buffer_Size - 1);
      MSP_Link   : Adaflight.MSP_Telemetry.Tunnel;
      MSP_Answer : Answer_Bytes;
      --  The serial receiver port's bytes as taken, with their arrival times,
      --  and the times the port's interrupt stamps them with.
      Input      : Adaflight.Bytes.Byte_Array (0 .. 63);
      Times      : Adaflight.STM32.USART.Time_Array (0 .. 63);
      Stamps     : Adaflight.STM32.USART.Time_Array (0 .. 255);
      FP_Stream  : Adaflight.SmartPort_Telemetry.Stream;
      SRXL_Tlm   : Adaflight.SRXL_Telemetry.Stream;
      Screen     : Adaflight.CRSF_Display_Port.Screen;
   end record;

   type SPI_Side (Built : Boolean := False) is record
      case Built is
         when True =>
            Receiver   : Adaflight.ExpressLRS_Receiver.Receiver;
            Pin_Ops    : Adaflight.SPI_Radio.Output;
            Tunnel     : Adaflight.MSP_Telemetry.Tunnel;
            MSP_Answer : Answer_Bytes;
         when False =>
            null;
      end case;
   end record;
   subtype Built_SPI_Side is SPI_Side (Adaflight.Build_Features.SX1280_Receiver);

   --  A CC2500 family's settings, its state and the trial copy a call runs
   --  first, and for FrSky the X telemetry's stream, values, MSP tunnel and
   --  reply.
   type FrSky_Side is record
      Settings     : Adaflight.FrSky_SPI.Settings;
      State        : Adaflight.FrSky_SPI.State;
      Trial        : Adaflight.FrSky_SPI.State;
      Smart        : Adaflight.SmartPort_Telemetry.Stream;
      Smart_Values : Adaflight.SmartPort_Telemetry.Inputs;
      Tunnel       : Adaflight.MSP_Telemetry.Tunnel;
      Reply        : Answer_Bytes;
   end record;

   type SFHSS_Side is record
      Settings : Adaflight.SFHSS.Settings;
      State    : Adaflight.SFHSS.State;
      Trial    : Adaflight.SFHSS.State;
   end record;

   type Redpine_Side is record
      Settings : Adaflight.Redpine.Settings;
      State    : Adaflight.Redpine.State;
      Trial    : Adaflight.Redpine.State;
   end record;

   type Radio_Family is (FrSky, SFHSS, Redpine);
   type Family_Sides (Which : Radio_Family := FrSky) is record
      case Which is
         when FrSky =>
            FrSky_State : FrSky_Side;
         when SFHSS =>
            SFHSS_State : SFHSS_Side;
         when Redpine =>
            Redpine_State : Redpine_Side;
      end case;
   end record with Unchecked_Union;

   --  The calibration table a start fills, and the started family's state.
   type Radio_Side (Built : Boolean := False) is record
      case Built is
         when True =>
            Calibration : Adaflight.FrSky_SPI.Calibration_Table;
            Family      : Family_Sides;
         when False =>
            null;
      end case;
   end record;
   subtype Built_Radio_Side is Radio_Side (Adaflight.Build_Features.CC2500_Receiver);

   type Side is (Serial, SPI, Radio);
   type Sides (Which : Side := Serial) is record
      case Which is
         when Serial =>
            Serial_State : Serial_Side;
         when SPI =>
            SPI_State : Built_SPI_Side;
         when Radio =>
            Radio_State : Built_Radio_Side;
      end case;
   end record with Unchecked_Union;

   Shared : Sides with Suppress_Initialization;

end Adaflight.STM32.Receiver_Storage;
