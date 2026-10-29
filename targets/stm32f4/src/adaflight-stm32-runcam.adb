with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.STM32.ESC_Sensor;
with Adaflight.STM32.GPS;
with Adaflight.STM32.Radio;
with Adaflight.STM32.VTX;
package body Adaflight.STM32.RunCam is
   use type Interfaces.Integer_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.STM32.USART.Number;
   package USART renames Adaflight.STM32.USART;
   package Core renames Adaflight.RunCam_Device;

   Port_Ids : constant array (USART.Number) of Interfaces.Integer_8 :=
     (USART.UART1 => 51, USART.UART2 => 52, USART.UART3 => 53, USART.UART4 => 54, USART.UART5 => 55, USART.UART6 => 56);
   No_Port : constant Interfaces.Integer_8 := -1;
   Baud    : constant := 115_200;

   Open     : Boolean := False;
   Which    : USART.Number := USART.UART1;
   Port     : USART.Port;
   Device   : Core.Device;
   Settings : Core.Settings;
   Input    : Byte_Array (0 .. 63);
   --  The bytes received that the device has not taken yet.
   Pending  : Byte_Array (0 .. 255) := (others => 0);
   Waiting  : Natural range 0 .. 256 := 0;

   --  The bytes a call sends.
   procedure Send (E : Core.Events) is
   begin
      if E.Line.Count > 0 then
         USART.Put (Port, E.Line.Tx (0 .. E.Line.Count - 1));
      end if;
   end Send;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Now_Ms : Interfaces.Unsigned_32) is
      R : Adaflight.Config_Groups.Rcdevice_Config_Record renames Config.Rcdevice_Config;
      E : Core.Events;
   begin
      Settings :=
        (Protocol_Setting =>
           (if Natural (R.Protocol_Version) <= Core.Protocol'Pos (Core.Protocol'Last)
            then Core.Protocol'Val (R.Protocol_Version) else Core.Unknown),
         Feature          => Interfaces.Unsigned_16 (R.Feature and 16#FFFF#),
         Init_Attempts    => Natural (R.Init_Device_Attempts),
         Init_Interval_Ms => R.Init_Device_Attempt_Interval);
      Open := False;
      Waiting := 0;
      if R.Rcdevice_Uart /= No_Port then
         for N of USART.Present_Set loop
            if Port_Ids (N) = R.Rcdevice_Uart then
               if not Adaflight.STM32.Radio.Holds (N) and then not Adaflight.STM32.GPS.Holds (N)
                 and then not Adaflight.STM32.ESC_Sensor.Holds (N) and then not Adaflight.STM32.VTX.Holds (N)
               then
                  Which := N;
                  Open := True;
               end if;
               exit;
            end if;
         end loop;
      end if;
      if Open then
         Port.Which := Which;
         USART.Init (Which, Baud);
      end if;
      Core.Init (Device, Settings, Open, Now_Ms, E);
      if Open then
         Send (E);
      end if;
   end Init;

   function Enabled return Boolean is (Open);

   function Holds (N : USART.Number) return Boolean is (Open and then N = Which);

   procedure Run (Inp : Core.Inputs; Sound : out Core.Beep) is
      Count : Natural;
      Take  : Natural;
      E     : Core.Events;
   begin
      Sound := Core.No_Beep;
      if not Open then
         return;
      end if;
      USART.Take (Which, Input, Count);
      Take := Natural'Min (Count, Pending'Length - Waiting);
      Pending (Waiting .. Waiting + Take - 1) := Input (0 .. Take - 1);
      Waiting := Waiting + Take;
      Core.Update (Device, Settings, Inp, Pending (0 .. Waiting - 1), E);
      Send (E);
      if E.Flushed then
         Waiting := 0;
      else
         Pending (0 .. Waiting - E.Consumed - 1) := Pending (E.Consumed .. Waiting - 1);
         Waiting := Waiting - E.Consumed;
      end if;
      Sound := E.Sound;
   end Run;
end Adaflight.STM32.RunCam;
