pragma SPARK_Mode (On);
--  The mass storage engine over a storage that reads as zeros.
with Adaflight.Mass_Storage.Engine;
with Adaflight.Mass_Storage_Steps;

package Adaflight.Blank_Mass_Storage is new Adaflight.Mass_Storage.Engine
  (Buffer_Blocks   => 8,
   Inquiry         => (others => 0),
   Start_Storage   => Adaflight.Mass_Storage_Steps.Start_Storage,
   Capacity        => Adaflight.Mass_Storage_Steps.Capacity,
   Ready           => Adaflight.Mass_Storage_Steps.Ready,
   Write_Protected => Adaflight.Mass_Storage_Steps.Write_Protected,
   Read_Blocks     => Adaflight.Mass_Storage_Steps.Read_Blocks,
   Write_Blocks    => Adaflight.Mass_Storage_Steps.Write_Blocks);
