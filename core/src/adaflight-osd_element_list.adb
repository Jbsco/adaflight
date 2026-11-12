package body Adaflight.OSD_Element_List with SPARK_Mode is

   function Element (L : List; Index : Natural) return Item is
      Left : Natural;
   begin
      if Index < Fixed_Count then
         return Item'Val (Index);
      end if;
      Left := Index - Fixed_Count;
      if L.Waypoints then
         if Left < Waypoint_Count then
            return Item'Val (Item'Pos (WP_Number) + Left);
         end if;
         Left := Left - Waypoint_Count;
      end if;
      if L.Map then
         if Left = 0 then
            return Nav_Map;
         end if;
         Left := Left - 1;
      end if;
      if L.Position_Hold and then Left = 0 then
         return Position_Hold_Ready;
      end if;
      return Airspeed;
   end Element;

end Adaflight.OSD_Element_List;
