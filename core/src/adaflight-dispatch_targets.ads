--  The delayed calls the reference queues, numbered for the dispatch queue:
--  the statistics save, the MSP reboot, and the MSP settings write and read.
with Adaflight.Dispatch;

package Adaflight.Dispatch_Targets with SPARK_Mode is
   type Call is (Write_Stats, MSP_Reboot, Write_Read_EEPROM);

   function Target_Of (C : Call) return Adaflight.Dispatch.Target is
     (Adaflight.Dispatch.Target (Call'Pos (C)));

end Adaflight.Dispatch_Targets;
