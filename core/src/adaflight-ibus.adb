with Adaflight.Clock;

package body Adaflight.IBUS with SPARK_Mode is
   use type Interfaces.Integer_32;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State) is
   begin
      S := (others => <>);
   end Init;

   --  A frame start: the family, its sync byte, length, slot offset, and
   --  checksum seed, with the sync byte as the frame's first byte.
   procedure Start_Frame (S : in out State; Kind : Model; Sync : Byte; Size : Byte; Offset : Byte; Seed : Unsigned_16)
     with Pre => (case Kind is
                    when IA6  => Sync = IA6_Sync_Byte and then Size = IA6_Frame_Size and then Offset = 1,
                    when IA6B => Sync = Size and then Size in Telemetry_Packet_Length | Channel_Packet_Length
                                 and then Offset = 2),
          Post => S.Kind = Kind and then S.Sync_Byte = Sync and then S.Frame_Size = Size
                  and then S.Position = S.Position'Old and then S.Done = S.Done'Old
   is
      F : Frame_Bytes := S.Frame;
   begin
      F (0) := Sync;
      S := (Kind               => Kind,
            Sync_Byte          => Sync,
            Frame_Size         => Size,
            Channel_Offset     => Offset,
            Bytes_To_Ignore    => S.Bytes_To_Ignore,
            Checksum           => Seed,
            Done               => S.Done,
            Data               => S.Data,
            Frame              => F,
            Position           => S.Position,
            Time_Last_Us       => S.Time_Last_Us,
            Completed_At_Us    => S.Completed_At_Us,
            Last_Frame_Time_Us => S.Last_Frame_Time_Us);
   end Start_Frame;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
      Low : constant Byte := C mod 256;
   begin
      if Clock.Elapsed (Now_Us, S.Time_Last_Us) > Frame_Gap_Us then
         S.Position := 0;
         S.Bytes_To_Ignore := 0;
      elsif S.Bytes_To_Ignore > 0 then
         S.Bytes_To_Ignore := S.Bytes_To_Ignore - 1;
         return;
      end if;
      S.Time_Last_Us := Now_Us;
      if S.Position = 0 then
         if Low = Telemetry_Packet_Length or else Low = Channel_Packet_Length then
            Start_Frame (S, IA6B, Sync => Low, Size => Low, Offset => 2, Seed => 16#FFFF#);
         elsif S.Sync_Byte = 0 and then C = IA6_Sync_Byte then
            Start_Frame (S, IA6, Sync => IA6_Sync_Byte, Size => IA6_Frame_Size, Offset => 1, Seed => 0);
         elsif S.Sync_Byte /= C then
            return;
         end if;
      end if;
      if S.Position < Buffer_Size then
         S.Frame (S.Position) := Low;
      end if;
      if S.Position + 1 = S.Frame_Size then
         S.Completed_At_Us := Now_Us;
         S.Done := True;
      else
         S.Position := (S.Position + 1) mod 256;
      end if;
   end Receive_Byte;

   --  The IA6 checksum: the slots summed onto the frame's start value against
   --  the two bytes after them, low byte first.
   function IA6_Checksum_OK (S : State) return Boolean
     with Pre => S.Kind = IA6
   is
      Sum      : Unsigned_16 := S.Checksum;
      Received : constant Unsigned_16 :=
        Unsigned_16 (S.Frame (S.Frame_Size - 2)) + Unsigned_16 (S.Frame (S.Frame_Size - 1)) * 2 ** 8;
   begin
      for I in Slot loop
         Sum := Sum + Unsigned_16 (S.Frame (S.Channel_Offset + 2 * I))
           + Unsigned_16 (S.Frame (S.Channel_Offset + 2 * I + 1)) * 2 ** 8;
      end loop;
      return Sum = Received;
   end IA6_Checksum_OK;

   --  The IA6B checksum: the bytes before the two checksum bytes taken from
   --  all ones against those two bytes, low byte first. The count of bytes
   --  comes from the first byte, the frame's length, which a complete frame
   --  has at four or more, so the reference's byte wrap below two is not
   --  reached.
   function IA6B_Checksum_OK (S : State) return Boolean
     with Pre => S.Kind = IA6B and then S.Frame_Size >= Telemetry_Packet_Length
   is
      Data_Size : constant Natural range 0 .. Buffer_Size - 2 := S.Frame (0) - 2;
      Sum       : Unsigned_16 := 16#FFFF#;
   begin
      for I in 0 .. Data_Size - 1 loop
         Sum := Sum - Unsigned_16 (S.Frame (I));
      end loop;
      return Natural (Sum / 2 ** 8) = S.Frame (S.Frame_Size - 1)
        and then Natural (Sum and 16#FF#) = S.Frame (S.Frame_Size - 2);
   end IA6B_Checksum_OK;

   function Checksum_OK (S : State) return Boolean is
     (case S.Kind is
         when IA6  => IA6_Checksum_OK (S),
         when IA6B => IA6B_Checksum_OK (S))
     with Pre => S.Frame_Size >= Telemetry_Packet_Length;

   --  A slot's twelve bits: its first byte and the low four bits of its
   --  second.
   function Slot_Value (F : Frame_Bytes; Off : Buffer_Index) return Channel_Value
     with Pre => Off <= Buffer_Size - 2
   is
      Low  : constant Natural range 0 .. 255 := F (Off);
      High : constant Natural range 0 .. 15 := F (Off + 1) mod 16;
   begin
      return Low + High * 2 ** 8;
   end Slot_Value;

   --  A channel past the slots: the high four bits of three second bytes,
   --  two slots apart.
   function High_Bits_Value (F : Frame_Bytes; Off : Buffer_Index) return Channel_Value
     with Pre => Off <= Buffer_Size - 5
   is
      Word : constant Unsigned_16 :=
        Interfaces.Shift_Right (Unsigned_16 (F (Off)) and 16#F0#, 4)
        or (Unsigned_16 (F (Off + 2)) and 16#F0#)
        or Interfaces.Shift_Left (Unsigned_16 (F (Off + 4)) and 16#F0#, 4);
   begin
      return Channel_Value (Word);
   end High_Bits_Value;

   --  The fourteen slots, then the four channels packed into the spare high
   --  bits, six bytes apart from the second byte of the first slot.
   procedure Decode_Channels (S : in out State)
     with Pre => S.Kind = IA6 or else S.Frame_Size = Channel_Packet_Length
   is
      Offset : constant Natural range 1 .. 2 := S.Channel_Offset;
      Data   : Channel_Data := S.Data;
   begin
      for I in Slot loop
         Data (I) := Slot_Value (S.Frame, Offset + 2 * I);
      end loop;
      for J in 0 .. Channel_Count - Slot_Count - 1 loop
         Data (Slot_Count + J) := High_Bits_Value (S.Frame, Offset + 1 + 6 * J);
      end loop;
      S.Data := Data;
   end Decode_Channels;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report; Telemetry_Request : out Boolean) is
   begin
      Status := (others => False);
      Telemetry_Request := False;
      if not S.Done then
         return;
      end if;
      S.Done := False;
      if Checksum_OK (S) then
         if S.Kind = IA6 or else S.Sync_Byte = Channel_Packet_Length then
            Decode_Channels (S);
            Status.Complete := True;
            S.Last_Frame_Time_Us := S.Completed_At_Us;
         else
            Telemetry_Request := True;
         end if;
      end if;
   end Frame_Status;

   -----------------
   -- Ignore_Echo --
   -----------------

   procedure Ignore_Echo (S : in out State; Count : Byte) is
   begin
      S.Bytes_To_Ignore := Count;
   end Ignore_Echo;

end Adaflight.IBUS;
