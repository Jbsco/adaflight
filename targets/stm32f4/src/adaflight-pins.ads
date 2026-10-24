--  Pin names for the board packages that tools/boardgen.py writes: a port
--  letter and a number within it, and the entries of a board's timer map.
package Adaflight.Pins is

   type Port_Name is (Port_A, Port_B, Port_C, Port_D, Port_E, Port_F, Port_G, Port_H, Port_I, Port_J, Port_K);
   type Pin_Number is range 0 .. 15;

   type Pin is record
      Port   : Port_Name;
      Number : Pin_Number;
   end record;

   --  A timer map entry: its index in the board's list, the pin, the timer
   --  option and the DMA option, -1 for none.
   type Timer_Pin is record
      Index        : Natural;
      P            : Pin;
      Timer_Option : Natural;
      DMA_Option   : Integer;
   end record;

   type Timer_Pin_Map is array (Positive range <>) of Timer_Pin;

end Adaflight.Pins;
