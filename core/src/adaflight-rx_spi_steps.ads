--  The SPI receiver layer's device, interrupt and receiver families as
--  units that count their calls and answer by the count, the shapes the
--  layer's proof takes.
with Interfaces;
with Adaflight.RX_SPI;

package Adaflight.RX_SPI_Steps with SPARK_Mode, Initializes => Calls is

   Calls : Natural := 0;

   function Counted (Before : Natural) return Natural is
     (if Before < Natural'Last then Before + 1 else 0);

   procedure Step
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   procedure Step_Ok (Ok : out Boolean)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then Ok = (Calls mod 2 = 0);

   procedure Step_Family_Ok (F : RX_SPI.Family; Ok : out Boolean)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old) and then Ok = (Calls mod 2 = 0);

   function Step_Query return Boolean is (Calls mod 2 = 1)
     with Global => (Input => Calls);

   function Step_Time return Interfaces.Unsigned_32 is (Interfaces.Unsigned_32 (Calls))
     with Global => (Input => Calls);

   procedure Step_Received (F : RX_SPI.Family; R : out RX_SPI.Received)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   procedure Step_Channels (F : RX_SPI.Family; Data : in out RX_SPI.Channel_Data)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

   procedure Step_Family (F : RX_SPI.Family)
     with Global => (In_Out => Calls),
          Post   => Calls = Counted (Calls'Old);

end Adaflight.RX_SPI_Steps;
