with Adaflight.MSP_Battery_In;
with Adaflight.MSP_Blackbox_In;
with Adaflight.MSP_Box;
with Adaflight.MSP_CLI_Setting;
with Adaflight.MSP_Feature_In;
with Adaflight.MSP_Hardware_In;
with Adaflight.MSP_Hardware_Out;
with Adaflight.MSP_OSD_Out;
with Adaflight.MSP_Peripheral_Out;
with Adaflight.MSP_Receiver_Out;
with Adaflight.MSP_Simplified_Tuning;
with Adaflight.MSP_Text_Out;

package body Adaflight.MSP_Processor with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type MSP_Battery_In.Result;
   use type MSP_Blackbox_In.Result;
   use type MSP_Board_In.Result;
   use type MSP_CLI_Setting.Result;
   use type MSP_Control_In.Result;
   use type MSP_Feature_In.Result;
   use type MSP_Font_In.Result;
   use type MSP_Hardware_In.Result;
   use type MSP_LED_In.Result;
   use type MSP_Motor_In.Result;
   use type MSP_OSD_In.Result;
   use type MSP_Peripheral_In.Result;
   use type MSP_Receiver_In.Result;
   use type MSP_Runtime_In.Result;
   use type MSP_Servo_In.Result;
   use type MSP_Text_In.Result;
   use type MSP_Tuning_In.Result;
   use type MSP_VTX_In.Result;
   use type RX_Bind.Bind;

   --  The room the longest reply of the out stages takes.
   Stage_Reply_Length : constant := 300;

   procedure Write_Text (B : in out Byte_Array; S : in out Stream; Reply : MSP_CLI_Setting.Reply_Text)
     with Pre  => Fits (S, B) and then Remaining (S) >= Reply.Length,
          Post => Fits (S, B) and then S.Last = S.Last'Old and then S.Next = S.Next'Old + Reply.Length;

   procedure Write_Text (B : in out Byte_Array; S : in out Stream; Reply : MSP_CLI_Setting.Reply_Text) is
   begin
      for K in 1 .. Reply.Length loop
         pragma Loop_Invariant (Fits (S, B));
         pragma Loop_Invariant (S.Last = S.Last'Loop_Entry);
         pragma Loop_Invariant (S.Next = S.Next'Loop_Entry + (K - 1));
         Write_U8 (B, S, Byte (Character'Pos (Reply.Text (K))));
      end loop;
   end Write_Text;

   --  The common out replies and the state and configuration replies: the
   --  stages the reference runs before the replies with an argument, and the
   --  stages a request for several replies in one runs again. Acked says a
   --  unit answered; a reply the build or the state leaves out is not acked.
   procedure Out_Reply
     (Ctx : Context; C : Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array;
      B : in out Byte_Array; S : in out Stream; Acked : out Boolean; E : in out Effects)
     with Pre  => Request'Length <= Max_Request and then Profiles_Valid (C)
                  and then Fits (S, B) and then Remaining (S) >= Stage_Reply_Length
                  and then MSP_Common_Out.Consistent (Ctx.Out_Views.Common),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then S.Next - S.Next'Old in 0 .. Stage_Reply_Length
                  and then (if not Acked then S.Next = S.Next'Old);

   procedure Out_Reply
     (Ctx : Context; C : Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array;
      B : in out Byte_Array; S : in out Stream; Acked : out Boolean; E : in out Effects)
   is
      V : Views renames Ctx.Out_Views;
   begin
      Acked := False;
      if MSP_Common_Out.Handles (Command) then
         declare
            CV : MSP_Common_Out.Snapshot := V.Common;
         begin
            MSP_Views.Common_View (C, CV);
            if MSP_Common_Out.Supported (Command, CV) then
               MSP_Common_Out.Reply (B, S, Command, CV);
               Acked := True;
            end if;
         end;
      elsif Command in MSP_OSD_Out.OSD_Config_Command | MSP_OSD_Out.OSD_Warnings_Command then
         declare
            OV : constant MSP_OSD_Out.Snapshot := MSP_Views.OSD_View (C, V.OSD);
         begin
            if MSP_OSD_Out.Handles (Command, OV) then
               MSP_OSD_Out.Reply (B, S, Command, OV);
               Acked := True;
            end if;
         end;
      elsif MSP_Out.Handles (Command) then
         if MSP_Out.Supported (Command, V.State) then
            MSP_Out.Reply (B, S, Command, V.State);
            Acked := True;
         end if;
      elsif MSP_Hardware_Out.Handles (Command) then
         declare
            HV : constant MSP_Hardware_Out.Snapshot := MSP_Views.Hardware_View (C, V.Hardware);
         begin
            if MSP_Hardware_Out.Supported (Command, HV) then
               MSP_Hardware_Out.Reply (B, S, Command, HV);
               Acked := True;
            end if;
         end;
      elsif MSP_Tuning_Out.Handles (Command) then
         MSP_Tuning_Out.Reply (B, S, Command, MSP_Views.Tuning_View (C, V.Build, V.Detected_Flags));
         Acked := True;
      elsif MSP_Receiver_Out.Handles (Command) then
         MSP_Receiver_Out.Reply (B, S, Command, MSP_Views.Receiver_View (C, V.Receiver));
         Acked := True;
      elsif MSP_Peripheral_Out.Handles (Command) then
         declare
            PV : constant MSP_Peripheral_Out.Snapshot := MSP_Views.Peripheral_View (C, V.Peripheral);
         begin
            if MSP_Peripheral_Out.Supported (Command, PV) then
               MSP_Peripheral_Out.Reply (B, S, Command, PV);
               Acked := True;
               if Command = MSP_Peripheral_Out.VTX_Config_Command then
                  E.Peripheral.VTX_Ready := True;
               end if;
            end if;
         end;
      elsif MSP_Serial_Out.Handles (Command) then
         MSP_Serial_Out.Reply (B, S, Command, MSP_Views.Serial_View (C, V.Serial_Ports, V.Serial_Count));
         Acked := True;
      elsif MSP_VTX_Status_Out.Handles (Command, V.VTX_Status) then
         MSP_VTX_Status_Out.Reply (B, S, Command, V.VTX_Status);
         Acked := True;
      elsif Command = MSP_Text_Out.Name_Command then
         MSP_Text_Out.Reply (B, S, Command, Request, MSP_Views.Text_View (C, V.Text), Acked);
      end if;
   end Out_Reply;

   --  Whether a command belongs to the out stages, answered or left out.
   function Out_Stage (Command : Interfaces.Unsigned_16) return Boolean is
     (MSP_Common_Out.Handles (Command) or else MSP_Out.Handles (Command)
      or else MSP_Hardware_Out.Handles (Command) or else MSP_Tuning_Out.Handles (Command)
      or else MSP_Receiver_Out.Handles (Command) or else MSP_Peripheral_Out.Handles (Command)
      or else MSP_Serial_Out.Handles (Command)
      or else Command in MSP_OSD_Out.OSD_Config_Command | MSP_OSD_Out.OSD_Warnings_Command
                       | MSP_VTX_Status_Out.Device_Status_Command | MSP_Text_Out.Name_Command);

   --  Several replies in one: each requested command's reply behind its size
   --  byte, as many as fit the room, with a request that names a reply the
   --  stages leave out, or one longer than its size byte holds, answered as an
   --  error (finding F288).
   procedure Multiple_Reply
     (Ctx : Context; C : Configuration; Request : Byte_Array; B : in out Byte_Array; S : in out Stream;
      R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request and then Profiles_Valid (C) and then Fits (S, B)
                  and then Remaining (S) >= Max_Reply_Length
                  and then MSP_Common_Out.Consistent (Ctx.Out_Views.Common),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then S.Next >= S.Next'Old;

   procedure Multiple_Reply
     (Ctx : Context; C : Configuration; Request : Byte_Array; B : in out Byte_Array; S : in out Stream;
      R : out Result; E : in out Effects)
   is
      Acked : Boolean;
   begin
      R := Error;
      if Request'Length > 0 then
         declare
            Scratch : Byte_Array (0 .. Stage_Reply_Length - 1) := (others => 0);
            SS      : Stream;
            Room    : Integer := Remaining (S);
            Count   : Natural := 0;
            Failed  : Boolean := False;
         begin
            for K in Request'Range loop
               pragma Loop_Invariant (Count <= K - Request'First);
               exit when Room <= 0;
               Init (SS, 0, Scratch'Length);
               Out_Reply (Ctx, C, Interfaces.Unsigned_16 (Request (K)), Request (K + 1 .. K), Scratch, SS,
                          Acked, E);
               if not Acked or else SS.Next > 255 then
                  Failed := True;
                  exit;
               end if;
               Room := Room - (SS.Next + 1);
               if Room >= 0 then
                  Count := Count + 1;
               end if;
            end loop;
            if not Failed then
               for K in Request'First .. Request'First + Count - 1 loop
                  pragma Loop_Invariant (Fits (S, B));
                  pragma Loop_Invariant (S.Last = S.Last'Loop_Entry);
                  pragma Loop_Invariant (S.Next >= S.Next'Loop_Entry);
                  Init (SS, 0, Scratch'Length);
                  Out_Reply (Ctx, C, Interfaces.Unsigned_16 (Request (K)), Request (K + 1 .. K), Scratch, SS,
                             Acked, E);
                  exit when not Acked or else SS.Next > 255 or else Remaining (S) < SS.Next + 1;
                  Write_U8 (B, S, Byte (SS.Next));
                  Write_Data (B, S, Scratch (0 .. SS.Next - 1));
               end loop;
               R := Ack;
            end if;
         end;
      end if;
   end Multiple_Reply;

   --  The replies with an argument and the passthrough request: the box names
   --  and ids, several replies in one, the restart, the texts with an argument,
   --  the simplified tuning, the configuration reset, the command line setting
   --  and its information, and the passthrough.
   procedure With_Argument
     (Ctx     : Context;
      C       : in out Configuration;
      Board   : in out Board_Info.State;
      Command : Interfaces.Unsigned_16;
      Request : Byte_Array;
      Ports   : Port_List;
      B       : in out Byte_Array;
      S       : in out Stream;
      R       : out Result;
      E       : in out Effects;
      Handled : out Boolean)
     with Pre  => Request'Length <= Max_Request and then Ports'Length <= Serial_Feature_Map.Max_Ports
                  and then Profiles_Valid (C) and then Fits (S, B) and then Remaining (S) >= Max_Reply_Length
                  and then MSP_Common_Out.Consistent (Ctx.Out_Views.Common),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then S.Next >= S.Next'Old
                  and then (if not Handled then C = C'Old and then S.Next = S.Next'Old);

   procedure With_Argument
     (Ctx     : Context;
      C       : in out Configuration;
      Board   : in out Board_Info.State;
      Command : Interfaces.Unsigned_16;
      Request : Byte_Array;
      Ports   : Port_List;
      B       : in out Byte_Array;
      S       : in out Stream;
      R       : out Result;
      E       : in out Effects;
      Handled : out Boolean)
   is
      Acked : Boolean;
   begin
      Handled := True;
      R := Error;
      if Command in Box_Names_Command | Box_Ids_Command then
         MSP_Box.Serialize_Box_Reply
           (B, S, Ctx.Out_Views.Active, (if Request'Length > 0 then Natural (Request (Request'First)) else 0),
            (if Command = Box_Names_Command then MSP_Box.Box_Names else MSP_Box.Box_Permanent_Ids),
            MSP_Views.Box_Names (C));
         R := Ack;
      elsif Command = Multiple_Command then
         Multiple_Reply (Ctx, C, Request, B, S, R, E);
      elsif MSP_Text_Out.Handles (Command, MSP_Views.Text_View (C, Ctx.Out_Views.Text)) then
         MSP_Text_Out.Reply (B, S, Command, Request, MSP_Views.Text_View (C, Ctx.Out_Views.Text), Acked);
         R := (if Acked then Ack else Error);
         if Command in MSP_Text_Out.VTX_Table_Band_Command | MSP_Text_Out.VTX_Table_Power_Command then
            E.Peripheral.VTX_Ready := True;
         end if;
      elsif MSP_Simplified_Tuning.Handles (Command) then
         MSP_Simplified_Tuning.Reply
           (B, S, Command, Request, Ctx.Out_Views.Simplified_P, Ctx.Out_Views.Simplified_G, Acked);
         R := (if Acked then Ack else Error);
      elsif MSP_Board_In.Handles (Command) then
         declare
            BR : MSP_Board_In.Result;
         begin
            MSP_Board_In.Process (C, Board, Command, Request, Ctx.Control.Armed, BR, E.Board);
            R := (if BR = MSP_Board_In.Ack then Ack else Error);
            E.Save := E.Board.Save;
            E.Reboot := E.Board.Reboot;
            if E.Board.Reply then
               Write_U8 (B, S, E.Board.Reply_Value);
            end if;
         end;
      elsif MSP_CLI_Setting.Handles (Command) then
         declare
            SR    : MSP_CLI_Setting.Result;
            Reply : MSP_CLI_Setting.Reply_Text;
         begin
            MSP_CLI_Setting.Process (C, Request, Ports, SR, Reply);
            R := (if SR = MSP_CLI_Setting.Ack then Ack else Error);
            Write_Text (B, S, Reply);
         end;
      elsif MSP_CLI_Setting.Handles_Info (Command) then
         declare
            SR    : MSP_CLI_Setting.Result;
            Reply : MSP_CLI_Setting.Info_Reply;
            Room  : Natural;
         begin
            MSP_CLI_Setting.Setting_Info (C, Request, Ports, SR, Reply);
            R := (if SR = MSP_CLI_Setting.Ack then Ack else Error);
            Room := Natural'Min (Reply.Length, Remaining (S));
            Write_Data (B, S, Reply.Data (0 .. Room - 1));
         end;
      elsif Command = Set_Passthrough_Command then
         declare
            Mode : constant Byte := (if Request'Length = 0 then Passthrough_ESC_4Way else Request (Request'First));
            Arg  : constant Byte := (if Request'Length >= 2 then Request (Request'First + 1) else 0);
         begin
            E.Passthrough := True;
            E.Passthrough_Mode := Mode;
            E.Passthrough_Argument := Arg;
            case Mode is
               when Passthrough_ESC_4Way =>
                  Write_U8 (B, S, Byte (Ctx.Motors));
               when Passthrough_ESC_First .. Passthrough_ESC_Last =>
                  Write_U8 (B, S, (if Natural (Arg) < Ctx.Motors
                                    or else (Mode = Passthrough_ESC_KISS and then Arg = All_Motors)
                                   then 1 else 0));
               when others =>
                  Write_U8 (B, S, 0);
            end case;
            R := Ack;
         end;
      else
         Handled := False;
      end if;
   end With_Argument;

   --  The common in messages and the in messages.
   procedure In_Message
     (Ctx     : Context;
      C       : in out Configuration;
      Links   : in out MSP_Control_In.Link_State;
      Command : Interfaces.Unsigned_16;
      Request : Byte_Array;
      B       : in out Byte_Array;
      S       : in out Stream;
      R       : out Result;
      E       : in out Effects;
      Handled : out Boolean)
     with Pre  => Request'Length <= Max_Request and then Profiles_Valid (C) and then Fits (S, B)
                  and then Remaining (S) >= Max_Reply_Length,
          Post => Fits (S, B) and then S.Last = S.Last'Old and then S.Next >= S.Next'Old;

   procedure In_Message
     (Ctx     : Context;
      C       : in out Configuration;
      Links   : in out MSP_Control_In.Link_State;
      Command : Interfaces.Unsigned_16;
      Request : Byte_Array;
      B       : in out Byte_Array;
      S       : in out Stream;
      R       : out Result;
      E       : in out Effects;
      Handled : out Boolean)
   is
   begin
      Handled := True;
      R := Error;
      if MSP_Control_In.Handles (Command) then
         declare
            CR : MSP_Control_In.Result;
         begin
            MSP_Control_In.Process (C, Links, Command, Request, Ctx.Control, CR, E.Control);
            R := (if CR = MSP_Control_In.Ack then Ack else Error);
            E.Save := E.Control.Save;
            E.Reboot := E.Control.Reboot;
            for K in 0 .. E.Control.Reply_Length - 1 loop
               pragma Loop_Invariant (Fits (S, B));
               pragma Loop_Invariant (S.Last = S.Last'Loop_Entry);
               pragma Loop_Invariant (S.Next = S.Next'Loop_Entry + K);
               Write_U8 (B, S, E.Control.Reply (K));
            end loop;
         end;
      elsif MSP_Peripheral_In.Handles (Command) then
         declare
            PR : MSP_Peripheral_In.Result;
         begin
            MSP_Peripheral_In.Process (C, Command, Request, PR, E.Peripheral);
            R := (if PR = MSP_Peripheral_In.Ack then Ack else Error);
            E.Tuning.PID_Init := E.Peripheral.PID_Init;
         end;
      elsif MSP_Battery_In.Handles (Command) then
         declare
            BR : MSP_Battery_In.Result;
         begin
            MSP_Battery_In.Process (C, Command, Request, BR);
            R := (if BR = MSP_Battery_In.Ack then Ack else Error);
         end;
      elsif MSP_OSD_In.Handles (Command) then
         declare
            OR_Result : MSP_OSD_In.Result;
         begin
            MSP_OSD_In.Process (C, Command, Request, OR_Result, E.OSD);
            R := (if OR_Result = MSP_OSD_In.Ack then Ack else Error);
            E.Text.OSD_Elements := E.OSD.OSD_Elements;
            E.Save := E.OSD.Save;
            E.Reboot := E.OSD.Reboot;
         end;
      elsif MSP_Font_In.Handles (Command) then
         declare
            FR : MSP_Font_In.Result;
         begin
            MSP_Font_In.Process (Request, Ctx.OSD_Port, FR, E.Font);
            R := (if FR = MSP_Font_In.Ack and then Ctx.Font_Write_Taken then Ack else Error);
         end;
      elsif MSP_Profile_In.Handles (Command) then
         MSP_Profile_In.Process (C, Command, Request, Ctx.Control.Armed, E.Profile);
         R := Ack;
         E.Tuning.ESC_Endpoints := E.Profile.PID_Profile;
         E.Tuning.Mixer_Profile := E.Profile.PID_Profile;
         E.Tuning.RC_Init := E.Profile.Rate_Profile;
      elsif MSP_Runtime_In.Handles (Command) then
         declare
            RR : MSP_Runtime_In.Result;
         begin
            MSP_Runtime_In.Process (Command, Request, RR, E.Runtime);
            R := (if RR = MSP_Runtime_In.Ack then Ack else Error);
         end;
      elsif MSP_Tuning_In.Handles (Command) then
         declare
            TR : MSP_Tuning_In.Result;
         begin
            MSP_Tuning_In.Process (C, Command, Request, Ctx.Gyro_Sample_Rate_Hz, TR, E.Tuning);
            R := (if TR = MSP_Tuning_In.Ack then Ack else Error);
         end;
      elsif MSP_Receiver_In.Handles (Command) then
         declare
            RR : MSP_Receiver_In.Result;
         begin
            MSP_Receiver_In.Process (C, Command, Request, RR, E.Receiver);
            R := (if RR = MSP_Receiver_In.Ack then Ack else Error);
         end;
      elsif MSP_Hardware_In.Handles (Command) then
         declare
            HR : MSP_Hardware_In.Result;
         begin
            MSP_Hardware_In.Process (C, Command, Request, HR);
            R := (if HR = MSP_Hardware_In.Ack then Ack else Error);
         end;
      elsif MSP_Motor_In.Handles (Command) then
         declare
            MR : MSP_Motor_In.Result;
         begin
            MSP_Motor_In.Process (Request, Ctx.Motors, Ctx.Motor_Device, Ctx.Three_D, MR, E.Motor);
            R := (if MR = MSP_Motor_In.Ack then Ack else Error);
         end;
      elsif MSP_Servo_In.Handles (Command) then
         declare
            SR : MSP_Servo_In.Result;
         begin
            MSP_Servo_In.Process (C, Command, Request, SR, E.Servo);
            R := (if SR = MSP_Servo_In.Ack then Ack else Error);
         end;
      elsif MSP_Blackbox_In.Handles (Command) then
         declare
            LR : MSP_Blackbox_In.Result;
         begin
            MSP_Blackbox_In.Process (C, Command, Request, Ctx.Log, Ctx.Loop_Time, LR);
            R := (if LR = MSP_Blackbox_In.Ack then Ack else Error);
         end;
      elsif MSP_VTX_In.Handles (Command) then
         declare
            VR : MSP_VTX_In.Result;
         begin
            MSP_VTX_In.Process (C, Command, Request, Ctx.VTX_Device, Ctx.VTX_Table, VR, E.VTX);
            R := (if VR = MSP_VTX_In.Ack then Ack else Error);
            E.Peripheral.VTX_Ready := E.VTX.VTX_Ready;
         end;
      elsif MSP_Feature_In.Handles (Command) then
         declare
            FR : MSP_Feature_In.Result;
         begin
            MSP_Feature_In.Process (C, Command, Request, FR);
            R := (if FR = MSP_Feature_In.Ack then Ack else Error);
         end;
      elsif MSP_Text_In.Handles (Command) then
         declare
            TR : MSP_Text_In.Result;
         begin
            MSP_Text_In.Process (C, Command, Request, TR, E.Text);
            R := (if TR = MSP_Text_In.Ack then Ack else Error);
         end;
      elsif MSP_LED_In.Handles (Command) then
         declare
            LR : MSP_LED_In.Result;
         begin
            MSP_LED_In.Process (C, Command, Request, LR, E.LED);
            R := (if LR = MSP_LED_In.Ack then Ack else Error);
         end;
      elsif RX_Bind.Handles (Command) then
         E.Bind := RX_Bind.Bind_For (Ctx.Receiver_Source, Ctx.Serial_Protocol,
                                     Natural (C.Rx_Spi_Config.Rx_Spi_Protocol));
         R := (if E.Bind = RX_Bind.No_Bind then Error else Ack);
      else
         Handled := False;
      end if;
   end In_Message;

   procedure Process
     (Ctx     : Context;
      C       : in out Configuration;
      Board   : in out Board_Info.State;
      Links   : in out MSP_Control_In.Link_State;
      Command : Interfaces.Unsigned_16;
      Request : Byte_Array;
      Ports   : Port_List;
      B       : in out Byte_Array;
      S       : in out Stream;
      R       : out Result;
      E       : out Effects)
   is
      Acked : Boolean;
   begin
      E := (others => <>);
      R := Error;
      Out_Reply (Ctx, C, Command, Request, B, S, Acked, E);
      if Acked then
         R := Ack;
         E.Handled := True;
      elsif Out_Stage (Command) then
         E.Handled := True;
      else
         With_Argument (Ctx, C, Board, Command, Request, Ports, B, S, R, E, Acked);
         if not Acked then
            In_Message (Ctx, C, Links, Command, Request, B, S, R, E, Acked);
         end if;
         E.Handled := Acked;
      end if;
   end Process;

end Adaflight.MSP_Processor;
