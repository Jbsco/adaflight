--  The MSP box table: the names and permanent ids of the flight and switch
--  modes, their lookups, the box name and permanent id serializers with the
--  paged box reply, the box state from the arming and flight mode flags, and
--  the active-box bits packed for the MSP status. The active set from the
--  build's features stays with the target.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;
with Adaflight.Modes;
with Adaflight.Arming;

package Adaflight.MSP_Box with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Box is Adaflight.Modes.Box;
   subtype Active_Mask is Adaflight.Modes.Mask;
   subtype Mode_Set is Adaflight.Arming.Mode_Set;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Box_Count       : constant := Box'Pos (Box'Last) + 1;
   Max_Name_Length : constant := 24;
   No_Permanent_Id : constant Byte := 255;
   Page_Size       : constant := 32;

   --  The reference's name and permanent id, which identifies a box for life.
   function Box_Name (B : Box) return String
     with Post => Box_Name'Result'Length in 1 .. Max_Name_Length;

   function Permanent_Id (B : Box) return Byte
     with Post => Permanent_Id'Result <= 58;

   procedure Find_By_Permanent_Id (Id : Byte; Found : out Boolean; B : out Box);

   --  A user box's custom name of up to sixteen characters, with no terminator
   --  required; an empty name means the table's.
   Max_User_Name_Length : constant := 16;
   subtype User_Name_Length is Natural range 0 .. Max_User_Name_Length;
   type User_Name is record
      Text   : String (1 .. Max_User_Name_Length) := (others => ' ');
      Length : User_Name_Length := 0;
   end record;
   subtype User_Box is Box range Adaflight.Modes.User_1 .. Adaflight.Modes.User_4;
   type User_Names is array (User_Box) of User_Name;

   --  The name and its separator, or nothing when they would not fit, with
   --  the bytes written or -1.
   procedure Serialize_Box_Name (B : in out Byte_Array; S : in out Stream; Which : Box; Names : User_Names;
                                 Written : out Integer)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B),
          Post => Written in -1 | 1 .. Max_Name_Length + 1 and then Adaflight.Stream_Buffers.Fits (S, B);

   procedure Serialize_Box_Permanent_Id (B : in out Byte_Array; S : in out Stream; Which : Box; Written : out Integer)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B),
          Post => Written in -1 | 1 and then Adaflight.Stream_Buffers.Fits (S, B);

   type Reply_Kind is (Box_Names, Box_Permanent_Ids);

   --  One page of thirty-two active boxes, stopped at the first that does
   --  not fit.
   procedure Serialize_Box_Reply (B : in out Byte_Array; S : in out Stream; Active : Active_Mask; Page : Natural;
                                  Kind : Reply_Kind; Names : User_Names)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B) and then Page <= 255,
          Post => Adaflight.Stream_Buffers.Fits (S, B);

   --  Whether a box is on: the arming flag, the flight mode, or the switch;
   --  on a wing the launch box reads the launch flight mode.
   function Box_State (Which : Box; Armed : Boolean; Flight : Mode_Set; Switches : Active_Mask; Wing : Boolean)
                       return Boolean;

   subtype Packed_Index is Natural range 0 .. 1;
   type Packed_Words is array (Packed_Index) of Unsigned_32;

   --  The on bits of the active boxes in their order, and how many were
   --  counted.
   procedure Pack_Flight_Mode_Flags (Active : Active_Mask; Armed : Boolean; Flight : Mode_Set; Switches : Active_Mask;
                                     Wing : Boolean; Packed : out Packed_Words; Count : out Natural)
     with Post => Count <= Box_Count;

end Adaflight.MSP_Box;
