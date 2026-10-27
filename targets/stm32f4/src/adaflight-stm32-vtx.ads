--  The video transmitter control of the board: the device the stored
--  configuration names on the UART it names, SmartAudio at 4800 baud with
--  two stop bits, half duplex and push-pull with a pull-down, or Tramp at
--  9600 baud, half duplex and open drain when the configuration asks for
--  it, the port taken when the receiver and the GPS do not hold it; the
--  core's control layer started over the running table, run as the VTX
--  task with the bytes the device sent and its frames queued on the port,
--  the channel switches applied after the mode pass, and the readings the
--  MSP replies take.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Modes;
with Adaflight.MSP_VTX_In;
with Adaflight.MSP_VTX_Status_Out;
with Adaflight.SmartAudio;
with Adaflight.STM32.USART;
with Adaflight.VTX_Table;
package Adaflight.STM32.VTX is
   --  The device and its port from the configuration, then the control
   --  layer's start; Save asks for the configuration to be stored when the
   --  start changed a setting, which it wrote back.
   procedure Init (C : in out Adaflight.Config_Groups.Configuration; Save : out Boolean);
   --  Whether the transmitter holds a UART.
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  The VTX task: the stored settings, the inputs and the device's bytes
   --  into the control layer, its frames out, and the settings it changed
   --  written back; Save asks for the configuration to be stored.
   procedure Run
     (C        : in out Adaflight.Config_Groups.Configuration;
      Now_Ms   : Interfaces.Unsigned_32;
      Now_Us   : Interfaces.Unsigned_32;
      Cli_Mode : Boolean;
      Save     : out Boolean);
   --  The channel switches after the mode pass.
   procedure Switches
     (C : in out Adaflight.Config_Groups.Configuration; Aux : Adaflight.Modes.Aux_Values; Armed : Boolean);
   --  A pit mode an MSP write asks for.
   procedure Set_Pit_Mode (Value : Interfaces.Unsigned_8);
   --  The readings of the MSP replies and writes.
   function Device return Adaflight.MSP_VTX_In.Device;
   function Table return Adaflight.VTX_Table.Table;
   function Status return Adaflight.MSP_VTX_Status_Out.Snapshot;
   procedure Peripheral (Present, Pit_Mode, Ready : out Boolean; Type_Code : out Interfaces.Unsigned_8);
   --  The power levels in dBm and milliwatts the device reports, none
   --  without levels.
   procedure Power_Levels
     (Count : out Natural; Levels, Powers : out Adaflight.SmartAudio.Level_Values);
end Adaflight.STM32.VTX;
