with Interfaces; use Interfaces;
with System.Storage_Elements; use System.Storage_Elements;

package body Adaflight.Config_Codec with SPARK_Mode => Off is

   subtype Byte_Array is Adaflight.Bytes.Byte_Array;

   --  Each run of a group's fields that lie next to each other in the configuration record: its
   --  offset from the group, or from a profile group's element, its bytes, and whether each byte is a
   --  Boolean.
   type Run is record
      Offset   : Unsigned_16;
      Size     : Unsigned_16;
      Booleans : Boolean;
   end record;

   Runs : constant array (1 .. 245) of Run :=
     ((0, 10, False), (0, 2, False), (0, 17, False), (0, 4, False), (0, 1, False), (2, 18, False), (0, 4, False),
      (0, 22, False), (0, 1, False), (0, 31, False), (0, 3, False), (0, 5, False), (6, 9, False), (16, 9, False),
      (26, 9, False), (36, 9, False), (46, 9, False), (56, 9, False), (66, 9, False), (76, 9, False), (86, 9, False),
      (96, 9, False), (106, 9, False), (116, 9, False), (126, 9, False), (136, 9, False), (146, 9, False),
      (156, 9, False), (166, 9, False), (176, 9, False), (186, 9, False), (196, 9, False), (206, 9, False),
      (216, 9, False), (226, 9, False), (236, 9, False), (246, 9, False), (256, 9, False), (266, 9, False),
      (276, 9, False), (286, 9, False), (296, 4, False), (0, 2, False), (2, 1, True), (0, 3, False), (0, 13, False),
      (0, 120, False), (0, 64, False), (0, 11, False), (0, 8, False), (0, 1, False), (1, 1, True), (2, 2, False),
      (4, 1, True), (5, 1, False), (6, 1, True), (8, 8, False), (0, 128, False), (0, 1, False), (0, 5, False),
      (0, 11, False), (12, 3, False), (16, 3, False), (20, 3, False), (24, 3, False), (28, 3, False), (32, 3, False),
      (36, 3, False), (40, 3, False), (44, 3, False), (48, 11, False), (60, 35, False), (96, 57, False),
      (154, 7, False), (162, 7, False), (170, 17, False), (188, 23, False), (212, 16, False), (0, 8, False),
      (0, 16, False), (0, 112, False), (0, 96, False), (0, 1, False), (0, 16, False), (0, 240, False), (0, 3, False),
      (0, 12, False), (0, 61, False), (0, 3, False), (4, 8, False), (0, 1, False), (0, 10, False), (12, 6, False),
      (20, 5, False), (26, 59, False), (86, 35, False), (0, 198, False), (0, 1, True), (1, 2, False), (3, 1, True),
      (4, 2, False), (6, 1, True), (7, 2, False), (9, 1, True), (10, 3, False), (14, 9, False), (0, 2, False),
      (0, 1, False), (2, 39, False), (42, 7, False), (50, 11, False), (62, 7, False), (70, 11, False), (82, 3, False),
      (0, 3, False), (4, 2, False), (0, 5, False), (8, 4, False), (0, 60, False), (0, 2, False), (2, 1, True),
      (4, 4, False), (8, 1, True), (10, 4, False), (14, 1, True), (16, 2, False), (0, 15, False), (0, 5, False),
      (0, 2, False), (2, 1, True), (3, 7, False), (0, 2, False), (2, 1, True), (3, 7, False), (0, 7, False),
      (0, 4, False), (0, 1, False), (4, 21, False), (28, 21, False), (52, 21, False), (76, 21, False),
      (100, 21, False), (124, 21, False), (148, 21, False), (172, 21, False), (196, 21, False), (220, 21, False),
      (244, 21, False), (268, 21, False), (292, 21, False), (316, 21, False), (340, 21, False), (364, 21, False),
      (388, 21, False), (412, 21, False), (436, 21, False), (460, 21, False), (484, 21, False), (508, 21, False),
      (532, 21, False), (556, 21, False), (580, 21, False), (604, 21, False), (628, 21, False), (652, 21, False),
      (676, 21, False), (700, 21, False), (0, 18, False), (0, 11, False), (0, 7, False), (7, 4, True), (11, 1, False),
      (12, 1, True), (13, 67, False), (0, 3, False), (4, 16, False), (0, 15, False), (0, 3, False), (3, 1, True),
      (0, 6, False), (0, 27, False), (28, 9, False), (0, 7, False), (0, 4, False), (0, 102, False), (0, 4, False),
      (0, 8, False), (0, 4, False), (0, 4, False), (0, 3, False), (4, 2, False), (0, 1, False), (4, 10, False),
      (0, 5, False), (6, 6, False), (0, 51, False), (0, 9, False), (0, 1, False), (0, 61, False), (0, 11, False),
      (0, 1, False), (4, 11, False), (0, 7, False), (0, 5, False), (0, 12, False), (0, 13, False), (16, 5, False),
      (0, 63, False), (0, 4, False), (0, 3, False), (0, 5, False), (0, 226, False), (226, 8, True), (234, 1, False),
      (236, 48, False), (0, 20, False), (0, 6, False), (0, 16, False), (0, 36, False), (0, 3, False), (3, 1, True),
      (4, 12, False), (0, 10, False), (0, 21, False), (0, 5, False), (5, 2, True), (7, 6, False), (13, 1, True),
      (0, 12, False), (0, 22, False), (0, 4, False), (0, 4, False), (0, 1, False), (2, 3, False), (0, 3, False),
      (4, 32, False), (0, 1, False), (2, 4, False), (0, 4, False), (0, 2, False), (0, 2, False), (0, 3, False),
      (0, 27, False), (28, 2, False), (32, 21, False));

   --  Each group's runs, its offset in the configuration record, and a profile's size there, zero for a
   --  group without profiles.
   type Shape is record
      First  : Unsigned_16;
      Last   : Unsigned_16;
      Base   : Unsigned_16;
      Stride : Unsigned_16;
   end record;

   Shapes : constant array (Registry'Range) of Shape :=
     ((1, 1, 0, 0), (2, 2, 12, 0), (3, 3, 14, 0), (4, 4, 32, 0), (5, 6, 36, 0), (7, 7, 56, 0), (8, 8, 60, 0),
      (9, 9, 82, 0), (10, 10, 84, 32), (11, 11, 212, 0), (12, 42, 216, 0), (43, 44, 516, 0), (45, 45, 519, 0),
      (46, 46, 522, 0), (47, 47, 536, 0), (48, 48, 656, 0), (49, 49, 720, 0), (50, 50, 732, 0), (51, 57, 740, 0),
      (58, 58, 756, 0), (59, 59, 884, 0), (60, 60, 886, 0), (61, 78, 892, 228), (79, 79, 1804, 0), (80, 80, 1812, 0),
      (81, 81, 1828, 0), (82, 82, 1940, 0), (83, 83, 2036, 0), (84, 84, 2038, 0), (85, 85, 2056, 0), (86, 86, 2296, 0),
      (87, 87, 2300, 0), (88, 88, 2312, 0), (89, 90, 2374, 0), (91, 91, 2386, 0), (92, 96, 2388, 0), (97, 97, 2512, 0),
      (98, 106, 2710, 0), (107, 107, 2734, 0), (108, 114, 2736, 0), (115, 116, 2822, 0), (117, 118, 2828, 0),
      (119, 119, 2840, 0), (120, 126, 2900, 0), (127, 127, 2918, 0), (128, 128, 2936, 0), (129, 131, 2944, 0),
      (132, 134, 2954, 0), (135, 135, 2964, 0), (136, 136, 2972, 0), (137, 167, 2976, 0), (168, 168, 3700, 0),
      (169, 169, 3720, 0), (170, 174, 3732, 0), (175, 176, 3812, 0), (177, 177, 3832, 0), (178, 179, 3848, 0),
      (180, 180, 3852, 0), (181, 182, 3858, 0), (183, 183, 3896, 0), (184, 184, 3904, 0), (185, 185, 3908, 0),
      (186, 186, 4010, 0), (187, 187, 4014, 0), (188, 188, 4022, 0), (189, 189, 4026, 0), (190, 191, 4030, 0),
      (192, 193, 4036, 0), (194, 195, 4052, 0), (196, 196, 4064, 0), (197, 197, 4116, 0), (198, 198, 4125, 0),
      (199, 199, 4126, 0), (200, 200, 4187, 0), (201, 202, 4200, 0), (203, 203, 4216, 0), (204, 204, 4224, 0),
      (205, 205, 4229, 0), (206, 207, 4244, 0), (208, 208, 4268, 0), (209, 209, 4331, 0), (210, 210, 4335, 0),
      (211, 211, 4338, 0), (212, 215, 4344, 0), (216, 216, 4628, 0), (217, 217, 4648, 0), (218, 218, 4654, 0),
      (219, 219, 4670, 0), (220, 222, 4706, 0), (223, 223, 4722, 0), (224, 224, 4732, 22), (225, 228, 4798, 0),
      (229, 229, 4812, 0), (230, 230, 4824, 0), (231, 231, 4846, 0), (232, 232, 4850, 0), (233, 234, 4854, 0),
      (235, 236, 4860, 0), (237, 238, 4896, 0), (239, 239, 4902, 0), (240, 240, 4906, 0), (241, 241, 4908, 0),
      (242, 242, 4910, 0), (243, 245, 4916, 0));

   --  The elements of each group in the data: a profile group's profiles, one for the others.
   Copies : constant array (Registry'Range) of Positive :=
     (1, 1, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

   --  A group's position in the registry, zero for a number without a group.
   function Index_Of (Number : Natural) return Natural is
   begin
      for K in Registry'Range loop
         if Natural (Registry (K).Number) = Number then
            return K;
         end if;
      end loop;
      return 0;
   end Index_Of;

   --  The bytes of a group, or of a profile group's element, from the record into the data.
   procedure Copy_Out (C : Configuration; K : Positive; Profile : Natural; D : in out Byte_Array;
                       Pos : in out Natural)
   is
      Base : constant System.Address :=
        C'Address + Storage_Offset (Natural (Shapes (K).Base) + Profile * Natural (Shapes (K).Stride));
   begin
      for R in Natural (Shapes (K).First) .. Natural (Shapes (K).Last) loop
         declare
            Field : Byte_Array (0 .. Natural (Runs (R).Size) - 1)
              with Import, Address => Base + Storage_Offset (Runs (R).Offset);
         begin
            D (Pos .. Pos + Field'Length - 1) := Field;
            Pos := Pos + Field'Length;
         end;
      end loop;
   end Copy_Out;

   --  The bytes of a group, or of a profile group's element, from the data into the record, each
   --  Boolean as false for a zero byte and true for any other.
   procedure Copy_In (D : Byte_Array; Pos : in out Natural; K : Positive; Profile : Natural;
                      C : in out Configuration)
   is
      Base : constant System.Address :=
        C'Address + Storage_Offset (Natural (Shapes (K).Base) + Profile * Natural (Shapes (K).Stride));
   begin
      for R in Natural (Shapes (K).First) .. Natural (Shapes (K).Last) loop
         declare
            Field : Byte_Array (0 .. Natural (Runs (R).Size) - 1)
              with Import, Address => Base + Storage_Offset (Runs (R).Offset);
         begin
            if Runs (R).Booleans then
               for I in Field'Range loop
                  Field (I) := (if D (Pos + I) /= 0 then 1 else 0);
               end loop;
            else
               Field := D (Pos .. Pos + Field'Length - 1);
            end if;
            Pos := Pos + Field'Length;
         end;
      end loop;
   end Copy_In;

   procedure Encode (C : Configuration; D : out Data) is
      Pos : Natural := 0;
   begin
      D := (others => 0);
      for K in Registry'Range loop
         for P in 0 .. Copies (K) - 1 loop
            Copy_Out (C, K, P, D, Pos);
         end loop;
      end loop;
   end Encode;

   procedure Decode (D : Data; C : in out Configuration) is
      Pos : Natural := 0;
   begin
      for K in Registry'Range loop
         for P in 0 .. Copies (K) - 1 loop
            Copy_In (D, Pos, K, P, C);
         end loop;
      end loop;
   end Decode;

   procedure Encode_Group (C : Configuration; Number : Natural; Profile : Natural; D : out Group_Data) is
      K   : constant Natural := Index_Of (Number);
      Pos : Natural := 0;
   begin
      D := (others => 0);
      if K /= 0 then
         Copy_Out (C, K, Profile, D, Pos);
      end if;
   end Encode_Group;

   procedure Decode_Group (D : Group_Data; Number : Natural; Profile : Natural; C : in out Configuration) is
      K   : constant Natural := Index_Of (Number);
      Pos : Natural := 0;
   begin
      if K /= 0 then
         Copy_In (D, Pos, K, Profile, C);
      end if;
   end Decode_Group;

end Adaflight.Config_Codec;
