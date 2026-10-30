--  The bit-banged DShot output: a GPIO port's buffer of set and reset
--  words, three states a bit and three hold states, which a timer paced DMA
--  stream writes into the port's bit set and reset register. Every pin of
--  the port goes high at a bit's start and low at its end, and a pin whose
--  bit is a zero goes low at the bit's middle; inverted output swaps the
--  set and reset halves. The hold states keep the line at idle after the
--  frame. With bidirectional DShot the ports' samples after a frame give
--  the motors' replies. The setup groups the motors by port, each group
--  paced by a TIM8 or TIM1 channel's DMA stream.
with Interfaces; use Interfaces;
with Adaflight.DShot;
with Adaflight.Timer_Allocation;

package Adaflight.DShot_Bitbang with SPARK_Mode is

   use type Adaflight.DShot.Raw_State;

   Frame_Bits      : constant := 16;
   States_Per_Bit  : constant := 3;
   Buffer_Length   : constant := Frame_Bits * States_Per_Bit + 3;
   subtype Pin_Number is Natural range 0 .. 15;
   type Port_Buffer is array (0 .. Buffer_Length - 1) of Unsigned_32;

   --  A pin's set and reset states added to its port's buffer, the middles
   --  and the hold states after the first cleared.
   procedure Init (B : in out Port_Buffer; Port_Mask : Unsigned_16; Inverted : Boolean)
     with Global => null;

   --  A motor's frame in its pin's middles, most significant bit first.
   procedure Set (B : in out Port_Buffer; Pin : Pin_Number; Value : Unsigned_16; Inverted : Boolean)
     with Global => null;

   --  Every frame's middles cleared for the next update.
   procedure Clear (B : in out Port_Buffer)
     with Global => null;

   ---------------------------------------------------------------------------
   --  The replies read from the ports' samples after a frame
   ---------------------------------------------------------------------------

   Max_Ports : constant := 4;
   subtype Port_Index is Natural range 0 .. Max_Ports - 1;
   subtype Port_Total is Natural range 0 .. Max_Ports;
   subtype Input_Buffer is Adaflight.DShot.Samples (0 .. Adaflight.DShot.Max_Samples - 1);

   --  A port's samples of its pins, the samples its stream took, and whether
   --  the wait for them gave up.
   type Port_Input is record
      Count   : Adaflight.DShot.Sample_Count := Adaflight.DShot.Max_Samples;
      Aborted : Boolean := False;
      Buffer  : Input_Buffer := (others => 0);
   end record;
   type Port_Inputs is array (Port_Index) of Port_Input;

   type Motor_Pin is record
      Port : Port_Index := 0;
      Pin  : Pin_Number := 0;
   end record;
   type Motor_Pins is array (Adaflight.DShot.Motor_Index) of Motor_Pin;

   --  The read after a frame: nothing without telemetry. Else each motor in
   --  order whose port's wait did not give up decodes its pin's samples; a
   --  reply found counts a read, keeps the value, or marks the extended
   --  telemetry acknowledged when the value is the acknowledgement and the
   --  motor's command enables it, or counts an invalid reply, and counts the
   --  reply in the motor's quality. After every motor the raw values wait
   --  for processing and the used ports' marks clear.
   procedure Read_Replies
     (T : in out Adaflight.DShot.Telemetry; Counts : in out Adaflight.DShot.Read_Counts;
      Q : in out Adaflight.DShot.Qualities; D : in out Adaflight.DShot.Edge_Decoder; Ports : in out Port_Inputs;
      Used_Ports : Port_Total; Motors : Motor_Pins; Count : Adaflight.DShot.Motor_Total; Use_Telemetry : Boolean;
      Commands : Adaflight.DShot.Command_List; Now_Us : Adaflight.DShot.Time_Us; Now_Ms : Adaflight.DShot.Time_Ms)
     with Global => null,
          Post   => (if Use_Telemetry
                     then T.State = Adaflight.DShot.Not_Processed
                          and then (for all P in 0 .. Used_Ports - 1 => not Ports (P).Aborted));

   ---------------------------------------------------------------------------
   --  The driver's setup
   ---------------------------------------------------------------------------

   --  The bit-banged driver runs when its setting is on, or automatic with a
   --  protocol other than ProShot and, on the F4, the telemetry.
   Setting_On      : constant := 1;
   Setting_Auto    : constant := 2;
   ProShot         : constant := 8;
   function Active (Setting : Unsigned_8; Telemetry : Boolean; Protocol : Unsigned_8; F4 : Boolean) return Boolean is
     (Setting = Setting_On
      or else (Setting = Setting_Auto and then (Telemetry or else not F4) and then Protocol /= ProShot));

   --  The pacer channels in search order, each with its DMA stream numbered
   --  from 1 for the first controller's stream 0, and the stream's request
   --  channel.
   Pacer_Count : constant := 9;
   subtype Pacer_Row is Natural range 0 .. Pacer_Count;
   subtype Stream_Number is Natural range 0 .. 16;
   subtype Pacer_Stream is Positive range 1 .. 16;
   type Pacer is record
      Timer   : Positive range 1 .. 8;
      Channel : Positive range 1 .. 4;
      Stream  : Pacer_Stream;
      Request : Natural range 0 .. 7;
   end record;
   type Pacer_List is array (1 .. Pacer_Count) of Pacer;
   Pacers : constant Pacer_List :=
     ((8, 1, 11, 7), (8, 2, 12, 7), (8, 3, 13, 7), (8, 4, 16, 7), (1, 1, 10, 6), (1, 1, 12, 6), (1, 2, 11, 6),
      (1, 3, 15, 6), (1, 4, 13, 6));

   type Status_Kind is (OK, Motor_Pin_Conflict, No_Pacer, Too_Many_Ports);

   --  A port group: its port's number from 1 for port A, its pacer, the
   --  pacer's stream, and whether the group was allocated.
   type Port_Setup is record
      Port      : Unsigned_8 := 0;
      Pacer     : Pacer_Row := 0;
      Stream    : Stream_Number := 0;
      Allocated : Boolean := False;
   end record;
   type Port_Setups is array (Port_Index) of Port_Setup;

   --  A motor: its pin's tag, the output flags with the inversion and the
   --  telemetry applied, its group, and whether it was set up and enabled.
   type Motor_Setup is record
      Tag        : Unsigned_8 := 0;
      Pin        : Pin_Number := 0;
      Output     : Unsigned_8 := 0;
      Group      : Port_Index := 0;
      Configured : Boolean := False;
      Enabled    : Boolean := False;
   end record;
   type Motor_Setups is array (Adaflight.DShot.Motor_Index) of Motor_Setup;

   --  A pacer timer and the DMA requests of its channels in use.
   type Pacer_Timer is record
      Timer    : Natural range 0 .. 8 := 0;
      Requests : Unsigned_16 := 0;
   end record;
   type Pacer_Timers is array (Port_Index) of Pacer_Timer;

   --  The streams' bit-banged owners, a group's port number, zero for none.
   type Stream_Owners is array (1 .. 16) of Unsigned_8;
   type Stream_Flags is array (1 .. 16) of Boolean;
   type Pin_Flags is array (Unsigned_8) of Boolean;
   type Tag_List is array (Adaflight.DShot.Motor_Index) of Unsigned_8;
   type Order_List is array (Adaflight.DShot.Motor_Index) of Adaflight.DShot.Motor_Index;

   type Setup is record
      Init_OK       : Boolean := False;
      Status        : Status_Kind := OK;
      Used_Ports    : Port_Total := 0;
      Used_Pacers   : Port_Total := 0;
      Timers        : Pacer_Timers;
      Ports         : Port_Setups;
      Motors        : Motor_Setups;
      Streams       : Stream_Owners := (others => 0);
      Output_Period : Unsigned_32 := 0;
      Input_Period  : Unsigned_32 := 0;
      Timeout_Us    : Integer_32 := 0;
      Frame_Us      : Unsigned_32 := 0;
   end record;

   --  The setup at the device's start and after the other owners took their
   --  timers and streams. Each motor in order takes the pin of its place in
   --  the output order; a pin without a timer map channel, or one already
   --  held, stops the start with a pin conflict. Each port group slot then
   --  takes the first pacer the setting allows whose timer no map owner holds
   --  and no earlier slot shares and whose stream is free. Each motor in order
   --  joins its port's group or starts the next, which stops the setup with
   --  too many ports past four, without a pacer when the slot has none, or
   --  quietly when the pacer's stream is taken; a started group owns its
   --  stream, sets the periods from the timer clock, and adds its request to
   --  its timer.
   procedure Configure
     (S : out Setup; T : Adaflight.Timer_Allocation.Table; Busy : Stream_Flags; Taken : Pin_Flags;
      Count : Adaflight.DShot.Motor_Total; Tags : Tag_List; Order : Order_List; Choice : Unsigned_8;
      Telemetry : Boolean; Inversion : Boolean; Protocol : Unsigned_8; Clock : Unsigned_32)
     with Global => null,
          Post   => S.Used_Pacers <= S.Used_Ports;

   --  The port number of the group a pacer channel paces, zero for none.
   function Pacer_Owner (S : Setup; Timer : Positive; Channel : Positive) return Unsigned_8
     with Global => null;

end Adaflight.DShot_Bitbang;
