package body Adaflight.RX_SPI_Steps with SPARK_Mode is

   ----------
   -- Step --
   ----------

   procedure Step is
   begin
      Calls := Counted (Calls);
   end Step;

   -------------
   -- Step_Ok --
   -------------

   procedure Step_Ok (Ok : out Boolean) is
   begin
      Calls := Counted (Calls);
      Ok := Calls mod 2 = 0;
   end Step_Ok;

   --------------------
   -- Step_Family_Ok --
   --------------------

   procedure Step_Family_Ok (F : RX_SPI.Family; Ok : out Boolean) is
      pragma Unreferenced (F);
   begin
      Calls := Counted (Calls);
      Ok := Calls mod 2 = 0;
   end Step_Family_Ok;

   -------------------
   -- Step_Received --
   -------------------

   procedure Step_Received (F : RX_SPI.Family; R : out RX_SPI.Received) is
      pragma Unreferenced (F);
   begin
      Calls := Counted (Calls);
      R := (Bind => Calls mod 2 = 0, Data => Calls mod 3 = 0, Processing_Required => Calls mod 5 = 0);
   end Step_Received;

   -------------------
   -- Step_Channels --
   -------------------

   procedure Step_Channels (F : RX_SPI.Family; Data : in out RX_SPI.Channel_Data) is
      pragma Unreferenced (F);
   begin
      Calls := Counted (Calls);
      Data (0) := Interfaces.Unsigned_16 (Calls mod 2048);
   end Step_Channels;

   -----------------
   -- Step_Family --
   -----------------

   procedure Step_Family (F : RX_SPI.Family) is
      pragma Unreferenced (F);
   begin
      Calls := Counted (Calls);
   end Step_Family;

end Adaflight.RX_SPI_Steps;
