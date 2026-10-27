--  The RunCam device on a UART: the port the camera setting names at
--  115200 baud, the device information asked at the start, and the camera
--  task, which takes the bytes received, presses the camera's buttons from
--  the camera boxes, drives the five key cable from the sticks and answers
--  the camera's attitude requests.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.RunCam_Device;
with Adaflight.STM32.USART;
package Adaflight.STM32.RunCam is
   --  The port, opened when the camera setting names a UART that the
   --  receiver, the GPS, the ESC sensor and the video transmitter leave
   --  free, and the first device information request.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Now_Ms : Interfaces.Unsigned_32);
   --  Whether the port is open, and whether it holds a UART.
   function Enabled return Boolean;
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the camera task with the bytes received since the last,
   --  and the beep a five key connection asks for.
   procedure Run (Inp : Adaflight.RunCam_Device.Inputs; Sound : out Adaflight.RunCam_Device.Beep);
end Adaflight.STM32.RunCam;
