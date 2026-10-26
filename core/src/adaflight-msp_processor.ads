--  The MSP command processor: one command frame routed through the stages
--  of the reference's dispatch to the unit that answers it, in the
--  reference's order: the common out replies, the state and configuration
--  replies, the out replies that take an argument (the box names and ids,
--  the restart, several replies in one, the VTX table rows, the simplified
--  tuning, the configuration reset, the texts, the battery profile, the LED
--  strip values, the command line setting and its information), the
--  passthrough request, then the common in messages (the transponder, the
--  battery and its meters, the OSD and its canvas, a font character) and the
--  in messages. A command no unit answers is an error with an empty reply.
--  The out replies read the configuration through its views, with the
--  running part of each view taken from the caller. The flash read reply
--  waits for the flash layer (F269), the command line over MSP is not in the
--  reference's default build, and the simplified tuning write, which acts on
--  the running profile and gyro settings, answers an error until the stored
--  form lands. The reply's bytes go to the caller's stream, cut to its room.
--  The effects of every unit come back together with the runtime work the
--  reference does between the units: a PID profile change asks for the motor
--  output endpoints and the mixer profile again, a rate profile change for
--  the stick processing, the wing's tuning for the PID settings, an OSD
--  write for the elements, and a VTX configuration write or a VTX reply
--  marks the MSP transmitter ready. A passthrough request comes back as an
--  effect with its mode and argument; its reply counts the motors for the
--  ESC passthroughs and answers no port for the serial one.
with Interfaces;
with Adaflight.Blackbox;
with Adaflight.Board_Info;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.Gyro_Filters;
with Adaflight.Modes;
with Adaflight.MSP_Board_In;
with Adaflight.MSP_Common_Out;
with Adaflight.MSP_Control_In;
with Adaflight.MSP_Font_In;
with Adaflight.MSP_LED_In;
with Adaflight.MSP_Motor_In;
with Adaflight.MSP_OSD_In;
with Adaflight.MSP_Out;
with Adaflight.MSP_Peripheral_In;
with Adaflight.MSP_Profile_In;
with Adaflight.MSP_Receiver_In;
with Adaflight.MSP_Runtime_In;
with Adaflight.MSP_Serial_Out;
with Adaflight.MSP_Servo_In;
with Adaflight.MSP_Text_In;
with Adaflight.MSP_Tuning_In;
with Adaflight.MSP_Tuning_Out;
with Adaflight.MSP_Views;
with Adaflight.MSP_VTX_In;
with Adaflight.MSP_VTX_Status_Out;
with Adaflight.MSP_Write_Plans;
with Adaflight.PID_Profile;
with Adaflight.Receiver;
with Adaflight.RX_Bind;
with Adaflight.Serial_Feature_Map;
with Adaflight.Stream_Buffers;
with Adaflight.VTX_Table;

package Adaflight.MSP_Processor with SPARK_Mode is

   subtype Stream is Adaflight.Stream_Buffers.Stream;
   subtype Port_List is Serial_Feature_Map.Port_List;
   subtype Unsigned_8 is Interfaces.Unsigned_8;

   type Result is (Ack, Error);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  The room a reply needs at most, apart from the setting information,
   --  which is cut to the room left.
   Max_Reply_Length : constant := 512;

   Box_Names_Command       : constant := 116;
   Box_Ids_Command         : constant := 119;
   Multiple_Command        : constant := 230;
   Set_Passthrough_Command : constant := 245;
   Dataflash_Read_Command  : constant := 71;

   --  The passthrough modes: a serial port by identifier, the ESC 4-way
   --  interface, and an ESC's serial link by protocol.
   Passthrough_Serial_Id : constant := 16#FD#;
   Passthrough_ESC_4Way  : constant := 16#FF#;
   Passthrough_ESC_First : constant := 0;
   Passthrough_ESC_KISS  : constant := 3;
   Passthrough_ESC_Last  : constant := 4;
   All_Motors            : constant := 255;

   --  What the out replies read beside the configuration: the common
   --  replies' identity, board and meter readings (the stored part is
   --  filled here), the state replies' snapshot, the VTX device status,
   --  the active boxes, the simplified tuning's running profile and gyro
   --  settings, and the running part of each configuration view.
   type Views is record
      Common         : MSP_Common_Out.Snapshot;
      State          : MSP_Out.Snapshot;
      VTX_Status     : MSP_VTX_Status_Out.Snapshot;
      Active         : Modes.Mask := (others => False);
      Simplified_P   : PID_Profile.Profile;
      Simplified_G   : Gyro_Filters.Settings;
      Build          : MSP_Tuning_Out.Build_Options;
      Detected_Flags : Unsigned_8 := 0;
      Receiver       : MSP_Views.Receiver_Options;
      Hardware       : MSP_Views.Hardware_Runtime;
      Peripheral     : MSP_Views.Peripheral_Runtime;
      Serial_Ports   : MSP_Serial_Out.Port_Entries;
      Serial_Count   : Natural range 0 .. MSP_Serial_Out.Max_Ports := 0;
      Text           : MSP_Views.Text_Runtime;
      OSD            : MSP_Views.OSD_Runtime;
   end record;

   --  What the board reports to the messages: the control state (armed, the
   --  SPI receiver running, the request's link and whether it is the
   --  telemetry link, the mass storage readiness), the gyro's sample rate,
   --  the flight log and the PID loop time, the motors and their output
   --  device with the 3D feature, the OSD display port and whether it took
   --  the font character, the video transmitter and its running table, the
   --  receiver's provider with its serial protocol, and the out views.
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
      Out_Views           : Views;
   end record;

   --  Handled says a unit answered. Save and Reboot gather the configuration
   --  write and the restart the board, control and OSD messages ask for.
   --  Passthrough carries a passthrough request with its mode and argument.
   type Effects is record
      Handled              : Boolean := False;
      Tuning               : MSP_Tuning_In.Effects;
      Receiver             : MSP_Receiver_In.Effects;
      Servo                : MSP_Servo_In.Effects;
      LED                  : MSP_LED_In.Effects;
      Text                 : MSP_Text_In.Effects;
      Peripheral           : MSP_Peripheral_In.Effects;
      Control              : MSP_Control_In.Effects;
      OSD                  : MSP_OSD_In.Effects;
      Profile              : MSP_Profile_In.Effects;
      VTX                  : MSP_VTX_In.Effects;
      Runtime              : MSP_Runtime_In.Effects;
      Board                : MSP_Board_In.Effects;
      Motor                : MSP_Motor_In.Effects;
      Font                 : MSP_Font_In.Effects;
      Bind                 : RX_Bind.Bind := RX_Bind.No_Bind;
      Save                 : Boolean := False;
      Reboot               : Boolean := False;
      Passthrough          : Boolean := False;
      Passthrough_Mode     : Byte := 0;
      Passthrough_Argument : Byte := 0;
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
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length
                  and then MSP_Common_Out.Consistent (Ctx.Out_Views.Common),
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old and then S.Next >= S.Next'Old;

end Adaflight.MSP_Processor;
