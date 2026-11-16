--  The failure indication on the first two status LEDs: five short flashes,
--  a pause, a failure's code as long flashes and a second's pause.
package Adaflight.STM32.Failure_Flashes is
   Missing_Acc                 : constant := 1;
   Config_Store_Failure        : constant := 5;
   Gyro_Init_Failed            : constant := 6;
   External_Flash_Write_Failed : constant := 11;

   --  Count flashes of the first two LEDs, the second from on and the first
   --  from off, each toggled twice a flash with the duration between.
   procedure Flash (Count : Natural; Duration_Ms : Natural);

   --  The indication of a code, a number of times.
   procedure Indicate (Code : Natural; Repeats : Natural);
end Adaflight.STM32.Failure_Flashes;
