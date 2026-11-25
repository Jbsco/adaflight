--  The flight log output's debug values as the reference records them over
--  the bytes written to the log device: the output rate in kilobits per
--  second over windows longer than 100 ms, the peak rate, and on a serial
--  port the bytes dropped with no transmit room and the free transmit bytes
--  before each byte. A byte counts eight bits, ten on a serial port. The
--  counts run under every debug mode, as the reference keeps them.
with Interfaces;
with Adaflight.Debug;

package Adaflight.Blackbox_Output_Debug with SPARK_Mode is

   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  The bits written since the last window, the window's start, the peak
   --  rate and the bytes dropped.
   type State is record
      Bits          : Unsigned_32 := 0;
      Last_Clear_Ms : Unsigned_32 := 0;
      Rate_Max      : Unsigned_16 := 0;
      Drops         : Unsigned_32 := 0;
   end record;

   --  A block of Count bytes handed to the log device at Now_Ms. On a serial
   --  port, Free is its free transmit bytes before the block: each byte
   --  written takes one, and a byte with none left is dropped.
   procedure Record_Write
     (D : in out Debug.State; S : in out State; Serial : Boolean; Count : Natural; Free : Unsigned_32;
      Now_Ms : Unsigned_32)
     with Global => null;

end Adaflight.Blackbox_Output_Debug;
