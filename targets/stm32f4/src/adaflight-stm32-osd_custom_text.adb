with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.OSD_Custom_Text;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.GPS;
with Adaflight.STM32.Radio;
with Adaflight.STM32.Rangefinder;
package body Adaflight.STM32.OSD_Custom_Text is
   use type Interfaces.Integer_8;
   use type Interfaces.Unsigned_8;
   use type Adaflight.STM32.USART.Number;
   package USART renames Adaflight.STM32.USART;
   package Core renames Adaflight.OSD_Custom_Text;
   package SFM renames Adaflight.Serial_Feature_Map;

   Port_Ids : constant array (USART.Number) of Interfaces.Integer_8 :=
     (USART.UART1 => 51, USART.UART2 => 52, USART.UART3 => 53, USART.UART4 => 54, USART.UART5 => 55, USART.UART6 => 56);

   Open  : Boolean := False;
   Which : USART.Number := USART.UART1;
   State : Core.State;

   procedure Init (Config : Adaflight.Config_Groups.Configuration) is
      Rate : constant Natural := Natural (Config.Osd_Config.Osd_Custom_Text_Baud);
   begin
      Open := False;
      for N of USART.Present_Set loop
         if Port_Ids (N) = Config.Osd_Config.Osd_Custom_Text_Uart then
            if not Adaflight.STM32.Rangefinder.Holds (N) and then not Adaflight.STM32.Radio.Holds (N)
              and then not Adaflight.STM32.GPS.Holds (N)
            then
               Which := N;
               Open := True;
            end if;
            exit;
         end if;
      end loop;
      if Open then
         USART.Init
           (Which,
            Positive
              (SFM.Rate_Of
                 (if Rate = SFM.Baud_Auto or else Rate > SFM.Baud_Index'Last then SFM.Baud_115200 else Rate)));
      end if;
      Core.Init (State, Open);
   end Init;

   function Holds (N : USART.Number) return Boolean is (Open and then N = Which);

   procedure Update (Terminator : Interfaces.Unsigned_8) is
      Ends  : constant Core.Terminator := (if Terminator = 0 then Core.Null_Byte else Core.Line_Feed);
      Input : Byte_Array (0 .. 63);
      Count : Natural;
   begin
      if not Open then
         return;
      end if;
      loop
         USART.Take (Which, Input, Count);
         Core.Update (State, Ends, Input (0 .. Count - 1));
         exit when Count < Input'Length;
      end loop;
   end Update;

   function Text return Adaflight.OSD_Render.Custom_Text is
      T : Adaflight.OSD_Render.Custom_Text;
   begin
      T.Length := State.Display_Length;
      for K in 1 .. State.Display_Length loop
         T.Data (K) := Character'Val (State.Display (K - 1));
      end loop;
      return T;
   end Text;
end Adaflight.STM32.OSD_Custom_Text;
