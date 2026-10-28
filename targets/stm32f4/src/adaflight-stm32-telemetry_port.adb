with Adaflight.Config_Fix;
with Adaflight.STM32.Blackbox;
with Adaflight.STM32.ESC_Sensor;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.GPS;
with Adaflight.STM32.Radio;
with Adaflight.STM32.VTX;
package body Adaflight.STM32.Telemetry_Port is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.STM32.USART.Number;
   package USART renames Adaflight.STM32.USART;
   package SFM renames Adaflight.Serial_Feature_Map;

   Port_Ids : constant array (USART.Number) of SFM.Port_Id :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);

   type Sharing is (Unused, Not_Shared, Shared);

   Have_Port    : Boolean := False;
   Which        : USART.Number := USART.UART1;
   Port_Sharing : Sharing := Unused;
   Baud         : SFM.Baud_Index := Default_Baud;
   Is_Open      : Boolean := False;
   Inverted     : Boolean := False;
   Wire         : USART.Half_Duplex := USART.Full_Duplex;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32) is
      Assigned : constant SFM.Assignments := Adaflight.Config_Fix.Serial_Assignments (Config);
   begin
      Have_Port := False;
      Is_Open := False;
      Port_Sharing := Unused;
      Inverted := (Config.Telemetry_Config.Telemetry_Inverted /= 0) /= Inverted_Default;
      --  One wire is push-pull with a pull-down when inverted, open drain
      --  with a pull-up otherwise.
      Wire :=
        (if Single_Wire or else (Half_Duplex_Use and then Config.Telemetry_Config.Half_Duplex /= 0)
         then (On => True, Push_Pull => Inverted, Resistor => (if Inverted then GPIO.Down else GPIO.Up))
         else USART.Full_Duplex);
      if (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) = 0 then
         return;
      end if;
      Find_Provider :
      for P of Config.Telemetry_Config.Providers loop
         if P.Protocol = Protocol and then Integer (P.Uart) /= Integer (SFM.No_Port) then
            for N in USART.Number loop
               if Integer (Port_Ids (N)) = Integer (P.Uart) then
                  Have_Port := True;
                  Which := N;
                  Baud :=
                    (if P.Baud = 0 or else Fixed_Rate then Default_Baud
                     else SFM.Baud_Index (Natural'Min (15, Natural (P.Baud))));
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
              (if (Mask and Function_Bit) = 0 then Unused
               elsif Mask = Function_Bit then Not_Shared
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
      if Wanted = Is_Open then
         return;
      end if;
      if Wanted then
         if Have_Port and then not Held_Elsewhere (Which) then
            USART.Init (Which, Positive (SFM.Rate_Of (Baud)), Line => Wire, Inverted => Inverted);
            Is_Open := True;
         end if;
      else
         Is_Open := False;
      end if;
   end Check_State;

   function Enabled return Boolean is (Is_Open);

   function Holds (N : USART.Number) return Boolean is (Is_Open and then N = Which);

   function Line return USART.Number is (Which);
end Adaflight.STM32.Telemetry_Port;
