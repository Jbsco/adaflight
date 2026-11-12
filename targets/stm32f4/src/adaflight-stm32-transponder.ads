--  The board's race transponder: the configured provider's coding on the
--  transponder's pin, the configured code's toggles, and a transmission each
--  time the coding's repeat schedule asks for one.
with Interfaces;
with Adaflight.Config_Groups;
package Adaflight.STM32.Transponder is
   --  The output taken for the configured pin and set up for the configured
   --  provider's coding, and the configured code loaded. Nothing is set up
   --  with no provider, with no pin, or when the pin has no free channel and
   --  stream.
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   --  The configured code loaded again. A provider other than the one set
   --  up sets the output up again for it first. A board that started with
   --  nothing set up stays so until a restart.
   procedure Update_Data (C : Adaflight.Config_Groups.Configuration);
   --  One task run.
   procedure Run (C : Adaflight.Config_Groups.Configuration; Now_Us : Interfaces.Unsigned_32);
   --  The output's DMA stream, numbered from 1 for the first controller's
   --  stream 0, or 0 without one.
   function Stream_Number return Natural;
end Adaflight.STM32.Transponder;
