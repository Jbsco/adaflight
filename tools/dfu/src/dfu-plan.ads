with Interfaces;
with DFU.Layout;

--  Placement of the images in a memory region and the pages to erase before writing them.
package DFU.Plan with Pure, SPARK_Mode is

   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use DFU.Layout;

   Max_Images : constant := 4;
   subtype Image_Count is Natural range 0 .. Max_Images;
   subtype Image_Index is Image_Count range 1 .. Max_Images;

   type Image is record
      First  : Address := 0;
      Length : Data_Index := 0;
   end record;
   type Image_Array is array (Image_Index) of Image;

   function Last (I : Image) return Interfaces.Unsigned_64 is
     (Interfaces.Unsigned_64 (I.First) + Interfaces.Unsigned_64 (I.Length) - 1)
   with Pre => I.Length > 0;

   function Inside (M : Memory; I : Image) return Boolean is
     (I.Length > 0 and then M.Pages >= 1 and then I.First >= M.First (1)
      and then Last (I) <= Interfaces.Unsigned_64 (M.Last (M.Pages)));

   function Apart (I, J : Image) return Boolean is
     (Last (I) < Interfaces.Unsigned_64 (J.First) or else Last (J) < Interfaces.Unsigned_64 (I.First))
   with Pre => I.Length > 0 and then J.Length > 0;

   function Valid (M : Memory; Images : Image_Array; Count : Image_Count) return Boolean is
     (Count >= 1
      and then (for all K in 1 .. Count => Inside (M, Images (K)))
      and then (for all K in 1 .. Count => (for all L in K + 1 .. Count => Apart (Images (K), Images (L)))));

   function Touches (M : Memory; P : Page_Index; I : Image) return Boolean is
     (I.Length > 0 and then Interfaces.Unsigned_64 (I.First) <= Interfaces.Unsigned_64 (M.Last (P))
      and then Last (I) >= Interfaces.Unsigned_64 (M.First (P)));

   type Page_Set is array (Page_Index) of Boolean;

   --  A page is erased exactly when one of the images writes into it.
   procedure Erase_Set (M : Memory; Images : Image_Array; Count : Image_Count; Erase : out Page_Set)
   with
     Global => null,
     Post   =>
       (for all P in Page_Index =>
          Erase (P) = (P <= M.Pages and then (for some K in 1 .. Count => Touches (M, P, Images (K)))));

   --  An image directory's two files: the first at the region's start, within its first page, and the
   --  second from the start of its third page, so the second page stays as it is.
   procedure Place_Pair
     (M : Memory; First_Length, Second_Length : Data_Index; Images : out Image_Array; Ok : out Boolean)
   with
     Global => null,
     Pre    => Contiguous (M),
     Post   =>
       (if Ok then M.Pages >= 3 and then Valid (M, Images, 2)
                   and then not Touches (M, 2, Images (1)) and then not Touches (M, 2, Images (2)));

end DFU.Plan;
