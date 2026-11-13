--  The board's one ESC serial port: the engine's port with the pins and timers
--  its operations name. A task's calls on the port run with every interrupt
--  held off. On a board the timer interrupts run the port's ticks and edges;
--  the host image runs them from a line model as bytes arrive.
with Interfaces;
with Adaflight.Bytes;
with Adaflight.ESC_Serial;
with Adaflight.STM32.Timers;
package Adaflight.STM32.ESC_Serial_Port is
   package Engine renames Adaflight.ESC_Serial;

   subtype Pin_Target is Engine.Target range 0 .. Engine.Send_Pin;

   --  The engine's calls on the port. Open_All opens every motor for KISS at
   --  a rate. At the exit request From_Host also carries out the port's
   --  closing operations before it returns.
   procedure Start
     (Mode : Engine.Protocol; Index : Natural; B : Engine.Board; Ops : in out Engine.Op_List; Started : out Boolean)
     with Pre => Engine."/=" (Mode, Engine.KISS_All) and then Ops.Room >= Engine.Start_Ops;
   procedure Open_All
     (Baud : Interfaces.Unsigned_32; B : Engine.Board; Ops : in out Engine.Op_List; Started : out Boolean)
     with Pre => Interfaces.">" (Baud, 0) and then Ops.Room >= Engine.Open_Ops;
   procedure Forward (Ops : in out Engine.Op_List; More : out Boolean)
     with Pre => Ops.Room >= Engine.Chunk;
   procedure From_Host (Host : Adaflight.Bytes.Byte_Array; Ops : in out Engine.Op_List; Left : out Boolean)
     with Pre => Host'Length <= Engine.Chunk and then Ops.Room >= Engine.From_Host_Ops;
   function Pass_Wait_Ms return Natural;

   --  A pin's timer channel as its take gave it, or none. The port leaves
   --  out the operations on a pin without one.
   procedure Assign (Who : Pin_Target; E : Adaflight.STM32.Timers.Timer_Entry; Found : Boolean);

   --  The pin and timer operations among a list's items First to Last
   --  carried out, with the port's interrupts held off. A channel's take,
   --  the motors' stop, a wait and a byte for the host are the caller's.
   procedure Perform (Ops : Engine.Op_List; First, Last : Positive);

   --  The port's timers given up after a start that failed.
   procedure Release;

end Adaflight.STM32.ESC_Serial_Port;
