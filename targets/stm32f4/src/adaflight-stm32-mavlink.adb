with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Runtime;
with Adaflight.MAVLink;
with Adaflight.MAVLink_Debug;
with Adaflight.MAVLink_Frames;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Debug_Values;
with Adaflight.STM32.MAVLink_Link;
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
   --  Whether the telemetry rides on a MAVLink receiver's port, whether it
   --  started there, and the free transmitter buffer it waits for.
   On_RX_Port  : Boolean := False;
   Shared_On   : Boolean := False;
   Min_Free    : Adaflight.MAVLink.Byte := 0;
   MAVLink_Provider : constant Interfaces.Unsigned_8 := 16;

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
      Shared_On := False;
      Min_Free := Adaflight.MAVLink.Byte (Config.Telemetry_Config.Mavlink_Min_Txbuff);
      declare
         package SFM renames Adaflight.Serial_Feature_Map;
         use type Interfaces.Unsigned_8;
         use type Interfaces.Unsigned_32;
         Assigned : constant SFM.Assignments := Adaflight.Config_Fix.Serial_Assignments (Config);
         Tlm_Port : constant SFM.Port_Id :=
           SFM.Provider_Port (Adaflight.Config_Fix.Serial_Options, Assigned, SFM.MAVLink);
      begin
         On_RX_Port :=
           (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0
           and then Config.Rx_Config.Serialrx_Provider = MAVLink_Provider
           and then (Tlm_Port = SFM.No_Port
                     or else SFM.Telemetry_Shares_RX_Port (Adaflight.Config_Fix.Serial_Options, Assigned, Tlm_Port));
      end;
      Port_Of.Init (Config, Runtime_Features);
   end Init;

   procedure Check_State (Armed, Box_Present, Box_Active : Boolean; Now_Ms : Interfaces.Unsigned_32) is
      Was : constant Boolean := Port_Of.Enabled;
   begin
      if On_RX_Port then
         if not Shared_On and then Adaflight.STM32.MAVLink_Link.Open then
            Shared_On := True;
            Tlm.Last_Flags := (others => False);
            Telemetry.Configure_Intervals (Tlm, Tlm_Set, Now_Ms);
         end if;
         return;
      end if;
      Port_Of.Check_State (Armed, Box_Present, Box_Active);
      if Port_Of.Enabled and then not Was then
         Tlm.Last_Flags := (others => False);
         Station.Port := (others => <>);
         Waiting := 0;
         Telemetry.Configure_Intervals (Tlm, Tlm_Set, Now_Ms);
      end if;
   end Check_State;

   function Holds (N : Adaflight.STM32.USART.Number) return Boolean is (Port_Of.Holds (N));

   function Running return Boolean is (Shared_On or else Port_Of.Enabled);

   function Current_Line return Adaflight.STM32.USART.Number is
     (if Shared_On then Adaflight.STM32.MAVLink_Link.Line else Port_Of.Line);

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
      Line.Which := Current_Line;
      Adaflight.STM32.USART.Put (Line, Out_Bytes);
   end Put;

   procedure Run
     (Now_Us, Now_Ms : Interfaces.Unsigned_32;
      Inp            : Telemetry.Inputs;
      Cmd            : Commands.Inputs;
      R              : out Commands.Requests)
   is
      Count     : Natural;
      Consumed  : Natural;
      Replies   : Commands.Output;
      Stream    : Telemetry.Output;
      Tx_Valid  : Boolean;
      Tx_Should : Boolean;
   begin
      R := (others => <>);
      if not Running then
         return;
      end if;
      if Shared_On then
         Commands.Process_Queue
           (Station, Tlm, Tlm_Set, Station_Set, Cmd, Adaflight.STM32.MAVLink_Link.State, Replies, R);
      else
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
      end if;
      Put (Replies.Data (1 .. Replies.Length));
      --  The receiver's last radio status, where one runs.
      Tx_Valid := Adaflight.STM32.MAVLink_Link.Open and then Adaflight.STM32.MAVLink_Link.State.Tx_Buffer_Valid;
      Tx_Should := Tx_Valid
        and then Adaflight.MAVLink.Should_Send_Telemetry (Adaflight.STM32.MAVLink_Link.State, Min_Free);
      Telemetry.Handle
        (Tlm, Tlm_Set, Inp, Now_Us, Now_Ms, Tx_Valid => Tx_Valid, Tx_Should_Send => Tx_Should, O => Stream);
      Adaflight.MAVLink_Debug.Record_Telemetry
        (Adaflight.STM32.Debug_Values.State, Tlm, Tx_Valid => Tx_Valid, Tx_Should_Send => Tx_Should);
      Put (Stream.Data (1 .. Stream.Length));
   end Run;
   procedure Finish_Transmit is
   begin
      for Count in 1 .. 1_000 loop
         exit when not Running or else Adaflight.STM32.USART.Transmit_Empty (Current_Line);
         Adaflight.STM32.Time.Delay_Us (100);
      end loop;
   end Finish_Transmit;
end Adaflight.STM32.MAVLink;
