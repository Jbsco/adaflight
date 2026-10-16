--  The receiver bind: the CRSF and SRXL2 serial receivers and the SPI
--  receivers with a bind take one, the others none. The provider and the
--  serial protocol are the board's from its start, the SPI protocol the
--  configuration's. The MSP bind message starts the bind, or is an error
--  for a receiver without one.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.RX_Bind with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   type Bind is (No_Bind, CRSF_Bind, SRXL2_Bind, SPI_Bind);

   --  The serial and SPI protocol numbers of the receiver settings.
   CRSF_Protocol  : constant := 9;
   SRXL2_Protocol : constant := 13;
   subtype SPI_Bind_Protocol is Natural
     with Static_Predicate => SPI_Bind_Protocol in 8 .. 11 | 13 .. 19;

   function Bind_For (Source : Receiver.Provider; Serial_Protocol, SPI_Protocol : Natural) return Bind is
     (case Source is
         when Receiver.Serial =>
           (if Serial_Protocol = CRSF_Protocol then CRSF_Bind
            elsif Serial_Protocol = SRXL2_Protocol then SRXL2_Bind
            else No_Bind),
         when Receiver.SPI =>
           (if SPI_Protocol in SPI_Bind_Protocol then SPI_Bind else No_Bind),
         when Receiver.None | Receiver.Parallel_PWM | Receiver.PPM | Receiver.MSP | Receiver.UDP =>
           No_Bind);

   Bind_Command : constant := 16#3000#;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is (Command = Bind_Command);

end Adaflight.RX_Bind;
