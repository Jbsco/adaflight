--  The STM32H743's interrupt count. The H7 clock setup brings up the supply
--  and the voltage scale itself, so this unit has no procedures.

package System.BB.MCU_Parameters is
   pragma No_Elaboration_Code_All;
   pragma Preelaborate;

   Number_Of_Interrupts : constant := 150;

end System.BB.MCU_Parameters;
