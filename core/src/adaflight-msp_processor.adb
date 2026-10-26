with Adaflight.MSP_Battery_In;
with Adaflight.MSP_Blackbox_In;
with Adaflight.MSP_Feature_In;
with Adaflight.MSP_Hardware_In;

package body Adaflight.MSP_Processor with SPARK_Mode is
   use Adaflight.Stream_Buffers;
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
   begin
      E := (others => <>);
      R := Error;
      if MSP_CLI_Setting.Handles (Command) then
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
      elsif MSP_Control_In.Handles (Command) then
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
         return;
      end if;
      E.Handled := True;
   end Process;

end Adaflight.MSP_Processor;
