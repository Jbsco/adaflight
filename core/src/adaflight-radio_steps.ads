--  An SX1280 radio's receiver bus, pins, clock and receiver as steps that
--  do nothing, the shape the radio driver's proof takes.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Radio_Steps with SPARK_Mode is

   type Radio_Line is null record;

   procedure Step_Read_Busy (D : in out Radio_Line; Busy : out Boolean)
     with Global => null;

   procedure Step_Micros (D : in out Radio_Line; Now : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Exti_Configured (D : in out Radio_Line; Configured : out Boolean)
     with Global => null;

   procedure Step_Set_Normal_Speed (D : in out Radio_Line; Hz : Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Pin (D : in out Radio_Line)
     with Global => null;

   procedure Step_Delay_Ms (D : in out Radio_Line; Ms : Natural)
     with Global => null;

   procedure Step_Last_Exti_Time (D : in out Radio_Line; Time : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Bus_Write_Command (D : in out Radio_Line; Command : Byte; Value : Byte)
     with Global => null;

   procedure Step_Bus_Transfer (D : in out Radio_Line; Data : in out Byte_Array)
     with Global => null;

   procedure Step_Bus_Write (D : in out Radio_Line; Data : Byte_Array)
     with Global => null;

   procedure Step_Run_Transfer (D : in out Radio_Line; Step : Byte; Data : in out Byte_Array)
     with Global => null;

   procedure Step_Run_Write (D : in out Radio_Line; Step : Byte; Data : Byte_Array)
     with Global => null;

   procedure Step_Run_Pair (D : in out Radio_Line; Step : Byte; Head : Byte_Array; Tail : in out Byte_Array)
     with Global => null;

   procedure Step_Run_Pair_Write (D : in out Radio_Line; Step : Byte; Head : Byte_Array; Tail : Byte_Array)
     with Global => null;

   procedure Step_Answer (D : in out Radio_Line; Answer : out Boolean)
     with Global => null;

   procedure Step_Current_Frequency (D : in out Radio_Line; Frequency : out Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Telemetry_Buffer (D : in out Radio_Line; Data : out Byte_Array)
     with Global => null;

   procedure Step_Process_Packet
     (D : in out Radio_Line; Payload : Byte_Array; Timestamp : Interfaces.Unsigned_32; Status : out Byte)
     with Global => null;

   procedure Step_Set_Packet_Status (D : in out Radio_Line; Status : Byte)
     with Global => null;

end Adaflight.Radio_Steps;
