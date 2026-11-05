with Interfaces;
with DFU.Layout;
with DFU.Plan;
with DFU.Session;
with DFU.Transport;

--  The phases of a flash: erase the pages the images touch, write the images, read them back. The images'
--  bytes follow each other in one buffer, image K's from Offsets (K).
package DFU.Flash with SPARK_Mode is

   use DFU.Plan;

   type Offset_Array is array (Image_Index) of Data_Index;

   function Fits (Images : Image_Array; Offsets : Offset_Array; Count : Image_Count; Data : Byte_Array)
     return Boolean
   is (Data'First = 0 and then (for all K in 1 .. Count => Offsets (K) + Images (K).Length <= Data'Length));

   procedure Erase
     (M : DFU.Layout.Memory; Images : Image_Array; Count : Image_Count; Pages : out Natural;
      Bytes : out Interfaces.Unsigned_64; Failed : out Address; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device), Pre => Valid (M, Images, Count);

   procedure Write
     (Images : Image_Array; Offsets : Offset_Array; Count : Image_Count; Data : Byte_Array;
      Transfer : DFU.Session.Transfer_Size; Failed : out Address; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device), Pre => Fits (Images, Offsets, Count, Data);

   procedure Verify
     (Images : Image_Array; Offsets : Offset_Array; Count : Image_Count; Data : Byte_Array;
      Transfer : DFU.Session.Transfer_Size; Failed : out Address; Ok : out Boolean)
   with Global => (In_Out => DFU.Transport.Device), Pre => Fits (Images, Offsets, Count, Data);

end DFU.Flash;
