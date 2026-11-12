--  The OSD elements a build lists over MSP, in order. The last elements
--  exist only in a build with their options: the waypoint elements with GPS
--  and the flight plan, the map with those on a multirotor, position hold
--  readiness with position hold, and airspeed with a pitot. A build without
--  an option lists the later elements that many places earlier, so an MSP
--  element index names a place in this list and not in the item set.
with Adaflight.OSD_Elements; use Adaflight.OSD_Elements;

package Adaflight.OSD_Element_List with SPARK_Mode is

   type List is record
      Waypoints     : Boolean := True;
      Map           : Boolean := True;
      Position_Hold : Boolean := True;
      Airspeed      : Boolean := True;
   end record;

   function Of_Build (GPS, Flight_Plan, Wing, Position_Hold, Pitot : Boolean) return List is
     (Waypoints     => GPS and then Flight_Plan,
      Map           => GPS and then Flight_Plan and then not Wing,
      Position_Hold => Position_Hold,
      Airspeed      => Pitot);

   --  The elements every build lists, and the waypoint elements.
   Fixed_Count    : constant := Item'Pos (Battery_Profile_Name) + 1;
   Waypoint_Count : constant := Item'Pos (WP_ETA) - Item'Pos (WP_Number) + 1;

   function Count (L : List) return Natural is
     (Fixed_Count + (if L.Waypoints then Waypoint_Count else 0) + (if L.Map then 1 else 0)
      + (if L.Position_Hold then 1 else 0) + (if L.Airspeed then 1 else 0))
     with Post => Count'Result in Fixed_Count .. Item_Count;

   --  The element at a place of the list.
   function Element (L : List; Index : Natural) return Item
     with Pre  => Index < Count (L),
          Post => (if Index < Fixed_Count then Element'Result = Item'Val (Index));

end Adaflight.OSD_Element_List;
