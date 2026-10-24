package body Adaflight.Card_Bus_Steps with SPARK_Mode is

   procedure Step_Preinit_CS (D : in out Card_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Preinit_CS;

   procedure Step_Init_Detect_Pin (D : in out Card_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Init_Detect_Pin;

   procedure Step_Read_Detect_Pin (D : in out Card_Line; High : out Boolean) is
      pragma Unreferenced (D);
   begin
      High := True;
   end Step_Read_Detect_Pin;

   procedure Step_Attach_Bus (D : in out Card_Line; Instance : Byte) is
      pragma Unreferenced (D, Instance);
   begin
      null;
   end Step_Attach_Bus;

   procedure Step_Prepare_CS (D : in out Card_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Prepare_CS;

   procedure Step_Configure_CS (D : in out Card_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Configure_CS;

   procedure Step_CS_High (D : in out Card_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_CS_High;

   procedure Step_Divider (D : in out Card_Line; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16) is
      pragma Unreferenced (D, Hz);
   begin
      Divisor := 1;
   end Step_Divider;

   procedure Step_Set_Divisor (D : in out Card_Line; Divisor : Interfaces.Unsigned_16) is
      pragma Unreferenced (D, Divisor);
   begin
      null;
   end Step_Set_Divisor;

   procedure Step_Delay_Ms (D : in out Card_Line; Ms : Natural) is
      pragma Unreferenced (D, Ms);
   begin
      null;
   end Step_Delay_Ms;

   procedure Step_Delay_Us (D : in out Card_Line; Us : Natural) is
      pragma Unreferenced (D, Us);
   begin
      null;
   end Step_Delay_Us;

   procedure Step_Millis (D : in out Card_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Millis;

   procedure Step_Start_Sequence (D : in out Card_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Start_Sequence;

   procedure Step_Segment
     (D       : in out Card_Line;
      Kind    : Adaflight.SD_Card_Bus.Segment_Kind;
      Negate  : Boolean;
      Length  : Positive;
      Tx      : Byte_Array;
      Rx      : in out Byte_Array;
      Receive : Boolean)
   is
      pragma Unreferenced (D, Kind, Negate, Length, Tx, Rx, Receive);
   begin
      null;
   end Step_Segment;

   procedure Step_Wait (D : in out Card_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Wait;

   procedure Step_Release (D : in out Card_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Release;

   procedure Step_Bus_Busy (D : in out Card_Line; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
   end Step_Bus_Busy;

   function Step_Uses_DMA (D : Card_Line) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Step_Uses_DMA;

   procedure Step_Read_Write (D : in out Card_Line; Tx : Byte_Array) is
      pragma Unreferenced (D, Tx);
   begin
      null;
   end Step_Read_Write;

   procedure Step_Complete
     (D          : in out Card_Line;
      Write      : Boolean;
      Index      : Interfaces.Unsigned_32;
      Has_Buffer : Boolean;
      Data       : Interfaces.Unsigned_32)
   is
      pragma Unreferenced (D, Write, Index, Has_Buffer, Data);
   begin
      null;
   end Step_Complete;

end Adaflight.Card_Bus_Steps;
