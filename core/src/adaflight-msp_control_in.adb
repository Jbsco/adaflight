with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Control_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_32;

   Configured : constant := 1;

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
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Control_In;
