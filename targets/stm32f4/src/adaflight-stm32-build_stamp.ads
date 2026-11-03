--  The image's build date and time, in a body generated at every build and
--  kept out of a packed image's compressed data.
package Adaflight.STM32.Build_Stamp is
   function Build_Date return String;
   function Build_Time return String;
end Adaflight.STM32.Build_Stamp;
