--  The STM32F405's timer channels and DMA options, generated from the
--  reference's tables.
package body Adaflight.Timer_Tables with SPARK_Mode is

   type Timer_Channel_List is array (Positive range <>) of Timer_Channel;
   Channels : constant Timer_Channel_List (1 .. 70) :=
     ((16, 2, 1, False, 1), (17, 2, 2, False, 1), (18, 2, 3, False, 1), (19, 2, 4, False, 1), (21, 2, 1, False, 1),
      (23, 1, 1, True, 1), (24, 1, 1, False, 1), (25, 1, 2, False, 1), (26, 1, 3, False, 1), (27, 1, 4, False, 1),
      (31, 2, 1, False, 1), (16, 5, 1, False, 2), (17, 5, 2, False, 2), (18, 5, 3, False, 2), (19, 5, 4, False, 2),
      (22, 3, 1, False, 2), (23, 3, 2, False, 2), (18, 9, 1, False, 3), (19, 9, 2, False, 3), (21, 8, 1, True, 3),
      (23, 8, 1, True, 3), (22, 13, 1, False, 9), (23, 14, 1, False, 9), (32, 1, 2, True, 1), (33, 1, 3, True, 1),
      (35, 2, 2, False, 1), (42, 2, 3, False, 1), (43, 2, 4, False, 1), (45, 1, 1, True, 1), (46, 1, 2, True, 1),
      (47, 1, 3, True, 1), (32, 3, 3, False, 2), (33, 3, 4, False, 2), (36, 3, 1, False, 2), (37, 3, 2, False, 2),
      (38, 4, 1, False, 2), (39, 4, 2, False, 2), (40, 4, 3, False, 2), (41, 4, 4, False, 2), (32, 8, 2, True, 3),
      (33, 8, 3, True, 3), (40, 10, 1, False, 3), (41, 11, 1, False, 3), (46, 8, 2, True, 3), (47, 8, 3, True, 3),
      (46, 12, 1, False, 9), (47, 12, 2, False, 9), (54, 3, 1, False, 2), (55, 3, 2, False, 2),
      (56, 3, 3, False, 2), (57, 3, 4, False, 2), (54, 8, 1, False, 3), (55, 8, 2, False, 3), (56, 8, 3, False, 3),
      (57, 8, 4, False, 3), (76, 4, 1, False, 2), (77, 4, 2, False, 2), (78, 4, 3, False, 2), (79, 4, 4, False, 2),
      (88, 1, 1, True, 1), (89, 1, 1, False, 1), (90, 1, 2, True, 1), (91, 1, 2, False, 1), (92, 1, 3, True, 1),
      (93, 1, 3, False, 1), (94, 1, 4, False, 1), (85, 9, 1, False, 3), (86, 9, 2, False, 3),
      (102, 10, 1, False, 3), (103, 11, 1, False, 3));

   --  The most DMA options a timer channel and a peripheral have here.
   Timer_Option_Count      : constant := 3;
   Peripheral_Option_Count : constant := 2;
   type Timer_Options is array (1 .. Timer_Option_Count) of DMA_Stream;
   type Peripheral_Options is array (1 .. Peripheral_Option_Count) of DMA_Stream;

   --  A timer channel's DMA stream options, in option number order.
   type Timer_DMA is record
      Timer   : Timer_Number;
      Channel : Channel_Number;
      Count   : Natural range 0 .. Timer_Option_Count;
      Options : Timer_Options;
   end record;
   type Timer_DMA_List is array (Positive range <>) of Timer_DMA;

   Timer_Streams : constant Timer_DMA_List (1 .. 23) :=
     ((1, 1, 3, ((2, 6, 0), (2, 1, 6), (2, 3, 6))), (1, 2, 2, ((2, 6, 0), (2, 2, 6), (1, 0, 0))),
      (1, 3, 2, ((2, 6, 0), (2, 6, 6), (1, 0, 0))), (1, 4, 1, ((2, 4, 6), (1, 0, 0), (1, 0, 0))),
      (2, 1, 1, ((1, 5, 3), (1, 0, 0), (1, 0, 0))), (2, 2, 1, ((1, 6, 3), (1, 0, 0), (1, 0, 0))),
      (2, 3, 1, ((1, 1, 3), (1, 0, 0), (1, 0, 0))), (2, 4, 2, ((1, 7, 3), (1, 6, 3), (1, 0, 0))),
      (3, 1, 1, ((1, 4, 5), (1, 0, 0), (1, 0, 0))), (3, 2, 1, ((1, 5, 5), (1, 0, 0), (1, 0, 0))),
      (3, 3, 1, ((1, 7, 5), (1, 0, 0), (1, 0, 0))), (3, 4, 1, ((1, 2, 5), (1, 0, 0), (1, 0, 0))),
      (4, 1, 1, ((1, 0, 2), (1, 0, 0), (1, 0, 0))), (4, 2, 1, ((1, 3, 2), (1, 0, 0), (1, 0, 0))),
      (4, 3, 1, ((1, 7, 2), (1, 0, 0), (1, 0, 0))), (5, 1, 1, ((1, 2, 6), (1, 0, 0), (1, 0, 0))),
      (5, 2, 1, ((1, 4, 6), (1, 0, 0), (1, 0, 0))), (5, 3, 1, ((1, 0, 6), (1, 0, 0), (1, 0, 0))),
      (5, 4, 2, ((1, 1, 6), (1, 3, 6), (1, 0, 0))), (8, 1, 2, ((2, 2, 0), (2, 2, 7), (1, 0, 0))),
      (8, 2, 2, ((2, 2, 0), (2, 3, 7), (1, 0, 0))), (8, 3, 2, ((2, 2, 0), (2, 4, 7), (1, 0, 0))),
      (8, 4, 1, ((2, 7, 7), (1, 0, 0), (1, 0, 0))));

   --  A peripheral device's DMA stream options, the device counted from zero.
   type Peripheral_DMA is record
      Which   : Peripheral;
      Device  : Natural range 0 .. 15;
      Count   : Natural range 0 .. Peripheral_Option_Count;
      Options : Peripheral_Options;
   end record;
   type Peripheral_DMA_List is array (Positive range <>) of Peripheral_DMA;

   Peripheral_Streams : constant Peripheral_DMA_List (1 .. 21) :=
     ((SPI_SDO, 0, 2, ((2, 3, 3), (2, 5, 3))), (SPI_SDI, 0, 2, ((2, 0, 3), (2, 2, 3))),
      (SPI_SDO, 1, 1, ((1, 4, 0), (1, 0, 0))), (SPI_SDI, 1, 1, ((1, 3, 0), (1, 0, 0))),
      (SPI_SDO, 2, 2, ((1, 5, 0), (1, 7, 0))), (SPI_SDI, 2, 2, ((1, 0, 0), (1, 2, 0))),
      (ADC, 0, 2, ((2, 0, 0), (2, 4, 0))), (ADC, 1, 2, ((2, 2, 1), (2, 3, 1))),
      (ADC, 2, 2, ((2, 0, 2), (2, 1, 2))), (UART_TX, 0, 1, ((2, 7, 4), (1, 0, 0))),
      (UART_RX, 0, 2, ((2, 5, 4), (2, 2, 4))), (UART_TX, 1, 1, ((1, 6, 4), (1, 0, 0))),
      (UART_RX, 1, 1, ((1, 5, 4), (1, 0, 0))), (UART_TX, 2, 1, ((1, 3, 4), (1, 0, 0))),
      (UART_RX, 2, 1, ((1, 1, 4), (1, 0, 0))), (UART_TX, 3, 1, ((1, 4, 4), (1, 0, 0))),
      (UART_RX, 3, 1, ((1, 2, 4), (1, 0, 0))), (UART_TX, 4, 1, ((1, 7, 4), (1, 0, 0))),
      (UART_RX, 4, 1, ((1, 0, 4), (1, 0, 0))), (UART_TX, 5, 2, ((2, 6, 5), (2, 7, 5))),
      (UART_RX, 5, 2, ((2, 1, 5), (2, 2, 5))));

   type Timer_List is array (Positive range <>) of Timer_Number;
   Timers : constant Timer_List (1 .. 14) := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14);

   function Channel_Count return Natural is (Channels'Last);
   function Channel (K : Positive) return Timer_Channel is (Channels (K));
   function Timer_Count return Natural is (Timers'Last);
   function Timer_At (I : Positive) return Timer_Number is (Timers (I));
   function Request_Multiplexed return Boolean is (False);

   function By_Tag_And_Index (Tag : Unsigned_8; Index : Natural) return Natural is
      Seen : Natural := 0;
   begin
      if Tag = 0 or else Index = 0 then
         return 0;
      end if;
      for K in Channels'Range loop
         pragma Loop_Invariant (Seen < K);
         if Channels (K).Tag = Tag then
            Seen := Seen + 1;
            if Seen = Index then
               return K;
            end if;
         end if;
      end loop;
      return 0;
   end By_Tag_And_Index;

   function Occurrences (Tag : Unsigned_8) return Natural is
      Seen : Natural := 0;
   begin
      for K in Channels'Range loop
         pragma Loop_Invariant (Seen < K);
         if Tag /= 0 and then Channels (K).Tag = Tag then
            Seen := Seen + 1;
         end if;
      end loop;
      return Seen;
   end Occurrences;

   procedure Timer_Option
     (Timer : Timer_Number; Channel : Channel_Number; Option : Integer; Found : out Boolean; Stream : out DMA_Stream)
   is
   begin
      Found := False;
      Stream := (1, 0, 0);
      if Option not in 0 .. Timer_Option_Count - 1 then
         return;
      end if;
      for K in Timer_Streams'Range loop
         if Timer_Streams (K).Timer = Timer and then Timer_Streams (K).Channel = Channel
           and then Option < Timer_Streams (K).Count
         then
            Found := True;
            Stream := Timer_Streams (K).Options (Option + 1);
            return;
         end if;
      end loop;
   end Timer_Option;

   procedure Peripheral_Option
     (Which : Peripheral; Device : Natural; Option : Integer; Found : out Boolean; Stream : out DMA_Stream)
   is
   begin
      Found := False;
      Stream := (1, 0, 0);
      if Option not in 0 .. Peripheral_Option_Count - 1 then
         return;
      end if;
      for K in Peripheral_Streams'Range loop
         if Peripheral_Streams (K).Which = Which and then Peripheral_Streams (K).Device = Device
           and then Option < Peripheral_Streams (K).Count
         then
            Found := True;
            Stream := Peripheral_Streams (K).Options (Option + 1);
            return;
         end if;
      end loop;
   end Peripheral_Option;

   function Has_Timer_Option (Timer : Timer_Number; Channel : Channel_Number; Option : Integer) return Boolean is
   begin
      if Option not in 0 .. Timer_Option_Count - 1 then
         return False;
      end if;
      for K in Timer_Streams'Range loop
         if Timer_Streams (K).Timer = Timer and then Timer_Streams (K).Channel = Channel
           and then Option < Timer_Streams (K).Count
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Timer_Option;

   function Has_Peripheral_Option (Which : Peripheral; Device : Natural; Option : Integer) return Boolean is
   begin
      if Option not in 0 .. Peripheral_Option_Count - 1 then
         return False;
      end if;
      for K in Peripheral_Streams'Range loop
         if Peripheral_Streams (K).Which = Which and then Peripheral_Streams (K).Device = Device
           and then Option < Peripheral_Streams (K).Count
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Peripheral_Option;

end Adaflight.Timer_Tables;
