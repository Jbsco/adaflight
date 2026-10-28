with Adaflight.Axes;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Runtime;
with Adaflight.PID_Controller;
with Adaflight.Modes;
with Adaflight.Serial_Feature_Map;
with Adaflight.Stream_Buffers;
with Adaflight.STM32.Control;
with Adaflight.STM32.ESC_Sensor;
with Adaflight.STM32.Flash_Chip;
with Adaflight.STM32.Pilot;
with Adaflight.STM32.SD;
with Adaflight.STM32.Time;
with Adaflight.STM32.VTX;
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
   Flushes   : Interfaces.Unsigned_32 := 0;
   Erases    : Interfaces.Unsigned_32 := 0;
   Header_Flushes : Interfaces.Unsigned_32 := 0;

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
               Open_Port := not Adaflight.STM32.VTX.Holds (N) and then not Adaflight.STM32.ESC_Sensor.Holds (N);
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
      Flushes := L.Flush_Requests;
      Erases := L.Erase_Requests;
      Header_Flushes := L.Writer.Flushes;
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
      In_Flight.Main.Surface_Raw := F.Surface_Raw;
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

   --  The bytes of the iteration onto the card's file, into the flash
   --  chip's write buffer, or onto the port, which takes what its ring has
   --  room for; the writer counted the rest against the device's room.
   procedure Flush is
      Taken : Natural;
   begin
      if Stream.Next > 0 then
         if C.Device = Header.SD_Card then
            Adaflight.STM32.SD.Log_Write (Buffer (0 .. Stream.Next - 1));
         elsif C.Device = Header.Flash then
            Adaflight.STM32.Flash_Chip.Write (Buffer (0 .. Stream.Next - 1));
         elsif Open_Port then
            USART.Queue (Which, Buffer (0 .. Stream.Next - 1), Taken);
         end if;
      end if;
      Adaflight.Stream_Buffers.Init (Stream, 0, Buffer'Length);
   end Flush;

   --  The card device's answers for the recorder's state: a log start step
   --  while the log file is prepared, a flush until every sector is on the
   --  card while the cache flushes, and
   --  while the log shuts down its end, then its flush inside the shutdown
   --  timeout.
   procedure Card_Device (D : out Core.Device_Inputs) is
   begin
      D := (Free            => Natural'Min (Adaflight.STM32.SD.Log_Free_Space, Header.Device_Space'Last),
            Open_OK         => Adaflight.STM32.SD.Log_Open_OK,
            Buffer_Size     => 0,
            Begin_Log_Done  => True,
            End_Log_Done    => True,
            Flush_Complete  => True,
            Flush_Forced    => True,
            Full            => Adaflight.STM32.SD.Log_Full,
            Erased          => True,
            Shared_MSP_Port => False);
      case L.State is
         when Core.Prepare_Log_File =>
            Adaflight.STM32.SD.Log_Begin (D.Begin_Log_Done);
         when Core.Cache_Flush =>
            Adaflight.STM32.SD.Log_Flush_Complete (D.Flush_Complete);
         when Core.Shutting_Down =>
            Adaflight.STM32.SD.Log_End (L.Logged_Any_Frames, D.End_Log_Done);
            if D.End_Log_Done
              and then In_Flight.Now_Ms <= L.Header_St.Start_Time_Ms + Core.Shutdown_Timeout_Ms
            then
               Adaflight.STM32.SD.Log_Flush (D.Flush_Forced);
            end if;
         when others =>
            null;
      end case;
   end Card_Device;

   --  The flash chip's answers for the recorder's state: the volume's room
   --  and fullness, the chip's readiness while the volume erases, and the
   --  forced flush while the cache flushes and while the log shuts down
   --  inside the shutdown timeout.
   procedure Chip_Device (D : out Core.Device_Inputs) is
   begin
      D := (Free            => Natural'Min (Adaflight.STM32.Flash_Chip.Free_Space, Header.Device_Space'Last),
            Open_OK         => Adaflight.STM32.Flash_Chip.Supported and then not Adaflight.STM32.Flash_Chip.Full,
            Buffer_Size     => Natural'Min (Adaflight.STM32.Flash_Chip.Buffer_Usable, Header.Device_Space'Last),
            Begin_Log_Done  => True,
            End_Log_Done    => True,
            Flush_Complete  => True,
            Flush_Forced    => True,
            Full            => not Adaflight.STM32.Flash_Chip.Supported or else Adaflight.STM32.Flash_Chip.Full,
            Erased          => True,
            Shared_MSP_Port => False);
      case L.State is
         when Core.Erasing =>
            Adaflight.STM32.Flash_Chip.Is_Ready (D.Erased);
         when Core.Cache_Flush =>
            Adaflight.STM32.Flash_Chip.Flush (True, D.Flush_Forced);
         when Core.Shutting_Down =>
            if In_Flight.Now_Ms <= L.Header_St.Start_Time_Ms + Core.Shutdown_Timeout_Ms then
               Adaflight.STM32.Flash_Chip.Flush (True, D.Flush_Forced);
            end if;
         when others =>
            null;
      end case;
   end Chip_Device;

   --  The log step: the device's room and state, what the controller and
   --  the mixer hold, the boxes, then the recorder's iteration; the port
   --  returns to the MSP when the log closes and leaves it when it opens.
   procedure Update is
      Motors  : constant Natural := Natural'Min (Core.Motor_Count, Adaflight.STM32.Control.Motor_Count);
      Ignored : Boolean;
   begin
      In_Flight.Now_Us := Adaflight.STM32.Time.Micros;
      In_Flight.Armed := Adaflight.STM32.Pilot.Armed;
      In_Flight.Blackbox_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Blackbox);
      In_Flight.Erase_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Blackbox_Erase);
      In_Flight.Motors_Running := Adaflight.STM32.Control.Motors_Running;
      In_Flight.Mode_Activation_Present := Adaflight.STM32.Pilot.Box_Configured (Adaflight.Modes.Blackbox);
      if C.Device = Header.SD_Card then
         Card_Device (In_Flight.Device);
      elsif C.Device = Header.Flash then
         Chip_Device (In_Flight.Device);
      else
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
      end if;
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
      if L.Writer.Flushes /= Header_Flushes then
         Header_Flushes := L.Writer.Flushes;
         if C.Device = Header.Flash then
            Adaflight.STM32.Flash_Chip.Flush (True, Ignored);
         end if;
      end if;
      if L.Flush_Requests /= Flushes then
         Flushes := L.Flush_Requests;
         if C.Device = Header.Flash then
            Adaflight.STM32.Flash_Chip.Flush (False, Ignored);
         end if;
      end if;
      if L.Erase_Requests /= Erases then
         Erases := L.Erase_Requests;
         if C.Device = Header.Flash then
            Adaflight.STM32.Flash_Chip.Erase_Completely;
         end if;
      end if;
      if L.Closes /= Closes then
         Closes := L.Closes;
         Held := False;
         if C.Device = Header.Flash then
            Adaflight.STM32.Flash_Chip.Close;
         end if;
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
