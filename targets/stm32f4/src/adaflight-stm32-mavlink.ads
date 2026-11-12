--  The MAVLink telemetry on a UART: the stream messages of the core's MAVLink
--  telemetry unit and the ground station's messages through the core's
--  command unit, on the telemetry port of the first provider with the
--  MAVLink protocol, at the provider's rate or 57600 baud.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.MAVLink;
with Adaflight.MAVLink_Commands;
with Adaflight.MAVLink_Frames;
with Adaflight.MAVLink_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.MAVLink is
   --  The provider's port and its sharing, with the telemetry feature on, the
   --  stream settings, and the board's identity for the autopilot version.
   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      UID    : Adaflight.MAVLink_Commands.UID_Words);
   --  The port opened or released as its sharing state asks now; the stream
   --  intervals start again from the settings when it opens.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean; Now_Ms : Interfaces.Unsigned_32);
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  Whether the telemetry runs on a port now.
   function Running return Boolean;
   --  One run of the telemetry task: up to 64 bytes of the ground station's
   --  messages answered or executed, the requests they made, then the stream
   --  messages due.
   procedure Run
     (Now_Us, Now_Ms : Interfaces.Unsigned_32;
      Inp            : Adaflight.MAVLink_Telemetry.Inputs;
      Cmd            : Adaflight.MAVLink_Commands.Inputs;
      R              : out Adaflight.MAVLink_Commands.Requests);
   --  A run in parts, for a build with the mission protocol behind the
   --  command dispatch. The drain starts with the port's waiting bytes and
   --  goes in steps, each with its replies written; a step that ends at a
   --  message for the mission protocol hands it back, and the caller takes
   --  the next step after handling it. The drain's end gives the reboot it
   --  accepted, and the stream messages due follow.
   procedure Begin_Drain;
   procedure Drain_Step
     (Cmd   : Adaflight.MAVLink_Commands.Inputs;
      R     : out Adaflight.MAVLink_Commands.Requests;
      Other : out Boolean;
      Msg   : out Adaflight.MAVLink.Message);
   procedure End_Drain (R : out Adaflight.MAVLink_Commands.Requests);
   procedure Send_Streams
     (Now_Us, Now_Ms : Interfaces.Unsigned_32; Inp : Adaflight.MAVLink_Telemetry.Inputs);
   --  The link's transmit sequence for the frames the mission protocol
   --  builds, and those frames written with the sequence after them.
   function Sequence return Interfaces.Unsigned_8;
   procedure Send (Data : Adaflight.MAVLink_Frames.Byte_Buffer; Sequence_After : Interfaces.Unsigned_8);
   --  Whether the telemetry started on its port since the last call.
   procedure Take_Started (Started : out Boolean);
   --  Waits up to 100 ms for the port's queued bytes to leave.
   procedure Finish_Transmit;
end Adaflight.STM32.MAVLink;
