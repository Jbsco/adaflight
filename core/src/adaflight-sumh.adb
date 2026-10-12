package body Adaflight.SUMH with SPARK_Mode is

   ----------
   -- Init --
   ----------

   procedure Init (S : out State) is
   begin
      S := (others => <>);
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
      Interval : constant Unsigned_32 := Now_Us - S.Time_Last_Us;
   begin
      S.Time_Last_Us := Now_Us;
      if Interval > Gap_Us then
         S.Position := 0;
      end if;
      S.Frame (S.Position) := C mod 256;
      if S.Position = Frame_Size - 1 then
         S.Done := True;
      else
         S.Position := S.Position + 1;
      end if;
   end Receive_Byte;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report) is
   begin
      Status := (others => False);
      if not S.Done then
         return;
      end if;
      S.Done := False;
      if not (S.Frame (0) = Sync_Byte and then S.Frame (Frame_Size - 2) = 0) then
         return;
      end if;
      for Ch in Channel loop
         declare
            Raw   : constant Float range 0.0 .. 65_535.0 :=
              Float (Unsigned_32 (S.Frame (2 * Ch + 3)) * 256 + Unsigned_32 (S.Frame (2 * Ch + 4)));
            Value : constant Float range -400.0 .. 11_000.0 := Raw / 6.4 - 375.0;
         begin
            S.Data (Ch) := (if Value <= 0.0 then 0 else Unsigned_32 (Float'Truncation (Value)));
         end;
      end loop;
      Status.Complete := True;
   end Frame_Status;

end Adaflight.SUMH;
