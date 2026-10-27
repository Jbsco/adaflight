package body Adaflight.Host_Pins is
   Count : array (Port_Name, Pin_Number) of Natural := (others => (others => 0));

   procedure Rose (P : Pin) is
   begin
      Count (P.Port, P.Number) := (if Count (P.Port, P.Number) = Natural'Last then 0 else Count (P.Port, P.Number) + 1);
   end Rose;

   function Rises (P : Pin) return Natural is (Count (P.Port, P.Number));
end Adaflight.Host_Pins;
