--  The STM32H743's timer channels and DMA requests, generated from the
--  reference's tables. Its DMA multiplexer gives any stream any request,
--  so a DMA option names a stream, DMA1 streams 0 to 7 then DMA2's, and its
--  channel is the device's request.
package body Adaflight.Timer_Tables with SPARK_Mode is

   type Timer_Channel_List is array (Positive range <>) of Timer_Channel;
   Channels : constant Timer_Channel_List (1 .. 91) :=
     ((16, 2, 1, False, 1), (17, 2, 2, False, 1), (18, 2, 3, False, 1), (19, 2, 4, False, 1), (21, 2, 1, False, 1),
      (23, 1, 1, True, 1), (24, 1, 1, False, 1), (25, 1, 2, False, 1), (26, 1, 3, False, 1), (27, 1, 4, False, 1),
      (31, 2, 1, False, 1), (16, 5, 1, False, 2), (17, 5, 2, False, 2), (18, 5, 3, False, 2), (19, 5, 4, False, 2),
      (22, 3, 1, False, 2), (23, 3, 2, False, 2), (21, 8, 1, True, 3), (23, 8, 1, True, 3), (22, 13, 1, False, 9),
      (23, 14, 1, False, 9), (17, 15, 1, True, 4), (18, 15, 1, False, 4), (19, 15, 2, False, 4),
      (32, 1, 2, True, 1), (33, 1, 3, True, 1), (35, 2, 2, False, 1), (38, 16, 1, True, 1), (39, 17, 1, True, 1),
      (40, 16, 1, False, 1), (41, 17, 1, False, 1), (42, 2, 3, False, 1), (43, 2, 4, False, 1),
      (45, 1, 1, True, 1), (46, 1, 2, True, 1), (47, 1, 3, True, 1), (32, 3, 3, False, 2), (33, 3, 4, False, 2),
      (36, 3, 1, False, 2), (37, 3, 2, False, 2), (38, 4, 1, False, 2), (39, 4, 2, False, 2), (40, 4, 3, False, 2),
      (41, 4, 4, False, 2), (46, 12, 1, False, 2), (47, 12, 2, False, 2), (32, 8, 2, True, 3), (33, 8, 3, True, 3),
      (46, 8, 2, True, 3), (47, 8, 3, True, 3), (54, 3, 1, False, 2), (55, 3, 2, False, 2), (56, 3, 3, False, 2),
      (57, 3, 4, False, 2), (54, 8, 1, False, 3), (55, 8, 2, False, 3), (56, 8, 3, False, 3), (57, 8, 4, False, 3),
      (76, 4, 1, False, 2), (77, 4, 2, False, 2), (78, 4, 3, False, 2), (79, 4, 4, False, 2), (88, 1, 1, True, 1),
      (89, 1, 1, False, 1), (90, 1, 2, True, 1), (91, 1, 2, False, 1), (92, 1, 3, True, 1), (93, 1, 3, False, 1),
      (94, 1, 4, False, 1), (84, 15, 1, True, 4), (85, 15, 1, False, 4), (86, 15, 2, False, 4),
      (102, 16, 1, False, 1), (103, 17, 1, False, 1), (104, 16, 1, True, 1), (105, 17, 1, True, 1),
      (104, 13, 1, False, 9), (105, 14, 1, False, 9), (138, 5, 1, False, 2), (139, 5, 2, False, 2),
      (140, 5, 3, False, 2), (141, 8, 1, True, 3), (142, 8, 2, True, 3), (143, 8, 3, True, 3),
      (134, 12, 1, False, 2), (137, 12, 2, False, 2), (144, 5, 4, False, 2), (146, 8, 4, False, 3),
      (149, 8, 1, False, 3), (150, 8, 2, False, 3), (151, 8, 3, False, 3));

   subtype Request is Natural range 0 .. 127;

   --  A timer channel's request.
   type Timer_Request is record
      Timer   : Timer_Number;
      Channel : Channel_Number;
      Code    : Request;
   end record;
   type Timer_Request_List is array (Positive range <>) of Timer_Request;
   Timer_Requests : constant Timer_Request_List (1 .. 26) :=
     ((1, 1, 11), (1, 2, 12), (1, 3, 13), (1, 4, 14), (2, 1, 18), (2, 2, 19), (2, 3, 20), (2, 4, 21), (3, 1, 23),
      (3, 2, 24), (3, 3, 25), (3, 4, 26), (4, 1, 29), (4, 2, 30), (4, 3, 31), (5, 1, 55), (5, 2, 56), (5, 3, 57),
      (5, 4, 58), (8, 1, 47), (8, 2, 48), (8, 3, 49), (8, 4, 50), (15, 1, 105), (16, 1, 109), (17, 1, 111));

   --  A peripheral device's request, the device counted from zero.
   type Peripheral_Request is record
      Which  : Peripheral;
      Device : Natural range 0 .. 15;
      Code   : Request;
   end record;
   type Peripheral_Request_List is array (Positive range <>) of Peripheral_Request;
   Peripheral_Requests : constant Peripheral_Request_List (1 .. 29) :=
     ((SPI_SDO, 0, 38), (SPI_SDI, 0, 37), (SPI_SDO, 1, 40), (SPI_SDI, 1, 39), (SPI_SDO, 2, 62), (SPI_SDI, 2, 61),
      (SPI_SDO, 3, 84), (SPI_SDI, 3, 83), (SPI_SDO, 4, 86), (SPI_SDI, 4, 85), (ADC, 0, 9), (ADC, 1, 10),
      (ADC, 2, 115), (UART_TX, 0, 42), (UART_RX, 0, 41), (UART_TX, 1, 44), (UART_RX, 1, 43), (UART_TX, 2, 46),
      (UART_RX, 2, 45), (UART_TX, 3, 64), (UART_RX, 3, 63), (UART_TX, 4, 66), (UART_RX, 4, 65), (UART_TX, 5, 72),
      (UART_RX, 5, 71), (UART_TX, 6, 80), (UART_RX, 6, 79), (UART_TX, 7, 82), (UART_RX, 7, 81));

   type Timer_List is array (Positive range <>) of Timer_Number;
   Timers : constant Timer_List (1 .. 14) := (1, 2, 3, 4, 5, 6, 7, 8, 12, 13, 14, 15, 16, 17);

   function Channel_Count return Natural is (Channels'Last);
   function Channel (K : Positive) return Timer_Channel is (Channels (K));
   function Timer_Count return Natural is (Timers'Last);
   function Timer_At (I : Positive) return Timer_Number is (Timers (I));
   function Request_Multiplexed return Boolean is (True);

   --  The stream of an option, with a request as its channel.
   function Stream_Of (Option : Natural; Code : Request) return DMA_Stream is
     ((Controller => Option / 8 + 1, Stream => Option mod 8, Channel => Code))
     with Pre => Option < Max_Timer_Options;

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
      if Option not in 0 .. Max_Timer_Options - 1 then
         return;
      end if;
      for K in Timer_Requests'Range loop
         if Timer_Requests (K).Timer = Timer and then Timer_Requests (K).Channel = Channel then
            Found := True;
            Stream := Stream_Of (Option, Timer_Requests (K).Code);
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
      if Option not in 0 .. Max_Peripheral_Options - 1 then
         return;
      end if;
      for K in Peripheral_Requests'Range loop
         if Peripheral_Requests (K).Which = Which and then Peripheral_Requests (K).Device = Device then
            Found := True;
            Stream := Stream_Of (Option, Peripheral_Requests (K).Code);
            return;
         end if;
      end loop;
   end Peripheral_Option;

   function Has_Timer_Option (Timer : Timer_Number; Channel : Channel_Number; Option : Integer) return Boolean is
   begin
      if Option not in 0 .. Max_Timer_Options - 1 then
         return False;
      end if;
      for K in Timer_Requests'Range loop
         if Timer_Requests (K).Timer = Timer and then Timer_Requests (K).Channel = Channel then
            return True;
         end if;
      end loop;
      return False;
   end Has_Timer_Option;

   function Has_Peripheral_Option (Which : Peripheral; Device : Natural; Option : Integer) return Boolean is
   begin
      if Option not in 0 .. Max_Peripheral_Options - 1 then
         return False;
      end if;
      for K in Peripheral_Requests'Range loop
         if Peripheral_Requests (K).Which = Which and then Peripheral_Requests (K).Device = Device then
            return True;
         end if;
      end loop;
      return False;
   end Has_Peripheral_Option;

end Adaflight.Timer_Tables;
