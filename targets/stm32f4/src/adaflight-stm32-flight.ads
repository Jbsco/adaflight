--  The flight software on the board: the configuration, the MSP context and
--  the command line environment, the gyro, accelerometer and attitude units,
--  the scheduler with the board's tasks, and the pass the main loop repeats.
package Adaflight.STM32.Flight is
   procedure Init;
   procedure Pass;
end Adaflight.STM32.Flight;
