with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Runtime;
with Adaflight.MAVLink_Frames;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Telemetry_Port;
with Adaflight.STM32.Time;
package body Adaflight.STM32.MAVLink is
   package Telemetry renames Adaflight.MAVLink_Telemetry;
   package Commands renames Adaflight.MAVLink_Commands;
   package Port_Of is new Adaflight.STM32.Telemetry_Port
     (Protocol => 5, Function_Bit => Adaflight.Serial_Feature_Map.Function_MAVLink, Default_Baud => 4);

   Pending_Size : constant := 512;

   Tlm         : Telemetry.State;
   Tlm_Set     : Telemetry.Settings;
   Station     : Commands.State;
   Station_Set : Commands.Settings;
   Pending     : Adaflight.MAVLink_Frames.Byte_Buffer (1 .. Pending_Size) := (others => 0);
   Waiting     : Natural range 0 .. Pending_Size := 0;
   Input       : Byte_Array (0 .. 255);

   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      UID    : Commands.UID_Words)
   is
   begin
      Tlm := (others => <>);
      Station := (others => <>);
      Tlm_Set := Adaflight.Config_Runtime.MAVLink_Settings_Of (Config.Telemetry_Config);
      Station_Set.UID := UID;
      Waiting := 0;
      Port_Of.Init (Config, Runtime_Features);
   end Init;

   procedure Check_State (Armed, Box_Present, Box_Active : Boolean; Now_Ms : Interfaces.Unsigned_32) is
      Was : constant Boolean := Port_Of.Enabled;
   begin
      Port_Of.Check_State (Armed, Box_Present, Box_Active);
      if Port_Of.Enabled and then not Was then
         Tlm.Last_Flags := (others => False);
         Station.Port := (others => <>);
         Waiting := 0;
         Telemetry.Configure_Intervals (Tlm, Tlm_Set, Now_Ms);
      end if;
   end Check_State;

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (Port_Of.Holds (N));

   procedure Put (Data : Adaflight.MAVLink_Frames.Byte_Buffer) is
      Line      : Adaflight.STM32.USART.Port;
      Out_Bytes : Byte_Array (0 .. Data'Length - 1);
   begin
      if Data'Length = 0 then
         return;
      end if;
      for I in Out_Bytes'Range loop
         Out_Bytes (I) := Data (Data'First + I);
      end loop;
      Line.Which := Port_Of.Line;
      Adaflight.STM32.USART.Put (Line, Out_Bytes);
   end Put;

   procedure Run
     (Now_Us, Now_Ms : Interfaces.Unsigned_32;
      Inp            : Telemetry.Inputs;
      Cmd            : Commands.Inputs;
      R              : out Commands.Requests)
   is
      Count    : Natural;
      Consumed : Natural;
      Replies  : Commands.Output;
      Stream   : Telemetry.Output;
   begin
      R := (others => <>);
      if not Port_Of.Enabled then
         return;
      end if;
      Adaflight.STM32.USART.Take (Port_Of.Line, Input, Count);
      for I in 0 .. Count - 1 loop
         exit when Waiting = Pending_Size;
         Waiting := Waiting + 1;
         Pending (Waiting) := Input (I);
      end loop;
      Commands.Process_Port
        (Station, Tlm, Tlm_Set, Station_Set, Cmd, Pending (1 .. Waiting), Consumed, Replies, R);
      Pending (1 .. Waiting - Consumed) := Pending (Consumed + 1 .. Waiting);
      Waiting := Waiting - Consumed;
      Put (Replies.Data (1 .. Replies.Length));
      Telemetry.Handle (Tlm, Tlm_Set, Inp, Now_Us, Now_Ms, Tx_Valid => False, Tx_Should_Send => False, O => Stream);
      Put (Stream.Data (1 .. Stream.Length));
   end Run;
   procedure Finish_Transmit is
   begin
      for Count in 1 .. 1_000 loop
         exit when not Port_Of.Enabled or else Adaflight.STM32.USART.Transmit_Empty (Port_Of.Line);
         Adaflight.STM32.Time.Delay_Us (100);
      end loop;
   end Finish_Transmit;
end Adaflight.STM32.MAVLink;
