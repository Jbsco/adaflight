pragma SPARK_Mode (On);
--  The USB mass storage device over a storage that reads as zeros.
with Adaflight.Mass_Storage_Steps;
with Adaflight.USB_MSC;

package Adaflight.Blank_USB_MSC is new Adaflight.USB_MSC
  (Buffer_Blocks   => 1,
   Inquiry         => (others => 0),
   Start_Storage   => Adaflight.Mass_Storage_Steps.Start_Storage,
   Capacity        => Adaflight.Mass_Storage_Steps.Capacity,
   Ready           => Adaflight.Mass_Storage_Steps.Ready,
   Write_Protected => Adaflight.Mass_Storage_Steps.Write_Protected,
   Read_Blocks     => Adaflight.Mass_Storage_Steps.Read_Blocks,
   Write_Blocks    => Adaflight.Mass_Storage_Steps.Write_Blocks);
