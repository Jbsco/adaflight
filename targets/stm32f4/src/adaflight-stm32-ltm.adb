with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Blackbox;
with Adaflight.STM32.ESC_Sensor;
with Adaflight.STM32.GPS;
with Adaflight.STM32.Radio;
with Adaflight.STM32.VTX;
package body Adaflight.STM32.LTM is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.STM32.USART.Number;
   package USART renames Adaflight.STM32.USART;
   package SFM renames Adaflight.Serial_Feature_Map;
   package Core renames Adaflight.LTM_Telemetry;

   Port_Ids : constant array (USART.Number) of SFM.Port_Id :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);
   Protocol_LTM : constant := 3;
   Baud_19200   : constant SFM.Baud_Index := 2;

   type Sharing is (Unused, Not_Shared, Shared);

   Have_Port    : Boolean := False;
   Which        : USART.Number := USART.UART1;
   Port_Sharing : Sharing := Unused;
   Baud         : SFM.Baud_Index := Baud_19200;
   Enabled      : Boolean := False;
   Port         : USART.Port;
   Stream       : Core.Stream;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32) is
      Assigned : constant SFM.Assignments := Adaflight.Config_Fix.Serial_Assignments (Config);
   begin
      Have_Port := False;
      Enabled := False;
      Port_Sharing := Unused;
      Stream := (others => <>);
      if (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) = 0 then
         return;
      end if;
      Find_Provider :
      for P of Config.Telemetry_Config.Providers loop
         if P.Protocol = Protocol_LTM and then Integer (P.Uart) /= Integer (SFM.No_Port) then
            for N in USART.Number loop
               if Integer (Port_Ids (N)) = Integer (P.Uart) then
                  Have_Port := True;
                  Which := N;
                  Baud := (if P.Baud = 0 then Baud_19200 else SFM.Baud_Index (Natural'Min (15, Natural (P.Baud))));
               end if;
            end loop;
            exit Find_Provider;
         end if;
      end loop Find_Provider;
      if Have_Port then
         declare
            Mask : constant Interfaces.Unsigned_32 :=
              SFM.Function_Mask (Adaflight.Config_Fix.Serial_Options, Assigned, Port_Ids (Which));
         begin
            Port_Sharing :=
              (if (Mask and SFM.Function_LTM) = 0 then Unused
               elsif Mask = SFM.Function_LTM then Not_Shared
               else Shared);
         end;
      end if;
   end Init;

   function Held_Elsewhere (N : USART.Number) return Boolean is
     (Adaflight.STM32.Radio.Holds (N) or else Adaflight.STM32.GPS.Holds (N)
      or else Adaflight.STM32.ESC_Sensor.Holds (N) or else Adaflight.STM32.VTX.Holds (N)
      or else Adaflight.STM32.Blackbox.Holds (N));

   procedure Check_State (Armed, Box_Present, Box_Active : Boolean) is
      Wanted : constant Boolean :=
        (case Port_Sharing is
            when Not_Shared => True,
            when Shared     => (if Box_Present then Box_Active else Armed),
            when Unused     => False);
   begin
      if Wanted = Enabled then
         return;
      end if;
      if Wanted then
         if Have_Port and then not Held_Elsewhere (Which) then
            Port.Which := Which;
            USART.Init (Which, Positive (SFM.Rate_Of (Baud)));
            Enabled := True;
         end if;
      else
         Enabled := False;
      end if;
   end Check_State;

   function Holds (N : USART.Number) return Boolean is (Enabled and then N = Which);

   function Shared_Port (N : USART.Number) return Boolean is
     (Have_Port and then N = Which and then Port_Sharing = Shared);

   procedure Run (Now_Ms : Interfaces.Unsigned_32; Inp : Core.Inputs) is
      O : Core.Output;
   begin
      if not Enabled then
         return;
      end if;
      Core.Update (Stream, Inp, Now_Ms, Enabled, O);
      if O.Count > 0 then
         USART.Put (Port, O.Data (0 .. O.Count - 1));
      end if;
   end Run;
end Adaflight.STM32.LTM;
