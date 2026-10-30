--  The configuration as bytes in adaflight's layout: every field of every
--  parameter group in declaration order, little-endian, without padding,
--  the groups one after another, and the registry the storage image keeps
--  them by. Generated from the settings oracle.
with Adaflight.Bytes;
with Adaflight.Config_Store;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;

package Adaflight.Config_Codec with SPARK_Mode is

   Group_Count : constant := 104;
   Data_Size   : constant := 4674;

   subtype Data is Adaflight.Bytes.Byte_Array (0 .. Data_Size - 1);

   --  Each group's number, version, offset and size in the data.
   Registry : constant Adaflight.Config_Store.Registry (1 .. Group_Count) :=
     ((Number => 5, Version => 4, Offset => 0, Size => 10),
      (Number => 526, Version => 0, Offset => 10, Size => 2),
      (Number => 18, Version => 4, Offset => 12, Size => 17),
      (Number => 19, Version => 1, Offset => 29, Size => 4),
      (Number => 522, Version => 0, Offset => 33, Size => 19),
      (Number => 505, Version => 0, Offset => 52, Size => 4),
      (Number => 509, Version => 0, Offset => 56, Size => 22),
      (Number => 521, Version => 0, Offset => 78, Size => 1),
      (Number => 12, Version => 7, Offset => 79, Size => 124),
      (Number => 39, Version => 0, Offset => 203, Size => 3),
      (Number => 37, Version => 2, Offset => 206, Size => 270),
      (Number => 25, Version => 1, Offset => 476, Size => 3),
      (Number => 16, Version => 2, Offset => 479, Size => 3),
      (Number => 26, Version => 0, Offset => 482, Size => 13),
      (Number => 41, Version => 5, Offset => 495, Size => 120),
      (Number => 553, Version => 0, Offset => 615, Size => 64),
      (Number => 1, Version => 2, Offset => 679, Size => 11),
      (Number => 22, Version => 3, Offset => 690, Size => 8),
      (Number => 20, Version => 2, Offset => 698, Size => 15),
      (Number => 4, Version => 0, Offset => 713, Size => 128),
      (Number => 528, Version => 0, Offset => 841, Size => 1),
      (Number => 504, Version => 4, Offset => 842, Size => 5),
      (Number => 14, Version => 12, Offset => 847, Size => 844),
      (Number => 56, Version => 7, Offset => 1691, Size => 8),
      (Number => 52, Version => 0, Offset => 1699, Size => 16),
      (Number => 21, Version => 0, Offset => 1715, Size => 112),
      (Number => 42, Version => 0, Offset => 1827, Size => 96),
      (Number => 3, Version => 0, Offset => 1923, Size => 1),
      (Number => 27, Version => 3, Offset => 1924, Size => 16),
      (Number => 545, Version => 0, Offset => 1940, Size => 240),
      (Number => 13, Version => 2, Offset => 2180, Size => 3),
      (Number => 17, Version => 0, Offset => 2183, Size => 12),
      (Number => 515, Version => 1, Offset => 2195, Size => 61),
      (Number => 259, Version => 1, Offset => 2256, Size => 11),
      (Number => 2044, Version => 0, Offset => 2267, Size => 1),
      (Number => 501, Version => 13, Offset => 2268, Size => 115),
      (Number => 2045, Version => 4, Offset => 2383, Size => 198),
      (Number => 510, Version => 0, Offset => 2581, Size => 22),
      (Number => 59, Version => 4, Offset => 2603, Size => 2),
      (Number => 60, Version => 13, Offset => 2605, Size => 79),
      (Number => 503, Version => 0, Offset => 2684, Size => 5),
      (Number => 502, Version => 3, Offset => 2689, Size => 9),
      (Number => 538, Version => 0, Offset => 2698, Size => 60),
      (Number => 518, Version => 1, Offset => 2758, Size => 15),
      (Number => 520, Version => 1, Offset => 2773, Size => 15),
      (Number => 519, Version => 0, Offset => 2788, Size => 2),
      (Number => 512, Version => 1, Offset => 2790, Size => 10),
      (Number => 513, Version => 0, Offset => 2800, Size => 10),
      (Number => 554, Version => 1, Offset => 2810, Size => 7),
      (Number => 506, Version => 0, Offset => 2817, Size => 4),
      (Number => 562, Version => 2, Offset => 2821, Size => 631),
      (Number => 559, Version => 0, Offset => 3452, Size => 18),
      (Number => 58, Version => 1, Offset => 3470, Size => 11),
      (Number => 30, Version => 4, Offset => 3481, Size => 80),
      (Number => 55, Version => 8, Offset => 3561, Size => 19),
      (Number => 540, Version => 1, Offset => 3580, Size => 15),
      (Number => 524, Version => 0, Offset => 3595, Size => 4),
      (Number => 541, Version => 0, Offset => 3599, Size => 6),
      (Number => 6, Version => 3, Offset => 3605, Size => 36),
      (Number => 557, Version => 0, Offset => 3641, Size => 7),
      (Number => 568, Version => 0, Offset => 3648, Size => 4),
      (Number => 47, Version => 2, Offset => 3652, Size => 102),
      (Number => 530, Version => 1, Offset => 3754, Size => 4),
      (Number => 529, Version => 0, Offset => 3758, Size => 8),
      (Number => 551, Version => 0, Offset => 3766, Size => 4),
      (Number => 552, Version => 0, Offset => 3770, Size => 4),
      (Number => 61, Version => 2, Offset => 3774, Size => 5),
      (Number => 539, Version => 0, Offset => 3779, Size => 11),
      (Number => 544, Version => 6, Offset => 3790, Size => 11),
      (Number => 24, Version => 4, Offset => 3801, Size => 51),
      (Number => 508, Version => 0, Offset => 3852, Size => 9),
      (Number => 507, Version => 0, Offset => 3861, Size => 1),
      (Number => 523, Version => 2, Offset => 3862, Size => 61),
      (Number => 555, Version => 0, Offset => 3923, Size => 11),
      (Number => 537, Version => 0, Offset => 3934, Size => 12),
      (Number => 556, Version => 2, Offset => 3946, Size => 7),
      (Number => 511, Version => 2, Offset => 3953, Size => 5),
      (Number => 543, Version => 0, Offset => 3958, Size => 12),
      (Number => 547, Version => 4, Offset => 3970, Size => 18),
      (Number => 534, Version => 0, Offset => 3988, Size => 63),
      (Number => 531, Version => 0, Offset => 4051, Size => 4),
      (Number => 514, Version => 0, Offset => 4055, Size => 3),
      (Number => 57, Version => 0, Offset => 4058, Size => 5),
      (Number => 546, Version => 0, Offset => 4063, Size => 283),
      (Number => 525, Version => 1, Offset => 4346, Size => 20),
      (Number => 542, Version => 0, Offset => 4366, Size => 6),
      (Number => 44, Version => 0, Offset => 4372, Size => 16),
      (Number => 43, Version => 0, Offset => 4388, Size => 36),
      (Number => 35, Version => 2, Offset => 4424, Size => 16),
      (Number => 38, Version => 4, Offset => 4440, Size => 10),
      (Number => 561, Version => 1, Offset => 4450, Size => 63),
      (Number => 11, Version => 4, Offset => 4513, Size => 14),
      (Number => 2, Version => 1, Offset => 4527, Size => 12),
      (Number => 40, Version => 4, Offset => 4539, Size => 22),
      (Number => 256, Version => 0, Offset => 4561, Size => 4),
      (Number => 257, Version => 0, Offset => 4565, Size => 4),
      (Number => 517, Version => 0, Offset => 4569, Size => 4),
      (Number => 10, Version => 10, Offset => 4573, Size => 35),
      (Number => 560, Version => 3, Offset => 4608, Size => 5),
      (Number => 569, Version => 0, Offset => 4613, Size => 4),
      (Number => 527, Version => 1, Offset => 4617, Size => 2),
      (Number => 516, Version => 1, Offset => 4619, Size => 2),
      (Number => 258, Version => 0, Offset => 4621, Size => 3),
      (Number => 31, Version => 7, Offset => 4624, Size => 50));

   --  Each group's bytes lie inside the data, as the storage image needs.
   function Groups_Within return Boolean is
     (Adaflight.Config_Store.Within (Registry, Data'(others => 0)))
     with Post => Groups_Within'Result;

   procedure Encode (C : Configuration; D : out Data);

   --  The groups of the configuration from the data.
   procedure Decode (D : Data; C : in out Configuration);

   --  Room for the bytes of the largest group, or of a profile group's element, and for every
   --  setting's value inside them.
   Group_Data_Size : constant := 631;
   subtype Group_Data is Adaflight.Bytes.Byte_Array (0 .. Group_Data_Size - 1);

   --  A group's bytes from the start of the data, a profile group's at the profile's element.
   procedure Encode_Group (C : Configuration; Number : Natural; Profile : Natural; D : out Group_Data)
     with Global => null, Always_Terminates;

   --  A group, or a profile group's element, from the start of the data.
   procedure Decode_Group (D : Group_Data; Number : Natural; Profile : Natural; C : in out Configuration)
     with Global => null, Always_Terminates;

end Adaflight.Config_Codec;
