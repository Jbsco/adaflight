--  The STM32F405's timer channels and DMA options for the command line:
--  the full timer table in the reference's order, which a pin's occurrence
--  numbers count along, each timer channel's DMA stream options and each
--  peripheral's, and the timers in their listing order. Generated from the
--  reference's tables.
with Interfaces; use Interfaces;

package Adaflight.Timer_Tables with SPARK_Mode is

   subtype Timer_Number is Positive range 1 .. 14;
   subtype Channel_Number is Positive range 1 .. 4;

   --  A timer channel on a pin: the pin's tag, the timer, the channel, whether
   --  the pin is the complementary output, and the pin's alternate function.
   type Timer_Channel is record
      Tag     : Unsigned_8;
      Timer   : Timer_Number;
      Channel : Channel_Number;
      N       : Boolean;
      AF      : Unsigned_8;
   end record;
   type Timer_Channel_List is array (Positive range <>) of Timer_Channel;

   Channels : constant Timer_Channel_List (1 .. 70) :=
     ((16, 2, 1, False, 1), (17, 2, 2, False, 1), (18, 2, 3, False, 1), (19, 2, 4, False, 1), (21, 2, 1, False, 1),
      (23, 1, 1, True, 1), (24, 1, 1, False, 1), (25, 1, 2, False, 1), (26, 1, 3, False, 1), (27, 1, 4, False, 1),
      (31, 2, 1, False, 1), (16, 5, 1, False, 2), (17, 5, 2, False, 2), (18, 5, 3, False, 2), (19, 5, 4, False, 2),
      (22, 3, 1, False, 2), (23, 3, 2, False, 2), (18, 9, 1, False, 3), (19, 9, 2, False, 3), (21, 8, 1, True, 3),
      (23, 8, 1, True, 3), (22, 13, 1, False, 9), (23, 14, 1, False, 9), (32, 1, 2, True, 1), (33, 1, 3, True, 1),
      (35, 2, 2, False, 1), (42, 2, 3, False, 1), (43, 2, 4, False, 1), (45, 1, 1, True, 1), (46, 1, 2, True, 1),
      (47, 1, 3, True, 1), (32, 3, 3, False, 2), (33, 3, 4, False, 2), (36, 3, 1, False, 2), (37, 3, 2, False, 2),
      (38, 4, 1, False, 2), (39, 4, 2, False, 2), (40, 4, 3, False, 2), (41, 4, 4, False, 2), (32, 8, 2, True, 3),
      (33, 8, 3, True, 3), (40, 10, 1, False, 3), (41, 11, 1, False, 3), (46, 8, 2, True, 3), (47, 8, 3, True, 3),
      (46, 12, 1, False, 9), (47, 12, 2, False, 9), (54, 3, 1, False, 2), (55, 3, 2, False, 2),
      (56, 3, 3, False, 2), (57, 3, 4, False, 2), (54, 8, 1, False, 3), (55, 8, 2, False, 3), (56, 8, 3, False, 3),
      (57, 8, 4, False, 3), (76, 4, 1, False, 2), (77, 4, 2, False, 2), (78, 4, 3, False, 2), (79, 4, 4, False, 2),
      (88, 1, 1, True, 1), (89, 1, 1, False, 1), (90, 1, 2, True, 1), (91, 1, 2, False, 1), (92, 1, 3, True, 1),
      (93, 1, 3, False, 1), (94, 1, 4, False, 1), (85, 9, 1, False, 3), (86, 9, 2, False, 3),
      (102, 10, 1, False, 3), (103, 11, 1, False, 3));

   --  A DMA stream option: the controller, the stream and the channel.
   type DMA_Stream is record
      Controller : Positive range 1 .. 2;
      Stream     : Natural range 0 .. 7;
      Channel    : Natural range 0 .. 7;
   end record;

   Max_Timer_Options      : constant := 3;
   Max_Peripheral_Options : constant := 2;
   type Timer_Options is array (1 .. Max_Timer_Options) of DMA_Stream;
   type Peripheral_Options is array (1 .. Max_Peripheral_Options) of DMA_Stream;

   --  A timer channel's DMA stream options, in option number order.
   type Timer_DMA is record
      Timer   : Timer_Number;
      Channel : Channel_Number;
      Count   : Natural range 0 .. Max_Timer_Options;
      Options : Timer_Options;
   end record;
   type Timer_DMA_List is array (Positive range <>) of Timer_DMA;

   Timer_Streams : constant Timer_DMA_List (1 .. 23) :=
     ((1, 1, 3, ((2, 6, 0), (2, 1, 6), (2, 3, 6))), (1, 2, 2, ((2, 6, 0), (2, 2, 6), (1, 0, 0))),
      (1, 3, 2, ((2, 6, 0), (2, 6, 6), (1, 0, 0))), (1, 4, 1, ((2, 4, 6), (1, 0, 0), (1, 0, 0))),
      (2, 1, 1, ((1, 5, 3), (1, 0, 0), (1, 0, 0))), (2, 2, 1, ((1, 6, 3), (1, 0, 0), (1, 0, 0))),
      (2, 3, 1, ((1, 1, 3), (1, 0, 0), (1, 0, 0))), (2, 4, 2, ((1, 7, 3), (1, 6, 3), (1, 0, 0))),
      (3, 1, 1, ((1, 4, 5), (1, 0, 0), (1, 0, 0))), (3, 2, 1, ((1, 5, 5), (1, 0, 0), (1, 0, 0))),
      (3, 3, 1, ((1, 7, 5), (1, 0, 0), (1, 0, 0))), (3, 4, 1, ((1, 2, 5), (1, 0, 0), (1, 0, 0))),
      (4, 1, 1, ((1, 0, 2), (1, 0, 0), (1, 0, 0))), (4, 2, 1, ((1, 3, 2), (1, 0, 0), (1, 0, 0))),
      (4, 3, 1, ((1, 7, 2), (1, 0, 0), (1, 0, 0))), (5, 1, 1, ((1, 2, 6), (1, 0, 0), (1, 0, 0))),
      (5, 2, 1, ((1, 4, 6), (1, 0, 0), (1, 0, 0))), (5, 3, 1, ((1, 0, 6), (1, 0, 0), (1, 0, 0))),
      (5, 4, 2, ((1, 1, 6), (1, 3, 6), (1, 0, 0))), (8, 1, 2, ((2, 2, 0), (2, 2, 7), (1, 0, 0))),
      (8, 2, 2, ((2, 2, 0), (2, 3, 7), (1, 0, 0))), (8, 3, 2, ((2, 2, 0), (2, 4, 7), (1, 0, 0))),
      (8, 4, 1, ((2, 7, 7), (1, 0, 0), (1, 0, 0))));

   --  The peripherals with DMA options, by the reference's device names.
   type Peripheral is (SPI_SDO, SPI_SDI, ADC, UART_TX, UART_RX);

   --  A peripheral device's DMA stream options, the device counted from zero.
   type Peripheral_DMA is record
      Which   : Peripheral;
      Device  : Natural range 0 .. 15;
      Count   : Natural range 0 .. Max_Peripheral_Options;
      Options : Peripheral_Options;
   end record;
   type Peripheral_DMA_List is array (Positive range <>) of Peripheral_DMA;

   Peripheral_Streams : constant Peripheral_DMA_List (1 .. 21) :=
     ((SPI_SDO, 0, 2, ((2, 3, 3), (2, 5, 3))), (SPI_SDI, 0, 2, ((2, 0, 3), (2, 2, 3))),
      (SPI_SDO, 1, 1, ((1, 4, 0), (1, 0, 0))), (SPI_SDI, 1, 1, ((1, 3, 0), (1, 0, 0))),
      (SPI_SDO, 2, 2, ((1, 5, 0), (1, 7, 0))), (SPI_SDI, 2, 2, ((1, 0, 0), (1, 2, 0))),
      (ADC, 0, 2, ((2, 0, 0), (2, 4, 0))), (ADC, 1, 2, ((2, 2, 1), (2, 3, 1))),
      (ADC, 2, 2, ((2, 0, 2), (2, 1, 2))), (UART_TX, 0, 1, ((2, 7, 4), (1, 0, 0))),
      (UART_RX, 0, 2, ((2, 5, 4), (2, 2, 4))), (UART_TX, 1, 1, ((1, 6, 4), (1, 0, 0))),
      (UART_RX, 1, 1, ((1, 5, 4), (1, 0, 0))), (UART_TX, 2, 1, ((1, 3, 4), (1, 0, 0))),
      (UART_RX, 2, 1, ((1, 1, 4), (1, 0, 0))), (UART_TX, 3, 1, ((1, 4, 4), (1, 0, 0))),
      (UART_RX, 3, 1, ((1, 2, 4), (1, 0, 0))), (UART_TX, 4, 1, ((1, 7, 4), (1, 0, 0))),
      (UART_RX, 4, 1, ((1, 0, 4), (1, 0, 0))), (UART_TX, 5, 2, ((2, 6, 5), (2, 7, 5))),
      (UART_RX, 5, 2, ((2, 1, 5), (2, 2, 5))));

   --  The timers in the order the timer listing takes them.
   type Timer_List is array (Positive range <>) of Timer_Number;
   Timers : constant Timer_List (1 .. 14) := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14);

   --  The table index of a pin's timer channel by its occurrence from one,
   --  zero when the pin has fewer.
   function By_Tag_And_Index (Tag : Unsigned_8; Index : Natural) return Natural
     with Post => By_Tag_And_Index'Result <= Channels'Last;

   --  How many timer channels a pin has.
   function Occurrences (Tag : Unsigned_8) return Natural
     with Post => Occurrences'Result <= Channels'Last;

   --  Whether a timer channel has a DMA option of a number, and the stream.
   procedure Timer_Option
     (Timer : Timer_Number; Channel : Channel_Number; Option : Integer; Found : out Boolean; Stream : out DMA_Stream);

   --  Whether a peripheral device has a DMA option of a number, and the stream.
   procedure Peripheral_Option
     (Which : Peripheral; Device : Natural; Option : Integer; Found : out Boolean; Stream : out DMA_Stream);

   --  Whether a timer channel, or a peripheral device, has a DMA option of a number.
   function Has_Timer_Option (Timer : Timer_Number; Channel : Channel_Number; Option : Integer) return Boolean
     with Post => (if Has_Timer_Option'Result then Option in 0 .. Max_Timer_Options - 1);
   function Has_Peripheral_Option (Which : Peripheral; Device : Natural; Option : Integer) return Boolean
     with Post => (if Has_Peripheral_Option'Result then Option in 0 .. Max_Peripheral_Options - 1);

end Adaflight.Timer_Tables;
