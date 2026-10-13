--  The BLHeli 4-way interface that ESC configurators reach through the
--  flight controller. A host frame is an escape byte, a command, a 16-bit
--  address, a parameter length with 0 for 256, the parameters and a
--  CRC-16/XMODEM. The reply repeats the command and the address and adds the
--  output parameters, an acknowledgement and its own check. The commands
--  select an ESC, connect to its BLHeli or STK500v2 bootloader, and read,
--  write, erase and verify its flash and EEPROM. The unit takes the host's
--  bytes one at a time and asks the caller for each bootloader operation in
--  turn. Its motor, pin and LED operations and the reply go out in order.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Four_Way with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   subtype Unsigned_16 is Interfaces.Unsigned_16;

   Max_Motors : constant := 8;
   subtype Motor_Index is Natural range 0 .. Max_Motors - 1;
   subtype Motor_Total is Natural range 0 .. Max_Motors;
   type Motor_Flags is array (Motor_Index) of Boolean;
   type Motor_Pins is array (Motor_Index) of Motor_Index;

   --  Interface modes: C2 at power-on, the BLHeli bootloader on SiLabs,
   --  Atmel and ARM ESCs, and the STK500v2 bootloader.
   C2_Mode     : constant := 0;
   SiLabs_Mode : constant := 1;
   Atmel_Mode  : constant := 2;
   STK_Mode    : constant := 3;
   ARM_Mode    : constant := 4;
   subtype Interface_Mode is Byte range C2_Mode .. ARM_Mode;

   Ack_OK              : constant := 16#00#;
   Ack_Invalid_Command : constant := 16#02#;
   Ack_Invalid_CRC     : constant := 16#03#;
   Ack_Verify_Error    : constant := 16#04#;
   Ack_Invalid_Channel : constant := 16#08#;
   Ack_Invalid_Param   : constant := 16#09#;
   Ack_General_Error   : constant := 16#0F#;

   subtype Info_Index is Natural range 0 .. 3;
   type Device_Info is array (Info_Index) of Byte;

   subtype Param_Index is Natural range 0 .. 255;
   subtype Param_Buffer is Byte_Array (Param_Index);

   type Op_Kind is
     (Disable_Motors, Enable_Motors_If_Reinstated, Release_Pin, Reinstate_Pin, Pin_Input, Pin_Output,
      Pin_Alternate, Pin_High, Pin_Low, Wait_Ms, LED_On, LED_Off, Silence_Beeper, Send_Reply);

   --  A pin operation names the motor whose pin it drives; a wait carries its
   --  milliseconds.
   type Op is record
      Kind  : Op_Kind := Send_Reply;
      Index : Motor_Index := 0;
      Value : Natural range 0 .. 300 := 0;
   end record;

   Max_Ops : constant := 40;
   subtype Op_Count is Natural range 0 .. Max_Ops;
   type Op_List is array (1 .. Max_Ops) of Op;

   Max_Reply : constant := 5 + 256 + 3;
   subtype Reply_Length is Natural range 0 .. Max_Reply;
   subtype Reply_Bytes is Byte_Array (0 .. Max_Reply - 1);

   type Output is record
      Ops    : Op_List := (others => (others => <>));
      Count  : Op_Count := 0;
      Reply  : Reply_Bytes := (others => 0);
      Length : Reply_Length := 0;
   end record;

   type Request_Kind is
     (STK_Connect, BL_Connect, BL_Keep_Alive, STK_Sign_On, BL_Restart, STK_Chip_Erase, BL_Page_Erase,
      BL_Read_Flash, STK_Read_Flash, BL_Read_EEPROM, STK_Read_EEPROM, BL_Write_Flash, STK_Write_Flash,
      BL_Write_EEPROM, STK_Write_EEPROM, BL_Verify_Flash);

   --  A bootloader operation for the selected ESC: the address and the count
   --  with 0 for 256, and the interface mode for a BLHeli flash read. A write
   --  or a verify sends the parameters, a restart sends the device
   --  information.
   type Request is record
      Kind         : Request_Kind := BL_Keep_Alive;
      ESC          : Byte := 0;
      Mode         : Interface_Mode := C2_Mode;
      Address_High : Byte := 0;
      Address_Low  : Byte := 0;
      Count        : Byte := 0;
   end record;

   --  The answer: non-zero for success or the verify outcome, the device
   --  information after a connect, and the bytes a read returned.
   type Result is record
      Code : Byte := 0;
      Info : Device_Info := (others => 0);
      Data : Param_Buffer := (others => 0);
   end record;

   type Phase is
     (Await_Escape, Command, Address_High, Address_Low, Length, Parameters, Check_High, Check_Low, Awaiting,
      Finished);

   type Reply_Source is (Scratch, Name, Info, Parameters);
   subtype Scratch_Index is Natural range 0 .. 1;
   type Scratch_Bytes is array (Scratch_Index) of Byte;
   subtype Try_Count is Natural range 0 .. 3;

   type State is record
      ESC_Total      : Motor_Total := 0;
      Pins           : Motor_Pins := (others => 0);
      Enabled        : Motor_Flags := (others => False);
      Has_Pin        : Motor_Flags := (others => False);
      TX_LED         : Natural range 0 .. 1 := 0;
      Mode           : Interface_Mode := C2_Mode;
      Info           : Device_Info := (others => 0);
      Selected       : Byte := 0;
      Current        : Phase := Await_Escape;
      CRC            : Unsigned_16 := 0;
      Command        : Byte := 0;
      Address_High   : Byte := 0;
      Address_Low    : Byte := 0;
      Param_Length   : Byte := 0;
      Received       : Natural range 0 .. 256 := 0;
      Params         : Param_Buffer := (others => 0);
      Check          : Unsigned_16 := 0;
      Ack            : Byte := Ack_OK;
      Out_Length     : Byte := 1;
      Source         : Reply_Source := Scratch;
      Scratch        : Scratch_Bytes := (others => 0);
      Count          : Byte := 0;
      Pending        : Request;
      Try            : Try_Count := 0;
      Reboot         : Boolean := False;
      Reboot_Pin     : Motor_Index := 0;
      Exit_Scheduled : Boolean := False;
   end record;

   --  The number of bytes a count of 0 to 255 stands for.
   function Span (Count : Byte) return Positive is (if Count = 0 then 256 else Natural (Count));

   function Awaiting (T : State) return Boolean is (T.Current = Awaiting);
   function Finished (T : State) return Boolean is (T.Current = Finished);

   --  The bootloader operation the caller performs next.
   function Pending (T : State) return Request is (T.Pending);

   --  Takes the pins of the enabled motors that have one, in motor order, as
   --  the ESCs: the motors stop, each pin is released, set as an input and
   --  pulled high. TX_LED is the LED of the transmit indication. The
   --  interface mode, the device information and the selected ESC carry over
   --  from an earlier session.
   procedure Init (T : in out State; Enabled : Motor_Flags; Has_Pin : Motor_Flags; TX_LED : Natural; O : out Output)
     with Pre => TX_LED <= 1;

   --  The interface takes over the port and silences the beeper.
   procedure Start (T : in out State; O : out Output);

   --  One byte from the host. A complete frame replies, or asks for a
   --  bootloader operation first.
   procedure Receive (T : in out State; B : Byte; O : out Output)
     with Pre => not Awaiting (T) and then not Finished (T);

   --  The answer to the pending operation. The command replies, or asks for
   --  the next operation.
   procedure Complete (T : in out State; R : Result; O : out Output)
     with Pre => Awaiting (T);

end Adaflight.Four_Way;
