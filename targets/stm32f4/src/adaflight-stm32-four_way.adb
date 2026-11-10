with Ada.Real_Time;
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.BLHeli_Bootloader;
with Adaflight.Board;
with Adaflight.Four_Way;
with Adaflight.Pins;
with Adaflight.STK_Bootloader;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Motors;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Four_Way is
   package FW renames Adaflight.Four_Way;
   package GPIO renames Adaflight.STM32.GPIO;
   package Motors renames Adaflight.STM32.Motors;
   package Serial renames Adaflight.STM32.Serial;
   package Time renames Adaflight.STM32.Time;

   --  The ESCs' signal pins in the interface's order, for the bootloader
   --  protocols, which name an ESC by its number.
   type Pin_List is array (FW.Motor_Index) of Adaflight.Pins.Pin;
   type Line is record
      Pins : Pin_List := (others => (Port => Adaflight.Pins.Port_A, Number => 0));
   end record;

   function Pin_Of (L : Line; ESC : Byte) return Adaflight.Pins.Pin is (L.Pins (Natural (ESC) mod FW.Max_Motors));

   procedure Read_Micros (L : in out Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (L);
   begin
      Now := Time.Micros;
   end Read_Micros;

   procedure Read_Millis (L : in out Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (L);
   begin
      Now := Time.Millis;
   end Read_Millis;

   procedure Delay_Micros (L : in out Line; Micros : Natural) is
      pragma Unreferenced (L);
   begin
      Time.Delay_Us (Micros);
   end Delay_Micros;

   procedure Read_Pin (L : in out Line; ESC : Byte; High : out Boolean) is
   begin
      High := GPIO.Is_High (Pin_Of (L, ESC));
   end Read_Pin;

   procedure Pin_Low (L : in out Line; ESC : Byte) is
   begin
      GPIO.Set_Low (Pin_Of (L, ESC));
   end Pin_Low;

   procedure Pin_High (L : in out Line; ESC : Byte) is
   begin
      GPIO.Set_High (Pin_Of (L, ESC));
   end Pin_High;

   --  An ESC's pin as an input pulled up, the level its line idles at.
   procedure Pin_Input (L : in out Line; ESC : Byte) is
   begin
      GPIO.Set_Input (Pin_Of (L, ESC), GPIO.Up);
   end Pin_Input;

   procedure Pin_Output (L : in out Line; ESC : Byte) is
   begin
      GPIO.Set_Output (Pin_Of (L, ESC));
   end Pin_Output;

   package BL is new Adaflight.BLHeli_Bootloader
     (Line, Read_Micros, Read_Millis, Read_Pin, Pin_Low, Pin_High, Pin_Input, Pin_Output);
   package STK is new Adaflight.STK_Bootloader
     (Line, Read_Micros, Delay_Micros, Read_Pin, Pin_Low, Pin_High, Pin_Input, Pin_Output);

   --  The interface's state, whose mode, device information and selected
   --  ESC a later session finds again, and the STK500v2 link's.
   State    : FW.State;
   STK_Link : STK.Link;

   function Taken (Index : FW.Motor_Index) return Boolean is
     (Motors.Motor_Enabled (Index) and then Motors.Has_Pin (Index));

   function ESC_Count return Natural is
      Total : Natural := 0;
   begin
      for I in FW.Motor_Index loop
         if Taken (I) then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end ESC_Count;

   procedure Run (Host : Serial.Line; Silence_Beeper : not null access procedure) is
      use type Ada.Real_Time.Time;
      To_Host  : Serial.Port;
      O        : FW.Output;
      All_Back : Boolean := True;
      Data     : Byte_Array (0 .. 63);
      Count    : Natural;

      --  The interface's operations in order. A released pin needs no step
      --  of its own, since its setting as an input follows. The board's LED,
      --  which a low level lights, is both the receive and the transmit LED.
      procedure Perform (O : FW.Output) is
         OK : Boolean;
      begin
         for I in 1 .. O.Count loop
            declare
               Op : constant FW.Op := O.Ops (I);
            begin
               case Op.Kind is
                  when FW.Disable_Motors =>
                     Motors.Disable;
                  when FW.Enable_Motors_If_Reinstated =>
                     if All_Back then
                        Motors.Enable;
                     end if;
                  when FW.Reinstate_Pin =>
                     Motors.Reinstate_Pin (Op.Index, OK);
                     All_Back := All_Back and then OK;
                  when FW.Pin_Alternate =>
                     Motors.Reinstate_Pin (Op.Index, OK);
                  when FW.Pin_Input =>
                     if Motors.Has_Pin (Op.Index) then
                        GPIO.Set_Input (Motors.Pin_Of (Op.Index), GPIO.Up);
                     end if;
                  when FW.Pin_Output =>
                     if Motors.Has_Pin (Op.Index) then
                        GPIO.Set_Output (Motors.Pin_Of (Op.Index));
                     end if;
                  when FW.Pin_High =>
                     if Motors.Has_Pin (Op.Index) then
                        GPIO.Set_High (Motors.Pin_Of (Op.Index));
                     end if;
                  when FW.Pin_Low =>
                     if Motors.Has_Pin (Op.Index) then
                        GPIO.Set_Low (Motors.Pin_Of (Op.Index));
                     end if;
                  when FW.Wait_Ms =>
                     Time.Delay_Ms (Op.Value);
                  when FW.Silence_Beeper =>
                     Silence_Beeper.all;
                  when FW.Send_Reply =>
                     Serial.Put (To_Host, O.Reply (0 .. O.Length - 1));
                  when FW.LED_On =>
                     GPIO.Set_Low (Adaflight.Board.LED0_Pin);
                  when FW.LED_Off =>
                     GPIO.Set_High (Adaflight.Board.LED0_Pin);
                  when FW.Release_Pin =>
                     null;
               end case;
            end;
         end loop;
      end Perform;

      --  The pending bootloader operation on the selected ESC's pin, and the
      --  interface's next step with its answer.
      procedure Answer_Pending is
         Q : constant FW.Request := FW.Pending (State);
         L : Line;
         R : FW.Result;
      begin
         for K in FW.Motor_Index loop
            if K < State.ESC_Total and then Motors.Has_Pin (State.Pins (K)) then
               L.Pins (K) := Motors.Pin_Of (State.Pins (K));
            end if;
         end loop;
         if BL.Handles (Q.Kind) then
            BL.Perform (L, Q, State.Info, State.Params, R);
         else
            STK.Perform (L, STK_Link, Q, State.Info, State.Params, R);
         end if;
         FW.Complete (State, R, O);
         Perform (O);
      end Answer_Pending;

      Enabled, Has_Pin : FW.Motor_Flags;
   begin
      To_Host.Which := Host;
      for I in FW.Motor_Index loop
         Enabled (I) := Motors.Motor_Enabled (I);
         Has_Pin (I) := Motors.Has_Pin (I);
      end loop;
      FW.Init (State, Enabled, Has_Pin, TX_LED => 0, O => O);
      Perform (O);
      FW.Start (State, O);
      Perform (O);
      loop
         Serial.Take (Host, Data, Count);
         for I in 0 .. Count - 1 loop
            FW.Receive (State, Data (I), O);
            Perform (O);
            while FW.Awaiting (State) loop
               Answer_Pending;
            end loop;
            if FW.Finished (State) then
               return;
            end if;
         end loop;
         if Count = 0 then
            delay until Ada.Real_Time.Clock + Ada.Real_Time.Microseconds (100);
         end if;
      end loop;
   end Run;

end Adaflight.STM32.Four_Way;
