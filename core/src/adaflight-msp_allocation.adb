package body Adaflight.MSP_Allocation
  with SPARK_Mode
is

   procedure Allocate
     (O           : SFM.Options;
      A           : SFM.Assignments;
      Half_Duplex : Boolean;
      Present     : Port_Flags;
      Busy        : Port_Flags;
      Ports       : out Opened_Ports;
      Count       : out Port_Count)
   is
      Taken : Port_Flags := Busy;

      --  Whether an MSP port is open on an identifier.
      function Is_Open (Port : Port_Id) return Boolean is
        (for some I in 1 .. Count => Ports (I).Port = Port);

      --  Opens MSP on a port at a slot's baud index, as the port's driver
      --  allows: a free port the board has, and a soft serial port only up to
      --  its rate.
      procedure Open (Port : Port_Id; Baud : SFM.Baud_Index)
        with Pre  => (for all I in 1 .. Count => Present (Ports (I).Port) and then not Busy (Ports (I).Port)
                                                  and then Taken (Ports (I).Port))
                     and then (for all P in Port_Id => (if Busy (P) then Taken (P))),
             Post => (for all I in 1 .. Count => Present (Ports (I).Port) and then not Busy (Ports (I).Port)
                                                  and then Taken (Ports (I).Port))
                     and then (for all P in Port_Id => (if Busy (P) then Taken (P)))
                     and then Count >= Count'Old
      is
         Rate : constant Interfaces.Unsigned_32 :=
           SFM.Rate_Of (if Baud = SFM.Baud_Auto then SFM.Baud_115200 else Baud);
         Kind : constant Port_Kind := Kind_Of (Port);
         Mask : Interfaces.Unsigned_32;
      begin
         if Count = Max_Ports or else Port = SFM.No_Port or else not Present (Port) or else Taken (Port)
           or else (Kind = Soft_Serial and then Rate > Soft_Serial_Max_Rate)
         then
            return;
         end if;
         Mask := SFM.Function_Mask (O, A, Port);
         Count := Count + 1;
         Ports (Count) :=
           (Port          => Port,
            Rate          => Rate,
            Bidirectional => Half_Duplex,
            Check_TX      => not Half_Duplex and then Kind = UART,
            Shared        => (Mask and Telemetry_Functions) /= 0 and then (Mask and SFM.Function_MSP) /= 0);
         Taken (Port) := True;
      end Open;

      Implied     : SFM.Implied_Ports;
      Implied_Count : Natural;
   begin
      Ports := (others => (others => <>));
      Count := 0;
      pragma Assert (for all P in Port_Id => (if Busy (P) then Taken (P)));
      for S in SFM.MSP_Slot loop
         pragma Loop_Invariant (for all I in 1 .. Count => Present (Ports (I).Port) and then not Busy (Ports (I).Port)
                                                            and then Taken (Ports (I).Port));
         pragma Loop_Invariant (for all P in Port_Id => (if Busy (P) then Taken (P)));
         Open (A.MSP_Port (S), A.MSP_Baud (S));
      end loop;
      SFM.Implied_MSP_Ports (O, A, Implied_Limit (O), Implied, Implied_Count);
      for I in 1 .. Implied_Count loop
         pragma Loop_Invariant (for all J in 1 .. Count => Present (Ports (J).Port) and then not Busy (Ports (J).Port)
                                                            and then Taken (Ports (J).Port));
         pragma Loop_Invariant (for all P in Port_Id => (if Busy (P) then Taken (P)));
         if not Is_Open (Implied (I)) then
            Open (Implied (I), SFM.Baud_115200);
         end if;
      end loop;
   end Allocate;

   function Default_Slots (First, MSP_UART, Other_MSP_UART, Display_Port_UART : Port_Id) return SFM.MSP_Ports is
      Slots : SFM.MSP_Ports := (others => SFM.No_Port);
      Used  : Natural range 0 .. 3 := 0;

      --  Names a port in the next free slot unless it is none, the slots are
      --  full, or an earlier slot names it.
      procedure Claim (Port : Port_Id) is
      begin
         if Port = SFM.No_Port or else Used = 3 then
            return;
         end if;
         for I in 1 .. Used loop
            if Slots (SFM.MSP_Slot (I)) = Port then
               return;
            end if;
         end loop;
         Used := Used + 1;
         Slots (SFM.MSP_Slot (Used)) := Port;
      end Claim;
   begin
      Claim (First);
      Claim (MSP_UART);
      Claim (Other_MSP_UART);
      Claim (Display_Port_UART);
      return Slots;
   end Default_Slots;

end Adaflight.MSP_Allocation;
