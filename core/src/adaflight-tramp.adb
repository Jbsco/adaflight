with Adaflight.Clock;

package body Adaflight.Tramp with SPARK_Mode is
   use type Interfaces.Integer_32;

   Start_Byte       : constant Byte := 16#0F#;
   Race_Lock        : constant Unsigned_8 := 1;
   Min_Period_Us    : constant := 200_000;
   Status_Period_Us : constant := 1_000_000;

   Cmd_Limits    : constant Byte := Character'Pos ('r');
   Cmd_Settings  : constant Byte := Character'Pos ('v');
   Cmd_Temp      : constant Byte := Character'Pos ('s');
   Cmd_Set_Freq  : constant Byte := Character'Pos ('F');
   Cmd_Set_Power : constant Byte := Character'Pos ('P');
   Cmd_Active    : constant Byte := Character'Pos ('I');

   function Word (F : Frame_Bytes; I : Natural) return Unsigned_16 is
     (Unsigned_16 (F (I)) or Interfaces.Shift_Left (Unsigned_16 (F (I + 1)), 8))
     with Pre => I <= Frame_Length - 2;

   function Checksum (F : Frame_Bytes) return Byte is
      Sum : Byte := 0;
   begin
      for I in 1 .. 13 loop
         Sum := Sum + F (I);
      end loop;
      return Sum;
   end Checksum;

   --  A frame with the command and a sixteen-bit parameter.
   procedure Send (D : Driver; Cmd : Byte; Param : Unsigned_16; E : in out Events) is
      F : Frame_Bytes := (others => 0);
   begin
      if not D.Port_Open then
         return;
      end if;
      F (0) := Start_Byte;
      F (1) := Cmd;
      F (2) := Byte (Param and 16#FF#);
      F (3) := Byte (Interfaces.Shift_Right (Param, 8));
      F (14) := Checksum (F);
      E.Tx := F;
      E.Tx_Count := Frame_Length;
   end Send;

   procedure Send_Command (D : Driver; Cmd : Byte; Param : Unsigned_16; Control_Disabled : Boolean;
                           E : in out Events) is
   begin
      if not Control_Disabled then
         Send (D, Cmd, Param, E);
      end if;
   end Send_Command;

   --  A complete frame: the limits, the settings or the temperature, each
   --  rejected when its first word is zero, as an echoed request is.
   procedure Handle_Response (D : in out Driver; Code : out Byte) is
      Rx : constant Frame_Bytes := D.Rx;
   begin
      Code := 0;
      if Rx (1) = Cmd_Limits then
         if Word (Rx, 2) /= 0 then
            D.Freq_Min := Unsigned_32 (Word (Rx, 2));
            D.Freq_Max := Unsigned_32 (Word (Rx, 4));
            D.Power_Max := Unsigned_32 (Word (Rx, 6));
            Code := Cmd_Limits;
         end if;
      elsif Rx (1) = Cmd_Settings then
         if Word (Rx, 2) /= 0 then
            D.Cur_Freq := Unsigned_32 (Word (Rx, 2));
            D.Cur_Conf_Power := Word (Rx, 4);
            D.Cur_Control_Mode := Rx (6);
            D.Cur_Pit_Mode := Rx (7);
            D.Cur_Act_Power := Word (Rx, 8);
            if D.Conf_Freq = 0 then
               D.Conf_Freq := D.Cur_Freq;
            end if;
            if D.Conf_Power = 0 then
               D.Conf_Power := D.Cur_Conf_Power;
            end if;
            Code := Cmd_Settings;
         end if;
      elsif Rx (1) = Cmd_Temp then
         if Word (Rx, 6) /= 0 then
            D.Cur_Temp := (if Word (Rx, 6) >= 2 ** 15 then Integer_16 (Integer (Word (Rx, 6)) - 2 ** 16)
                           else Integer_16 (Word (Rx, 6)));
            Code := Cmd_Temp;
         end if;
      end if;
   end Handle_Response;

   procedure Reset_Receiver (D : in out Driver) is
   begin
      D.Phase := Wait_Start;
      D.Rx_Pos := 0;
   end Reset_Receiver;

   --  Bytes up to the first complete and valid reply.
   procedure Receive (D : in out Driver; Rx : Byte_Array; Code : out Byte; Consumed : out Natural)
     with Post => Consumed <= Rx'Length
   is
      C : Byte;
   begin
      Code := 0;
      Consumed := 0;
      if not D.Port_Open then
         return;
      end if;
      for I in Rx'Range loop
         pragma Loop_Invariant (Consumed = I - Rx'First);
         C := Rx (I);
         Consumed := Consumed + 1;
         if D.Rx_Pos < Frame_Length then
            D.Rx (D.Rx_Pos) := C;
            D.Rx_Pos := D.Rx_Pos + 1;
         end if;
         case D.Phase is
            when Wait_Start =>
               if C = Start_Byte then
                  D.Phase := Wait_Code;
               else
                  Reset_Receiver (D);
               end if;
            when Wait_Code =>
               if C = Cmd_Limits or else C = Cmd_Settings or else C = Cmd_Temp then
                  D.Phase := Data;
               else
                  Reset_Receiver (D);
               end if;
            when Data =>
               if D.Rx_Pos = Frame_Length then
                  declare
                     Sum : constant Byte := Checksum (D.Rx);
                  begin
                     Reset_Receiver (D);
                     if D.Rx (14) = Sum and then D.Rx (15) = 0 then
                        Handle_Response (D, Code);
                        if Code /= 0 then
                           return;
                        end if;
                     end if;
                  end;
               end if;
         end case;
      end loop;
   end Receive;

   procedure Query (D : in out Driver; Cmd : Byte; E : in out Events) is
   begin
      Reset_Receiver (D);
      Send (D, Cmd, 0, E);
   end Query;

   function Race_Locked (D : Driver) return Boolean is ((D.Cur_Control_Mode and Race_Lock) /= 0);

   ----------
   -- Init --
   ----------

   procedure Init (D : out Driver; Port_Opened : Boolean) is
   begin
      D := (others => <>);
      D.Port_Open := Port_Opened;
   end Init;

   -------------
   -- Process --
   -------------

   procedure Process (D : in out Driver; Now_Us : Unsigned_32; Rx : Byte_Array; Control_Disabled : Boolean;
                      E : out Events; Consumed : out Natural) is
      Reply   : Byte;
      Changed : Boolean := False;
      Due     : constant Boolean := Adaflight.Clock.Elapsed (Now_Us, D.Last_Time_Us) >= Min_Period_Us;
   begin
      E := (others => <>);
      Consumed := 0;
      if not D.Port_Open then
         return;
      end if;
      Receive (D, Rx, Reply, Consumed);
      case D.Current is
         when Offline =>
            if Reply = Cmd_Limits then
               D.Current := Init;
            elsif Due then
               Query (D, Cmd_Limits, E);
               D.Last_Time_Us := Now_Us;
            end if;
         when Init =>
            if Reply = Cmd_Settings then
               D.Current := Monitor_Settings;
            elsif Due then
               Query (D, Cmd_Settings, E);
               D.Last_Time_Us := Now_Us;
            end if;
         when Monitor_Settings =>
            if D.Retry_Count > 0 and then Due then
               if not Race_Locked (D) and then D.Conf_Freq /= D.Cur_Freq then
                  Send_Command (D, Cmd_Set_Freq, Unsigned_16'Mod (D.Conf_Freq), Control_Disabled, E);
                  Changed := True;
               elsif not Race_Locked (D) and then D.Conf_Power /= D.Cur_Conf_Power then
                  Send_Command (D, Cmd_Set_Power, D.Conf_Power, Control_Disabled, E);
                  Changed := True;
               elsif D.Conf_Pit_Mode /= D.Cur_Pit_Mode then
                  Send_Command (D, Cmd_Active, (if D.Conf_Pit_Mode /= 0 then 0 else 1), Control_Disabled, E);
                  Changed := True;
               end if;
               if Changed then
                  D.Retry_Count := D.Retry_Count - 1;
                  D.Last_Time_Us := Now_Us;
                  D.Current := Config;
               else
                  D.Retry_Count := Max_Retries;
               end if;
            end if;
            if not Changed then
               if Adaflight.Clock.Elapsed (Now_Us, D.Last_Time_Us) >= Status_Period_Us then
                  Query (D, Cmd_Settings, E);
                  D.Last_Time_Us := Now_Us;
               elsif Reply = Cmd_Settings then
                  Query (D, Cmd_Temp, E);
                  D.Current := Monitor_Temperature;
                  D.Last_Time_Us := Now_Us;
               end if;
            end if;
         when Monitor_Temperature =>
            if Reply = Cmd_Temp then
               D.Current := Monitor_Temperature;
            elsif Due then
               D.Current := Monitor_Settings;
            end if;
         when Config =>
            if Due then
               Query (D, Cmd_Settings, E);
               D.Current := Monitor_Settings;
               D.Last_Time_Us := Now_Us;
            end if;
      end case;
   end Process;

   ---------------------
   -- Set_Power_Index --
   ---------------------

   procedure Set_Power_Index (D : in out Driver; T : VTX_Table.Table; Index : Unsigned_8) is
   begin
      if VTX_Table.Has_Power_Value (T, Natural (Index)) then
         D.Conf_Power := VTX_Table.Power_Value_Of (T, Natural (Index));
         if D.Conf_Power /= D.Last_Conf_Power then
            D.Retry_Count := Max_Retries;
            D.Last_Conf_Power := D.Conf_Power;
         end if;
      end if;
   end Set_Power_Index;

   ------------------
   -- Set_Pit_Mode --
   ------------------

   procedure Set_Pit_Mode (D : in out Driver; Value : Unsigned_8) is
   begin
      D.Conf_Pit_Mode := Value;
      if D.Conf_Pit_Mode /= D.Last_Conf_Pit_Mode then
         D.Retry_Count := Max_Retries;
         D.Last_Conf_Pit_Mode := D.Conf_Pit_Mode;
      end if;
   end Set_Pit_Mode;

   -------------------
   -- Set_Frequency --
   -------------------

   procedure Set_Frequency (D : in out Driver; Freq : Unsigned_16) is
      Valid : Boolean;
   begin
      if D.Freq_Min /= 0 and then D.Freq_Max /= 0 then
         Valid := Unsigned_32 (Freq) >= D.Freq_Min and then Unsigned_32 (Freq) <= D.Freq_Max;
      else
         Valid := Freq in Min_Frequency .. Max_Frequency;
      end if;
      if Valid then
         D.Conf_Freq := Unsigned_32 (Freq);
         if D.Conf_Freq /= D.Last_Conf_Freq then
            D.Retry_Count := Max_Retries;
            D.Last_Conf_Freq := D.Conf_Freq;
         end if;
      end if;
   end Set_Frequency;

   ----------------------
   -- Get_Band_Channel --
   ----------------------

   procedure Get_Band_Channel (D : Driver; Band, Channel : out Unsigned_8; Known : out Boolean) is
   begin
      Band := 0;
      Channel := 0;
      Known := Ready (D);
   end Get_Band_Channel;

   ---------------------
   -- Get_Power_Index --
   ---------------------

   function Power_Found (D : Driver; T : VTX_Table.Table) return Boolean is
     (for some I in 1 .. T.Power_Levels => D.Conf_Power = T.Power_Value (I));

   procedure Read_Power_Index (D : Driver; T : VTX_Table.Table; Index : in out Unsigned_8) is
   begin
      if not Ready (D) then
         return;
      end if;
      if D.Conf_Power = 0 then
         Index := 0;
         return;
      end if;
      for I in 1 .. T.Power_Levels loop
         if D.Conf_Power = T.Power_Value (I) then
            Index := Unsigned_8 (I);
            return;
         end if;
      end loop;
   end Read_Power_Index;

   procedure Get_Power_Index (D : Driver; T : VTX_Table.Table; Index : in out Unsigned_8; Known : out Boolean) is
   begin
      Read_Power_Index (D, T, Index);
      Known := Ready (D) and then (D.Conf_Power = 0 or else Power_Found (D, T));
   end Get_Power_Index;

   -------------------
   -- Get_Frequency --
   -------------------

   procedure Get_Frequency (D : Driver; Freq : out Unsigned_16; Known : out Boolean) is
   begin
      Known := Ready (D);
      Freq := (if Known then Unsigned_16'Mod (D.Cur_Freq) else 0);
   end Get_Frequency;

   ----------------
   -- Get_Status --
   ----------------

   procedure Get_Status (D : Driver; Pit_Mode, Locked : out Boolean; Known : out Boolean) is
   begin
      Known := Ready (D);
      Pit_Mode := Known and then D.Conf_Pit_Mode /= 0;
      Locked := Known and then Race_Locked (D);
   end Get_Status;

   ------------------
   -- Get_Pit_Mode --
   ------------------

   procedure Get_Pit_Mode (D : Driver; Pit_Mode : out Boolean; Known : out Boolean) is
   begin
      Known := Ready (D);
      Pit_Mode := Known and then D.Conf_Pit_Mode /= 0;
   end Get_Pit_Mode;

end Adaflight.Tramp;
