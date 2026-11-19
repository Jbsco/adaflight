--  The storage of a serial receiver's frame and telemetry state and of the
--  SX1280 receiver's state, which a boot never uses together: a serial
--  receiver's port opens only with the serial receiver feature, and the
--  SX1280 receiver starts only with the SPI one. A build without the SX1280
--  receiver keeps no room for it.
with Adaflight.Build_Features;
with Adaflight.Bytes;
with Adaflight.CRSF;
with Adaflight.CRSF_Display_Port;
with Adaflight.ExpressLRS_Receiver;
with Adaflight.MSP_Telemetry;
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

   type Side is (Serial, SPI);
   type Sides (Which : Side := Serial) is record
      case Which is
         when Serial =>
            Serial_State : Serial_Side;
         when SPI =>
            SPI_State : Built_SPI_Side;
      end case;
   end record with Unchecked_Union;

   Shared : Sides with Suppress_Initialization;

end Adaflight.STM32.Receiver_Storage;
