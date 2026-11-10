with Ada.Streams;
with Ada.Strings.Fixed;
with GNAT.Serial_Communications;
with GNAT.Sockets;

package body MSP.Transport with SPARK_Mode => Off is

   package Serial renames GNAT.Serial_Communications;
   package Sockets renames GNAT.Sockets;

   use type Ada.Streams.Stream_Element_Offset;

   --  A read returns after this wait when no byte arrives.
   Wait : constant Duration := 0.05;

   type Link_Kind is (Closed, Over_TCP, Over_Serial);

   Kind   : Link_Kind := Closed;
   Socket : Sockets.Socket_Type := Sockets.No_Socket;
   Port   : Serial.Serial_Port;

   procedure Open_TCP (Host : String; Number : Natural; Ok : out Boolean) is
      Address : Sockets.Sock_Addr_Type;
   begin
      Address.Addr := Sockets.Addresses (Sockets.Get_Host_By_Name (Host), 1);
      Address.Port := Sockets.Port_Type (Number);
      Sockets.Create_Socket (Socket);
      Sockets.Connect_Socket (Socket, Address);
      Sockets.Set_Socket_Option (Socket, Sockets.Socket_Level, (Sockets.Receive_Timeout, Timeout => Wait));
      Sockets.Set_Socket_Option (Socket, Sockets.IP_Protocol_For_TCP_Level, (Sockets.No_Delay, True));
      Kind := Over_TCP;
      Ok := True;
   exception
      when others =>
         Ok := False;
   end Open_TCP;

   procedure Open_Serial (Path : String; Ok : out Boolean) is
   begin
      Serial.Open (Port, Serial.Port_Name (Path));
      Serial.Set (Port, Rate => Serial.B115200, Block => False, Timeout => Wait);
      Kind := Over_Serial;
      Ok := True;
   exception
      when others =>
         Ok := False;
   end Open_Serial;

   procedure Open (Target : String; Ok : out Boolean) is
      Prefix : constant String := "tcp:";
   begin
      Close;
      if Target'Length > Prefix'Length and then Target (Target'First .. Target'First + Prefix'Length - 1) = Prefix
      then
         declare
            Rest  : constant String := Target (Target'First + Prefix'Length .. Target'Last);
            Colon : constant Natural := Ada.Strings.Fixed.Index (Rest, ":", Ada.Strings.Backward);
         begin
            if Colon <= Rest'First or else Colon = Rest'Last then
               Ok := False;
            else
               Open_TCP (Rest (Rest'First .. Colon - 1), Natural'Value (Rest (Colon + 1 .. Rest'Last)), Ok);
            end if;
         exception
            when Constraint_Error =>
               Ok := False;
         end;
      else
         Open_Serial (Target, Ok);
      end if;
   end Open;

   procedure Close is
   begin
      case Kind is
         when Over_TCP =>
            Sockets.Close_Socket (Socket);
         when Over_Serial =>
            Serial.Close (Port);
         when Closed =>
            null;
      end case;
      Kind := Closed;
   exception
      when others =>
         Kind := Closed;
   end Close;

   procedure Send (Data : Byte_Array; Ok : out Boolean) is
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Data'Length);
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      for I in Data'Range loop
         Buffer (Ada.Streams.Stream_Element_Offset (I - Data'First + 1)) := Ada.Streams.Stream_Element (Data (I));
      end loop;
      case Kind is
         when Over_TCP =>
            Sockets.Send_Socket (Socket, Buffer, Last);
            Ok := Last = Buffer'Last;
         when Over_Serial =>
            Serial.Write (Port, Buffer);
            Ok := True;
         when Closed =>
            Ok := False;
      end case;
   exception
      when others =>
         Ok := False;
   end Send;

   procedure Receive (Data : out Byte_Array; Got : out Natural) is
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Data'Length);
      Last   : Ada.Streams.Stream_Element_Offset := 0;
   begin
      Data := (others => 0);
      Got := 0;
      if Data'Length = 0 then
         return;
      end if;
      case Kind is
         when Over_TCP =>
            Sockets.Receive_Socket (Socket, Buffer, Last);
         when Over_Serial =>
            Serial.Read (Port, Buffer, Last);
         when Closed =>
            return;
      end case;
      for I in 1 .. Last loop
         Data (Data'First + Natural (I) - 1) := Byte (Buffer (I));
      end loop;
      Got := Natural (Last);
   exception
      when others =>
         Got := 0;
   end Receive;

end MSP.Transport;
