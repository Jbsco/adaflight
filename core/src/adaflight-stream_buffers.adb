package body Adaflight.Stream_Buffers with SPARK_Mode is

   ----------
   -- Init --
   ----------

   procedure Init (S : out Stream; First : Position; Last : Position) is
   begin
      S := (Next => First, Last => Last);
   end Init;

   --------------
   -- Write_U8 --
   --------------

   procedure Write_U8 (B : in out Byte_Array; S : in out Stream; V : Byte) is
   begin
      B (S.Next) := V;
      S.Next := S.Next + 1;
   end Write_U8;

   ---------------
   -- Write_U16 --
   ---------------

   procedure Write_U16 (B : in out Byte_Array; S : in out Stream; V : Unsigned_16) is
   begin
      Write_U8 (B, S, Byte (V and 16#FF#));
      Write_U8 (B, S, Byte (Interfaces.Shift_Right (V, 8)));
   end Write_U16;

   ---------------
   -- Write_U32 --
   ---------------

   procedure Write_U32 (B : in out Byte_Array; S : in out Stream; V : Unsigned_32) is
   begin
      Write_U8 (B, S, Byte (V and 16#FF#));
      Write_U8 (B, S, Byte (Interfaces.Shift_Right (V, 8) and 16#FF#));
      Write_U8 (B, S, Byte (Interfaces.Shift_Right (V, 16) and 16#FF#));
      Write_U8 (B, S, Byte (Interfaces.Shift_Right (V, 24)));
   end Write_U32;

   --------------------------
   -- Write_U16_Big_Endian --
   --------------------------

   procedure Write_U16_Big_Endian (B : in out Byte_Array; S : in out Stream; V : Unsigned_16) is
   begin
      Write_U8 (B, S, Byte (Interfaces.Shift_Right (V, 8)));
      Write_U8 (B, S, Byte (V and 16#FF#));
   end Write_U16_Big_Endian;

   --------------------------
   -- Write_U32_Big_Endian --
   --------------------------

   procedure Write_U32_Big_Endian (B : in out Byte_Array; S : in out Stream; V : Unsigned_32) is
   begin
      Write_U8 (B, S, Byte (Interfaces.Shift_Right (V, 24)));
      Write_U8 (B, S, Byte (Interfaces.Shift_Right (V, 16) and 16#FF#));
      Write_U8 (B, S, Byte (Interfaces.Shift_Right (V, 8) and 16#FF#));
      Write_U8 (B, S, Byte (V and 16#FF#));
   end Write_U32_Big_Endian;

   ----------
   -- Fill --
   ----------

   procedure Fill (B : in out Byte_Array; S : in out Stream; Value : Byte; Count : Natural) is
   begin
      for I in 1 .. Count loop
         pragma Loop_Invariant (S.Next = S.Next'Loop_Entry + (I - 1)
                                and then S.Last = S.Last'Loop_Entry);
         Write_U8 (B, S, Value);
      end loop;
   end Fill;

   ----------------
   -- Write_Data --
   ----------------

   procedure Write_Data (B : in out Byte_Array; S : in out Stream; Data : Byte_Array) is
   begin
      for I in Data'Range loop
         pragma Loop_Invariant (S.Next = S.Next'Loop_Entry + (I - Data'First)
                                and then S.Last = S.Last'Loop_Entry);
         Write_U8 (B, S, Data (I));
      end loop;
   end Write_Data;

   ------------------
   -- Write_String --
   ------------------

   procedure Write_String (B : in out Byte_Array; S : in out Stream; Text : String) is
   begin
      for I in Text'Range loop
         pragma Loop_Invariant (S.Next = S.Next'Loop_Entry + (I - Text'First)
                                and then S.Last = S.Last'Loop_Entry);
         Write_U8 (B, S, Character'Pos (Text (I)));
      end loop;
   end Write_String;

   ---------------------------
   -- Write_Prefixed_String --
   ---------------------------

   procedure Write_Prefixed_String (B : in out Byte_Array; S : in out Stream; Text : String) is
      Length : constant Natural := Natural'Min (Text'Length, 255);
   begin
      Write_U8 (B, S, Byte (Length));
      pragma Assert (Length <= 255);
      Write_String (B, S, Text (Text'First .. Text'First - 1 + Length));
   end Write_Prefixed_String;

   ----------------------------------
   -- Write_String_With_Terminator --
   ----------------------------------

   procedure Write_String_With_Terminator (B : in out Byte_Array; S : in out Stream; Text : String) is
   begin
      pragma Assert (Text'Length <= Max_Buffer);
      Write_String (B, S, Text);
      Write_U8 (B, S, 0);
   end Write_String_With_Terminator;

   -------------
   -- Read_U8 --
   -------------

   procedure Read_U8 (B : Byte_Array; S : in out Stream; V : out Byte) is
   begin
      if S.Next < S.Last then
         V := B (S.Next);
         S.Next := S.Next + 1;
      else
         V := 0;
      end if;
   end Read_U8;

   --------------
   -- Read_U16 --
   --------------

   procedure Read_U16 (B : Byte_Array; S : in out Stream; V : out Unsigned_16) is
      Low, High : Byte;
   begin
      Read_U8 (B, S, Low);
      Read_U8 (B, S, High);
      V := Unsigned_16 (Low) or Interfaces.Shift_Left (Unsigned_16 (High), 8);
   end Read_U16;

   --------------
   -- Read_U32 --
   --------------

   procedure Read_U32 (B : Byte_Array; S : in out Stream; V : out Unsigned_32) is
      B0, B1, B2, B3 : Byte;
   begin
      Read_U8 (B, S, B0);
      Read_U8 (B, S, B1);
      Read_U8 (B, S, B2);
      Read_U8 (B, S, B3);
      V := Unsigned_32 (B0) or Interfaces.Shift_Left (Unsigned_32 (B1), 8)
        or Interfaces.Shift_Left (Unsigned_32 (B2), 16) or Interfaces.Shift_Left (Unsigned_32 (B3), 24);
   end Read_U32;

   ---------------
   -- Read_Data --
   ---------------

   procedure Read_Data (B : Byte_Array; S : in out Stream; Data : out Byte_Array) is
   begin
      for I in Data'Range loop
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry
                                and then S.Next >= S.Next'Loop_Entry
                                and then S.Next <= S.Next'Loop_Entry + (I - Data'First));
         Read_U8 (B, S, Data (I));
      end loop;
   end Read_Data;

   -------------
   -- Advance --
   -------------

   procedure Advance (S : in out Stream; Count : Natural) is
   begin
      if Count > S.Last - S.Next then
         S.Next := S.Last;
      else
         S.Next := S.Next + Count;
      end if;
   end Advance;

   ----------------------
   -- Switch_To_Reader --
   ----------------------

   procedure Switch_To_Reader (S : in out Stream; Base : Position) is
   begin
      S := (Next => Base, Last => S.Next);
   end Switch_To_Reader;

   ------------------------
   -- Append_CRC16_CCITT --
   ------------------------

   procedure Append_CRC16_CCITT (B : in out Byte_Array; S : in out Stream; Start : Natural) is
      CRC : constant Unsigned_16 := CRC16_CCITT_Update (0, B (Start .. S.Next - 1));
   begin
      Write_U16 (B, S, CRC);
   end Append_CRC16_CCITT;

   -----------------
   -- Append_CRC8 --
   -----------------

   procedure Append_CRC8 (B : in out Byte_Array; S : in out Stream; Start : Natural; Poly : Byte) is
      CRC : constant Byte := CRC8_Update (0, B (Start .. S.Next - 1), Poly);
   begin
      Write_U8 (B, S, CRC);
   end Append_CRC8;

   ----------------
   -- Append_Xor --
   ----------------

   procedure Append_Xor (B : in out Byte_Array; S : in out Stream; Start : Natural) is
      CRC : constant Byte := CRC8_Xor_Update (0, B (Start .. S.Next - 1));
   begin
      Write_U8 (B, S, CRC);
   end Append_Xor;

end Adaflight.Stream_Buffers;
