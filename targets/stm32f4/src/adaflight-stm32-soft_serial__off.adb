--  The software serial ports of a build without them: no port and no pins.
package body Adaflight.STM32.Soft_Serial is

   procedure Configure (C : Adaflight.Config_Groups.Configuration; Feature_On : Boolean) is null;

   function Present (N : Port_Number) return Boolean is (False);

   function TX_Tag (N : Port_Number) return Interfaces.Unsigned_8 is (0);

   function RX_Tag (N : Port_Number) return Interfaces.Unsigned_8 is (0);

   procedure Open
     (N : Port_Number; Baud : Positive; Half_Duplex : Boolean; Inverted : Boolean;
      Resistor : Adaflight.STM32.GPIO.Pull; Opened : out Boolean)
   is
      pragma Unreferenced (N, Baud, Half_Duplex, Inverted, Resistor);
   begin
      Opened := False;
   end Open;

   function Is_Open (N : Port_Number) return Boolean is (False);

   procedure Set_Baud (N : Port_Number; Baud : Positive; Changed : out Boolean) is
      pragma Unreferenced (N, Baud);
   begin
      Changed := False;
   end Set_Baud;

   procedure Queue (N : Port_Number; Data : Byte_Array; Taken : out Natural) is
      pragma Unreferenced (N, Data);
   begin
      Taken := 0;
   end Queue;

   function Free (N : Port_Number) return Natural is (0);

   function Transmit_Empty (N : Port_Number) return Boolean is (True);

   procedure Take (N : Port_Number; Into : out Byte_Array; Count : out Natural) is
      pragma Unreferenced (N);
   begin
      Into := (others => 0);
      Count := 0;
   end Take;

end Adaflight.STM32.Soft_Serial;
