--  The Spektrum satellite bind at power-up: whether a start binds, which pin
--  carries the pulses, and whether the bind count returns to zero afterwards.
--  A start binds when its bind plug, where the board has one, reads low,
--  the start is not a software reset, and the bind count is one to ten. The
--  pulses go out on the override pin when one is set, else on the receiver
--  port's line: the transmit pin on a half-duplex line, or for the SRXL
--  receiver only when the telemetry is on and does not share the port, and
--  the receive pin otherwise; no port means no pin. The count returns to
--  zero, to be saved, when no bind plug exists, the autoreset setting is on
--  and the start is not a software reset.
with Interfaces; use Interfaces;

package Adaflight.Spektrum_Bind with SPARK_Mode, Pure is

   Max_Pulses    : constant := 10;
   SRXL_Provider : constant Unsigned_8 := 10;

   --  The pin high for the power-up window, each pulse low then high for
   --  its time, and the override pin held high before its release.
   Window_Ms  : constant := 60;
   Pulse_Us   : constant := 120;
   Release_Ms : constant := 50;

   function Wanted (Plug_Present, Plug_High, Soft_Reset : Boolean; Count : Unsigned_8) return Boolean is
     (not (Plug_Present and Plug_High) and then not Soft_Reset and then Count in 1 .. Max_Pulses);

   function Pin
     (Override, Rx_Tag, Tx_Tag : Unsigned_8; Port_Known : Boolean; Provider : Unsigned_8;
      Telemetry, Shared, Half_Duplex : Boolean) return Unsigned_8 is
     (if Override /= 0 then Override
      elsif not Port_Known then 0
      elsif Provider = SRXL_Provider then (if Telemetry and then not Shared then Tx_Tag else 0)
      elsif Half_Duplex then Tx_Tag
      else Rx_Tag);

   function Autoreset (Plug_Present : Boolean; Setting : Unsigned_8; Soft_Reset : Boolean) return Boolean is
     (not Plug_Present and then Setting = 1 and then not Soft_Reset);

end Adaflight.Spektrum_Bind;
