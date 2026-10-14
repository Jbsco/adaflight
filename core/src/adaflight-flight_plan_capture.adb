with Adaflight.Clock;
with Adaflight.Text;

package body Adaflight.Flight_Plan_Capture with SPARK_Mode is

   use type Interfaces.Integer_32;

   procedure Set_Message (C : in out Capture; Now_Us : Unsigned_32; Template : String; Index : Integer_32)
     with Pre => Template'Last < Integer'Last
   is
   begin
      Text.Format (Template, (1 => Text.Int_Argument (Index)), "", C.Message, C.Message_Length);
      C.Message_Expire_Us := Now_Us + Message_Time_Us;
      C.Message_Valid := True;
   end Set_Message;

   ------------
   -- Update --
   ------------

   procedure Update (C : in out Capture; P : in out Flight_Plan.Plan; Now_Us : Unsigned_32;
                     Switch_Active, Channels_Valid, Plan_Active : Boolean; Where : Position)
   is
   begin
      if not Channels_Valid then
         return;
      end if;
      if Switch_Active and then not C.Switch_Was then
         --  The press samples the position. The plan's capacity counts only
         --  at the release, so a hold deletes from a full plan.
         C.Delete_Fired := False;
         C.Pending_Valid := False;
         C.Press_Accepted := not Plan_Active;
         C.Press_Time_Us := Now_Us;
         if C.Press_Accepted and then Where.Fix then
            C.Pending := (Latitude  => Where.Latitude,
                          Longitude => Where.Longitude,
                          Altitude  => Where.Altitude_Cm,
                          Kind      => Flight_Plan.Type_Flyby,
                          Pattern   => Flight_Plan.Pattern_None,
                          others    => <>);
            C.Pending_Valid := True;
         end if;
      elsif Switch_Active and then C.Switch_Was and then not C.Delete_Fired
        and then Clock.Elapsed (Now_Us, C.Press_Time_Us) >= Hold_Delete_Us
      then
         --  The hold deletes the last waypoint once per press.
         C.Delete_Fired := True;
         C.Pending_Valid := False;
         if C.Press_Accepted and then not Plan_Active and then P.Count > 0 then
            P.Count := P.Count - 1;
            Set_Message (C, Now_Us, "WP%d DELETED", Integer_32 (P.Count + 1));
         end if;
      elsif not Switch_Active and then C.Switch_Was and then not C.Delete_Fired and then C.Press_Accepted then
         if C.Pending_Valid and then not Plan_Active then
            if P.Count < Flight_Plan.Max_Waypoints then
               P.Waypoints (P.Count) := C.Pending;
               P.Count := P.Count + 1;
               Set_Message (C, Now_Us, "WP%d SET", Integer_32 (P.Count));
            else
               Set_Message (C, Now_Us, "WP FULL", 0);
            end if;
         end if;
         C.Pending_Valid := False;
      end if;
      C.Switch_Was := Switch_Active;
   end Update;

   ------------------
   -- Read_Message --
   ------------------

   procedure Read_Message (C : in out Capture; Now_Us : Unsigned_32; Valid : out Boolean) is
   begin
      if not C.Message_Valid then
         Valid := False;
      elsif Clock.Elapsed (Now_Us, C.Message_Expire_Us) >= 0 then
         C.Message_Valid := False;
         Valid := False;
      else
         Valid := True;
      end if;
   end Read_Message;

end Adaflight.Flight_Plan_Capture;
