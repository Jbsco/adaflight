--  The HC-SR04 ultrasonic rangefinder on a trigger pin and an echo pin.
--  Detection fails when either pin has an owner; otherwise it sets the trigger
--  pin up as an output driven low, waits 100 ms, sets the echo pin up as an
--  input, and, when the echo pin reads low, fires up to five 11 us trigger
--  pulses, each followed by 60 ms of polling the echo pin for a high level by
--  the millisecond clock. A sensor that answers gets the echo pin's interrupt
--  on both edges and gives the task a 100 ms period, a 4 m range, a 30 degree
--  cone and a 45 degree extended cone; one that does not gets both pins
--  released. The echo interrupt notes the rising edge's microsecond time and,
--  at a falling edge after it by less than 2^31 us, the travel time and the
--  millisecond clock's reading. An update that finds the echo ended within 60
--  ms after the last trigger gives the distance as the travel time over 59, out
--  of range past 4 m; one that finds no echo within 60 ms of the trigger gives
--  a hardware failure. An update more than 60 ms after the last trigger fires
--  the next pulse. A read gives the distance once, then no new data.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The pins and clocks: each pin's owner check, setup with its owner, mode,
--  level, read and release by tag, the interrupt's setup, configuration and
--  enable, the delays and the millisecond clock.
generic
   type Pin_Device is limited private;
   with procedure Pin_Owned (D : in out Pin_Device; Tag : Byte; Owned : out Boolean);
   with procedure Init_Pin (D : in out Pin_Device; Tag : Byte; Owner : Byte);
   with procedure Config_Pin (D : in out Pin_Device; Tag : Byte; Input : Boolean);
   with procedure Pin_High (D : in out Pin_Device; Tag : Byte);
   with procedure Pin_Low (D : in out Pin_Device; Tag : Byte);
   with procedure Read_Pin (D : in out Pin_Device; Tag : Byte; High : out Boolean);
   with procedure Release_Pin (D : in out Pin_Device; Tag : Byte);
   with procedure Interrupt_Init (D : in out Pin_Device);
   with procedure Interrupt_Config (D : in out Pin_Device; Tag : Byte);
   with procedure Interrupt_Enable (D : in out Pin_Device; Tag : Byte);
   with procedure Delay_Ms (D : in out Pin_Device; Ms : Natural);
   with procedure Delay_Us (D : in out Pin_Device; Us : Natural);
   with procedure Millis (D : in out Pin_Device; Now : out Interfaces.Unsigned_32);
package Adaflight.HCSR04 with SPARK_Mode is
   use type Interfaces.Integer_32;

   Trigger_Owner : constant Byte := 1;
   Echo_Owner    : constant Byte := 2;

   Out_Of_Range     : constant Interfaces.Integer_32 := -1;
   Hardware_Failure : constant Interfaces.Integer_32 := -2;
   No_New_Data      : constant Interfaces.Integer_32 := -3;

   --  The distance in centimetres, cut at 4 m, or one of the three codes.
   subtype Reading is Interfaces.Integer_32 range -3 .. 400;

   type Config is record
      Trigger_Tag : Byte := 0;
      Echo_Tag    : Byte := 0;
   end record;

   type Device is record
      Delay_Ms                  : Natural range 0 .. 255 := 0;
      Max_Range_Cm              : Interfaces.Unsigned_16 := 0;
      Cone_Decidegrees          : Natural range 0 .. 3600 := 0;
      Cone_Extended_Decidegrees : Natural range 0 .. 3600 := 0;
   end record;

   --  The pins, the travel time and the millisecond the last echo ended, the
   --  last distance, the millisecond of the last trigger and the microsecond
   --  of the last rising edge.
   type State is record
      Pins            : Config;
      Travel_Us       : Interfaces.Integer_32 range 0 .. Interfaces.Integer_32'Last := 0;
      Received_Ms     : Interfaces.Unsigned_32 := 0;
      Last_Distance   : Reading := Out_Of_Range;
      Started_Ms      : Interfaces.Unsigned_32 := 0;
      Timing_Start_Us : Interfaces.Unsigned_32 := 0;
   end record;

   procedure Detect (D : in out Pin_Device; C : Config; S : in out State; Found : out Boolean; Dev : out Device);

   --  The echo pin's interrupt with the pin's level and the microsecond time;
   --  a falling edge that ends a pulse reads the millisecond clock.
   procedure Echo_Edge (D : in out Pin_Device; S : in out State; High : Boolean; Now_Us : Interfaces.Unsigned_32);

   procedure Update (D : in out Pin_Device; S : in out State);

   procedure Read (S : in out State; Distance : out Reading)
     with Global => null;

end Adaflight.HCSR04;
