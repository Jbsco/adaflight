package body Adaflight.ESC_Serial with SPARK_Mode is

   procedure Add
     (L : in out Op_List; Kind : Op_Kind; Who : Target := Nothing; A : Unsigned_32 := 0; B : Unsigned_32 := 0)
     with Pre => L.Count < L.Room, Post => L.Count = L.Count'Old + 1
   is
   begin
      L.Count := L.Count + 1;
      L.Items (L.Count) := (Kind => Kind, Who => Who, A => A, B => B);
   end Add;

   --  A pin claimed and set to a mode.
   procedure Pin (L : in out Op_List; Who : Target; Mode : Unsigned_32)
     with Pre => L.Count <= L.Room - 2, Post => L.Count = L.Count'Old + 2
   is
   begin
      Add (L, Claim, Who);
      Add (L, Pin_Mode, Who, Mode);
   end Pin;

   --  The pin on its timer for the capture, with the capture's interrupt.
   procedure Input_Config (L : in out Op_List; Who : Target)
     with Pre => L.Count <= L.Room - 4, Post => L.Count = L.Count'Old + 4
   is
   begin
      Pin (L, Who, Mode_Capture);
      Add (L, Clear_Flag, Who);
      Add (L, Interrupt, Who, 1);
   end Input_Config;

   --  The pin as an output, without the capture's interrupt.
   procedure Output_Config (L : in out Op_List; Who : Target)
     with Pre => L.Count <= L.Room - 3, Post => L.Count = L.Count'Old + 3
   is
   begin
      Pin (L, Who, Mode_Output);
      Add (L, Interrupt, Who, 0);
   end Output_Config;

   --  A level on the line: on every output's pin for KISS on all motors,
   --  on the motor's pin otherwise, each turned over for an inverted output.
   function Signal_Ops (P : Port) return Natural is (if P.Mode = KISS_All then P.Output_Count else 1);

   procedure Tx_Signal (L : in out Op_List; P : Port; High : Boolean)
     with Pre => L.Count <= L.Room - Signal_Ops (P), Post => L.Count = L.Count'Old + Signal_Ops (P)
   is
   begin
      if P.Mode = KISS_All then
         for I in 0 .. P.Output_Count - 1 loop
            pragma Loop_Invariant (L.Count = L.Count'Loop_Entry + I);
            Add (L, (if High /= P.Outputs (I).Inverted then Pin_High else Pin_Low), P.Outputs (I).Motor);
         end loop;
      else
         Add (L, (if High /= P.Rx_Inverted then Pin_High else Pin_Low), P.Rx_Timer);
      end if;
   end Tx_Signal;

   --  The bit timer at a period and a rate, with its handler.
   procedure Tx_Config (L : in out Op_List; Who : Target; Period, Rate : Unsigned_32)
     with Pre => L.Count <= L.Room - 4, Post => L.Count = L.Count'Old + 4
   is
   begin
      Add (L, Reset, Who);
      Add (L, Time_Base, Who, Period, Rate);
      Add (L, Tick_Handler, Who, 1);
      Add (L, Start, Who);
   end Tx_Config;

   --  The capture set to a falling edge with its handler, its timer over
   --  its whole range at a rate unless the timer keeps the bit ticks' time
   --  base.
   procedure Rx_Config (L : in out Op_List; Who : Target; Rate : Unsigned_32; Keep_Base : Boolean)
     with Pre => L.Count <= L.Room - 5, Post => L.Count in L.Count'Old .. L.Count'Old + 5
   is
   begin
      if not Keep_Base then
         Add (L, Reset, Who);
         Add (L, Time_Base, Who, 16#FFFF#, Rate);
      end if;
      Add (L, Polarity, Who, 0);
      Add (L, Edge_Handler, Who, 1);
      Add (L, Start, Who);
   end Rx_Config;

   --  A bit's period at half the core clock, the clock halved until the
   --  period fits sixteen bits.
   procedure Bit_Base (Core_Clock, Baud : Unsigned_32; Period, Clock : out Unsigned_32)
     with Pre => Baud > 0, Post => Period <= 16#FFFF#
   is
   begin
      Clock := Core_Clock / 2;
      Period := Clock / Baud;
      while Period > 16#FFFF# and then Clock > 1 loop
         pragma Loop_Variant (Decreases => Clock);
         pragma Loop_Invariant (Period = Clock / Baud);
         Clock := Clock / 2;
         Period := Clock / Baud;
      end loop;
   end Bit_Base;

   function Next (I : Buffer_Index) return Buffer_Index is (if I = Buffer_Index'Last then 0 else I + 1);

   procedure Store (P : in out Port; B : Unsigned_8) is
   begin
      P.Rx_Buffer (P.Rx_Head) := B;
      P.Rx_Head := Next (P.Rx_Head);
   end Store;

   procedure Open_Into
     (P : out Port; Mode : Protocol; Output : Motor_Index; Baud : Unsigned_32; B : Board; Ops : in out Op_List;
      Opened : out Boolean)
     with Pre  => Baud > 0 and then Ops.Count <= 1 and then Ops.Room >= Ops.Count + Open_Ops,
          Post => Ops.Count <= Ops.Count'Old + Open_Ops
   is
      M             : constant Motor_Facts := B.Motors (Output);
      One_Timer     : constant Boolean := not B.Send_Set or else B.Send_Same_Timer;
      Period, Clock : Unsigned_32;
   begin
      P := (others => <>);
      Opened := False;
      Bit_Base (B.Core_Clock, Baud, Period, Clock);
      if Mode /= KISS_All then
         if not M.Assigned then
            Add (Ops, Allocate, Nothing);
            return;
         end if;
         Add (Ops, Allocate, Output);
         if not M.Timer or else M.Complementary then
            return;
         end if;
         Add (Ops, Configure, Output, 16#FFFF#, 1);
         if B.Send_Set then
            Add (Ops, Allocate, Send_Pin);
            if not B.Send_Timer then
               return;
            end if;
            Add (Ops, Configure, Send_Pin, 16#FFFF#, 1);
            P.Tx_Timer := Send_Pin;
         else
            P.Tx_Timer := Output;
         end if;
         if Mode = SimonK and then One_Timer then
            return;
         end if;
         P.Rx_Timer := Output;
         P.Rx_Inverted := M.Inverted;
      end if;
      P.Mode := Mode;
      P.Searching := True;
      if Mode /= KISS_All then
         Input_Config (Ops, P.Rx_Timer);
         Tx_Signal (Ops, P, True);
      end if;
      Add (Ops, Wait, Nothing, 50);
      case Mode is
         when SimonK =>
            Tx_Config (Ops, P.Tx_Timer, 34, 1_000_000);
            Rx_Config (Ops, P.Rx_Timer, 1_000_000, Keep_Base => False);
         when BLHeli =>
            Tx_Config (Ops, P.Tx_Timer, Period, Clock);
            Rx_Config (Ops, P.Rx_Timer, B.Core_Clock / 2, Keep_Base => One_Timer);
            P.Tx_Period := Period;
         when KISS =>
            Output_Config (Ops, P.Rx_Timer);
            Tx_Config (Ops, P.Tx_Timer, Period, Clock);
            P.Tx_Period := Period;
         when KISS_All =>
            for I in Motor_Index loop
               pragma Loop_Invariant (Ops.Count <= Ops.Count'Loop_Entry + 5 * I);
               pragma Loop_Invariant (P.Output_Count <= I);
               if B.Motors (I).Enabled and then B.Motors (I).Has_Pin and then B.Motors (I).Assigned then
                  Add (Ops, Allocate, I);
                  if B.Motors (I).Timer then
                     Add (Ops, Configure, I, 16#FFFF#, 1);
                     Output_Config (Ops, I);
                     P.Outputs (P.Output_Count) := (Motor => I, Inverted => B.Motors (I).Inverted);
                     P.Tx_Timer := I;
                     P.Output_Count := P.Output_Count + 1;
                  end if;
               end if;
            end loop;
            if P.Output_Count = 0 then
               return;
            end if;
            Tx_Signal (Ops, P, True);
            Tx_Config (Ops, P.Tx_Timer, Period, Clock);
            P.Tx_Period := Period;
         when Castle =>
            Output_Config (Ops, P.Rx_Timer);
            Tx_Config (Ops, P.Tx_Timer, Period, Clock);
            Rx_Config (Ops, P.Rx_Timer, B.Core_Clock / 2, Keep_Base => One_Timer);
            P.Tx_Period := Period;
      end case;
      Opened := True;
   end Open_Into;

   procedure Open
     (P : out Port; Mode : Protocol; Output : Motor_Index; Baud : Unsigned_32; B : Board; Ops : in out Op_List;
      Opened : out Boolean) is
   begin
      Ops.Count := 0;
      Open_Into (P, Mode, Output, Baud, B, Ops, Opened);
   end Open;

   --  A run of high bits ended at an edge or at the frame's end: the bits
   --  from the last leading edge up to the current one are ones.
   procedure Apply_Changed (P : in out Port; Up_To : Bit_Count) is
   begin
      if P.Rx_Edge = Trailing then
         for Bit in P.Rx_Last_Leading .. Up_To - 1 loop
            P.Internal_Rx := P.Internal_Rx or Interfaces.Shift_Left (1, Bit);
         end loop;
      end if;
   end Apply_Changed;

   procedure Tx_BL (P : in out Port; Ops : in out Op_List)
     with Pre => Ops.Count = 0 and then Ops.Room >= Tick_Ops, Post => Ops.Count <= Max_Motors
   is
      Byte : Unsigned_8;
   begin
      if P.Receiving then
         return;
      end if;
      if not P.Transmitting then
         if Tx_Empty (P) then
            return;
         end if;
         Byte := P.Tx_Buffer (P.Tx_Tail);
         P.Tx_Tail := Next (P.Tx_Tail);
         P.Internal_Tx := 16#200# or Interfaces.Shift_Left (Unsigned_16 (Byte), 1);
         P.Bits_Left := 10;
         P.Transmitting := True;
         if P.Mode in BLHeli | Castle then
            Output_Config (Ops, P.Rx_Timer);
         end if;
         return;
      end if;
      if P.Bits_Left > 0 then
         Tx_Signal (Ops, P, (P.Internal_Tx and 1) = 1);
         P.Internal_Tx := Interfaces.Shift_Right (P.Internal_Tx, 1);
         P.Bits_Left := P.Bits_Left - 1;
         return;
      end if;
      P.Transmitting := False;
      if Tx_Empty (P) and then P.Mode in BLHeli | Castle then
         Input_Config (Ops, P.Rx_Timer);
      end if;
   end Tx_BL;

   procedure Rx_BL (P : in out Port; Ops : in out Op_List)
     with Pre => Ops.Count <= Max_Motors and then Ops.Room >= Tick_Ops, Post => Ops.Count <= Max_Motors + 1
   is
   begin
      if P.Searching then
         return;
      end if;
      if P.Rx_Bit < 8 then
         P.Rx_Bit := P.Rx_Bit + 1;
      elsif P.Rx_Bit = 8 then
         P.Rx_Bit := 9;
         Apply_Changed (P, 9);
      else
         if P.Rx_Edge = Trailing then
            P.Internal_Rx := P.Internal_Rx or 1;
         end if;
         if (P.Internal_Rx and 16#200#) /= 0 or else (P.Internal_Rx and 1) /= 1 then
            P.Receive_Errors := P.Receive_Errors + 1;
         else
            Store (P, Unsigned_8 (Interfaces.Shift_Right (P.Internal_Rx, 1) and 16#FF#));
         end if;
         P.Rx_Bit := 0;
         P.Searching := True;
         if P.Rx_Edge = Leading then
            P.Rx_Edge := Trailing;
            Add (Ops, Polarity, P.Rx_Timer, 0);
         end if;
      end if;
   end Rx_BL;

   procedure Tx_SimonK (P : in out Port; Ops : in out Op_List)
     with Pre  => P.Mode = SimonK and then Ops.Count <= 1 and then Ops.Room >= Tick_Ops,
          Post => Ops.Count <= 6
   is
      --  The next byte loaded: a preamble byte, then the queued ones.
      procedure Load
        with Pre  => P.Mode = SimonK and then Ops.Count <= 3 and then Ops.Room >= Tick_Ops,
             Post => P.Mode = SimonK and then Ops.Count <= Ops.Count'Old + 3
      is
         Byte : Unsigned_8;
      begin
         if Tx_Empty (P) then
            P.Preamble := 0;
            return;
         end if;
         if P.Preamble < 3 then
            Byte := (if P.Preamble = 2 then 16#7F# else 16#FF#);
            P.Preamble := P.Preamble + 1;
         else
            Byte := P.Tx_Buffer (P.Tx_Tail);
            P.Tx_Tail := Next (P.Tx_Tail);
         end if;
         P.Internal_Tx := Unsigned_16 (Byte);
         P.Bits_Left := 8;
         P.Transmitting := True;
         Output_Config (Ops, P.Rx_Timer);
      end Load;

      One : Boolean;
   begin
      if P.Receiving then
         return;
      end if;
      if P.Preamble = 0 then
         Tx_Signal (Ops, P, True);
      end if;
      if not P.Transmitting then
         Load;
         return;
      end if;
      if P.Bits_Left > 0 then
         One := (P.Internal_Tx and 1) = 1;
         Tx_Signal (Ops, P, (if One then P.Quarter in 0 | 1 else P.Quarter in 0 | 2));
         if P.Quarter = 3 then
            P.Internal_Tx := Interfaces.Shift_Right (P.Internal_Tx, 1);
            P.Bits_Left := P.Bits_Left - 1;
            P.Quarter := 0;
            if P.Bits_Left = 0 then
               Load;
            end if;
         else
            P.Quarter := P.Quarter + 1;
         end if;
         return;
      end if;
      if Tx_Empty (P) then
         P.Transmitting := False;
         Input_Config (Ops, P.Rx_Timer);
      end if;
   end Tx_SimonK;

   procedure Tick (P : in out Port; Ops : in out Op_List) is
   begin
      Ops.Count := 0;
      if P.Mode = SimonK then
         if P.Receiving then
            P.Receive_Timeout := P.Receive_Timeout + 1;
            if P.Receive_Timeout > 8 then
               P.Receiving := False;
               P.Receive_Timeout := 0;
               Add (Ops, Polarity, P.Rx_Timer, 0);
            end if;
         end if;
         Tx_SimonK (P, Ops);
      else
         Tx_BL (P, Ops);
         Rx_BL (P, Ops);
      end if;
   end Tick;

   procedure Edge_BL (P : in out Port; Ops : in out Op_List)
     with Pre => Ops.Count = 0 and then Ops.Room >= Edge_Ops, Post => Ops.Count <= Edge_Ops
   is
   begin
      if P.Searching then
         Add (Ops, Set_Counter, P.Tx_Timer, P.Tx_Period / 2);
         if P.Transmitting then
            P.Transmission_Errors := P.Transmission_Errors + 1;
         end if;
         Add (Ops, Polarity, P.Rx_Timer, 1);
         P.Rx_Edge := Leading;
         P.Rx_Bit := 0;
         P.Rx_Last_Leading := 0;
         P.Internal_Rx := 0;
         P.Searching := False;
         return;
      end if;
      if P.Rx_Edge = Leading then
         P.Rx_Last_Leading := P.Rx_Bit;
      end if;
      Apply_Changed (P, P.Rx_Bit);
      if P.Rx_Edge = Trailing then
         P.Rx_Edge := Leading;
         Add (Ops, Polarity, P.Rx_Timer, 1);
      else
         P.Rx_Edge := Trailing;
         Add (Ops, Polarity, P.Rx_Timer, 0);
      end if;
   end Edge_BL;

   procedure Edge_SimonK (P : in out Port; Capture : Unsigned_16; Ops : in out Op_List)
     with Pre => Ops.Count = 0 and then Ops.Room >= Edge_Ops, Post => Ops.Count <= Edge_Ops
   is
      Bits : Natural range 0 .. 8 := P.Bits;
   begin
      Add (Ops, Set_Counter, P.Rx_Timer, 0);
      if Capture > 40 and then Capture < 90 then
         if P.Half_Zeros = 1 then
            P.Half_Zeros := 0;
            P.Internal_Rx := Interfaces.Shift_Right (P.Internal_Rx, 1);
            Bits := Bits + 1;
         else
            P.Half_Zeros := 1;
         end if;
      elsif Capture > 90 and then Capture < 200 then
         P.Half_Zeros := 0;
         P.Internal_Rx := Interfaces.Shift_Right (P.Internal_Rx, 1) or 16#80#;
         Bits := Bits + 1;
      elsif not P.Receiving then
         P.Receiving := True;
         P.Half_Zeros := 0;
         P.Bytes := 0;
         Bits := 1;
         P.Internal_Rx := 16#80#;
         Add (Ops, Polarity, P.Rx_Timer, 1);
      end if;
      P.Receive_Timeout := 0;
      if Bits = 8 then
         P.Bits := 0;
         P.Bytes := P.Bytes + 1;
         if P.Bytes > 3 then
            Store (P, Unsigned_8 (P.Internal_Rx and 16#FF#));
         end if;
         P.Internal_Rx := 0;
      else
         P.Bits := Bits;
      end if;
   end Edge_SimonK;

   procedure Edge (P : in out Port; Capture : Unsigned_16; Ops : in out Op_List) is
   begin
      Ops.Count := 0;
      case P.Mode is
         when SimonK =>
            Edge_SimonK (P, Capture, Ops);
         when BLHeli | Castle =>
            Edge_BL (P, Ops);
         when KISS | KISS_All =>
            null;
      end case;
   end Edge;

   procedure Close_Into (P : Port; Ops : in out Op_List)
     with Pre => Ops.Count <= Ops.Room - Close_Ops, Post => Ops.Count <= Ops.Count'Old + Close_Ops
   is
   begin
      if P.Mode /= KISS_All then
         Add (Ops, Clear_Flag, P.Rx_Timer);
         Add (Ops, Interrupt, P.Rx_Timer, 0);
         Pin (Ops, P.Rx_Timer, Mode_Input);
         Add (Ops, Edge_Handler, P.Rx_Timer, 0);
         Add (Ops, Reset, P.Rx_Timer);
      end if;
      Add (Ops, Tick_Handler, P.Tx_Timer, 0);
      Add (Ops, Reset, P.Tx_Timer);
   end Close_Into;

   procedure Close (P : Port; Ops : in out Op_List) is
   begin
      Ops.Count := 0;
      Close_Into (P, Ops);
   end Close;

   procedure Write (P : in out Port; B : Unsigned_8) is
   begin
      P.Tx_Buffer (P.Tx_Head) := B;
      P.Tx_Head := Next (P.Tx_Head);
   end Write;

   function Rx_Waiting (P : Port) return Natural is ((P.Rx_Head + Buffer_Size - P.Rx_Tail) mod Buffer_Size);

   procedure Read (P : in out Port; B : out Unsigned_8) is
   begin
      B := 0;
      if Rx_Waiting (P) > 0 then
         B := P.Rx_Buffer (P.Rx_Tail);
         P.Rx_Tail := Next (P.Rx_Tail);
      end if;
   end Read;

   procedure Exit_Step (X : in out Exit_Parser; C : Unsigned_8; Leave : out Boolean) is
   begin
      Leave := False;
      case X.State is
         when Idle =>
            if C = Character'Pos ('$') then
               X.State := Header_Start;
            end if;
         when Header_Start =>
            X.State := (if C = Character'Pos ('M') then Header_M else Idle);
         when Header_M =>
            X.State := (if C = Character'Pos ('<') then Header_Arrow else Idle);
         when Header_Arrow =>
            if C > 10 then
               X.State := Idle;
            else
               X.Size := C;
               X.Offset := 0;
               X.Checksum := C;
               X.State := Header_Size;
            end if;
         when Header_Size =>
            X.Command := C;
            X.Checksum := X.Checksum xor C;
            X.State := Header_Command;
         when Header_Command =>
            if X.Offset < X.Size then
               X.Checksum := X.Checksum xor C;
               X.Offset := X.Offset + 1;
            else
               X.State := Idle;
               Leave := X.Checksum = C and then X.Command = 16#F4# and then X.Size = 0;
            end if;
      end case;
   end Exit_Step;

   procedure Start
     (P : out Port; Mode : Protocol; Index : Natural; B : Board; Ops : in out Op_List; Started : out Boolean)
   is
      Output : constant Natural := Index mod 256;
   begin
      Ops.Count := 0;
      Add (Ops, Motors_Off);
      if Mode = KISS and then Output = 255 then
         Open_Into (P, KISS_All, 0, Baud_Of (Mode), B, Ops, Started);
      elsif Output >= Max_Motors then
         P := (others => <>);
         Started := False;
      else
         Open_Into (P, Mode, Output, Baud_Of (Mode), B, Ops, Started);
      end if;
   end Start;

   procedure Forward (P : in out Port; Ops : in out Op_List; More : out Boolean) is
      Byte : Unsigned_8;
   begin
      Ops.Count := 0;
      More := False;
      if P.Mode = KISS then
         return;
      end if;
      for K in 1 .. Chunk loop
         pragma Loop_Invariant (Ops.Count = K - 1);
         exit when Rx_Waiting (P) = 0;
         Read (P, Byte);
         Add (Ops, Host_Byte, Nothing, Unsigned_32 (Byte));
      end loop;
      More := Rx_Waiting (P) > 0;
   end Forward;

   procedure From_Host
     (P : in out Port; X : in out Exit_Parser; Host : Adaflight.Bytes.Byte_Array; Ops : in out Op_List;
      Left : out Boolean)
   is
      Leave : Boolean;
   begin
      Ops.Count := 0;
      Left := False;
      for I in Host'Range loop
         pragma Loop_Invariant (Ops.Count <= 2 * (I - Host'First));
         Exit_Step (X, Host (I), Leave);
         if Leave then
            Add (Ops, Host_Byte, Nothing, 16#24#);
            Add (Ops, Host_Byte, Nothing, 16#4D#);
            Add (Ops, Host_Byte, Nothing, 16#3E#);
            Add (Ops, Host_Byte, Nothing, 16#00#);
            Add (Ops, Host_Byte, Nothing, 16#F4#);
            Add (Ops, Host_Byte, Nothing, 16#F4#);
            Close_Into (P, Ops);
            Left := True;
            return;
         end if;
         if P.Mode in BLHeli | KISS | KISS_All then
            Add (Ops, Host_Byte, Nothing, Unsigned_32 (Host (I)));
         end if;
         Write (P, Host (I));
         Add (Ops, ESC_Byte, Nothing, Unsigned_32 (Host (I)));
      end loop;
   end From_Host;

end Adaflight.ESC_Serial;
