with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.CLI_Resources;
with Adaflight.ESC_Serial;
with Adaflight.STM32.ESC_Serial_Port;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Motors;
with Adaflight.STM32.Passthrough;
with Adaflight.STM32.Platform;
with Adaflight.STM32.Time;
with Adaflight.STM32.Timer_Dispatch;
with Adaflight.STM32.Timers;
package body Adaflight.STM32.ESC_Serial is
   use Interfaces;
   package Engine renames Adaflight.ESC_Serial;
   package GPIO renames Adaflight.STM32.GPIO;
   package Port renames Adaflight.STM32.ESC_Serial_Port;
   package Timers renames Adaflight.STM32.Timers;
   use type Timers.Timer_Name;
   use type Engine.Op_Kind;

   --  The pins by their tags: each motor's and the separate send pin's, zero
   --  for none.
   Tags     : array (Engine.Motor_Index) of Unsigned_8 := (others => 0);
   Send_Tag : Unsigned_8 := 0;

   procedure Configure (C : Adaflight.Config_Groups.Configuration) is
   begin
      for I in Engine.Motor_Index loop
         Tags (I) := C.Motor_Config.Dev.Io_Tags (I);
      end loop;
      Send_Tag := C.Esc_Serial_Config.Io_Tag;
   end Configure;

   --  A pin's timer channel taken for the port in the motors' name: one a
   --  motor output holds, or a free one.
   procedure Take (Who : Port.Pin_Target) is
      E     : Timers.Timer_Entry;
      Found : Boolean;
   begin
      Timers.Take
        ((if Who = Engine.Send_Pin then Send_Tag else Tags (Who)), Adaflight.CLI_Resources.Motor, E, Found);
      Port.Assign (Who, E, Found);
   end Take;

   --  The motors stopped, and every motor's pin an input with a pull up, the
   --  level an ESC's serial line idles at.
   procedure Stop_Motors is
   begin
      Adaflight.STM32.Motors.Disable;
      for I in Engine.Motor_Index loop
         if Adaflight.STM32.Motors.Has_Pin (I) then
            GPIO.Set_Input (Adaflight.STM32.Motors.Pin_Of (I), GPIO.Up);
         end if;
      end loop;
   end Stop_Motors;

   --  What the engine asks of the board. A motor's pin has a timer for the
   --  port when its channel is free or a motor output's and the port can
   --  run on that timer. The send pin's timer is compared with the chosen
   --  motor's.
   function Facts (Chosen : Natural) return Engine.Board is
      B          : Engine.Board;
      E, Send_E  : Timers.Timer_Entry;
      Found      : Boolean;
      Send_Found : Boolean;
   begin
      Timers.Peek (Send_Tag, Send_E, Send_Found);
      B.Send_Set := Send_Tag /= 0;
      B.Send_Timer :=
        Send_Found and then Timers.Can_Take (Send_Tag, Adaflight.CLI_Resources.Motor)
        and then Adaflight.STM32.Timer_Dispatch.Served (Send_E.Timer);
      B.Core_Clock := Adaflight.STM32.Platform.Core_Hz;
      for I in Engine.Motor_Index loop
         Timers.Peek (Tags (I), E, Found);
         B.Motors (I) :=
           (Assigned      => Tags (I) /= 0,
            Timer         => Found and then Timers.Can_Take (Tags (I), Adaflight.CLI_Resources.Motor)
                             and then Adaflight.STM32.Timer_Dispatch.Served (E.Timer),
            Complementary => Found and then E.N,
            Inverted      => False,
            Enabled       => Adaflight.STM32.Motors.Motor_Enabled (I),
            Has_Pin       => Adaflight.STM32.Motors.Has_Pin (I));
         if I = Chosen then
            B.Send_Same_Timer := Found and then Send_Found and then E.Timer = Send_E.Timer;
         end if;
      end loop;
      return B;
   end Facts;

   procedure Run
     (Host : Adaflight.STM32.Serial.Line; Protocol : Unsigned_8; Index : Natural; Started : out Boolean)
   is
      To_Host    : Adaflight.STM32.Serial.Port;
      Start_List : Engine.Op_List (Engine.Start_Ops);
      Chunk_List : Engine.Op_List (Engine.Chunk);
      Host_List  : Engine.Op_List (Engine.From_Host_Ops);
      Data       : Byte_Array (0 .. Engine.Chunk - 1);
      Count      : Natural;
      More, Left : Boolean;

      --  A start list's operations in order: a channel's take, the motors'
      --  stop and a wait happen here, and the runs of pin and timer operations
      --  between them go to the port.
      procedure Perform (Ops : Engine.Op_List) is
         First : Natural := 0;

         procedure Flush (Up_To : Natural) is
         begin
            if First > 0 then
               Port.Perform (Ops, First, Up_To);
               First := 0;
            end if;
         end Flush;
      begin
         for I in 1 .. Ops.Count loop
            case Ops.Items (I).Kind is
               when Engine.Allocate =>
                  Flush (I - 1);
                  if Ops.Items (I).Who in Port.Pin_Target then
                     Take (Ops.Items (I).Who);
                  end if;
               when Engine.Motors_Off =>
                  Flush (I - 1);
                  Stop_Motors;
               when Engine.Wait =>
                  Flush (I - 1);
                  Adaflight.STM32.Time.Delay_Ms (Natural (Ops.Items (I).A));
               when Engine.Host_Byte | Engine.ESC_Byte =>
                  null;
               when others =>
                  if First = 0 then
                     First := I;
                  end if;
            end case;
         end loop;
         Flush (Ops.Count);
      end Perform;

      --  A list's bytes for the host, in one write.
      procedure Reply (Ops : Engine.Op_List) is
         Out_Bytes : Byte_Array (0 .. Engine.Max_Ops - 1);
         Used      : Natural := 0;
      begin
         for I in 1 .. Ops.Count loop
            if Ops.Items (I).Kind = Engine.Host_Byte then
               Out_Bytes (Used) := Byte (Ops.Items (I).A and 16#FF#);
               Used := Used + 1;
            end if;
         end loop;
         if Used > 0 then
            Adaflight.STM32.Serial.Put (To_Host, Out_Bytes (0 .. Used - 1));
         end if;
      end Reply;
   begin
      Started := False;
      To_Host.Which := Host;
      if Protocol > Engine.Protocol'Pos (Engine.Protocol'Last) then
         return;
      end if;
      GPIO.Set_High (Adaflight.Board.LED0_Pin);
      if Protocol = Engine.Protocol'Pos (Engine.KISS_All) then
         --  KISS on every motor asked for by its own number.
         Stop_Motors;
         Port.Open_All (Engine.Baud_Of (Engine.KISS_All), Facts (Index mod 256), Start_List, Started);
      else
         Port.Start (Engine.Protocol'Val (Protocol), Index, Facts (Index mod 256), Start_List, Started);
      end if;
      Perform (Start_List);
      if not Started then
         Port.Release;
         return;
      end if;
      loop
         --  The board's LED, which a low level lights, is on while the
         --  ESC's bytes go to the host.
         loop
            Port.Forward (Chunk_List, More);
            if Chunk_List.Count > 0 then
               GPIO.Set_Low (Adaflight.Board.LED0_Pin);
            end if;
            Reply (Chunk_List);
            exit when not More;
         end loop;
         GPIO.Set_High (Adaflight.Board.LED0_Pin);
         Left := False;
         loop
            Adaflight.STM32.Serial.Take (Host, Data, Count);
            exit when Count = 0;
            Port.From_Host (Data (0 .. Count - 1), Host_List, Left);
            Reply (Host_List);
            exit when Left;
         end loop;
         exit when Left;
         if Port.Pass_Wait_Ms > 0 then
            Adaflight.STM32.Time.Delay_Ms (Port.Pass_Wait_Ms);
         end if;
      end loop;
   end Run;

   procedure Run_On_Command_Line (Index : Natural; Protocol : Unsigned_8; Started : out Boolean) is
   begin
      Run (Adaflight.STM32.Passthrough.Command_Line, Protocol, Index, Started);
   end Run_On_Command_Line;

end Adaflight.STM32.ESC_Serial;
