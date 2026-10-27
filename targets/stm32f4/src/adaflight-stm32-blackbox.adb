with Adaflight.Axes;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Runtime;
with Adaflight.PID_Controller;
with Adaflight.Modes;
with Adaflight.Serial_Feature_Map;
with Adaflight.Stream_Buffers;
with Adaflight.STM32.Control;
with Adaflight.STM32.Pilot;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Blackbox is
   use type Interfaces.Unsigned_32;
   use type Adaflight.Blackbox_Header.Device_Kind;
   use type Adaflight.Blackbox.Log_State;
   use type Adaflight.STM32.USART.Number;
   package Core renames Adaflight.Blackbox;
   package Header renames Adaflight.Blackbox_Header;
   package SFM renames Adaflight.Serial_Feature_Map;
   package USART renames Adaflight.STM32.USART;

   Port_Ids : constant array (USART.Number) of SFM.Port_Id :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);

   --  The port's ring, which the header writer's budget reads as the device's
   --  buffer, and the bytes one iteration can add at most.
   Ring_Size   : constant := 256;
   Buffer_Size : constant := 512;

   L         : Core.Recorder;
   C         : Core.Settings;
   In_Flight : Core.Inputs;
   Buffer    : Byte_Array (0 .. Buffer_Size - 1) := (others => 0);
   Stream    : Adaflight.Stream_Buffers.Stream;
   Open_Port : Boolean := False;
   Which     : USART.Number := USART.UART1;
   Shared    : Boolean := False;
   Held      : Boolean := False;
   Info_Set  : Boolean := False;
   Opens     : Interfaces.Unsigned_32 := 0;
   Closes    : Interfaces.Unsigned_32 := 0;

   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Loop_Time : Adaflight.Blackbox.Loop_Time_Us)
   is
      Assigned : constant SFM.Assignments := Adaflight.Config_Fix.Serial_Assignments (Config);
      Rate     : constant Interfaces.Unsigned_32 :=
        SFM.Rate_Of (SFM.Baud_Index'Min (SFM.Baud_Index'Last, Natural (Config.Blackbox_Config.Blackbox_Baud)));
   begin
      C := Adaflight.Config_Runtime.Blackbox_Settings_Of (Config.Blackbox_Config, Wing => False);
      Core.Init (L, C, Loop_Time);
      Open_Port := False;
      Shared := False;
      if C.Device = Header.Serial then
         for N in USART.Number loop
            if Integer (Port_Ids (N)) = Integer (Config.Blackbox_Config.Blackbox_Uart) then
               Which := N;
               Open_Port := True;
               Shared :=
                 (SFM.Function_Mask (Adaflight.Config_Fix.Serial_Options, Assigned, Port_Ids (N)) and SFM.Function_MSP)
                 /= 0;
               exit;
            end if;
         end loop;
      end if;
      if Open_Port and then not Shared and then Rate > 0 then
         USART.Init (Which, Positive (Rate), Two_Stop_Bits => Rate = 230_400);
      end if;
      Held := Open_Port and then Shared;
      Info_Set := False;
      Opens := L.Opens;
      Closes := L.Closes;
   end Init;

   function Device_Set return Boolean is (C.Device /= Header.No_Device);

   function Holds (N : USART.Number) return Boolean is (Open_Port and then Held and then N = Which);

   procedure Set_Facts (F : Facts) is
   begin
      In_Flight.Now_Ms := F.Now_Ms;
      In_Flight.Arming_Beep_Time_Us := F.Arming_Beep_Us;
      In_Flight.Battery_Voltage := F.Battery_Voltage;
      In_Flight.Main.Gyro_Filtered := F.Gyro_Filtered;
      In_Flight.Main.Gyro_Raw := F.Gyro_Raw;
      In_Flight.Main.Acc := F.Acc;
      In_Flight.Main.Quaternion_W := F.Quaternion_W;
      In_Flight.Main.Quaternion_XYZ := F.Quaternion_XYZ;
      In_Flight.Main.VBat_Latest := F.VBat_Latest;
      In_Flight.Main.Amperage_Latest := F.Amperage;
      In_Flight.Main.RSSI := F.RSSI;
      In_Flight.Slow := F.Slow;
      In_Flight.GPS := F.GPS;
      In_Flight.GPS_Feature := F.GPS_Feature;
      In_Flight.Conditions := F.Conditions;
   end Set_Facts;

   function Needs_Info return Boolean is
     (L.State in Core.Prepare_Log_File .. Core.Send_Sysinfo and then not Info_Set);

   procedure Set_Info (I : Adaflight.Blackbox_Header.Sysinfo) is
   begin
      In_Flight.Info := I;
      Info_Set := True;
   end Set_Info;

   function Logged (X : Float) return Core.Logged_Float is
     (Float'Max (-1_000_000.0, Float'Min (1_000_000.0, X)));

   --  The bytes of the iteration onto the port, which takes what its ring
   --  has room for; the writer counted the rest against the device's room.
   procedure Flush is
      Taken : Natural;
   begin
      if Open_Port and then Stream.Next > 0 then
         USART.Queue (Which, Buffer (0 .. Stream.Next - 1), Taken);
      end if;
      Adaflight.Stream_Buffers.Init (Stream, 0, Buffer'Length);
   end Flush;

   --  The log step: the device's room and state, what the controller and
   --  the mixer hold, the boxes, then the recorder's iteration; the port
   --  returns to the MSP when the log closes and leaves it when it opens.
   procedure Update is
      Motors : constant Natural := Natural'Min (Core.Motor_Count, Adaflight.STM32.Control.Motor_Count);
   begin
      In_Flight.Now_Us := Adaflight.STM32.Time.Micros;
      In_Flight.Armed := Adaflight.STM32.Pilot.Armed;
      In_Flight.Blackbox_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Blackbox);
      In_Flight.Erase_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Blackbox_Erase);
      In_Flight.Motors_Running := Adaflight.STM32.Pilot.Armed;
      In_Flight.Mode_Activation_Present := Adaflight.STM32.Pilot.Box_Configured (Adaflight.Modes.Blackbox);
      In_Flight.Device :=
        (Free            => (if Open_Port then Natural'Min (USART.Free (Which), Header.Device_Space'Last) else 0),
         Open_OK         => Open_Port,
         Buffer_Size     => Ring_Size,
         Begin_Log_Done  => True,
         End_Log_Done    => True,
         Flush_Complete  => (if Open_Port then USART.Transmit_Empty (Which) else True),
         Flush_Forced    => (if Open_Port then USART.Transmit_Empty (Which) else True),
         Full            => False,
         Erased          => True,
         Shared_MSP_Port => Shared);
      for A in Adaflight.Axes.Axis loop
         declare
            T : constant Adaflight.PID_Controller.Terms := Adaflight.STM32.Control.Terms (A);
            K : constant Core.Axis := Adaflight.Axes.Axis'Pos (A);
         begin
            In_Flight.Main.PID_P (K) := Logged (T.P);
            In_Flight.Main.PID_I (K) := Logged (T.I);
            In_Flight.Main.PID_D (K) := Logged (T.D);
            In_Flight.Main.PID_F (K) := Logged (T.F);
            In_Flight.Main.PID_S (K) := Logged (T.S);
            In_Flight.Main.Setpoint (K) := Logged (Adaflight.STM32.Control.Previous_Setpoint (A));
         end;
      end loop;
      for Ch in 0 .. 3 loop
         In_Flight.Main.RC_Command (Ch) := Logged (Adaflight.STM32.Pilot.Command (Ch));
      end loop;
      In_Flight.Main.Throttle := Float'Max (-1_000.0, Float'Min (1_000.0, Adaflight.STM32.Control.Throttle));
      In_Flight.Main.Motor := (others => 0.0);
      for M in 0 .. Motors - 1 loop
         In_Flight.Main.Motor (M) := Logged (Adaflight.STM32.Control.Motors (M));
      end loop;
      In_Flight.Main.Motor_Output_Low := Logged (Adaflight.STM32.Control.Output_Low);
      In_Flight.Conditions.Motors := Header.Motor_Count'Min (Header.Motor_Count'Last, Motors);
      Core.Update (L, C, In_Flight, Buffer, Stream);
      Flush;
      if L.State = Core.Stopped or else L.State = Core.Disabled then
         Info_Set := False;
      end if;
      if L.Closes /= Closes then
         Closes := L.Closes;
         Held := False;
      end if;
      if L.Opens /= Opens then
         Opens := L.Opens;
         Held := Shared;
      end if;
   end Update;

   procedure Disarmed (Reason : Adaflight.Arming.Disarm_Reason; Now_Us, Now_Ms : Interfaces.Unsigned_32) is
      D : Core.Event_Data;
   begin
      D.Time_Us := Now_Us;
      D.Reason := Interfaces.Unsigned_32 (Adaflight.Arming.Disarm_Reason'Pos (Reason));
      Core.Log_Event (L, Core.Disarm, D, Buffer, Stream);
      Core.Finish (L, Now_Ms, Buffer, Stream);
      Flush;
   end Disarmed;

   function Recorder return Adaflight.Blackbox.Recorder is (L);
begin
   Adaflight.Stream_Buffers.Init (Stream, 0, Buffer'Length);
end Adaflight.STM32.Blackbox;
