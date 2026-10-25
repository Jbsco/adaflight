package body Adaflight.SmartAudio with SPARK_Mode is

   Cmd_Timeout_Ms     : constant := 120;
   Polling_Interval   : constant := 150;
   Polling_Window     : constant := 1000;
   Polynomial         : constant Byte := 16#D5#;
   Preamble_1         : constant Byte := 16#AA#;
   Preamble_2         : constant Byte := 16#55#;

   function Command_Code (Cmd : Unsigned_8) return Byte is (Interfaces.Shift_Left (Cmd, 1) or 1);

   function Powf (X, Y : Float) return Float
     with Import, Convention => C, External_Name => "powf", Global => null;

   function To_Int8 (B : Unsigned_8) return Integer_8 is
     (if B >= 128 then Integer_8 (Integer (B) - 256) else Integer_8 (B));

   function To_Byte (I : Integer_8) return Unsigned_8 is
     (if I < 0 then Unsigned_8 (Integer (I) + 256) else Unsigned_8 (I));

   --  The checksum over the whole command frame but its last byte.
   function Crc_Of (F : Frame) return Byte is
     (CRC8_Update (0, F.Data (0 .. F.Length - 2), Polynomial))
     with Pre => F.Length >= 2;

   procedure Finish (F : in out Frame)
     with Pre  => F.Length in 2 .. Max_Frame,
          Post => F.Length = F.Length'Old
   is
   begin
      F.Data (F.Length - 1) := Crc_Of (F);
   end Finish;

   function Queue_Empty (D : Driver) return Boolean is (D.Head = D.Tail);
   function Queue_Full (D : Driver) return Boolean is ((D.Head + 1) mod Queue_Size = D.Tail);

   procedure Enqueue (D : in out Driver; F : Frame) is
   begin
      if Queue_Full (D) then
         return;
      end if;
      D.Pending (D.Head) := F;
      D.Head := (D.Head + 1) mod Queue_Size;
   end Enqueue;

   procedure Send_Frame (D : in out Driver; F : Frame; Now_Ms : Unsigned_32; Control_Disabled, Prepend_Zero : Boolean;
                         E : in out Events) is
      Pos : Tx_Length := 0;
   begin
      if not Control_Disabled then
         if Prepend_Zero then
            E.Tx (0) := 0;
            Pos := 1;
         end if;
         for I in 0 .. F.Length - 1 loop
            E.Tx (Pos + I) := F.Data (I);
         end loop;
         E.Tx_Count := Pos + F.Length;
         D.Stat.Sent := D.Stat.Sent + 1;
      else
         D.Outstanding := Cmd_None;
      end if;
      D.Last_Tx_Ms := Now_Ms;
   end Send_Frame;

   procedure Send_Command (D : in out Driver; F : Frame; Now_Ms : Unsigned_32; Control_Disabled, Prepend_Zero : Boolean;
                           E : in out Events)
     with Pre => F.Length >= 3
   is
   begin
      D.Outstanding_Frame := F;
      D.Outstanding := Interfaces.Shift_Right (F.Data (2), 1);
      Send_Frame (D, F, Now_Ms, Control_Disabled, Prepend_Zero, E);
   end Send_Command;

   procedure Send_Queue (D : in out Driver; Now_Ms : Unsigned_32; Control_Disabled, Prepend_Zero : Boolean;
                         E : in out Events) is
      F : constant Frame := D.Pending (D.Tail);
   begin
      if Queue_Empty (D) or else F.Length < 3 then
         return;
      end if;
      Send_Command (D, F, Now_Ms, Control_Disabled, Prepend_Zero, E);
      D.Tail := (D.Tail + 1) mod Queue_Size;
   end Send_Queue;

   procedure Queue_Get_Settings (D : in out Driver) is
   begin
      Enqueue (D, (Data => (Preamble_1, Preamble_2, Command_Code (Cmd_Get_Settings), 0, 16#9F#, 0, 0), Length => 5));
   end Queue_Get_Settings;

   --  The settings response: the version from the code, the channel, the
   --  power as the table numbers it, the mode, the frequency, the boot
   --  flag while in pit mode, and the power levels of a 2.1 device.
   procedure Process_Settings (D : in out Driver; T : VTX_Table.Table; Code : Byte; Len : Natural)
     with Pre => Len in 7 .. Max_Receive
   is
      Raw_Power : Unsigned_8 := D.Rx (3);
   begin
      D.Device.Version_Seen := (if Code = Cmd_Get_Settings then V1 elsif Code = Rsp_Settings_V2 then V2 else V21);
      D.Device.Channel := To_Int8 (D.Rx (2));
      D.Device.Mode := D.Rx (4);
      D.Device.Freq := Interfaces.Shift_Left (Unsigned_16 (D.Rx (5)), 8) or Unsigned_16 (D.Rx (6));
      if (D.Device.Mode and Mode_Pit) /= 0 then
         D.Device.Will_Boot_Into_Pit_Mode :=
           (D.Device.Mode and Mode_In_Range_Pit) /= 0 or else (D.Device.Mode and Mode_Out_Range_Pit) /= 0;
      end if;
      if D.Device.Version_Seen = V21 then
         if Len < 10 then
            return;
         end if;
         D.Levels := Natural (Unsigned_8'Min (Unsigned_8 (Integer'Max (0, Integer (To_Int8 (D.Rx (8))))), Max_Levels));
         for I in 0 .. D.Levels - 1 loop
            D.Level_Value (I) := Unsigned_16 (D.Rx (10 + I));
         end loop;
         Raw_Power := D.Rx (7);
      end if;
      D.Device.Power := 0;
      for I in 1 .. T.Power_Levels loop
         if Unsigned_16 (Raw_Power) = T.Power_Value (I) then
            D.Device.Power := Integer_8 (I);
         end if;
      end loop;
   end Process_Settings;

   --  A response: the outstanding command is cleared by its code or by a
   --  settings code of a later version, then the response is read.
   procedure Process_Response (D : in out Driver; T : VTX_Table.Table; Len : Natural; Control_Disabled : Boolean;
                               Known : out Boolean)
     with Pre => Len in 2 .. Max_Receive
   is
      Code : constant Byte := D.Rx (0);
      Word : Unsigned_16;
   begin
      Known := False;
      if Control_Disabled then
         D.Outstanding := Cmd_None;
         return;
      end if;
      Known := True;
      if Code = D.Outstanding then
         D.Outstanding := Cmd_None;
      elsif (Code = Rsp_Settings_V2 or else Code = Rsp_Settings_V21) and then D.Outstanding = Cmd_Get_Settings then
         D.Outstanding := Cmd_None;
      else
         D.Stat.Out_Of_Order := D.Stat.Out_Of_Order + 1;
      end if;
      if Code = Cmd_Get_Settings or else Code = Rsp_Settings_V2 or else Code = Rsp_Settings_V21 then
         if Len >= 7 then
            Process_Settings (D, T, Code, Len);
         end if;
      elsif Code = Cmd_Set_Power or else Code = Cmd_Set_Channel or else Code = Cmd_Set_Mode then
         null;
      elsif Code = Cmd_Set_Freq then
         if Len >= 5 then
            Word := Interfaces.Shift_Left (Unsigned_16 (D.Rx (2)), 8) or Unsigned_16 (D.Rx (3));
            if (Word and Freq_Get_Pit) /= 0 or else (Word and Freq_Set_Pit) /= 0 then
               D.Device.Pit_Freq := Word and Freq_Mask;
            else
               D.Device.Freq := Word;
            end if;
         end if;
      else
         D.Stat.Bad_Code := D.Stat.Bad_Code + 1;
         Known := False;
      end if;
   end Process_Response;

   --  One byte of the line: the two preamble bytes, the code, the length,
   --  the payload and the checksum over the code, the length and the
   --  payload. A frame with an odd code is the echo of a command.
   procedure Receive_Byte (D : in out Driver; T : VTX_Table.Table; C : Byte; Control_Disabled : Boolean;
                           Processed, Changed : out Boolean) is
      Known : Boolean;
   begin
      Processed := False;
      Changed := False;
      case D.Phase is
         when Wait_Preamble_1 =>
            if C = Preamble_1 then
               D.Phase := Wait_Preamble_2;
            end if;
         when Wait_Preamble_2 =>
            if C = Preamble_2 then
               D.Phase := Wait_Code;
            else
               D.Stat.Bad_Preamble := D.Stat.Bad_Preamble + 1;
               D.Phase := Wait_Preamble_1;
            end if;
         when Wait_Code =>
            D.Rx (0) := C;
            D.Phase := Wait_Length;
         when Wait_Length =>
            D.Rx (1) := C;
            if Natural (C) > Max_Receive - 2 then
               D.Stat.Bad_Length := D.Stat.Bad_Length + 1;
               D.Phase := Wait_Preamble_1;
            elsif C = 0 then
               D.Rx_Length := 0;
               D.Phase := Wait_Crc;
            else
               D.Rx_Length := Natural (C);
               D.Rx_Fill := 0;
               D.Phase := Payload;
            end if;
         when Payload =>
            if D.Rx_Fill < D.Rx_Length then
               D.Rx (2 + D.Rx_Fill) := C;
               D.Rx_Fill := D.Rx_Fill + 1;
            end if;
            if D.Rx_Fill >= D.Rx_Length then
               D.Phase := Wait_Crc;
            end if;
         when Wait_Crc =>
            if CRC8_Update (0, D.Rx (0 .. 1 + D.Rx_Length), Polynomial) = C then
               Process_Response (D, T, D.Rx_Length + 2, Control_Disabled, Known);
               if Known then
                  Processed := True;
                  Changed := D.Device /= D.Prev_Device;
                  D.Prev_Device := D.Device;
               end if;
               D.Stat.Received := D.Stat.Received + 1;
            elsif (D.Rx (0) and 1) = 0 then
               D.Stat.Crc_Errors := D.Stat.Crc_Errors + 1;
            end if;
            D.Phase := Wait_Preamble_1;
      end case;
   end Receive_Byte;

   --  Fewer than seven answers in ten frames move the line rate one step
   --  between 4800 and 4950, turning at the ends.
   procedure Autobaud (D : in out Driver; E : in out Events) is
   begin
      if D.Stat.Sent < 10 then
         return;
      end if;
      if (Unsigned_32 (D.Stat.Received) * 100) / Unsigned_32 (D.Stat.Sent) >= 70 then
         D.Stat.Sent := 0;
         D.Stat.Received := 0;
         return;
      end if;
      if D.Adjust = Up and then D.Smart_Baud = Baud'Last then
         D.Adjust := Down;
      elsif D.Adjust = Down and then D.Smart_Baud = Baud'First then
         D.Adjust := Up;
      end if;
      D.Smart_Baud := (if D.Adjust = Up then Baud'Succ (D.Smart_Baud) else Baud'Pred (D.Smart_Baud));
      E.Baud_Changed := True;
      E.New_Baud := D.Smart_Baud;
      D.Stat.Sent := 0;
      D.Stat.Received := 0;
   end Autobaud;

   ----------
   -- Init --
   ----------

   procedure Init (D : out Driver; Port_Opened : Boolean) is
   begin
      D := (others => <>);
      if Port_Opened then
         D.Port_Open := True;
         D.Level_Value := (others => 1);
      end if;
   end Init;

   -------------
   -- Process --
   -------------

   procedure Process_Line (D : in out Driver; Now_Ms : Unsigned_32; Control_Disabled, Prepend_Zero : Boolean;
                           E : out Events) is
   begin
      E := (others => <>);
      if not D.Port_Open then
         return;
      end if;
      Autobaud (D, E);
      case D.Init_State is
         when Start =>
            Queue_Get_Settings (D);
            D.Init_State := Wait_Settings;
         when Wait_Settings =>
            if D.Device.Version_Seen /= Unknown then
               if D.Device.Version_Seen = V2 then
                  Set_Frequency_Word (D, Freq_Get_Pit);
                  D.Init_State := Wait_Pit_Freq;
               else
                  D.Init_State := Done;
               end if;
               if D.Device.Version_Seen >= V2 then
                  D.Device.Will_Boot_Into_Pit_Mode := (D.Device.Mode and Mode_Pit) /= 0;
               end if;
            end if;
         when Wait_Pit_Freq =>
            if D.Device.Pit_Freq /= 0 then
               D.Init_State := Done;
            end if;
         when Done =>
            null;
      end case;
      if D.Outstanding /= Cmd_None and then Now_Ms - D.Last_Tx_Ms > Cmd_Timeout_Ms then
         declare
            Resend : constant Frame := D.Outstanding_Frame;
         begin
            Send_Frame (D, Resend, Now_Ms, Control_Disabled, Prepend_Zero, E);
         end;
         D.Last_Command_Ms := Now_Ms;
      elsif not Queue_Empty (D) then
         Send_Queue (D, Now_Ms, Control_Disabled, Prepend_Zero, E);
         D.Last_Command_Ms := Now_Ms;
      elsif Now_Ms - D.Last_Command_Ms < Polling_Window and then Now_Ms - D.Last_Tx_Ms >= Polling_Interval then
         Queue_Get_Settings (D);
         Send_Queue (D, Now_Ms, Control_Disabled, Prepend_Zero, E);
      end if;
   end Process_Line;

   -------------
   -- Process --
   -------------

   procedure Process (D : in out Driver; T : VTX_Table.Table; Now_Ms : Unsigned_32; Rx : Byte_Array;
                      Control_Disabled, Prepend_Zero : Boolean; E : out Events) is
      Ignore_Processed : Boolean;
      Ignore_Changed   : Boolean;
   begin
      if D.Port_Open then
         for I in Rx'Range loop
            Receive_Byte (D, T, Rx (I), Control_Disabled, Ignore_Processed, Ignore_Changed);
         end loop;
      end if;
      Process_Line (D, Now_Ms, Control_Disabled, Prepend_Zero, E);
   end Process;

   --------------
   -- Set_Mode --
   --------------

   procedure Set_Mode (D : in out Driver; Mode : Unsigned_8) is
      F : Frame := (Data => (Preamble_1, Preamble_2, Command_Code (Cmd_Set_Mode), 1, 0, 0, 0), Length => 6);
   begin
      F.Data (4) := (Mode and 16#3F#) or D.Lock_Mode;
      if D.Device.Version_Seen >= V21 and then (Mode and Set_Clear_Pit) /= 0
        and then ((Mode and Set_In_Range_Pit) /= 0 or else (Mode and Set_Out_Range_Pit) /= 0)
      then
         D.Device.Will_Boot_Into_Pit_Mode := True;
      end if;
      Finish (F);
      Enqueue (D, F);
   end Set_Mode;

   ------------------------
   -- Set_Frequency_Word --
   ------------------------

   procedure Set_Frequency_Word (D : in out Driver; Freq : Unsigned_16) is
      F      : Frame := (Data => (Preamble_1, Preamble_2, Command_Code (Cmd_Set_Freq), 2, 0, 0, 0), Length => 7);
      Switch : Frame;
      Near   : Unsigned_16;
   begin
      F.Data (4) := Byte (Interfaces.Shift_Right (Freq, 8));
      F.Data (5) := Byte (Freq and 16#FF#);
      Finish (F);
      if (D.Device.Mode and Mode_Freq_By_Freq) = 0 and then Freq = D.Device.Freq then
         Switch := F;
         Near := (if Freq = Max_Frequency then Freq - 1 else Freq + 1);
         Switch.Data (4) := Byte (Interfaces.Shift_Right (Near, 8));
         Switch.Data (5) := Byte (Near and 16#FF#);
         Finish (Switch);
         Enqueue (D, Switch);
         Queue_Get_Settings (D);
      end if;
      Enqueue (D, F);
   end Set_Frequency_Word;

   -----------------------
   -- Set_Pit_Frequency --
   -----------------------

   procedure Set_Pit_Frequency (D : in out Driver; Freq : Unsigned_16) is
   begin
      Set_Frequency_Word (D, Freq or Freq_Set_Pit);
   end Set_Pit_Frequency;

   ----------------------
   -- Set_Band_Channel --
   ----------------------

   procedure Set_Band_Channel (D : in out Driver; T : VTX_Table.Table; Band, Channel : Unsigned_8) is
      F : Frame := (Data => (Preamble_1, Preamble_2, Command_Code (Cmd_Set_Channel), 1, 0, 0, 0), Length => 6);
   begin
      if Band in 1 .. Unsigned_8 (T.Bands) and then Channel in 1 .. Unsigned_8 (T.Channels) then
         F.Data (4) := (Band - 1) * Unsigned_8 (T.Channels) + (Channel - 1);
         Finish (F);
         Enqueue (D, F);
      end if;
   end Set_Band_Channel;

   ---------------------
   -- Set_Power_Index --
   ---------------------

   procedure Set_Power_Index (D : in out Driver; T : VTX_Table.Table; Index : Unsigned_8) is
      F : Frame := (Data => (Preamble_1, Preamble_2, Command_Code (Cmd_Set_Power), 1, 0, 0, 0), Length => 6);
   begin
      if not Ready (D) or else not VTX_Table.Has_Power_Value (T, Natural (Index)) then
         return;
      end if;
      F.Data (4) := Byte (VTX_Table.Power_Value_Of (T, Natural (Index)) and 16#FF#);
      if D.Device.Version_Seen = V21 then
         F.Data (4) := F.Data (4) or 128;
      end if;
      Finish (F);
      Enqueue (D, F);
   end Set_Power_Index;

   ------------------
   -- Set_Pit_Mode --
   ------------------

   procedure Set_Pit_Mode (D : in out Driver; On : Boolean) is
      New_Mode : Unsigned_8;
   begin
      if not Ready (D) or else D.Device.Version_Seen < V2 then
         return;
      end if;
      if On and then D.Device.Version_Seen < V21 then
         return;
      end if;
      if D.Device.Version_Seen >= V21 and then not D.Device.Will_Boot_Into_Pit_Mode then
         if On then
            declare
               F : Frame := (Data => (Preamble_1, Preamble_2, Command_Code (Cmd_Set_Power), 1, 128, 0, 0), Length => 6);
            begin
               Finish (F);
               Enqueue (D, F);
            end;
         else
            Set_Mode (D, Set_Clear_Pit);
         end if;
         return;
      end if;
      New_Mode := (if On then 0 else Set_Clear_Pit);
      if (D.Device.Mode and Mode_Out_Range_Pit) /= 0 then
         New_Mode := New_Mode or Set_Out_Range_Pit;
      end if;
      if (D.Device.Mode and Mode_In_Range_Pit) /= 0 or else (On and then New_Mode = 0) then
         New_Mode := New_Mode or Set_In_Range_Pit;
      end if;
      Set_Mode (D, New_Mode);
   end Set_Pit_Mode;

   -------------------
   -- Set_Frequency --
   -------------------

   procedure Set_Frequency (D : in out Driver; Freq : Unsigned_16) is
   begin
      if Ready (D) and then Freq in Min_Frequency .. Max_Frequency then
         Set_Frequency_Word (D, Freq);
      end if;
   end Set_Frequency;

   --  The device's channel number split by the table's channel count, as
   --  the hardware divides: a zero count gives a zero quotient and the
   --  number itself as the remainder.
   procedure Split_Channel (D : Driver; T : VTX_Table.Table; Band, Channel : out Unsigned_8) is
      Value : constant Integer := Integer (D.Device.Channel);
   begin
      if T.Channels = 0 then
         Band := 1;
         Channel := Unsigned_8'Mod (Value + 1);
      else
         Band := Unsigned_8'Mod (Value / T.Channels + 1);
         Channel := Unsigned_8'Mod (Value rem T.Channels + 1);
      end if;
   end Split_Channel;

   ----------------------
   -- Get_Band_Channel --
   ----------------------

   procedure Get_Band_Channel (D : Driver; T : VTX_Table.Table; Band, Channel : out Unsigned_8; Known : out Boolean) is
   begin
      Band := 0;
      Channel := 0;
      Known := Ready (D);
      if Known and then (D.Device.Mode and Mode_Freq_By_Freq) = 0 then
         Split_Channel (D, T, Band, Channel);
      end if;
   end Get_Band_Channel;

   ---------------------
   -- Get_Power_Index --
   ---------------------

   procedure Get_Power_Index (D : Driver; Index : out Unsigned_8; Known : out Boolean) is
   begin
      Known := Ready (D);
      Index := (if Known then To_Byte (D.Device.Power) else 0);
   end Get_Power_Index;

   -------------------
   -- Get_Frequency --
   -------------------

   procedure Get_Frequency (D : Driver; T : VTX_Table.Table; Freq : out Unsigned_16; Known : out Boolean) is
      Band, Channel : Unsigned_8;
   begin
      Known := Ready (D);
      Freq := 0;
      if not Known then
         return;
      end if;
      if (D.Device.Mode and Mode_Freq_By_Freq) /= 0 then
         Freq := D.Device.Freq;
      else
         Split_Channel (D, T, Band, Channel);
         Freq := VTX_Table.Frequency_Of (T, Natural (Band), Natural (Channel));
      end if;
   end Get_Frequency;

   ----------------
   -- Get_Status --
   ----------------

   procedure Get_Status (D : Driver; Pit_Mode : out Boolean; Known : out Boolean) is
   begin
      Known := Ready (D) and then D.Device.Version_Seen >= V2;
      Pit_Mode := Known and then (D.Device.Mode and Mode_Pit) /= 0;
   end Get_Status;

   ----------------------
   -- Get_Power_Levels --
   ----------------------

   procedure Get_Power_Levels (D : Driver; Count : out Level_Count; Levels, Powers : out Level_Values) is
      Milliwatts : Float;
      Power      : Natural;
   begin
      Levels := (others => 0);
      Powers := (others => 0);
      Count := 0;
      if not Ready (D) or else D.Device.Version_Seen < V2 then
         return;
      end if;
      Count := D.Levels;
      for I in 0 .. D.Levels - 1 loop
         Levels (I) := D.Level_Value (I);
         Milliwatts := Powf (10.0, Float (Levels (I)) / 10.0);
         Power := Natural (Float'Truncation (Float'Max (0.0, Float'Min (Milliwatts, 65535.0))));
         if Levels (I) > 14 then
            Power := 50 * ((Power + 25) / 50);
         end if;
         Powers (I) := Unsigned_16'Mod (Power);
      end loop;
   end Get_Power_Levels;

   -------------------
   -- Custom_Status --
   -------------------

   function Custom_Status (D : Driver) return Status_Bytes is
     (5, Version'Pos (D.Device.Version_Seen), D.Device.Mode,
      Byte (D.Device.Pit_Freq and 16#FF#), Byte (Interfaces.Shift_Right (D.Device.Pit_Freq, 8)),
      Boolean'Pos (D.Device.Will_Boot_Into_Pit_Mode));

end Adaflight.SmartAudio;
