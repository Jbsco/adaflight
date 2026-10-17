package body Adaflight.RX_SPI_Provider with SPARK_Mode is

   ----------
   -- Init --
   ----------

   procedure Init (S : in out State; Protocol : Unsigned_8; Ok : out Boolean; Providing : out Boolean) is
      F         : constant Family := Family_Of (Protocol);
      Device_Ok : Boolean;
   begin
      Ok := False;
      Providing := False;
      Device_Init (Device_Ok);
      if not Device_Ok or else F = None then
         return;
      end if;
      S.Selected := F;
      Family_Init (F, Ok);
      if Exti_Configured then
         Exti_Init;
      end if;
      S.New_Packet := False;
      Providing := True;
      Dispatch_Enable;
   end Init;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status
     (S : in out State; Report : out Receiver.Frame_Report; Last_Frame_Us : in out Receiver.Time_Us)
   is
      R : Received;
   begin
      Report := (others => False);
      Family_Data_Received (S.Selected, R);
      if R.Data then
         S.New_Packet := True;
         Last_Frame_Us := Last_Exti_Time;
         Report.Complete := True;
      end if;
      Report.Processing_Required := R.Processing_Required;
   end Frame_Status;

   -------------------
   -- Process_Frame --
   -------------------

   procedure Process_Frame (S : in out State) is
      R : Received;
   begin
      if S.Selected = FrSky then
         Family_Process_Frame (FrSky, R);
         if R.Data then
            S.New_Packet := True;
         end if;
      end if;
   end Process_Frame;

   --------------
   -- Read_Raw --
   --------------

   procedure Read_Raw (S : in out State; Channels : Natural; Ch : Natural; Value : out Float) is
   begin
      if Ch >= Channels then
         Value := 0.0;
         return;
      end if;
      if S.New_Packet then
         Family_Set_Channels (S.Selected, S.Data);
         S.New_Packet := False;
      end if;
      Value := Float (S.Data (Ch));
   end Read_Raw;

   ----------
   -- Stop --
   ----------

   procedure Stop (S : State) is
   begin
      if S.Selected = ExpressLRS then
         Family_Stop (ExpressLRS);
      end if;
   end Stop;

   -----------------
   -- Enable_Exti --
   -----------------

   procedure Enable_Exti is
   begin
      Exti_Init;
   end Enable_Exti;

end Adaflight.RX_SPI_Provider;
