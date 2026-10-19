package body Adaflight.SD_Card_SDIO with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_64;

   Init_Timeout_Ms  : constant := 1000;
   Read_Timeout_Ms  : constant := 100;
   Write_Timeout_Ms : constant := 250;
   Max_Failures     : constant := 8;
   Max_Passes       : constant := 64;

   type Receive_Status is (Received, In_Progress, Error);

   procedure Is_Inserted (D : in out SDIO_Device; S : Card; Inserted : out Boolean) is
      High : Boolean;
   begin
      Inserted := True;
      if S.Has_Detect_Pin then
         Read_Detect_Pin (D, High);
         Inserted := High;
         if S.Detect_Inverted then
            Inserted := not Inserted;
         end if;
      end if;
   end Is_Inserted;

   procedure Reset_Card (D : in out SDIO_Device; S : in out Card)
     with Global => null;

   procedure Reset_Card (D : in out SDIO_Device; S : in out Card) is
      OK       : Boolean;
      Inserted : Boolean;
   begin
      Init_Card (D, OK);
      if OK then
         return;
      end if;
      S.Failure_Count := S.Failure_Count + 1;
      if S.Failure_Count >= Max_Failures then
         S.State := Not_Present;
         return;
      end if;
      Is_Inserted (D, S, Inserted);
      if Inserted then
         Millis (D, S.Operation_Start);
         S.State := Resetting;
      else
         S.State := Not_Present;
      end if;
   end Reset_Card;

   procedure Receive_Data_Block (D : in out SDIO_Device; Got : out Receive_Status)
     with Global => null;

   procedure Receive_Data_Block (D : in out SDIO_Device; Got : out Receive_Status) is
      Pending : Boolean;
      Free    : Boolean;
   begin
      Read_Pending (D, Pending);
      if Pending then
         Got := In_Progress;
         return;
      end if;
      Check_Ready (D, Free);
      Got := (if Free then Received else Error);
   end Receive_Data_Block;

   procedure Receive_CID (D : in out SDIO_Device; S : in out Card; OK : out Boolean)
     with Global => null;

   procedure Receive_CID (D : in out SDIO_Device; S : in out Card; OK : out Boolean) is
      Info : Card_Information;
   begin
      Card_Info (D, Info, OK);
      if not OK then
         return;
      end if;
      S.Meta.Manufacturer := Info.Manufacturer;
      S.Meta.OEM_Id := Info.OEM_Id;
      S.Meta.Product_Name :=
        (Byte (Info.Name_Head / 2 ** 24), Byte ((Info.Name_Head / 2 ** 16) and 16#FF#),
         Byte ((Info.Name_Head / 2 ** 8) and 16#FF#), Byte (Info.Name_Head and 16#FF#), Info.Name_Tail);
      S.Meta.Revision_Major := Info.Revision / 16;
      S.Meta.Revision_Minor := Info.Revision and 16#0F#;
      S.Meta.Serial := Info.Serial;
      S.Meta.Production_Year := (((Info.Date and 16#0F00#) / 256) or ((Info.Date and 16#FF#) / 16)) + 2000;
      S.Meta.Production_Month := Byte (Info.Date and 16#000F#);
   end Receive_CID;

   procedure Fetch_CSD (D : in out SDIO_Device; S : in out Card; OK : out Boolean)
     with Global => null;

   procedure Fetch_CSD (D : in out SDIO_Device; S : in out Card; OK : out Boolean) is
      Info : Card_Information;
   begin
      Card_Info (D, Info, OK);
      if OK then
         S.Meta.Num_Blocks := Interfaces.Unsigned_32 (Info.Capacity and 16#FFFF_FFFF#);
      end if;
   end Fetch_CSD;

   procedure Check_Init_Done (D : in out SDIO_Device; S : in out Card; Done : out Boolean)
     with Global => null;

   procedure Check_Init_Done (D : in out SDIO_Device; S : in out Card; Done : out Boolean) is
      Free : Boolean;
      Info : Card_Information;
      OK   : Boolean;
   begin
      Done := False;
      Check_Ready (D, Free);
      if Free then
         Card_Info (D, Info, OK);
         if OK then
            S.Version := (if Info.Kind /= 0 then 2 else 1);
            S.High_Capacity := Info.Kind = 2;
            Done := True;
         end if;
      end if;
   end Check_Init_Done;

   procedure End_Write_Blocks (D : in out SDIO_Device; S : in out Card; Status : out Operation_Status)
     with Global => null;

   procedure End_Write_Blocks (D : in out SDIO_Device; S : in out Card; Status : out Operation_Status) is
      Free : Boolean;
   begin
      S.Multi_Remain := 0;
      if S.Use_Cache then
         S.Cached := 0;
      end if;
      Check_Ready (D, Free);
      if Free then
         S.State := Ready;
         Status := Success;
      else
         S.State := Stopping_Multiple;
         Millis (D, S.Operation_Start);
         Status := In_Progress;
      end if;
   end End_Write_Blocks;

   procedure Init (D : in out SDIO_Device; S : in out Card; C : Config) is
      Identifier : Natural;
      OK         : Boolean;
      Inserted   : Boolean;
   begin
      S.Has_Detect_Pin := C.Detect_Tag /= 0;
      S.Detect_Inverted := S.Has_Detect_Pin and then C.Detect_Inverted;
      if S.Has_Detect_Pin then
         Init_Detect_Pin (D);
      end if;
      S.Enabled := C.Mode = Mode_SDIO;
      if not S.Enabled then
         S.State := Not_Present;
         return;
      end if;
      Find_DMA (D, Identifier);
      if Identifier = 0 then
         S.State := Not_Present;
         return;
      end if;
      S.Use_Cache := Cache_Writes (D);
      Init_Hardware (D, OK);
      if not OK then
         S.State := Not_Present;
         return;
      end if;
      Is_Inserted (D, S, Inserted);
      if not Inserted then
         S.State := Not_Present;
         S.Failure_Count := S.Failure_Count + 1;
         return;
      end if;
      Init_Card (D, OK);
      if not OK then
         S.State := Not_Present;
         S.Failure_Count := S.Failure_Count + 1;
         return;
      end if;
      Millis (D, S.Operation_Start);
      S.State := Resetting;
      S.Failure_Count := 0;
   end Init;

   procedure Poll (D : in out SDIO_Device; S : in out Card; Card_Ready : out Boolean) is
      Again         : Boolean;
      Done          : Boolean;
      OK            : Boolean;
      Pending       : Boolean;
      Free          : Boolean;
      Got           : Receive_Status;
      Now           : Interfaces.Unsigned_32;
      Unused_Ending : Operation_Status;
   begin
      if not S.Enabled then
         S.State := Not_Present;
         Card_Ready := False;
         return;
      end if;
      for Pass in 1 .. Max_Passes loop
         Again := False;
         case S.State is
            when Resetting =>
               S.State := Initializing;
               Again := True;
            when Initializing =>
               Check_Init_Done (D, S, Done);
               if Done then
                  Fetch_CSD (D, S, OK);
                  if OK then
                     S.State := Receiving_CID;
                  else
                     Reset_Card (D, S);
                  end if;
                  Again := True;
               end if;
            when Receiving_CID =>
               Receive_CID (D, S, OK);
               if OK then
                  S.Multi_Remain := 0;
                  S.State := Ready;
                  Again := True;
               end if;
            when Sending_Write =>
               Write_Pending (D, Pending);
               if not Pending then
                  S.State := Waiting_For_Write;
                  Millis (D, S.Operation_Start);
                  if S.Op.Has_Callback then
                     Complete (D, True, S.Op.Index, True, S.Op.Callback_Data, S.Data);
                  end if;
               end if;
            when Waiting_For_Write =>
               Check_Ready (D, Free);
               if Free then
                  S.Failure_Count := 0;
                  if S.Multi_Remain > 1 then
                     S.Multi_Remain := S.Multi_Remain - 1;
                     S.Multi_Next := S.Multi_Next + 1;
                     if S.Use_Cache then
                        S.Cached := 0;
                     end if;
                     S.State := Writing_Multiple;
                  elsif S.Multi_Remain = 1 then
                     End_Write_Blocks (D, S, Unused_Ending);
                  else
                     S.State := Ready;
                  end if;
               else
                  Millis (D, Now);
                  if Now > S.Operation_Start + Write_Timeout_Ms then
                     Reset_Card (D, S);
                     Again := True;
                  end if;
               end if;
            when Reading =>
               Receive_Data_Block (D, Got);
               case Got is
                  when Received =>
                     S.State := Ready;
                     S.Failure_Count := 0;
                     Fetch_Block (D, S.Op.Index, S.Data);
                     if S.Op.Has_Callback then
                        Complete (D, False, S.Op.Index, True, S.Op.Callback_Data, S.Data);
                     end if;
                  when In_Progress =>
                     Millis (D, Now);
                     Again := Now > S.Operation_Start + Read_Timeout_Ms;
                  when Error =>
                     Again := True;
               end case;
            when Stopping_Multiple =>
               Check_Ready (D, Free);
               if Free then
                  S.State := Ready;
               else
                  Millis (D, Now);
                  if Now > S.Operation_Start + Write_Timeout_Ms then
                     Reset_Card (D, S);
                     Again := True;
                  end if;
               end if;
            when Not_Present | Ready | Writing_Multiple =>
               null;
         end case;
         exit when not Again;
      end loop;
      if S.State in Resetting .. Receiving_CID then
         Millis (D, Now);
         if Now - S.Operation_Start > Init_Timeout_Ms then
            Reset_Card (D, S);
         end if;
      end if;
      Card_Ready := S.State = Ready or else S.State = Writing_Multiple;
   end Poll;

   procedure Read_Block
     (D             : in out SDIO_Device;
      S             : in out Card;
      Index         : Interfaces.Unsigned_32;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Accepted      : out Boolean)
   is
      Ending : Operation_Status;
      OK     : Boolean;
   begin
      if S.State /= Ready then
         if S.State = Writing_Multiple then
            End_Write_Blocks (D, S, Ending);
            if Ending /= Success then
               Accepted := False;
               return;
            end if;
         else
            Accepted := False;
            return;
         end if;
      end if;
      Start_Read (D, Index, OK);
      if OK then
         S.Op := (Index => Index, Has_Callback => Has_Callback, Callback_Data => Callback_Data);
         S.State := Reading;
         Millis (D, S.Operation_Start);
         Accepted := True;
      else
         Reset_Card (D, S);
         if S.Op.Has_Callback then
            Complete (D, False, S.Op.Index, False, S.Op.Callback_Data, S.Data);
         end if;
         Accepted := False;
      end if;
   end Read_Block;

   procedure Write_Block
     (D             : in out SDIO_Device;
      S             : in out Card;
      Index         : Interfaces.Unsigned_32;
      Data          : Block;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Status        : out Operation_Status)
   is
      Ending     : Operation_Status;
      OK         : Boolean;
      Start      : Interfaces.Unsigned_32 := Index;
      From_Cache : Boolean := False;
   begin
      if S.State = Writing_Multiple then
         if Index /= S.Multi_Next then
            End_Write_Blocks (D, S, Ending);
            if Ending /= Success then
               Status := Busy;
               return;
            end if;
         end if;
      elsif S.State /= Ready then
         Status := Busy;
         return;
      end if;
      S.Op.Index := Index;
      if S.Cached < Cache_Blocks and then S.Multi_Remain /= 0 and then S.Use_Cache then
         S.Cache (S.Cached * Block_Bytes .. S.Cached * Block_Bytes + Block_Bytes - 1) := Data;
         S.Cached := S.Cached + 1;
         if S.Cached = Cache_Blocks or else S.Multi_Remain = 1 then
            Start := Index - Interfaces.Unsigned_32 (S.Cached - 1);
            From_Cache := True;
         else
            S.Multi_Remain := S.Multi_Remain - 1;
            S.Multi_Next := S.Multi_Next + 1;
            S.State := Ready;
            Status := Success;
            return;
         end if;
      end if;
      S.Op.Has_Callback := Has_Callback;
      S.Op.Callback_Data := Callback_Data;
      S.State := Sending_Write;
      if From_Cache then
         Start_Write (D, Start, S.Cache (0 .. S.Cached * Block_Bytes - 1), OK);
      else
         Start_Write (D, Start, Data, OK);
      end if;
      if OK then
         Status := In_Progress;
      else
         Reset_Card (D, S);
         if S.Op.Has_Callback then
            Complete (D, True, S.Op.Index, False, S.Op.Callback_Data, S.Data);
         end if;
         Status := Failure;
      end if;
   end Write_Block;

   procedure Begin_Write_Blocks
     (D      : in out SDIO_Device;
      S      : in out Card;
      Index  : Interfaces.Unsigned_32;
      Count  : Interfaces.Unsigned_32;
      Status : out Operation_Status)
   is
      Ending : Operation_Status;
   begin
      if S.State /= Ready then
         if S.State = Writing_Multiple then
            if Index = S.Multi_Next then
               Status := Success;
               return;
            end if;
            End_Write_Blocks (D, S, Ending);
            if Ending /= Success then
               Status := Busy;
               return;
            end if;
         else
            Status := Busy;
            return;
         end if;
      end if;
      S.State := Writing_Multiple;
      S.Multi_Remain := Count;
      S.Multi_Next := Index;
      Status := Success;
   end Begin_Write_Blocks;

end Adaflight.SD_Card_SDIO;
