--  The RTC6705 video transmitter, driven over its three-wire interface with
--  a power pin. A frequency from 5600 to 5950 MHz writes the reference
--  divider register and the frequency's divider register. A power index
--  writes the power amplifier register from the table's value, held from one
--  to two, full power at two. The pit mode switches the power pin off, or on
--  again with the boot delay before the stored power and frequency are
--  written, and the process powers the pin on the same way when the pit mode
--  is off and the pin has stayed off since the start. The writes, the pin and
--  the waits are operations for the board to carry out in order.
with Interfaces;
with Adaflight.VTX_Table;

package Adaflight.VTX_RTC6705 with SPARK_Mode is
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Freq_Min      : constant := 5600;
   Freq_Max      : constant := 5950;
   Boot_Delay_Ms : constant := 350;

   --  A register write with its address and the write bit, then its 20-bit
   --  value; the power pin switched on or off; a wait in milliseconds.
   type Operation_Kind is (Write_Register, Power_On, Power_Off, Wait);

   type Operation is record
      Kind    : Operation_Kind := Write_Register;
      Address : Unsigned_8 := 0;
      Value   : Unsigned_32 := 0;
   end record;

   Max_Operations : constant := 8;
   subtype Operation_Count is Natural range 0 .. Max_Operations;
   type Operation_List is array (1 .. Max_Operations) of Operation;

   type Operations is record
      Count : Operation_Count := 0;
      List  : Operation_List := (others => (Kind => Write_Register, Address => 0, Value => 0));
   end record;

   No_Operations : constant Operations := (Count => 0, List => (others => (Write_Register, 0, 0)));

   --  The frequency, the power index and the pit mode set last, whether the
   --  transmitter has been powered since the start, and the operations since
   --  they were taken.
   type Driver is record
      Frequency   : Unsigned_16 := 0;
      Power_Index : Unsigned_8 := 0;
      Pit_Active  : Boolean := False;
      Powered     : Boolean := False;
      Pending     : Operations := No_Operations;
   end record;

   --  The power pin as the board starts: off.
   procedure Start (Ops : out Operations);

   procedure Set_Frequency (D : in out Driver; Freq : Unsigned_16);

   --  A power index without a value in the table is ignored.
   procedure Set_Power_Index (D : in out Driver; T : VTX_Table.Table; Index : Unsigned_8);

   procedure Set_Pit_Mode (D : in out Driver; T : VTX_Table.Table; On : Boolean);

   --  The transmitter powered on with the boot delay and the stored power and
   --  frequency when the pit mode is off and it has not been powered since
   --  the start.
   procedure Process (D : in out Driver; T : VTX_Table.Table);

end Adaflight.VTX_RTC6705;
