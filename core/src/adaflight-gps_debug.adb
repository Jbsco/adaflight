with Interfaces;

package body Adaflight.GPS_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type GPS_Link.Link_State;

   --  The low sixteen bits of an unsigned value, as the reference's store of
   --  an unsigned into the debug array keeps them.
   function Low (U : Interfaces.Unsigned_32) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (U mod 2 ** 16)));

   function Small (N : Natural) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (Natural'Min (N, 2 ** 30))));

   --  The reference numbers its states with a data processing state before
   --  the lost communication one, which the link has no need of.
   function State_Code (S : GPS_Link.Link_State) return Interfaces.Unsigned_32 is
     (if S = GPS_Link.Lost_Communication then 7 else GPS_Link.Link_State'Pos (S));

   procedure Record_Update
     (D : in out Debug.State; L : GPS_Link.Link; R : GPS_Frames.Receiver; Execute_Time_Us : Natural)
   is
      T : GPS_Link.Debug_Taps renames L.Taps;
   begin
      if Debug.Selected (D, Debug.GPS_Connection) then
         if T.Model_Set then
            Debug.Set (D, Debug.GPS_Connection, 0, Small (T.Model));
         end if;
         if T.Conn1_Set then
            Debug.Set (D, Debug.GPS_Connection, 1, Low (T.Conn1));
         end if;
         if T.Conn2_Set then
            Debug.Set (D, Debug.GPS_Connection, 2, Low (T.Conn2));
         end if;
         if T.Conn3_Set then
            Debug.Set (D, Debug.GPS_Connection, 3, Low (T.Conn3));
         end if;
         if T.Updated then
            Debug.Set (D, Debug.GPS_Connection, 4, Low (State_Code (L.State) * 100 + L.Position));
            Debug.Set (D, Debug.GPS_Connection, 5, Small (Execute_Time_Us));
            Debug.Set (D, Debug.GPS_Connection, 6, Small (GPS_Frames.Ack_State'Pos (R.UBX.Ack)));
         end if;
         if T.Rx_Set then
            Debug.Set (D, Debug.GPS_Connection, 7, Small (T.Rx_Count));
         end if;
      end if;
      if T.Updated and then Debug.Selected (D, Debug.GPS_DOP) then
         Debug.Set (D, Debug.GPS_DOP, 0, Small (Natural (R.Sol.Num_Sat)));
         Debug.Set (D, Debug.GPS_DOP, 1, Low (Interfaces.Unsigned_32 (R.Sol.Dop.Pdop)));
         Debug.Set (D, Debug.GPS_DOP, 2, Low (Interfaces.Unsigned_32 (R.Sol.Dop.Hdop)));
         Debug.Set (D, Debug.GPS_DOP, 3, Low (Interfaces.Unsigned_32 (R.Sol.Dop.Vdop)));
      end if;
   end Record_Update;

end Adaflight.GPS_Debug;
