package body Adaflight.Soft_Serial with SPARK_Mode is

   --  A received frame's stop and start bits in the receive register, and
   --  a sent frame's stop bit in the send register.
   Stop_Mask    : constant Unsigned_16 := 2 ** 0;
   Start_Mask   : constant Unsigned_16 := 2 ** (Total_Bits - 1);
   Tx_Stop_Mask : constant Unsigned_16 := 2 ** (Total_Bits - 1);

   function Time_Base_Of (Clock : Unsigned_32; Baud : Unsigned_32) return Time_Base is
      C : Unsigned_32 := Clock;
   begin
      while C / Baud > 16#FFFF# and then C > 1 loop
         pragma Loop_Variant (Decreases => C);
         C := C / 2;
      end loop;
      return (Period => Unsigned_16 (C / Baud), Clock => C);
   end Time_Base_Of;

   --  The receive pin listening: a start bit searched from the first bit.
   procedure Listen (P : in out Port) is
   begin
      P.Rx_Active := True;
      P.Searching := True;
      P.Rx_Bit := 0;
   end Listen;

   procedure Open (P : out Port; R : Open_Request; Plan : out Open_Plan) is
      Rx_Timer : constant Boolean := (if R.Same_Pin then R.Tx_Timer else R.Rx_Timer);
      Rx_N     : constant Boolean := (if R.Same_Pin then R.Tx_N else R.Rx_N);
      Rx_Clock : constant Unsigned_32 := (if R.Same_Pin then R.Tx_Clock else R.Rx_Clock);
      Rx_Is    : constant Pin := (if not R.Rx_Assigned then No_Pin elsif R.Same_Pin then Tx_Pin else Rx_Pin);
      Tx_Is    : constant Pin := (if R.Tx_Assigned then Tx_Pin else No_Pin);
   begin
      P := (others => <>);
      Plan := (others => <>);
      if R.Options.Bidirectional then
         if not R.Tx_Timer or else R.Tx_N then
            return;
         end if;
         Plan.Main := Tx_Pin;
         Plan.Send_On := Tx_Is;
         Plan.Receive_On := Tx_Is;
         Plan.Claim_Tx := True;
      else
         if R.Mode.Rx then
            if not Rx_Timer or else Rx_N then
               return;
            end if;
            Plan.Receive_On := Rx_Is;
            Plan.Main := Rx_Pin;
            Plan.Claim_Rx := not (R.Mode.Tx and then Rx_Is = Tx_Is);
         end if;
         if R.Mode.Tx then
            if not R.Tx_Assigned then
               Plan := (others => <>);
               return;
            end if;
            Plan.Send_On := Tx_Is;
            if not R.Mode.Rx then
               if not R.Tx_Timer then
                  Plan := (others => <>);
                  return;
               end if;
               Plan.Main := Tx_Pin;
            else
               Plan.Extra_Timer := R.Tx_Timer;
            end if;
            Plan.Claim_Tx := True;
         end if;
         if Plan.Main = No_Pin then
            Plan := (others => <>);
            return;
         end if;
      end if;
      Plan.Opened := True;
      Plan.Main_Base := Time_Base_Of ((if Plan.Main = Tx_Pin then R.Tx_Clock else Rx_Clock), R.Baud);
      if R.Mode.Tx and then Plan.Extra_Timer and then not R.Same_Pin and then not R.Same_Timer then
         Plan.Timing := Dual;
         Plan.Second_Base := Time_Base_Of (R.Tx_Clock, R.Baud);
      end if;
      P.Mode := R.Mode;
      P.Options := R.Options;
      P.Timing := Plan.Timing;
      Listen (P);
   end Open;

   procedure Clock_Tx (P : in out Port; E : out Tx_Effect) is
   begin
      E := Nothing;
      if not P.Transmitting then
         if P.Tx_Head = P.Tx_Tail then
            if not P.Rx_Active and then P.Options.Bidirectional then
               Listen (P);
               E := To_Receive;
            end if;
            return;
         end if;
         P.Internal_Tx := Tx_Stop_Mask or Interfaces.Shift_Left (Unsigned_16 (P.Tx_Buffer (P.Tx_Tail)), 1);
         P.Tx_Tail := (if P.Tx_Tail = Buffer_Index'Last then 0 else P.Tx_Tail + 1);
         P.Bits_Left := Total_Bits;
         P.Transmitting := True;
         if P.Rx_Active and then P.Options.Bidirectional then
            P.Rx_Active := False;
            E := To_Transmit;
            return;
         end if;
      end if;
      if P.Bits_Left > 0 then
         E := (if ((P.Internal_Tx and 1) /= 0) /= P.Options.Inverted then Level_High else Level_Low);
         P.Internal_Tx := Interfaces.Shift_Right (P.Internal_Tx, 1);
         P.Bits_Left := P.Bits_Left - 1;
         return;
      end if;
      P.Transmitting := False;
   end Clock_Tx;

   --  The run of high bits that ends at the current bit, when the line is
   --  high.
   procedure Apply_Changed (P : in out Port; Up_To : Bit_Count) is
   begin
      if P.Rx_Edge = Trailing then
         for B in P.Rx_Last_Leading .. Up_To - 1 loop
            P.Internal_Rx := P.Internal_Rx or Interfaces.Shift_Left (Unsigned_16'(1), B);
         end loop;
      end if;
   end Apply_Changed;

   procedure Clock_Rx (P : in out Port; Rearm : out Boolean) is
      Bit : Bit_Count;
   begin
      Rearm := False;
      if P.Searching then
         return;
      end if;
      Bit := P.Rx_Bit + 1;
      if Bit = Total_Bits - 1 then
         P.Rx_Bit := Bit;
         Apply_Changed (P, Bit);
         return;
      end if;
      if Bit = Total_Bits then
         if P.Rx_Edge = Trailing then
            P.Internal_Rx := P.Internal_Rx or Stop_Mask;
         end if;
         if P.Mode.Rx then
            if (P.Internal_Rx and Start_Mask) /= 0 or else (P.Internal_Rx and Stop_Mask) = 0 then
               P.Receive_Errors := P.Receive_Errors + 1;
            else
               P.Rx_Buffer (P.Rx_Head) := Unsigned_8 (Interfaces.Shift_Right (P.Internal_Rx, 1) and 16#FF#);
               P.Rx_Head := (if P.Rx_Head = Buffer_Index'Last then 0 else P.Rx_Head + 1);
            end if;
         end if;
         P.Rx_Bit := 0;
         P.Searching := True;
         if P.Rx_Edge = Leading then
            P.Rx_Edge := Trailing;
            Rearm := True;
         end if;
         return;
      end if;
      P.Rx_Bit := Bit;
   end Clock_Rx;

   procedure Clock (P : in out Port; E : out Tx_Effect; Rearm : out Boolean) is
   begin
      E := Nothing;
      Rearm := False;
      if P.Mode.Tx then
         Clock_Tx (P, E);
      end if;
      if P.Mode.Rx then
         Clock_Rx (P, Rearm);
      end if;
   end Clock;

   procedure Edge (P : in out Port; Acted : out Boolean; Centre : out Boolean; Rising : out Boolean) is
   begin
      Acted := False;
      Centre := False;
      Rising := False;
      if not P.Mode.Rx then
         return;
      end if;
      Acted := True;
      if P.Searching then
         Centre := True;
         if P.Timing /= Dual and then P.Transmitting then
            P.Transmission_Errors := P.Transmission_Errors + 1;
         end if;
         Rising := not P.Options.Inverted;
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
         Rising := not P.Options.Inverted;
      else
         P.Rx_Edge := Trailing;
         Rising := P.Options.Inverted;
      end if;
   end Edge;

   procedure Write (P : in out Port; B : Unsigned_8) is
   begin
      if P.Mode.Tx then
         P.Tx_Buffer (P.Tx_Head) := B;
         P.Tx_Head := (if P.Tx_Head = Buffer_Index'Last then 0 else P.Tx_Head + 1);
      end if;
   end Write;

   function Rx_Waiting (P : Port) return Natural is
     (if P.Mode.Rx then (P.Rx_Head + Buffer_Size - P.Rx_Tail) mod Buffer_Size else 0);

   function Tx_Free (P : Port) return Natural is
     (if P.Mode.Tx then Buffer_Size - 1 - (P.Tx_Head + Buffer_Size - P.Tx_Tail) mod Buffer_Size else 0);

   procedure Read (P : in out Port; B : out Unsigned_8) is
   begin
      B := 0;
      if Rx_Waiting (P) > 0 then
         B := P.Rx_Buffer (P.Rx_Tail);
         P.Rx_Tail := (if P.Rx_Tail = Buffer_Index'Last then 0 else P.Rx_Tail + 1);
      end if;
   end Read;

   procedure Set_Mode (P : in out Port; M : Port_Mode) is
   begin
      P.Mode := M;
   end Set_Mode;

end Adaflight.Soft_Serial;
