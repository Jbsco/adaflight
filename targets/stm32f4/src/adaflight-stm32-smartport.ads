--  The SmartPort telemetry on a UART: the core's SmartPort stream answering
--  the receiver's polls on the telemetry port of the first provider with the
--  SmartPort protocol, at 57600 baud, inverted unless the telemetry's
--  inversion setting says otherwise and on one wire when its half-duplex
--  setting asks, with MSP requests from the receiver answered over it.
with Interfaces;
with Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.SmartPort_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.SmartPort is
   --  The provider's port and its sharing, with the telemetry feature on, and
   --  the value tables from the sensors.
   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Build  : Adaflight.SmartPort_Telemetry.Build_Inputs);
   --  The port opened or released as its sharing state asks now.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean);
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the telemetry task: the bytes received up to a complete
   --  poll, the rest kept for the next run, and the reply sent; an MSP
   --  request completed over the link goes through Answer for its reply.
   generic
      with procedure Answer (Command : Interfaces.Unsigned_16; Request : Adaflight.Bytes.Byte_Array;
                             Reply : out Adaflight.Bytes.Byte_Array; Length : out Natural; Failed : out Boolean);
   procedure Run (Inp : Adaflight.SmartPort_Telemetry.Inputs);
end Adaflight.STM32.SmartPort;
