with Adaflight.Build_Features;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Lidar_TF;
with Adaflight.Nooploop;
with Adaflight.Rangefinder;
with Adaflight.Rangefinder_Detect;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Rangefinder is
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Adaflight.STM32.USART.Number;
   use type Adaflight.Rangefinder_Detect.Driver;
   package USART renames Adaflight.STM32.USART;
   package Core renames Adaflight.Rangefinder;

   Port_Ids : constant array (USART.Number) of Interfaces.Integer_8 :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);

   --  The lidar's port: the UART, its received bytes not read yet, and the
   --  port record its commands go out through.
   type Lidar_Port is limited record
      Which   : USART.Number := USART.UART1;
      Open    : Boolean := False;
      Port    : USART.Port;
      Pending : Byte_Array (0 .. 63) := (others => 0);
      First   : Natural range 0 .. 64 := 0;
      Last    : Natural range 0 .. 64 := 0;
   end record;

   procedure Open_Port
     (D : in out Lidar_Port; Port : Interfaces.Integer_8; Baud : Interfaces.Unsigned_32; Opened : out Boolean) is
   begin
      Opened := False;
      for N in USART.Number loop
         if Port_Ids (N) = Port then
            D.Which := N;
            D.Port.Which := N;
            D.Open := True;
            D.First := 0;
            D.Last := 0;
            USART.Init (N, Positive (Baud));
            Opened := True;
            exit;
         end if;
      end loop;
   end Open_Port;

   --  The bytes received since the last take, after those not read yet.
   procedure Bytes_Waiting (D : in out Lidar_Port; Count : out Natural) is
   begin
      if D.First = D.Last and then D.Open then
         D.First := 0;
         USART.Take (D.Which, D.Pending, D.Last);
      end if;
      Count := D.Last - D.First;
   end Bytes_Waiting;

   procedure Read_Byte (D : in out Lidar_Port; B : out Byte) is
   begin
      if D.First < D.Last then
         B := D.Pending (D.First);
         D.First := D.First + 1;
      else
         B := 0;
      end if;
   end Read_Byte;

   procedure Write_Bytes (D : in out Lidar_Port; Data : Byte_Array) is
   begin
      if D.Open then
         USART.Put (D.Port, Data);
      end if;
   end Write_Bytes;

   procedure Millis (D : in out Lidar_Port; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Adaflight.STM32.Time.Millis;
   end Millis;

   package Lidar is new Adaflight.Lidar_TF
     (Serial_Device => Lidar_Port,
      Open_Port     => Open_Port,
      Bytes_Waiting => Bytes_Waiting,
      Read_Byte     => Read_Byte,
      Write_Bytes   => Write_Bytes,
      Millis        => Millis);

   package TOFSense is new Adaflight.Nooploop
     (Serial_Device => Lidar_Port,
      Open_Port     => Open_Port,
      Bytes_Waiting => Bytes_Waiting,
      Read_Byte     => Read_Byte,
      Millis        => Millis);

   Port       : Lidar_Port;
   State      : Lidar.State;
   TOF_State  : TOFSense.State;
   Sensor     : Core.Sensor;
   Found      : Boolean := False;
   Driver     : Adaflight.Rangefinder_Detect.Driver := Adaflight.Rangefinder_Detect.TF;
   Period     : Natural := 0;

   procedure Init (Config : Adaflight.Config_Groups.Configuration) is
      Hardware : constant Byte := Config.Rangefinder_Config.Rangefinder_Hardware;
      Uart     : constant Interfaces.Integer_8 := Config.Rangefinder_Config.Rangefinder_Uart;
      Delay_Ms : Natural := 0;
      Range_Cm : Interfaces.Unsigned_16 := 0;
      Cone     : Natural := 0;
   begin
      Found := False;
      if not Adaflight.Build_Features.Rangefinder then
         return;
      end if;
      if Adaflight.Rangefinder_Detect.Has_Driver (Hardware) then
         Driver := Adaflight.Rangefinder_Detect.Driver_Of (Hardware);
         case Driver is
            when Adaflight.Rangefinder_Detect.TF =>
               declare
                  Dev : Lidar.Device;
               begin
                  Lidar.Detect (Port, State, Hardware, Uart, Found, Dev);
                  Delay_Ms := Dev.Delay_Ms;
                  Range_Cm := Dev.Max_Range_Cm;
                  Cone := Dev.Cone_Extended_Decidegrees;
               end;
            when Adaflight.Rangefinder_Detect.Nooploop =>
               declare
                  Dev : TOFSense.Device;
               begin
                  TOFSense.Detect (Port, TOF_State, Hardware, Uart, Found, Dev);
                  Delay_Ms := Dev.Delay_Ms;
                  Range_Cm := Dev.Max_Range_Cm;
                  Cone := Dev.Cone_Extended_Decidegrees;
               end;
            when Adaflight.Rangefinder_Detect.HCSR04 | Adaflight.Rangefinder_Detect.MT
               | Adaflight.Rangefinder_Detect.UPT1 =>
               null;
         end case;
      end if;
      if Found then
         Period := Adaflight.Rangefinder_Detect.Period_Ms (Driver, Delay_Ms);
         case Driver is
            when Adaflight.Rangefinder_Detect.TF =>
               Lidar.Init (State);
            when Adaflight.Rangefinder_Detect.Nooploop =>
               TOFSense.Init (TOF_State);
            when Adaflight.Rangefinder_Detect.HCSR04 | Adaflight.Rangefinder_Detect.MT
               | Adaflight.Rangefinder_Detect.UPT1 =>
               null;
         end case;
         Core.Init
           (Sensor,
            (Max_Range_Cm              => Core.Range_Cm (Natural'Min (32_767, Natural (Range_Cm))),
             Cone_Extended_Decidegrees => Core.Decidegrees (Cone)),
            Adaflight.STM32.Time.Millis);
      end if;
   end Init;

   function Detected return Boolean is (Adaflight.Build_Features.Rangefinder and then Found);

   function Period_Ms return Natural is (Period);

   function Holds (N : USART.Number) return Boolean is
     (Adaflight.Build_Features.Rangefinder and then Found and then Port.Open and then N = Port.Which);

   procedure Update is
   begin
      if Adaflight.Build_Features.Rangefinder and then Found then
         case Driver is
            when Adaflight.Rangefinder_Detect.TF =>
               Lidar.Update (Port, State);
            when Adaflight.Rangefinder_Detect.Nooploop =>
               TOFSense.Update (Port, TOF_State);
            when Adaflight.Rangefinder_Detect.HCSR04 | Adaflight.Rangefinder_Detect.MT
               | Adaflight.Rangefinder_Detect.UPT1 =>
               null;
         end case;
      end if;
   end Update;

   --  The driver's reading: the TF lidar's last, the TOFSense's new one once.
   procedure Process (Now_Us : Interfaces.Unsigned_32; Cos_Tilt : Float) is
      Unused_Processed : Boolean;
      Distance         : Interfaces.Integer_32 := Core.No_New_Data;
   begin
      if not Adaflight.Build_Features.Rangefinder then
         return;
      end if;
      if not Found then
         return;
      end if;
      case Driver is
         when Adaflight.Rangefinder_Detect.TF =>
            Distance := Lidar.Read (State);
         when Adaflight.Rangefinder_Detect.Nooploop =>
            declare
               R : TOFSense.Reading;
            begin
               TOFSense.Read (TOF_State, R);
               Distance := R;
            end;
         when Adaflight.Rangefinder_Detect.HCSR04 | Adaflight.Rangefinder_Detect.MT
            | Adaflight.Rangefinder_Detect.UPT1 =>
            null;
      end case;
      Core.Process
        (Sensor, Now_Us, Adaflight.STM32.Time.Millis,
         Core.Reading (Interfaces.Integer_32'Min (Core.Reading'Last, Distance)),
         Float'Max (-1.0, Float'Min (1.0, Cos_Tilt)), Unused_Processed);
   end Process;

   function Altitude_Cm return Interfaces.Integer_32 is (Sensor.Calculated_Altitude);

   function Raw_Altitude_Cm return Interfaces.Integer_32 is (Sensor.Raw_Altitude);
end Adaflight.STM32.Rangefinder;
