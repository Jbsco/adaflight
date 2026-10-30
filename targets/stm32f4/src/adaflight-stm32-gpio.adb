package body Adaflight.STM32.GPIO is

   RCC_AHB1ENR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (16#4002_3830#);

   procedure Enable_Port (Port : Port_Name) is
   begin
      RCC_AHB1ENR := RCC_AHB1ENR or Shift_Left (1, Port_Name'Pos (Port));
   end Enable_Port;

   procedure Set_Output (P : Pin) is
      Regs  : Port_Registers with Import, Address => Port_Base (P.Port);
      Shift : constant Natural := 2 * Natural (P.Number);
   begin
      Regs.MODER := (Regs.MODER and not Shift_Left (3, Shift)) or Shift_Left (1, Shift);
      Regs.OTYPER := Regs.OTYPER and not Shift_Left (1, Natural (P.Number));
      Regs.OSPEEDR := Regs.OSPEEDR and not Shift_Left (3, Shift);
      Regs.PUPDR := Regs.PUPDR and not Shift_Left (3, Shift);
   end Set_Output;

   --  The pull-up and pull-down register's code for a resistor.
   Resistor_Code : constant array (Pull) of Unsigned_32 := (No_Pull => 0, Up => 1, Down => 2);

   procedure Set_Input (P : Pin; Resistor : Pull := No_Pull) is
      Regs  : Port_Registers with Import, Address => Port_Base (P.Port);
      Shift : constant Natural := 2 * Natural (P.Number);
   begin
      Regs.MODER := Regs.MODER and not Shift_Left (3, Shift);
      Regs.PUPDR := (Regs.PUPDR and not Shift_Left (3, Shift)) or Shift_Left (Resistor_Code (Resistor), Shift);
   end Set_Input;

   procedure Set_Open_Drain (P : Pin) is
      Regs : Port_Registers with Import, Address => Port_Base (P.Port);
   begin
      Regs.OTYPER := Regs.OTYPER or Shift_Left (1, Natural (P.Number));
   end Set_Open_Drain;

   function Is_High (P : Pin) return Boolean is
      Regs : Port_Registers with Import, Address => Port_Base (P.Port);
   begin
      return (Regs.IDR and Shift_Left (1, Natural (P.Number))) /= 0;
   end Is_High;

   procedure Set_Analog (P : Pin) is
      Regs  : Port_Registers with Import, Address => Port_Base (P.Port);
      Shift : constant Natural := 2 * Natural (P.Number);
   begin
      Regs.MODER := Regs.MODER or Shift_Left (3, Shift);
      Regs.PUPDR := Regs.PUPDR and not Shift_Left (3, Shift);
   end Set_Analog;

   procedure Set_Alternate
     (P : Pin; Func : Alternate_Function; Resistor : Pull := No_Pull; Rate : Speed := High)
   is
      Regs   : Port_Registers with Import, Address => Port_Base (P.Port);
      Shift  : constant Natural := 2 * Natural (P.Number);
      Nibble : constant Natural := 4 * (Natural (P.Number) mod 8);
      AF     : constant Unsigned_32 := Unsigned_32 (Func);
   begin
      Regs.MODER := (Regs.MODER and not Shift_Left (3, Shift)) or Shift_Left (2, Shift);
      Regs.OTYPER := Regs.OTYPER and not Shift_Left (1, Natural (P.Number));
      Regs.OSPEEDR :=
        (Regs.OSPEEDR and not Shift_Left (3, Shift)) or Shift_Left (Unsigned_32 (Speed'Pos (Rate)), Shift);
      Regs.PUPDR := (Regs.PUPDR and not Shift_Left (3, Shift)) or Shift_Left (Resistor_Code (Resistor), Shift);
      if P.Number < 8 then
         Regs.AFRL := (Regs.AFRL and not Shift_Left (15, Nibble)) or Shift_Left (AF, Nibble);
      else
         Regs.AFRH := (Regs.AFRH and not Shift_Left (15, Nibble)) or Shift_Left (AF, Nibble);
      end if;
   end Set_Alternate;

   procedure Set_High (P : Pin) is
      Regs : Port_Registers with Import, Address => Port_Base (P.Port);
   begin
      Regs.BSRR := Shift_Left (1, Natural (P.Number));
   end Set_High;

   procedure Set_Low (P : Pin) is
      Regs : Port_Registers with Import, Address => Port_Base (P.Port);
   begin
      Regs.BSRR := Shift_Left (1, Natural (P.Number) + 16);
   end Set_Low;

   procedure Toggle (P : Pin) is
      Regs : Port_Registers with Import, Address => Port_Base (P.Port);
   begin
      if (Regs.ODR and Shift_Left (1, Natural (P.Number))) /= 0 then
         Set_Low (P);
      else
         Set_High (P);
      end if;
   end Toggle;

end Adaflight.STM32.GPIO;
