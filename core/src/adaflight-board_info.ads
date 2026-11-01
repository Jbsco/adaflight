--  The board's information as the board holds it: its name and
--  manufacturer and whether the stored configuration set them, whether a
--  command changed them, and the same for its signature. It is taken in from
--  the stored configuration as the board starts, stored back when a command
--  or a message sets it, and written back into a reset configuration with
--  the defaults of the board's hardware.
with Interfaces;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;

package Adaflight.Board_Info with SPARK_Mode is

   --  A name the version line or the board's lines print: up to 32
   --  characters.
   Identity_Max : constant := 32;
   subtype Identity_Length is Natural range 0 .. Identity_Max;
   type Identity_Text is record
      Data   : String (1 .. Identity_Max) := (others => ' ');
      Length : Identity_Length := 0;
   end record;

   function To_Identity (Text : String) return Identity_Text
     with Pre  => Text'Length <= Identity_Max,
          Post => To_Identity'Result.Length = Text'Length;

   type Signature_Bytes is array (0 .. 31) of Interfaces.Unsigned_8;

   Board_Name_Length   : constant := 20;
   Manufacturer_Length : constant := 4;

   --  An analog input as the board has it: whether it is on, and its pin's
   --  tag, zero for none.
   type Analog_Input is record
      Enabled : Boolean := False;
      Io_Tag  : Interfaces.Unsigned_8 := 0;
   end record;

   --  The defaults of the groups that name the board's hardware: the battery
   --  voltage, current, RSSI and external analog inputs, the beeper's pin,
   --  inversion and PWM frequency, the battery's voltage and current meter
   --  sources, the analog meters' scales, the OSD chip's select pin and
   --  SPI bus, numbered from 1, the SD card's SPI bus, select and detect
   --  pins with the detect pin's sense, the flash chip's SPI bus and select
   --  pin, the flight log device, the PINIO outputs' pins, configuration
   --  bytes and boxes by permanent id, the motors' pins and the LED strip's
   --  pin. The values given here are the host build's, which has none of
   --  this hardware.
   type PINIO_Bytes is array (0 .. 3) of Interfaces.Unsigned_8;
   type Motor_Bytes is array (0 .. 7) of Interfaces.Unsigned_8;

   --  A serial port identifier as the MSP slots take one, -1 for none.
   subtype Serial_Port is Integer range -1 .. 79;

   type Hardware_Defaults is record
      Vbat             : Analog_Input;
      Current          : Analog_Input;
      RSSI             : Analog_Input;
      External1        : Analog_Input;
      Beeper_Tag       : Interfaces.Unsigned_8 := 0;
      Beeper_Inverted  : Boolean := False;
      Beeper_Frequency : Interfaces.Unsigned_16 := 0;
      Voltage_Source   : Interfaces.Unsigned_8 := 0;
      Current_Source   : Interfaces.Unsigned_8 := 2;
      Voltage_Scale    : Interfaces.Unsigned_8 := 110;
      Current_Scale    : Interfaces.Integer_16 := 400;
      OSD_CS_Tag       : Interfaces.Unsigned_8 := 0;
      OSD_SPI_Device   : Interfaces.Unsigned_8 := 0;
      SD_SPI_Device    : Interfaces.Integer_8 := 0;
      SD_CS_Tag        : Interfaces.Unsigned_8 := 0;
      SD_Detect_Tag    : Interfaces.Unsigned_8 := 0;
      SD_Detect_Low    : Boolean := False;
      Flash_SPI_Device : Interfaces.Unsigned_8 := 0;
      Flash_CS_Tag     : Interfaces.Unsigned_8 := 0;
      Blackbox_Device  : Interfaces.Unsigned_8 := 0;
      PINIO_Tags       : PINIO_Bytes := (others => 0);
      PINIO_Configs    : PINIO_Bytes := (others => 1);
      PINIO_Boxes      : PINIO_Bytes := (others => 255);
      Motor_Tags       : Motor_Bytes := (others => 0);
      LED_Strip_Tag    : Interfaces.Unsigned_8 := 0;
      --  The barometer's bus: SPI when the board names one, else I2C when
      --  it names one, else none with the hardware set to none, with the
      --  bus's device, the chip select or the address, and the conversion
      --  end and reset pins; the reference build's values when unset.
      Baro_Bus_Type    : Interfaces.Unsigned_8 := 2;
      Baro_I2C_Device  : Interfaces.Unsigned_8 := 0;
      Baro_I2C_Address : Interfaces.Unsigned_8 := 0;
      Baro_SPI_Device  : Interfaces.Unsigned_8 := 0;
      Baro_CS_Tag      : Interfaces.Unsigned_8 := 0;
      Baro_EOC_Tag     : Interfaces.Unsigned_8 := 0;
      Baro_XCLR_Tag    : Interfaces.Unsigned_8 := 0;
      Baro_Hardware    : Interfaces.Unsigned_8 := 0;
      --  The compass's bus, device, address or select pin, interrupt pin and
      --  alignment; the reference build's values when the board names none.
      Mag_Bus_Type     : Interfaces.Unsigned_8 := 1;
      Mag_I2C_Device   : Interfaces.Unsigned_8 := 0;
      Mag_I2C_Address  : Interfaces.Unsigned_8 := 0;
      Mag_SPI_Device   : Interfaces.Unsigned_8 := 0;
      Mag_CS_Tag       : Interfaces.Unsigned_8 := 0;
      Mag_EXTI_Tag     : Interfaces.Unsigned_8 := 0;
      Mag_Align        : Interfaces.Unsigned_8 := 0;
      --  The timer pin map, the camera control pin, the ADC devices' DMA
      --  options and the ESC serial pin of the board; the reference build's
      --  values when unset.
      Timer_Map          : Adaflight.Config_Groups.Timer_Io_Config_Record_List_21 :=
        Adaflight.Config_Groups.Defaults.Timer_Io_Config;
      Camera_Control_Tag : Interfaces.Unsigned_8 := 41;
      ADC_DMA_Options    : Adaflight.Config_Groups.Integer_8_List_3 :=
        (1, Interfaces.Integer_8 (-1), Interfaces.Integer_8 (-1));
      ESC_Serial_Tag     : Interfaces.Unsigned_8 := 0;
      --  The ports a fresh configuration's MSP slots name: the board's
      --  first port, the USB one, then the target's MSP UARTs.
      MSP_First_Port        : Serial_Port := 20;
      MSP_UART              : Serial_Port := -1;
      MSP_Other_UART        : Serial_Port := -1;
      MSP_Display_Port_UART : Serial_Port := -1;
   end record;

   type State is record
      Name                : Identity_Text;
      Manufacturer        : Identity_Text;
      Information_Set     : Boolean := False;
      Information_Updated : Boolean := False;
      Signature           : Signature_Bytes := (others => 0);
      Signature_Set       : Boolean := False;
      Signature_Updated   : Boolean := False;
      Hardware            : Hardware_Defaults;
   end record;

   --  The stored board information taken in as the board starts: the name
   --  and the manufacturer when they are set, the signature when it is set.
   procedure Init (Board : in out State; C : Configuration);

   --  The board's name and manufacturer as the board holds them, stored up
   --  to their lengths with the information marked set.
   procedure Store_Information (C : in out Configuration; Board : State);

   --  The board's signature as the board holds it, stored and marked set.
   procedure Store_Signature (C : in out Configuration; Board : State);

   --  The board configuration's reset: a reset configuration keeps the
   --  information and the signature the board has taken in, and takes the
   --  board's hardware defaults.
   procedure Reset_Config (C : in out Configuration; Board : State);

   --  The board's information as a command set it, stored and taken in
   --  again.
   procedure Persist_Information (C : in out Configuration; Board : in out State);

   --  The board's signature as a command set it, stored and taken in again.
   procedure Persist_Signature (C : in out Configuration; Board : in out State);

end Adaflight.Board_Info;
