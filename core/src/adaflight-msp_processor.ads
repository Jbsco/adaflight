--  The MSP command processor: one command frame routed through the stages
--  of the reference's dispatch to the unit that answers it, in the
--  reference's order: the out replies that take an argument and read the
--  configuration (the command line setting and its information, the
--  configuration reset and the restart), then the common in messages (the
--  transponder, the battery and its meters, the OSD and its canvas, a font
--  character), then the in messages. The out replies that read a snapshot
--  of the board's state wait for the snapshot layer, and the simplified
--  tuning write, which acts on the running profile and gyro settings,
--  answers an error until that layer lands. A command no unit answers is an
--  error with an empty reply, as the reference answers it. The reply's bytes
--  go to the caller's stream, cut to its room. The effects of every unit come
--  back together with the runtime work the reference does between the units:
--  a PID profile change asks for the motor output endpoints and the mixer
--  profile again, a rate profile change for the stick processing, the wing's
--  tuning for the PID settings, an OSD write for the elements, and a VTX
--  configuration write marks the MSP transmitter ready.
with Interfaces;
with Adaflight.Blackbox;
with Adaflight.Board_Info;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Board_In;
with Adaflight.MSP_CLI_Setting;
with Adaflight.MSP_Control_In;
with Adaflight.MSP_Font_In;
with Adaflight.MSP_LED_In;
with Adaflight.MSP_Motor_In;
with Adaflight.MSP_OSD_In;
with Adaflight.MSP_Peripheral_In;
with Adaflight.MSP_Profile_In;
with Adaflight.MSP_Receiver_In;
with Adaflight.MSP_Runtime_In;
with Adaflight.MSP_Servo_In;
with Adaflight.MSP_Text_In;
with Adaflight.MSP_Tuning_In;
with Adaflight.MSP_VTX_In;
with Adaflight.MSP_Write_Plans;
with Adaflight.Receiver;
with Adaflight.RX_Bind;
with Adaflight.Serial_Feature_Map;
with Adaflight.Stream_Buffers;
with Adaflight.VTX_Table;

package Adaflight.MSP_Processor with SPARK_Mode is

   subtype Stream is Adaflight.Stream_Buffers.Stream;
   subtype Port_List is Serial_Feature_Map.Port_List;

   type Result is (Ack, Error);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  The room a reply needs at most, apart from the setting information,
   --  which is cut to the room left.
   Max_Reply_Length : constant := MSP_CLI_Setting.Max_Reply;

   --  What the board reports to the messages: the control state (armed, the
   --  SPI receiver running, the request's link and whether it is the
   --  telemetry link, the mass storage readiness), the gyro's sample rate,
   --  the flight log and the PID loop time, the motors and their output
   --  device with the 3D feature, the OSD display port and whether it took
   --  the font character, the video transmitter and its running table, and
   --  the receiver's provider with its serial protocol.
   type Context is record
      Control             : MSP_Control_In.Board;
      Gyro_Sample_Rate_Hz : Config_Fix.Gyro_Rate := 0;
      Log                 : Blackbox.Recorder;
      Loop_Time           : Blackbox.Loop_Time_Us := 125;
      Motors              : MSP_Motor_In.Motor_Count := 0;
      Motor_Device        : MSP_Motor_In.Device_Kind := MSP_Motor_In.No_Device;
      Three_D             : Boolean := False;
      OSD_Port            : Boolean := False;
      Font_Write_Taken    : Boolean := False;
      VTX_Device          : MSP_VTX_In.Device;
      VTX_Table           : Adaflight.VTX_Table.Table;
      Receiver_Source     : Receiver.Provider := Receiver.None;
      Serial_Protocol     : Natural := 0;
   end record;

   --  Handled says a unit answered. Save and Reboot gather the configuration
   --  write and the restart the board, control and OSD messages ask for.
   type Effects is record
      Handled    : Boolean := False;
      Tuning     : MSP_Tuning_In.Effects;
      Receiver   : MSP_Receiver_In.Effects;
      Servo      : MSP_Servo_In.Effects;
      LED        : MSP_LED_In.Effects;
      Text       : MSP_Text_In.Effects;
      Peripheral : MSP_Peripheral_In.Effects;
      Control    : MSP_Control_In.Effects;
      OSD        : MSP_OSD_In.Effects;
      Profile    : MSP_Profile_In.Effects;
      VTX        : MSP_VTX_In.Effects;
      Runtime    : MSP_Runtime_In.Effects;
      Board      : MSP_Board_In.Effects;
      Motor      : MSP_Motor_In.Effects;
      Font       : MSP_Font_In.Effects;
      Bind       : RX_Bind.Bind := RX_Bind.No_Bind;
      Save       : Boolean := False;
      Reboot     : Boolean := False;
   end record;

   --  The profiles the configuration selects are among its profiles.
   function Profiles_Valid (C : Configuration) return Boolean is
     (Natural (C.System_Config.Pid_Profile_Index) < C.Pid_Profiles'Length
      and then Natural (C.System_Config.Active_Rate_Profile) < C.Control_Rate_Profiles'Length
      and then Natural (C.System_Config.Active_Battery_Profile) < C.Battery_Profiles'Length);

   --  One command frame: its reply to the stream, its result and effects.
   procedure Process
     (Ctx     : Context;
      C       : in out Configuration;
      Board   : in out Board_Info.State;
      Links   : in out MSP_Control_In.Link_State;
      Command : Interfaces.Unsigned_16;
      Request : Byte_Array;
      Ports   : Port_List;
      B       : in out Byte_Array;
      S       : in out Stream;
      R       : out Result;
      E       : out Effects)
     with Pre  => Request'Length <= Max_Request and then Ports'Length <= Serial_Feature_Map.Max_Ports
                  and then Profiles_Valid (C) and then Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old and then S.Next >= S.Next'Old;

end Adaflight.MSP_Processor;
