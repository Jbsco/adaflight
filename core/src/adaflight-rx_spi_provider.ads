--  The SPI receiver layer as the receiver core's provider: the device and
--  the protocol's receiver started, the interrupt started when configured,
--  the frame check that marks a new packet with its frame time, the FrSky
--  frame processing, the channel reads that take a new packet's channels
--  first, and the stop of the ExpressLRS receiver. The SPI device, the
--  interrupt, the dispatcher and the receiver families come in as the
--  instantiation's procedures.
with Adaflight.Receiver;
with Adaflight.RX_SPI; use Adaflight.RX_SPI;

generic
   with procedure Device_Init (Ok : out Boolean);
   with procedure Family_Init (F : Family; Ok : out Boolean);
   with function Exti_Configured return Boolean;
   with procedure Exti_Init;
   with procedure Dispatch_Enable;
   with procedure Family_Data_Received (F : Family; R : out Received);
   with procedure Family_Process_Frame (F : Family; R : out Received);
   with procedure Family_Set_Channels (F : Family; Data : in out Channel_Data);
   with procedure Family_Stop (F : Family);
   with function Last_Exti_Time return Receiver.Time_Us;
package Adaflight.RX_SPI_Provider with SPARK_Mode is

   --  The device, then the protocol's family and the interrupt. Providing
   --  says whether the receiver core takes this layer's functions.
   procedure Init (S : in out State; Protocol : Unsigned_8; Ok : out Boolean; Providing : out Boolean);

   procedure Frame_Status
     (S : in out State; Report : out Receiver.Frame_Report; Last_Frame_Us : in out Receiver.Time_Us);

   procedure Process_Frame (S : in out State);

   --  A channel outside the count reads 0 and leaves a new packet waiting.
   procedure Read_Raw (S : in out State; Channels : Natural; Ch : Natural; Value : out Float)
     with Pre => Channels <= Receiver.Channel_Count;

   procedure Stop (S : State);

   procedure Enable_Exti;

end Adaflight.RX_SPI_Provider;
