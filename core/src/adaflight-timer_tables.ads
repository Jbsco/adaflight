--  Timer channels and DMA options for the command line and the timer
--  drivers: the full timer table in the reference's order, which a pin's
--  occurrence numbers count along, each timer channel's DMA stream options
--  and each peripheral's, and the timers in their listing order. An MCU
--  family's body contains its tables, generated from the reference's.
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

   --  The most timer channels a table has.
   Max_Channels : constant := 96;

   --  How many timer channels the table has, and the one at an index from one.
   function Channel_Count return Natural
     with Global => null, Post => Channel_Count'Result <= Max_Channels;
   function Channel (K : Positive) return Timer_Channel
     with Global => null, Pre => K <= Channel_Count;

   --  A DMA stream option: the controller, the stream and the channel.
   type DMA_Stream is record
      Controller : Positive range 1 .. 2;
      Stream     : Natural range 0 .. 7;
      Channel    : Natural range 0 .. 7;
   end record;

   Max_Timer_Options      : constant := 3;
   Max_Peripheral_Options : constant := 2;

   --  The peripherals with DMA options, by the reference's device names.
   type Peripheral is (SPI_SDO, SPI_SDI, ADC, UART_TX, UART_RX);

   --  How many timers the timer listing takes, and the one at a place from one.
   function Timer_Count return Natural
     with Global => null, Post => Timer_Count'Result <= Timer_Number'Last;
   function Timer_At (I : Positive) return Timer_Number
     with Global => null, Pre => I <= Timer_Count;

   --  The table index of a pin's timer channel by its occurrence from one,
   --  zero when the pin has fewer.
   function By_Tag_And_Index (Tag : Unsigned_8; Index : Natural) return Natural
     with Global => null, Post => By_Tag_And_Index'Result <= Channel_Count;

   --  How many timer channels a pin has.
   function Occurrences (Tag : Unsigned_8) return Natural
     with Global => null, Post => Occurrences'Result <= Channel_Count;

   --  Whether a timer channel has a DMA option of a number, and the stream.
   procedure Timer_Option
     (Timer : Timer_Number; Channel : Channel_Number; Option : Integer; Found : out Boolean; Stream : out DMA_Stream)
     with Global => null;

   --  Whether a peripheral device has a DMA option of a number, and the stream.
   procedure Peripheral_Option
     (Which : Peripheral; Device : Natural; Option : Integer; Found : out Boolean; Stream : out DMA_Stream)
     with Global => null;

   --  Whether a timer channel, or a peripheral device, has a DMA option of a number.
   function Has_Timer_Option (Timer : Timer_Number; Channel : Channel_Number; Option : Integer) return Boolean
     with Global => null, Post => (if Has_Timer_Option'Result then Option in 0 .. Max_Timer_Options - 1);
   function Has_Peripheral_Option (Which : Peripheral; Device : Natural; Option : Integer) return Boolean
     with Global => null, Post => (if Has_Peripheral_Option'Result then Option in 0 .. Max_Peripheral_Options - 1);

end Adaflight.Timer_Tables;
