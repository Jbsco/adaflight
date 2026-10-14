--  The configuration as bytes in adaflight's layout: every field of every
--  parameter group in declaration order, little-endian, without padding,
--  the groups one after another, and the registry the storage image keeps
--  them by. Generated from the settings oracle.
with Adaflight.Bytes;
with Adaflight.Config_Store;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;

package Adaflight.Config_Codec with SPARK_Mode is

   Group_Count : constant := 101;
   Data_Size   : constant := 4591;

   subtype Data is Adaflight.Bytes.Byte_Array (0 .. Data_Size - 1);

   --  Each group's number, version, offset and size in the data.
   Registry : constant Adaflight.Config_Store.Registry (1 .. Group_Count) :=
     ((Number => 5, Version => 4, Offset => 0, Size => 10),
      (Number => 526, Version => 0, Offset => 10, Size => 2),
      (Number => 18, Version => 4, Offset => 12, Size => 17),
      (Number => 19, Version => 1, Offset => 29, Size => 4),
      (Number => 505, Version => 0, Offset => 33, Size => 4),
      (Number => 509, Version => 0, Offset => 37, Size => 22),
      (Number => 12, Version => 7, Offset => 59, Size => 124),
      (Number => 39, Version => 0, Offset => 183, Size => 3),
      (Number => 37, Version => 2, Offset => 186, Size => 270),
      (Number => 25, Version => 1, Offset => 456, Size => 3),
      (Number => 16, Version => 2, Offset => 459, Size => 3),
      (Number => 26, Version => 0, Offset => 462, Size => 13),
      (Number => 41, Version => 5, Offset => 475, Size => 120),
      (Number => 553, Version => 0, Offset => 595, Size => 64),
      (Number => 1, Version => 2, Offset => 659, Size => 11),
      (Number => 22, Version => 3, Offset => 670, Size => 8),
      (Number => 20, Version => 2, Offset => 678, Size => 15),
      (Number => 4, Version => 0, Offset => 693, Size => 128),
      (Number => 528, Version => 0, Offset => 821, Size => 1),
      (Number => 504, Version => 4, Offset => 822, Size => 5),
      (Number => 14, Version => 12, Offset => 827, Size => 844),
      (Number => 56, Version => 7, Offset => 1671, Size => 8),
      (Number => 52, Version => 0, Offset => 1679, Size => 16),
      (Number => 21, Version => 0, Offset => 1695, Size => 112),
      (Number => 42, Version => 0, Offset => 1807, Size => 96),
      (Number => 3, Version => 0, Offset => 1903, Size => 1),
      (Number => 27, Version => 3, Offset => 1904, Size => 16),
      (Number => 545, Version => 0, Offset => 1920, Size => 240),
      (Number => 13, Version => 2, Offset => 2160, Size => 3),
      (Number => 17, Version => 0, Offset => 2163, Size => 12),
      (Number => 515, Version => 1, Offset => 2175, Size => 61),
      (Number => 259, Version => 1, Offset => 2236, Size => 11),
      (Number => 2044, Version => 0, Offset => 2247, Size => 1),
      (Number => 501, Version => 13, Offset => 2248, Size => 115),
      (Number => 2045, Version => 4, Offset => 2363, Size => 198),
      (Number => 510, Version => 0, Offset => 2561, Size => 19),
      (Number => 59, Version => 4, Offset => 2580, Size => 2),
      (Number => 60, Version => 13, Offset => 2582, Size => 79),
      (Number => 503, Version => 0, Offset => 2661, Size => 5),
      (Number => 502, Version => 3, Offset => 2666, Size => 9),
      (Number => 538, Version => 0, Offset => 2675, Size => 60),
      (Number => 518, Version => 1, Offset => 2735, Size => 15),
      (Number => 520, Version => 1, Offset => 2750, Size => 15),
      (Number => 519, Version => 0, Offset => 2765, Size => 5),
      (Number => 512, Version => 1, Offset => 2770, Size => 10),
      (Number => 513, Version => 0, Offset => 2780, Size => 10),
      (Number => 554, Version => 1, Offset => 2790, Size => 7),
      (Number => 506, Version => 0, Offset => 2797, Size => 4),
      (Number => 562, Version => 2, Offset => 2801, Size => 631),
      (Number => 559, Version => 0, Offset => 3432, Size => 18),
      (Number => 58, Version => 1, Offset => 3450, Size => 11),
      (Number => 30, Version => 4, Offset => 3461, Size => 80),
      (Number => 55, Version => 8, Offset => 3541, Size => 19),
      (Number => 540, Version => 1, Offset => 3560, Size => 15),
      (Number => 524, Version => 0, Offset => 3575, Size => 4),
      (Number => 541, Version => 0, Offset => 3579, Size => 6),
      (Number => 6, Version => 3, Offset => 3585, Size => 36),
      (Number => 557, Version => 0, Offset => 3621, Size => 7),
      (Number => 568, Version => 0, Offset => 3628, Size => 4),
      (Number => 47, Version => 2, Offset => 3632, Size => 102),
      (Number => 530, Version => 1, Offset => 3734, Size => 4),
      (Number => 529, Version => 0, Offset => 3738, Size => 8),
      (Number => 551, Version => 0, Offset => 3746, Size => 4),
      (Number => 552, Version => 0, Offset => 3750, Size => 4),
      (Number => 61, Version => 2, Offset => 3754, Size => 5),
      (Number => 539, Version => 0, Offset => 3759, Size => 11),
      (Number => 544, Version => 6, Offset => 3770, Size => 11),
      (Number => 24, Version => 4, Offset => 3781, Size => 51),
      (Number => 508, Version => 0, Offset => 3832, Size => 9),
      (Number => 507, Version => 0, Offset => 3841, Size => 1),
      (Number => 523, Version => 2, Offset => 3842, Size => 61),
      (Number => 555, Version => 0, Offset => 3903, Size => 11),
      (Number => 537, Version => 0, Offset => 3914, Size => 12),
      (Number => 556, Version => 2, Offset => 3926, Size => 7),
      (Number => 511, Version => 2, Offset => 3933, Size => 5),
      (Number => 543, Version => 0, Offset => 3938, Size => 12),
      (Number => 547, Version => 4, Offset => 3950, Size => 18),
      (Number => 531, Version => 0, Offset => 3968, Size => 4),
      (Number => 514, Version => 0, Offset => 3972, Size => 3),
      (Number => 57, Version => 0, Offset => 3975, Size => 5),
      (Number => 546, Version => 0, Offset => 3980, Size => 283),
      (Number => 525, Version => 1, Offset => 4263, Size => 20),
      (Number => 542, Version => 0, Offset => 4283, Size => 6),
      (Number => 44, Version => 0, Offset => 4289, Size => 16),
      (Number => 43, Version => 0, Offset => 4305, Size => 36),
      (Number => 35, Version => 2, Offset => 4341, Size => 16),
      (Number => 38, Version => 4, Offset => 4357, Size => 10),
      (Number => 561, Version => 1, Offset => 4367, Size => 63),
      (Number => 11, Version => 4, Offset => 4430, Size => 14),
      (Number => 2, Version => 1, Offset => 4444, Size => 12),
      (Number => 40, Version => 4, Offset => 4456, Size => 22),
      (Number => 256, Version => 0, Offset => 4478, Size => 4),
      (Number => 257, Version => 0, Offset => 4482, Size => 4),
      (Number => 517, Version => 0, Offset => 4486, Size => 4),
      (Number => 10, Version => 10, Offset => 4490, Size => 35),
      (Number => 560, Version => 3, Offset => 4525, Size => 5),
      (Number => 569, Version => 0, Offset => 4530, Size => 4),
      (Number => 527, Version => 1, Offset => 4534, Size => 2),
      (Number => 516, Version => 1, Offset => 4536, Size => 2),
      (Number => 258, Version => 0, Offset => 4538, Size => 3),
      (Number => 31, Version => 7, Offset => 4541, Size => 50));

   --  Each group's bytes lie inside the data, as the storage image needs.
   function Groups_Within return Boolean is
     (Adaflight.Config_Store.Within (Registry, Data'(others => 0)))
     with Post => Groups_Within'Result;

   procedure Encode (C : Configuration; D : out Data);

   --  The groups of the configuration from the data.
   procedure Decode (D : Data; C : in out Configuration);

end Adaflight.Config_Codec;
