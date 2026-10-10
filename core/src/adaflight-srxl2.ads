--  The SRXL2 receiver protocol: the packets assembled from the serial bytes
--  into a pair of buffers swapped at the port's idle, the packet checked by
--  its id, length, and CRC at the status poll, the handshake that names the
--  bus master and the baud rate or asks for a reply, the control data with
--  the channels under their mask, the failsafe, and the VTX control word,
--  the link state machine with its activity and handshake timeouts, the
--  write buffer the reply, the bind request, and the telemetry frame go out
--  through once the bus is quiet, and the raw channel value the receiver
--  reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.SRXL2 with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   Channel_Count  : constant := 32;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Channel_Value is Natural range 0 .. 65_535;
   type Channel_Data is array (Channel) of Channel_Value;
   Channel_Center : constant := 16#8000#;
   Pulse_Offset   : constant := 988;

   Max_Packet_Length : constant := 80;
   subtype Packet_Index is Natural range 0 .. Max_Packet_Length - 1;
   subtype Packet_Length is Natural range 0 .. Max_Packet_Length;
   type Packet_Bytes is array (Packet_Index) of Byte;
   type Packet is record
      Len : Packet_Length := 0;
      Raw : Packet_Bytes := (others => 0);
   end record;
   subtype Buffer_Choice is Natural range 0 .. 1;
   type Buffer_Pair is array (Buffer_Choice) of Packet;

   Packet_Id             : constant := 16#A6#;
   Handshake_Type        : constant := 16#21#;
   Bind_Info_Type        : constant := 16#41#;
   Telemetry_Sensor_Type : constant := 16#80#;
   Control_Data_Type     : constant := 16#CD#;
   Channel_Data_Command  : constant := 16#00#;
   Failsafe_Command      : constant := 16#01#;
   VTX_Command           : constant := 16#02#;
   Flight_Controller     : constant := 3;
   Broadcast_Id          : constant := 16#FF#;
   Enter_Bind_Mode       : constant := 16#EB#;
   Bind_DSMX_11ms        : constant := 16#B2#;
   Bind_Options          : constant := 16#03#;

   Handshake_Length       : constant := 14;
   Bind_Info_Length       : constant := 21;
   Telemetry_Frame_Length : constant := 22;
   subtype Telemetry_Index is Natural range 0 .. Telemetry_Frame_Length - 1;
   type Telemetry_Bytes is array (Telemetry_Index) of Byte;

   Frame_Timeout_Us               : constant := 50_000;
   Listen_For_Activity_Timeout_Us : constant := 50_000;
   Send_Handshake_Timeout_Us      : constant := 50_000;
   Listen_For_Handshake_Timeout_Us : constant := 200_000;
   Default_Baud_Rate              : constant := 115_200;
   High_Baud_Rate                 : constant := 400_000;
   Reply_Quiescence_Us            : constant := 2 * 10 * 1_000_000 / Default_Baud_Rate;

   type Link_State is (Disabled, Listen_For_Activity, Send_Handshake, Listen_For_Handshake, Running);
   type Baud_Rate is (Default_Rate, High_Rate);

   --  The unit id of this flight controller on the bus and whether the fast
   --  baud rate is offered.
   type Settings is record
      Unit_Id   : Byte := 0;
      Baud_Fast : Byte := 0;
   end record;

   --  A VTX control word for the VTX layer, packed as the Spektrum control
   --  frame carries it.
   type VTX_Request is record
      Present : Boolean := False;
      Word    : Unsigned_32 := 0;
   end record;

   type State is record
      Unit_Id             : Byte := 0;
      Baud_Fast           : Byte := 0;
      Link                : Link_State := Disabled;
      Baud                : Baud_Rate := Default_Rate;
      Timeout_Us          : Time_Us := 0;
      Full_Timeout_Us     : Time_Us := 0;
      Last_Valid_Us       : Time_Us := 0;
      Last_Receive_Us     : Time_Us := 0;
      Last_Idle_Us        : Time_Us := 0;
      Buffers             : Buffer_Pair := (others => <>);
      Read_Buffer         : Buffer_Choice := 0;
      Read_Index          : Packet_Length := 0;
      Transmitting        : Boolean := False;
      Write_Buffer        : Packet_Bytes := (others => 0);
      Write_Length        : Packet_Length := 0;
      Bus_Master          : Byte := Broadcast_Id;
      Telemetry_Requested : Boolean := False;
      Telemetry_Frame     : Telemetry_Bytes := (others => 0);
      Telemetry_Fill      : Natural range 0 .. Telemetry_Frame_Length := 0;
      Result              : Receiver.Frame_Report;
      Data                : Channel_Data := (others => Channel_Center);
      Last_Frame_Time_Us  : Time_Us := 0;
   end record;

   --  Every channel at its center, the link listening for activity with its
   --  timeout from now; the receiver takes the protocol's RSSI claim at its
   --  own init.
   procedure Init (S : out State; C : Settings; Now_Us : Time_Us);

   --  One byte from the serial port at its arrival time, into the read
   --  buffer while it is free and has room, else the packet is dropped.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The port's idle: a transmission ends, an empty packet frees the read
   --  buffer, and a packet is handed over by swapping the buffers.
   procedure Idle (S : in out State; Now_Us : Time_Us);

   --  The frame status: the handed-over packet processed into the result,
   --  then the link state machine run at this time, processing asked for
   --  when the write buffer holds a reply, and the frame time kept unless
   --  the result failed or dropped.
   procedure Frame_Status (
      S      : in out State;
      Rx     : in out Receiver.State;
      Now_Us : Time_Us;
      Status : out Receiver.Frame_Report;
      VTX    : out VTX_Request
   );

   --  The processing the status asked for: the write buffer goes out once
   --  the bus has been idle since the last byte for the reply quiescence.
   procedure Process_Frame (S : in out State; Now_Us : Time_Us; Written : out Boolean);

   --  A packet into the write buffer with its CRC in its last two bytes.
   procedure Write_Data (S : in out State; Data : Packet_Bytes; Length : Natural)
     with Pre => Length in 2 .. Max_Packet_Length;

   --  The bind request to the bus master.
   procedure Bind (S : in out State);

   --  The telemetry frame the telemetry layer fills: its header, then its
   --  bytes, then the write with the CRC and the request cleared.
   procedure Begin_Telemetry_Frame (S : in out State);
   procedure Add_Telemetry_Byte (S : in out State; B : Byte)
     with Pre => S.Telemetry_Fill < Telemetry_Frame_Length;
   procedure Finish_Telemetry_Frame (S : in out State)
     with Pre => S.Telemetry_Fill <= Telemetry_Frame_Length - 2;

   --  The channel value in microseconds: the count's quarter over sixteen
   --  plus the pulse offset.
   function Read_Raw (S : State; Ch : Channel) return Float is (Float (S.Data (Ch) / 4) / 16.0 + Float (Pulse_Offset));

end Adaflight.SRXL2;
