with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Real_Time;
with Ada.Streams;
with GNAT.Sockets;
with Adaflight.Bytes;
package body Adaflight.Host_Simulator is
   use type Ada.Real_Time.Time;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_16;

   State_Port   : constant := 9003;
   PWM_Port     : constant := 9002;
   PWM_Raw_Port : constant := 9001;
   Motor_Count  : constant := 4;

   Setting : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_SIMULATOR", "");
   Comma   : constant Natural :=
     (if Setting'Length = 0 then 0 else Ada.Strings.Fixed.Index (Setting, ","));
   Bridge_Name : constant String := (if Comma = 0 then Setting else Setting (Setting'First .. Comma - 1));
   Address     : constant String := (if Comma = 0 then "127.0.0.1" else Setting (Comma + 1 .. Setting'Last));
   On      : constant Boolean := Bridge_Name = "gazebo" or else Bridge_Name = "legacy";
   Legacy  : constant Boolean := Bridge_Name = "legacy";
   Bridge  : constant Adaflight.Sim_FDM.Bridge :=
     (if Legacy then Adaflight.Sim_FDM.Legacy else Adaflight.Sim_FDM.Gazebo);

   Opened       : Boolean := False;
   State_Socket : GNAT.Sockets.Socket_Type;
   PWM_Socket   : GNAT.Sockets.Socket_Type;
   PWM_To       : GNAT.Sockets.Sock_Addr_Type;
   PWM_Raw_To   : GNAT.Sockets.Sock_Addr_Type;
   RC_Port      : constant := 9004;
   RC_Socket    : GNAT.Sockets.Socket_Type;
   Latest_RC    : Adaflight.STM32.MCU.RC_Pulses := (others => 0);
   Fresh_RC     : Boolean := False;
   FDM          : Adaflight.Sim_FDM.State;
   Feed_Gyro    : Adaflight.Sim_FDM.Axes := (others => 0);
   Feed_Acc     : Adaflight.Sim_FDM.Axes := (others => 0);
   Latest       : Adaflight.Attitude.Quaternion;
   Fresh_Q      : Boolean := False;
   Latest_GPS   : Adaflight.Sim_FDM.GPS_Fix;
   Fresh_GPS    : Boolean := False;
   Pressure_Pa  : Interfaces.Integer_32 := 101_325;
   Epoch        : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

   function Enabled return Boolean is (On);
   function Legacy_Bridge return Boolean is (Legacy);
   function Gyro return Adaflight.Sim_FDM.Axes is (Feed_Gyro);
   function Acc return Adaflight.Sim_FDM.Axes is (Feed_Acc);

   function Micros return Interfaces.Unsigned_64 is
     (Interfaces.Unsigned_64 (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Epoch) * 1_000_000));

   --  The monotonic clock as seconds and nanoseconds.
   function Now_Spec return Adaflight.Sim_FDM.Time_Spec is
      Seconds : Ada.Real_Time.Seconds_Count;
      Rest    : Ada.Real_Time.Time_Span;
   begin
      Ada.Real_Time.Split (Ada.Real_Time.Clock, Seconds, Rest);
      return (Sec  => Interfaces.Integer_64 (Seconds) mod 2 ** 40,
              Nsec => Interfaces.Integer_64'Min (999_999_999,
                        Interfaces.Integer_64 (Ada.Real_Time.To_Duration (Rest) * 1_000_000_000)));
   end Now_Spec;

   procedure Open is
      use GNAT.Sockets;
      Non_Blocking : Request_Type := (Non_Blocking_IO, True);
   begin
      Create_Socket (State_Socket, Family_Inet, Socket_Datagram);
      Set_Socket_Option (State_Socket, Socket_Level, (Reuse_Address, True));
      Bind_Socket (State_Socket, (Family_Inet, Any_Inet_Addr, State_Port));
      Control_Socket (State_Socket, Non_Blocking);
      Create_Socket (PWM_Socket, Family_Inet, Socket_Datagram);
      PWM_To := (Family_Inet, Inet_Addr (Address), PWM_Port);
      PWM_Raw_To := (Family_Inet, Inet_Addr (Address), PWM_Raw_Port);
      Create_Socket (RC_Socket, Family_Inet, Socket_Datagram);
      Set_Socket_Option (RC_Socket, Socket_Level, (Reuse_Address, True));
      Bind_Socket (RC_Socket, (Family_Inet, Any_Inet_Addr, RC_Port));
      Control_Socket (RC_Socket, Non_Blocking);
      Opened := True;
   end Open;

   --  The motor packets: four speeds as 32-bit floats, and the raw packet
   --  with its motor count and sixteen outputs, all at zero until the motor
   --  output feeds them.
   procedure Send_Motor_Packets is
      use GNAT.Sockets;
      Speeds : constant Ada.Streams.Stream_Element_Array (1 .. 4 * Motor_Count) := (others => 0);
      Raw    : Ada.Streams.Stream_Element_Array (1 .. 2 + 4 * 16) := (others => 0);
      Sent   : Ada.Streams.Stream_Element_Offset;
   begin
      Raw (1) := Motor_Count;
      Send_Socket (PWM_Socket, Speeds, Sent, PWM_To);
      if Sent >= 0 then
         Send_Socket (PWM_Socket, Raw, Sent, PWM_Raw_To);
      end if;
   exception
      when Socket_Error =>
         null;
   end Send_Motor_Packets;

   procedure Poll is
      use GNAT.Sockets;
      Item  : Ada.Streams.Stream_Element_Array (1 .. Adaflight.Sim_FDM.Packet_Size);
      Bytes : Adaflight.Bytes.Byte_Array (0 .. Adaflight.Sim_FDM.Packet_Size - 1);
      Last  : Ada.Streams.Stream_Element_Offset;
      From  : Sock_Addr_Type;
      P     : Adaflight.Sim_FDM.Packet;
      Valid : Boolean;
      F     : Adaflight.Sim_FDM.Feed;
      Start : Interfaces.Unsigned_64;
   begin
      if not On then
         return;
      end if;
      if not Opened then
         Open;
      end if;
      loop
         begin
            Receive_Socket (State_Socket, Item, Last, From);
         exception
            when Socket_Error =>
               exit;
         end;
         exit when Last < Item'Last;
         for I in Item'Range loop
            Bytes (Natural (I - Item'First)) := Adaflight.Bytes.Byte (Item (I));
         end loop;
         Adaflight.Sim_FDM.Decode (Bytes, P, Valid);
         if Valid then
            Start := Micros;
            Adaflight.Sim_FDM.Step (FDM, P, Bridge, Start, Micros, Now_Spec, F);
            case F.Kind is
               when Adaflight.Sim_FDM.Timeout =>
                  Send_Motor_Packets;
               when Adaflight.Sim_FDM.Update =>
                  Feed_Gyro := F.Gyro;
                  Feed_Acc := F.Acc;
                  Latest := (W => F.Attitude (1), X => F.Attitude (2), Y => F.Attitude (3), Z => F.Attitude (4));
                  Fresh_Q := True;
                  Pressure_Pa := F.Pressure;
                  if F.GPS_Set then
                     Latest_GPS := F.GPS;
                     Fresh_GPS := True;
                  end if;
               when Adaflight.Sim_FDM.Stale =>
                  null;
            end case;
         end if;
      end loop;
      loop
         declare
            RC_Item : Ada.Streams.Stream_Element_Array (1 .. 40);
            RC_Last : Ada.Streams.Stream_Element_Offset;
         begin
            Receive_Socket (RC_Socket, RC_Item, RC_Last, From);
            exit when RC_Last < RC_Item'Last;
            for I in Latest_RC'Range loop
               declare
                  Low : constant Ada.Streams.Stream_Element_Offset :=
                    RC_Item'First + 8 + Ada.Streams.Stream_Element_Offset (2 * I);
               begin
                  Latest_RC (I) := Interfaces.Unsigned_16 (RC_Item (Low))
                    + 256 * Interfaces.Unsigned_16 (RC_Item (Low + 1));
               end;
            end loop;
            Fresh_RC := True;
         exception
            when Socket_Error =>
               exit;
         end;
      end loop;
   end Poll;

   procedure Take_RC (Fresh : out Boolean; Pulses : out Adaflight.STM32.MCU.RC_Pulses) is
   begin
      Fresh := Fresh_RC;
      Pulses := Latest_RC;
      Fresh_RC := False;
   end Take_RC;

   procedure Take_GPS (Fresh : out Boolean; Fix : out Adaflight.Sim_FDM.GPS_Fix) is
   begin
      Fresh := Fresh_GPS;
      Fix := Latest_GPS;
      Fresh_GPS := False;
   end Take_GPS;

   function Pressure return Interfaces.Integer_32 is (Pressure_Pa);

   procedure Take_Attitude (Fresh : out Boolean; Q : out Adaflight.Attitude.Quaternion) is
   begin
      Fresh := Fresh_Q;
      Q := Latest;
      Fresh_Q := False;
   end Take_Attitude;
end Adaflight.Host_Simulator;
