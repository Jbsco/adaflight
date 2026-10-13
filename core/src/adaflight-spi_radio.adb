package body Adaflight.SPI_Radio with SPARK_Mode is

   procedure Add (O : in out Output; Item : Op) is
   begin
      if O.Count < Max_Ops then
         O.Count := O.Count + 1;
         O.Ops (O.Count) := Item;
      end if;
   end Add;

   procedure Strobe (O : in out Output; Command : Unsigned_8) is
   begin
      Add (O, (Kind => Strobe, A => Command, others => <>));
   end Strobe;

   procedure Write (O : in out Output; Register, Value : Unsigned_8) is
   begin
      Add (O, (Kind => Write_Register, A => Register, B => Value, others => <>));
   end Write;

   procedure Set_Pin (O : in out Output; On : Pin; High : Boolean) is
   begin
      Add (O, (Kind => (if High then Pin_High else Pin_Low), On => On, others => <>));
   end Set_Pin;

   procedure Write_All (O : in out Output; List : Register_List) is
   begin
      for R of List loop
         Write (O, R.Register, R.Value);
      end loop;
   end Write_All;

   procedure Calibrate_Channels (O : in out Output; Count, Step, Base : Unsigned_8) is
   begin
      Add (O, (Kind => Calibrate, A => Count, B => Step, Value => Unsigned_16 (Base), others => <>));
   end Calibrate_Channels;

   procedure LED_On (O : in out Output; P : Pins) is
   begin
      if P.LED then
         Set_Pin (O, LED, not P.LED_Inversion);
      end if;
   end LED_On;

   procedure LED_Off (O : in out Output; P : Pins) is
   begin
      if P.LED then
         Set_Pin (O, LED, P.LED_Inversion);
      end if;
   end LED_Off;

   procedure LED_Toggle (O : in out Output; P : Pins) is
   begin
      if P.LED then
         Add (O, (Kind => Pin_Toggle, On => LED, others => <>));
      end if;
   end LED_Toggle;

   procedure LED_Blink (R : in out Radio; P : Pins; O : in out Output; Now_Ms : Unsigned_32; Period_Ms : Unsigned_32) is
   begin
      if R.LED_Blink_Ms + Period_Ms > Now_Ms then
         return;
      end if;
      R.LED_Blink_Ms := Now_Ms;
      LED_Toggle (O, P);
   end LED_Blink;

   procedure LED_Blink_Rx_Loss (R : in out Radio; P : Pins; O : in out Output; Now_Ms : Unsigned_32; Data : Boolean) is
   begin
      if not P.LED then
         return;
      end if;
      if Data then
         LED_On (O, P);
      else
         if R.Rx_Loss_Ms + 1_000 > Now_Ms then
            return;
         end if;
         LED_Toggle (O, P);
      end if;
      R.Rx_Loss_Ms := Now_Ms;
   end LED_Blink_Rx_Loss;

   procedure Start_Common (R : out Radio; P : Pins; Bind_Pin_Level : Boolean; O : in out Output) is
   begin
      R := (others => <>);
      LED_Off (O, P);
      if P.Bind then
         R.Last_Bind_Pin := Bind_Pin_Level;
      end if;
   end Start_Common;

   procedure Start (R : out Radio; P : Pins; Bind_Pin_Level, Chip_Ok : Boolean; O : in out Output; Ok : out Boolean) is
   begin
      Start_Common (R, P, Bind_Pin_Level, O);
      Ok := False;
      if P.Chip_Detect then
         Add (O, (Kind => Reset, others => <>));
         if not Chip_Ok then
            return;
         end if;
      end if;
      if P.LNA then
         Set_Pin (O, LNA_Enable, True);
      end if;
      if P.Antenna then
         Set_Pin (O, Antenna_Select, True);
      end if;
      R.Antenna_Pin := P.Antenna;
      if P.Tx_Enable then
         Set_Pin (O, Tx_Enable, False);
      end if;
      Ok := True;
   end Start;

   procedure Check_Bind_Requested
     (R : in out Radio; P : Pins; Bind_Pin_Level : Boolean; Reset : Boolean; Requested : out Boolean)
   is
   begin
      if P.Bind then
         if R.Last_Bind_Pin and then not Bind_Pin_Level then
            R.Bind_Requested := True;
         end if;
         R.Last_Bind_Pin := Bind_Pin_Level;
      end if;
      Requested := R.Bind_Requested;
      if Requested and then Reset then
         R.Bind_Requested := False;
      end if;
   end Check_Bind_Requested;

   procedure Set_RSSI_Dbm (R : in out Radio; O : in out Output; Value : Unsigned_8) is
      Scaled : constant Integer := (Integer (Value) * 18) / 32;
   begin
      R.RSSI_Dbm := Integer_16 (if Value >= 128 then Scaled - 82 else Scaled + 65);
      Add (O, (Kind => Set_RSSI, Value => Unsigned_16 ((Integer (R.RSSI_Dbm) * 8) mod 65_536), others => <>));
   end Set_RSSI_Dbm;

   procedure Switch_Antennae (R : in out Radio; O : in out Output) is
   begin
      if R.Antenna_Pin then
         Set_Pin (O, Antenna_Select, not R.Other_Antenna);
         R.Other_Antenna := not R.Other_Antenna;
      end if;
   end Switch_Antennae;

end Adaflight.SPI_Radio;
