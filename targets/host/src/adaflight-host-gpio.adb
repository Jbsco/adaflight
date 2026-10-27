package body Adaflight.STM32.GPIO is
   procedure Enable_Port (Port : Port_Name) is null;
   procedure Set_Output (P : Pin) is null;
   procedure Set_Open_Drain (P : Pin) is null;
   procedure Set_Input (P : Pin; Resistor : Pull := No_Pull) is null;
   procedure Set_Analog (P : Pin) is null;
   procedure Set_Alternate
     (P : Pin; Func : Alternate_Function; Resistor : Pull := No_Pull; Rate : Speed := High) is null;
   procedure Set_High (P : Pin) is null;
   procedure Set_Low (P : Pin) is null;
   procedure Toggle (P : Pin) is null;
end Adaflight.STM32.GPIO;
