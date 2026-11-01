with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Control_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_8;

   Configured   : constant := 1;
   Reboot_Modes : constant := 5;
   MSC_Mode     : constant := 2;
   MSC_UTC_Mode : constant := 3;
   Blocking     : constant := 1;

   --  A command byte that switches arming off for the request's link, or on
   --  again, the reason cleared once no link holds it off; the runaway
   --  takeoff prevention's temporary disable follows.
   procedure Set_Arming (L : in out Link_State; Request : Byte_Array; B : Board; E : in out Effects)
     with Pre => Request'Length <= Max_Request
   is
      Bit : constant Interfaces.Unsigned_32 := Interfaces.Shift_Left (1, B.Source);
   begin
      if U8 (Request, 0) /= 0 then
         L.Disabled := L.Disabled or Bit;
         E.MSP_Arming := Disable;
         E.Disarm := B.Armed;
         E.Runaway_Set := True;
         E.Runaway_Value := 0;
      else
         L.Disabled := L.Disabled and not Bit;
         if L.Disabled = 0 then
            E.MSP_Arming := Enable;
            E.Runaway_Set := True;
            E.Runaway_Value := Byte (U8 (Request, 1));
         end if;
      end if;
   end Set_Arming;

   --  A restart mode, the firmware when the request leaves it out, answered
   --  back; for either mass storage mode the file system's readiness follows
   --  and only a ready one restarts (finding F199). The restart waits out a
   --  delay over the telemetry link with the SPI receiver running.
   procedure Set_Reboot (Request : Byte_Array; B : Board; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then E = E'Old)
   is
      Mode : constant Integer_64 := (if Request'Length > 0 then U8 (Request, 0) else 0);
   begin
      if B.Armed or else Mode >= Reboot_Modes then
         R := Error;
         return;
      end if;
      E.Reply_Length := 1;
      E.Reply (0) := Byte (Mode);
      R := Ack;
      if Mode in MSC_Mode | MSC_UTC_Mode then
         E.Reply_Length := 2;
         E.Reply (1) := (if B.MSC_Ready then 1 else 0);
         if not B.MSC_Ready then
            return;
         end if;
      end if;
      E.Reboot_Mode := Byte (Mode);
      if B.RX_SPI_Active and then B.From_Telemetry then
         E.Deferred_Reboot := True;
      else
         E.Reboot := True;
      end if;
   end Set_Reboot;

   --  A command type, a motor, a count and that many DShot commands, the
   --  motors switched off around blocking ones.
   procedure Set_DShot (Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then E = E'Old)
   is
      Count : constant Natural := Natural (U8 (Request, 2));
   begin
      if Request'Length < 3 or else Request'Length - 3 < Count then
         R := Error;
         return;
      end if;
      E.DShot := True;
      E.DShot_Type := Byte (U8 (Request, 0));
      E.DShot_Motor := Byte (U8 (Request, 1));
      E.DShot_Commands := Count;
      for I in 0 .. Count - 1 loop
         E.DShot_Values (I) := Request (Request'First + 3 + I);
      end loop;
      E.Motors_Off := E.DShot_Type = Blocking;
      R := Ack;
   end Set_DShot;

   procedure Process
     (C : in out Configuration; L : in out Link_State; Command : Interfaces.Unsigned_16; Request : Byte_Array;
      B : Board; R : out Result; E : out Effects)
   is
   begin
      E := No_Effects;
      R := Ack;
      case Command is
         when Erase_Flash_Command =>
            E.Erase_Flash := True;
         when Set_Arming_Disabled_Command =>
            Set_Arming (L, Request, B, E);
         when Acc_Calibration_Command =>
            E.Acc_Calibration := not B.Armed;
         when Mag_Calibration_Command =>
            E.Mag_Calibration := not B.Armed;
         when Camera_Control_Command =>
            if B.Armed then
               R := Error;
               return;
            end if;
            E.Camera_Press := True;
            E.Camera_Key := (if Request'Length > 0 then Byte (U8 (Request, 0)) else 0);
         when Write_Configuration_Command =>
            if B.Armed then
               R := Error;
               return;
            end if;
            E.Ignore_Task_Time := True;
            if B.RX_SPI_Active and then B.From_Telemetry then
               E.Deferred_Save := True;
            else
               C.System_Config.Configuration_State := Configured;
               E.Save := True;
            end if;
         when Reboot_Command =>
            Set_Reboot (Request, B, R, E);
         when DShot_Command_Command =>
            if not B.Armed then
               Set_DShot (Request, R, E);
            end if;
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Control_In;
