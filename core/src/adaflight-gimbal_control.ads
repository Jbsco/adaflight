--  The gimbal control: the head tracker's command frames that arrive on the
--  gimbal port, mixed with the RC sticks, offset and limited, and sent on to
--  the gimbal. A frame is the opcode 16#5AA5#, the stabilisation mode and the
--  sensitivity, the roll, pitch and yaw as 12-bit angles, and a CRC-16 CCITT
--  sent high byte first; the control passes every other byte through. After
--  250 ms without head-tracker bytes the gimbal gets the sticks alone, at
--  every update.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Gimbal_Control with SPARK_Mode is
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   subtype Gain is Integer range -100 .. 100;
   subtype Limit is Integer range 0 .. 100;

   --  Gains, offsets and limits in percent of the full deflection.
   type Settings is record
      Port_Configured        : Boolean := False;
      Roll_RC_Gain           : Gain := 40;
      Pitch_RC_Throttle_Gain : Gain := 10;
      Pitch_RC_Low_Gain      : Gain := 10;
      Pitch_RC_High_Gain     : Gain := -20;
      Yaw_RC_Gain            : Gain := 20;
      Roll_Gain              : Gain := 100;
      Roll_Offset            : Gain := 0;
      Roll_Limit             : Limit := 100;
      Pitch_Gain             : Gain := 50;
      Pitch_Offset           : Gain := -10;
      Pitch_Low_Limit        : Limit := 100;
      Pitch_High_Limit       : Limit := 100;
      Yaw_Gain               : Gain := 50;
      Yaw_Offset             : Gain := 0;
      Yaw_Limit              : Limit := 100;
      Stabilisation          : Natural range 0 .. 7 := 0;
      Sensitivity            : Integer range -16 .. 15 := 15;
      Mid_RC                 : Natural range 1200 .. 1700 := 1500;
   end record;

   --  The roll, pitch, yaw and throttle channels within the receiver's pulse
   --  limits.
   subtype Pulse is Float range 750.0 .. 2250.0;
   type Sticks is record
      Roll     : Pulse := 1500.0;
      Pitch    : Pulse := 1500.0;
      Yaw      : Pulse := 1500.0;
      Throttle : Pulse := 1500.0;
   end record;

   Frame_Length : constant := 10;
   subtype Frame_Index is Natural range 0 .. Frame_Length - 1;
   subtype Frame is Byte_Array (Frame_Index);

   type Parse_Phase is (Opcode_Low, Opcode_High, Command);

   type State is record
      Open        : Boolean := False;
      Phase       : Parse_Phase := Opcode_Low;
      Count       : Natural range 2 .. Frame_Length := 2;
      Received    : Frame := (others => 0);
      Sent        : Frame := (others => 0);
      Last_Rx_Us  : Unsigned_32 := 0;
   end record;

   Max_Input  : constant := 256;
   Max_Output : constant := 2 * Max_Input + Frame_Length;
   subtype Output_Length is Natural range 0 .. Max_Output;

   type Output is record
      Bytes        : Byte_Array (0 .. Max_Output - 1) := (others => 0);
      Length       : Output_Length := 0;
      Disable_Task : Boolean := False;
   end record;

   --  The control opens when its port is configured, with the gimbal frame at
   --  the sticks alone; it sends nothing yet.
   procedure Init (T : out State; C : Settings; S : Sticks)
     with Post => T.Open = C.Port_Configured;

   --  One update with the bytes that arrived since the last. Without a port
   --  the control asks for its task to stop.
   procedure Update (T : in out State; C : Settings; S : Sticks; Now_Us : Unsigned_32; Input : Byte_Array;
                     O : out Output)
     with Pre => Input'Length <= Max_Input;

end Adaflight.Gimbal_Control;
