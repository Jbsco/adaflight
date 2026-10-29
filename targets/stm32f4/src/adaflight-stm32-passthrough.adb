with Ada.Real_Time;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Passthrough_Escape;
with Adaflight.STM32.ESC_Sensor;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.GPS;
with Adaflight.STM32.MCU;
with Adaflight.STM32.Motors;
with Adaflight.STM32.PINIO;
with Adaflight.STM32.Radio;
with Adaflight.STM32.Time;
with Adaflight.STM32.USART;
with Adaflight.STM32.USB;
package body Adaflight.STM32.Passthrough is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   package Serial renames Adaflight.STM32.Serial;
   package USART renames Adaflight.STM32.USART;
   use type Serial.Line;

   USB_VCP_Id : constant := 20;

   type DTR_Action is (No_Action, Reset_When_Dropped, PINIO_While_Down);

   Command_Line_Port : Serial.Line := Serial.VCP;
   Baud_From_USB     : Boolean := False;
   Baud_Target       : Serial.Line := Serial.VCP;
   DTR               : DTR_Action := No_Action;
   DTR_PINIO         : Natural := 0;

   procedure Set_Command_Line_Port (Which : Serial.Line) is
   begin
      Command_Line_Port := Which;
   end Set_Command_Line_Port;

   --  The board's line for a port identifier, and whether the board has one.
   procedure Line_Of (Id : Interfaces.Integer_32; Which : out Serial.Line; Found : out Boolean) is
   begin
      Found := True;
      case Id is
         when USB_VCP_Id =>
            Which := Serial.VCP;
         when 51 =>
            Which := Serial.UART1;
         when 53 =>
            Which := Serial.UART3;
         when 54 =>
            Which := Serial.UART4;
         when 56 =>
            Which := Serial.UART6;
         when others =>
            Which := Serial.VCP;
            Found := False;
      end case;
   end Line_Of;

   function Id_Of (Which : Serial.Line) return Interfaces.Integer_32 is
     (case Which is
         when Serial.VCP   => USB_VCP_Id,
         when Serial.UART1 => 51,
         when Serial.UART3 => 53,
         when Serial.UART4 => 54,
         when Serial.UART6 => 56);

   function UART_Of (Which : Serial.Line) return USART.Number is
     (case Which is
         when Serial.UART1 | Serial.VCP => USART.UART1,
         when Serial.UART3              => USART.UART3,
         when Serial.UART4              => USART.UART4,
         when Serial.UART6              => USART.UART6);

   function Line_Of_UART (N : USART.Number) return Serial.Line is
     (case N is
         when USART.UART1 => Serial.UART1,
         when USART.UART3 => Serial.UART3,
         when USART.UART4 => Serial.UART4,
         when USART.UART6 => Serial.UART6);

   function Positive_Baud (Baud : Interfaces.Unsigned_32) return Boolean is
     (Baud in 1 .. Interfaces.Unsigned_32 (Positive'Last));

   procedure Port_State
     (Id : Interfaces.Integer_32; Open : out Boolean; Baud : out Interfaces.Unsigned_32;
      Mode : out Interfaces.Unsigned_8; Options : out Interfaces.Unsigned_32; Callback : out Boolean)
   is
      Which : Serial.Line;
      Found : Boolean;
   begin
      Open := False;
      Baud := 0;
      Mode := 0;
      Options := 0;
      Callback := False;
      Line_Of (Id, Which, Found);
      if not Found then
         return;
      end if;
      if Which = Serial.VCP then
         Open := True;
         Mode := 3;
         return;
      end if;
      declare
         N : constant USART.Number := UART_Of (Which);
         S : constant USART.Settings := USART.Current (N);
      begin
         if S.Started then
            Open := True;
            Baud := Interfaces.Unsigned_32 (S.Baud);
            Mode := 3;
            Options := (if S.Inverted then 1 else 0) or (if S.Two_Stop_Bits then 2 else 0)
              or (if S.Even_Parity then 4 else 0) or (if S.Line.On then 8 else 0)
              or (if S.Line.On and then S.Line.Push_Pull then 16 else 0);
            Callback := Adaflight.STM32.Radio.Holds (N) or else Adaflight.STM32.ESC_Sensor.Holds (N);
         end if;
      end;
   end Port_State;

   procedure Port_Open
     (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32; Mode : Interfaces.Unsigned_8;
      Options : Interfaces.Unsigned_32; Opened : out Boolean)
   is
      pragma Unreferenced (Mode);
      Which : Serial.Line;
      Found : Boolean;
   begin
      Line_Of (Id, Which, Found);
      Opened := Found and then (Which = Serial.VCP or else Positive_Baud (Baud));
      if Opened and then Which /= Serial.VCP then
         USART.Init
           (UART_Of (Which), Positive (Baud), Two_Stop_Bits => (Options and 2) /= 0,
            Line        =>
              (if (Options and 8) /= 0
               then (On => True, Push_Pull => (Options and 16) /= 0,
                     Resistor => (if (Options and 1) /= 0 then Adaflight.STM32.GPIO.Down
                                  else Adaflight.STM32.GPIO.Up))
               else USART.Full_Duplex),
            Even_Parity => (Options and 4) /= 0, Inverted => (Options and 1) /= 0);
      end if;
   end Port_Open;

   procedure Port_Set_Baud (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32) is
      Which : Serial.Line;
      Found : Boolean;
   begin
      Line_Of (Id, Which, Found);
      if Found and then Which /= Serial.VCP and then Positive_Baud (Baud) then
         declare
            N : constant USART.Number := UART_Of (Which);
            S : constant USART.Settings := USART.Current (N);
         begin
            USART.Init (N, Positive (Baud), S.Two_Stop_Bits, S.Line, S.Even_Parity, S.Inverted);
         end;
      end if;
   end Port_Set_Baud;

   procedure Port_Baud_From_USB (USB : Interfaces.Integer_32; Target : Interfaces.Integer_32) is
      pragma Unreferenced (USB);
      Which : Serial.Line;
      Found : Boolean;
   begin
      Line_Of (Target, Which, Found);
      if Found and then Which /= Serial.VCP then
         Baud_From_USB := True;
         Baud_Target := Which;
      end if;
   end Port_Baud_From_USB;

   procedure Port_DTR_Reset (USB : Interfaces.Integer_32) is
      pragma Unreferenced (USB);
   begin
      DTR := Reset_When_Dropped;
   end Port_DTR_Reset;

   procedure Port_DTR_PINIO (USB : Interfaces.Integer_32; PINIO : Natural) is
      pragma Unreferenced (USB);
   begin
      DTR := PINIO_While_Down;
      DTR_PINIO := PINIO;
   end Port_DTR_PINIO;

   procedure ESC_Sensor_Pins_Idle is
   begin
      Adaflight.STM32.Motors.Hold_Idle;
   end ESC_Sensor_Pins_Idle;

   --  The forwarding loop: the left port's bytes to the right, the right's
   --  to the left with each through the escape, the host's line coding and
   --  DTR acted on, until a reset. A pass that moves no byte waits 100
   --  microseconds, which the receive rings cover at any baud rate.
   procedure Forward (Left : Serial.Line; Right : Serial.Line)
     with No_Return
   is
      Escape   : Adaflight.Passthrough_Escape.State :=
        Adaflight.Passthrough_Escape.Start (Integer (Id_Of (Right)), Adaflight.STM32.Time.Millis);
      To_Left  : Serial.Port;
      To_Right : Serial.Port;
      Data     : Byte_Array (0 .. 63);
      Count    : Natural;
      Reset    : Boolean;
      Rate     : Interfaces.Unsigned_32 := Adaflight.STM32.USB.Line_Rate;
      State    : Interfaces.Unsigned_16;
      Seen     : Interfaces.Unsigned_32;
      Requests : Interfaces.Unsigned_32;
      Moved    : Boolean;
      use type Ada.Real_Time.Time;
   begin
      To_Left.Which := Left;
      To_Right.Which := Right;
      Adaflight.STM32.USB.Control_Line (State, Seen);
      loop
         Serial.Take (Left, Data, Count);
         Moved := Count > 0;
         if Count > 0 then
            Serial.Put (To_Right, Data (0 .. Count - 1));
         end if;
         Serial.Take (Right, Data, Count);
         Moved := Moved or else Count > 0;
         for I in 0 .. Count - 1 loop
            Serial.Put (To_Left, Data (I .. I));
            Adaflight.Passthrough_Escape.Host_Byte
              (Escape, Interfaces.Unsigned_8 (Data (I)), Adaflight.STM32.Time.Millis, Reset);
            if Reset then
               Adaflight.STM32.MCU.Reset;
            end if;
         end loop;
         if Baud_From_USB and then Adaflight.STM32.USB.Line_Rate /= Rate then
            Rate := Adaflight.STM32.USB.Line_Rate;
            Port_Set_Baud (Id_Of (Baud_Target), Rate);
         end if;
         if DTR /= No_Action then
            Adaflight.STM32.USB.Control_Line (State, Requests);
            if Requests /= Seen then
               Seen := Requests;
               case DTR is
                  when Reset_When_Dropped =>
                     if (State and 1) = 0 then
                        Adaflight.STM32.MCU.Reset;
                     end if;
                  when PINIO_While_Down =>
                     Adaflight.STM32.PINIO.Set (DTR_PINIO, (State and 1) = 0);
                  when No_Action =>
                     null;
               end case;
            end if;
         end if;
         if not Moved then
            delay until Ada.Real_Time.Clock + Ada.Real_Time.Microseconds (100);
         end if;
      end loop;
   end Forward;

   procedure Port_Forward (Left : Interfaces.Integer_32; Right : Interfaces.Integer_32) is
      L, R   : Serial.Line;
      L_Seen : Boolean;
      R_Seen : Boolean;
   begin
      Line_Of (Left, L, L_Seen);
      Line_Of (Right, R, R_Seen);
      if L_Seen and then R_Seen then
         Forward (L, R);
      end if;
   end Port_Forward;

   procedure GPS_Passthrough (Started : out Boolean) is
   begin
      for N in USART.Number loop
         if Adaflight.STM32.GPS.Holds (N) then
            Forward (Line_Of_UART (N), Command_Line_Port);
         end if;
      end loop;
      Started := False;
   end GPS_Passthrough;

end Adaflight.STM32.Passthrough;
