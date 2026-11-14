package body Adaflight.Virtual_FAT.Logs with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_64;

   subtype Integer_64 is Interfaces.Integer_64;
   --  A signed word as the flight log's numbers are read.
   subtype Signed_Word is Integer_64 range -2 ** 31 .. 2 ** 31 - 1;

   Product_Line : constant String := "H Product:Blackbox";
   Time_Line    : constant String := "H Log start datetime:";

   --  The time line's character at a count of matched ones, or the zero that
   --  ends it; past that nothing matches.
   function Time_Line_At (Matched : Natural) return Unsigned_8 is
     (if Matched < Time_Line'Length then Character'Pos (Time_Line (Time_Line'First + Matched))
      else 0);

   --  A number in the bytes of a read from a place: blanks, a sign and
   --  decimal digits, as a signed word that wraps past 32 bits, with the
   --  place after it. Without a digit the number is zero and the place
   --  stays. The read's end ends the number.
   type Parsed is record
      Value : Signed_Word := 0;
      Next  : Natural := 0;
   end record;

   function Number (Data : Flash_Read; Place : Natural) return Parsed
     with Post => Number'Result.Next <= Natural'Max (Place, Read_Size)
   is
      At_Byte : Natural := Place;
      Minus   : Boolean := False;
      Total   : Unsigned_32 := 0;
      Full    : Boolean := False;
      Found   : Boolean := False;
      Digit   : Unsigned_32;
   begin
      while At_Byte < Read_Size and then Data (At_Byte) in 9 .. 13 | 32 loop
         pragma Loop_Invariant (At_Byte >= Place);
         pragma Loop_Variant (Increases => At_Byte);
         At_Byte := At_Byte + 1;
      end loop;
      if At_Byte < Read_Size and then Data (At_Byte) in Character'Pos ('+') | Character'Pos ('-') then
         Minus := Data (At_Byte) = Character'Pos ('-');
         At_Byte := At_Byte + 1;
      end if;
      while At_Byte < Read_Size and then Data (At_Byte) in Character'Pos ('0') .. Character'Pos ('9') loop
         pragma Loop_Variant (Increases => At_Byte);
         Digit := Unsigned_32 (Data (At_Byte)) - Character'Pos ('0');
         if Full or else Total > 429_496_729 or else (Total = 429_496_729 and then Digit > 5) then
            Full := True;
            Total := Unsigned_32'Last;
         else
            Total := Total * 10 + Digit;
         end if;
         Found := True;
         At_Byte := At_Byte + 1;
      end loop;
      if not Found then
         return (Value => 0, Next => Place);
      end if;
      if Minus and then not Full then
         Total := 0 - Total;
      end if;
      return (Value => (if Total >= 2 ** 31 then Integer_64 (Total) - 2 ** 32 else Integer_64 (Total)),
              Next  => At_Byte);
   end Number;

   --  A date and time packed as a FAT entry has them, from signed words as
   --  they come, in two's complement.
   function Packed (Day, Month, Year, Hour, Minute, Second : Signed_Word) return Unsigned_32 is
      function Word (X : Integer_64) return Unsigned_32 is (Unsigned_32 (X mod 2 ** 32))
        with Pre => X in -2 ** 32 .. 2 ** 32 - 1;
      Half : constant Integer_64 := (if Second >= 0 then Second / 2 else -((1 - Second) / 2));
   begin
      return Interfaces.Shift_Left
          (Interfaces.Shift_Left (Word (Year - 1_980), 9) or Interfaces.Shift_Left (Word (Month), 5) or Word (Day), 16)
        or (Interfaces.Shift_Left (Word (Hour), 11) or Interfaces.Shift_Left (Word (Minute), 5) or Word (Half));
   end Packed;

   procedure Build
     (V : in out Volume; Predefined : Entry_Count; Used : Unsigned_32; Prefix : Prefix_Text; Mounted : Unsigned_32;
      OK : out Boolean)
   is
      Space    : constant Natural := Natural (Used);
      Buffer   : Flash_Read;
      Current  : Natural := 0;
      Previous : Natural := 0;
      Files    : Natural := 0;
      Matched  : Natural := 0;
      Slot     : Entry_Index := Predefined + 1;

      function Starts_Log return Boolean is
        (for all I in 0 .. Product_Line'Length - 1 =>
           Buffer (I) = Character'Pos (Product_Line (Product_Line'First + I)));

      --  A log's file at a slot: its number from 001 in its name, its place
      --  and size in the flash, and the times its first one gives.
      procedure Add_Log (Number_From_0 : Natural; Offset : Natural; Size : Natural)
        with Pre => Number_From_0 < Max_Logs and then Slot <= Max_Entries
      is
         N    : constant Positive := Number_From_0 + 1;
         Name : constant String :=
           Prefix & '_' & Character'Val (Character'Pos ('0') + N / 100)
           & Character'Val (Character'Pos ('0') + (N / 10) mod 10) & Character'Val (Character'Pos ('0') + N mod 10)
           & ".BBL";
      begin
         V.Entries (Slot).Name := (others => ' ');
         V.Entries (Slot).Name (1 .. Name'Length) := Name;
         V.Entries (Slot).Length := Name'Length;
         V.Entries (Slot).Level := 1;
         V.Entries (Slot).Offset := Unsigned_32 (Offset);
         V.Entries (Slot).Current_Size := Unsigned_32 (Size);
         V.Entries (Slot).Maximum_Size := Unsigned_32 (Size);
         V.Entries (Slot).Readable := True;
         V.Entries (Slot).CMA (1) := V.Entries (Slot).CMA (0);
         V.Entries (Slot).CMA (2) := V.Entries (Slot).CMA (0);
      end Add_Log;

      --  The start time line looked for after the product line in a log's
      --  first read, through later reads, up to the used space's end; the
      --  slot's first time from the line when its year is not zero.
      procedure Find_Time (Log_Start : Natural; First_Read : Flash_Read)
        with Pre => Log_Start < Space and then Space <= Max_Used and then Slot <= Max_Entries
      is
         Header : Natural := Log_Start;
         Place  : Natural := Product_Line'Length;
         Line   : Flash_Read := First_Read;
         P      : Parsed;
         Year, Month, Day, Hour, Minute : Signed_Word;
      begin
         loop
            pragma Loop_Invariant (Place < Read_Size and then Header <= Space);
            pragma Loop_Variant (Increases => Header, Increases => Place);
            if Matched <= Time_Line'Length and then Line (Place) = Time_Line_At (Matched) then
               Place := Place + 1;
               Matched := Matched + 1;
               if Matched = Time_Line'Length then
                  Read (Unsigned_32 (Header + Place), Line);
                  P := Number (Line, 0);
                  Year := P.Value;
                  P := Number (Line, P.Next + 1);
                  Month := P.Value;
                  P := Number (Line, P.Next + 1);
                  Day := P.Value;
                  P := Number (Line, P.Next + 1);
                  Hour := P.Value;
                  P := Number (Line, P.Next + 1);
                  Minute := P.Value;
                  P := Number (Line, P.Next + 1);
                  if Year /= 0 then
                     V.Entries (Slot).CMA (0) := Packed (Day, Month, Year, Hour, Minute, P.Value);
                  end if;
                  exit;
               end if;
            else
               Place := Place + 1;
               Matched := 0;
            end if;
            if Place = Read_Size then
               Header := Header + Read_Size;
               exit when Header > Space;
               Read (Unsigned_32 (Header), Line);
               Place := 0;
            end if;
         end loop;
      end Find_Time;
   begin
      for I in 1 .. Predefined loop
         V.Entries (I).CMA := (others => Mounted);
      end loop;
      for I in Predefined + 1 .. Max_Entries loop
         V.Entries (I) := (others => <>);
      end loop;
      while Current < Space loop
         pragma Loop_Invariant
           (Files < Max_Logs and then Slot = Predefined + 1 + Files and then Current mod Block_Size = 0
            and then Previous <= Current);
         pragma Loop_Variant (Increases => Current);
         Read (Unsigned_32 (Current), Buffer);
         if Starts_Log then
            if Previous /= Current then
               Add_Log (Files, Previous, Current - Previous);
               Slot := Slot + 1;
               Files := Files + 1;
            end if;
            V.Entries (Slot).CMA (0) := Mounted;
            Find_Time (Current, Buffer);
            exit when Files = Max_Logs;
            Previous := Current;
         end if;
         Current := Current + Block_Size;
      end loop;
      pragma Assert (Files <= Max_Logs and then Slot = Predefined + 1 + Files);
      if Files /= Max_Logs and then Previous /= Current then
         Add_Log (Files, Previous, Current - Previous);
         Files := Files + 1;
      end if;
      V.Count := Predefined + Files;
      if Files > 0 then
         declare
            Name : constant String := Prefix & "_ALL.BBL";
            E    : File_Entry;
         begin
            E.Name (1 .. Name'Length) := Name;
            E.Length := Name'Length;
            E.Level := 1;
            E.Current_Size := Used;
            E.Maximum_Size := Used;
            E.CMA := (others => Mounted);
            E.Readable := True;
            V.Count := V.Count + 1;
            V.Entries (V.Count) := E;
         end;
      end if;
      if 2 * Space < Padded_Size then
         declare
            Name : constant String := "PADDING.TXT";
            E    : File_Entry;
         begin
            E.Name (1 .. Name'Length) := Name;
            E.Length := Name'Length;
            E.Attr := Hidden;
            E.Level := 1;
            E.Current_Size := Unsigned_32 (Padded_Size - 2 * Space);
            E.Maximum_Size := E.Current_Size;
            E.CMA := (others => Mounted);
            V.Count := V.Count + 1;
            V.Entries (V.Count) := E;
         end;
      end if;
      Start (V, OK);
   end Build;

end Adaflight.Virtual_FAT.Logs;
