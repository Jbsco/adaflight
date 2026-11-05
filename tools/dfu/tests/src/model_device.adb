with DFU.Layout;

package body Model_Device is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Base : constant DFU.Address := 16#0800_0000#;
   Size : constant := 1024 * 1024;

   type State_Kind is (Idle, Download_Sync, Download_Busy, Download_Idle, Manifest_Sync, Upload_Idle, Error, Gone);

   State_Code : constant array (State_Kind) of DFU.Byte :=
     (Idle => 2, Download_Sync => 3, Download_Busy => 4, Download_Idle => 5, Manifest_Sync => 6,
      Upload_Idle => 9, Error => 10, Gone => 8);

   Error_Target : constant := 3;
   Error_Vendor : constant := 16#0B#;

   Option_Base : constant DFU.Address := 16#1FFF_C000#;
   Option_Data : constant DFU.Byte_Array (0 .. 15) := (16#AA#, 16#EC#, 16#FF#, 16#FF#, others => 16#FF#);

   Flash      : DFU.Byte_Array (0 .. Size - 1) := (others => 0);
   Layout     : DFU.Layout.Memory;
   Strings    : array (1 .. 4) of access constant String;
   Block_Size : Natural := 2048;
   State      : State_Kind := Idle;
   Code       : DFU.Byte := 0;
   Pointer    : DFU.Address := Base;
   Pending    : DFU.Byte_Array (0 .. 65_535) := (others => 0);
   Length     : Natural := 0;
   Block      : Interfaces.Unsigned_16 := 0;
   Present    : Boolean := True;
   Stuck      : Natural := 0;
   Executed   : Boolean := False;
   Erases     : Natural := 0;
   Has_Left   : Boolean := False;
   Locked     : Boolean := False;
   Left_Ptr   : DFU.Address := 0;

   F405_Flash : aliased constant String := "@Internal Flash  /0x08000000/04*016Kg,01*064Kg,07*128Kg";
   F722_Flash : aliased constant String := "@Internal Flash  /0x08000000/04*016Kg,01*64Kg,03*128Kg";
   Options    : aliased constant String := "@Option Bytes  /0x1FFFC000/01*016 e";
   OTP        : aliased constant String := "@OTP Memory /0x1FFF7800/01*512 e,01*016 e";
   Features   : aliased constant String := "@Device Feature/0xFFFF0000/01*004 e";

   procedure Reset (Kind : Chip; Transfer : Natural := 2048) is
      Ok : Boolean;
   begin
      Strings := ((if Kind = F405 then F405_Flash'Access else F722_Flash'Access), Options'Access, OTP'Access,
                  Features'Access);
      DFU.Layout.Parse (Strings (1).all, Layout, Ok);
      pragma Assert (Ok);
      Flash := (others => 16#5A#);
      Block_Size := Transfer;
      State := Idle;
      Code := 0;
      Pointer := Base;
      Length := 0;
      Present := True;
      Stuck := 0;
      Erases := 0;
      Has_Left := False;
      Left_Ptr := 0;
      Locked := False;
   end Reset;

   function In_Options (A : DFU.Address; N : Natural) return Boolean is
     (A >= Option_Base and then Natural (A - Option_Base) + N <= Option_Data'Length);

   function In_Flash (A : DFU.Address; N : Natural) return Boolean is
     (A >= Base and then Natural (A - Base) + N <= Natural (Layout.Last (Layout.Pages) - Base) + 1);

   procedure Fill (First : DFU.Address; Length : Natural; Value : DFU.Byte) is
   begin
      Flash (Natural (First - Base) .. Natural (First - Base) + Length - 1) := (others => Value);
   end Fill;

   function Peek (A : DFU.Address) return DFU.Byte is (Flash (Natural (A - Base)));

   procedure Flip (A : DFU.Address) is
   begin
      Flash (Natural (A - Base)) := Flash (Natural (A - Base)) xor 16#01#;
   end Flip;

   procedure Set_Present (Present : Boolean) is
   begin
      Model_Device.Present := Present;
   end Set_Present;

   function Is_Present return Boolean is (Present);

   procedure Set_Protected (Locked : Boolean) is
   begin
      Model_Device.Locked := Locked;
   end Set_Protected;

   function Is_Protected return Boolean is (Locked);

   procedure Set_Stuck_Erases (Count : Natural) is
   begin
      Stuck := Count;
   end Set_Stuck_Erases;

   function Erased_Pages return Natural is (Erases);

   function Left return Boolean is (Has_Left);

   function Left_At return DFU.Address is (Left_Ptr);

   function Word_At (Data : DFU.Byte_Array; I : Natural) return DFU.Address is
     (DFU.Address (Data (I)) + 256 * DFU.Address (Data (I + 1)) + 65_536 * DFU.Address (Data (I + 2))
      + 16_777_216 * DFU.Address (Data (I + 3)));

   procedure Put (Data : in out DFU.Byte_Array; Got : in out Natural; Value : DFU.Byte) is
   begin
      if Got < Data'Length then
         Data (Data'First + Got) := Value;
         Got := Got + 1;
      end if;
   end Put;

   procedure Descriptor
     (Value, Index : Interfaces.Unsigned_16; Data : out DFU.Byte_Array; Got : out Natural; Ok : out Boolean)
   is
      Kind   : constant Interfaces.Unsigned_16 := Value / 256;
      Number : constant Natural := Natural (Value mod 256);
   begin
      Data := (others => 0);
      Got := 0;
      Ok := Present and then State /= Gone;
      if not Ok then
         return;
      end if;
      if Kind = 2 then
         for B of DFU.Byte_Array'(9, 2, 54, 0, 1, 1, 0, 16#C0#, 16#32#) loop
            Put (Data, Got, B);
         end loop;
         for Alternate in 0 .. 3 loop
            for B of DFU.Byte_Array'(9, 4, 0, DFU.Byte (Alternate), 0, 16#FE#, 1, 2, DFU.Byte (4 + Alternate)) loop
               Put (Data, Got, B);
            end loop;
         end loop;
         for B of DFU.Byte_Array'(9, 16#21#, 16#0B#, 16#FF#, 0, DFU.Byte (Block_Size mod 256),
                                  DFU.Byte (Block_Size / 256), 16#1A#, 1)
         loop
            Put (Data, Got, B);
         end loop;
      elsif Kind = 3 and then Number = 0 then
         for B of DFU.Byte_Array'(4, 3, 9, 4) loop
            Put (Data, Got, B);
         end loop;
      elsif Kind = 3 and then Number in 4 .. 7 and then Index = 16#0409# then
         declare
            Text : constant String := Strings (Number - 3).all;
         begin
            Put (Data, Got, DFU.Byte (2 + 2 * Text'Length));
            Put (Data, Got, 3);
            for C of Text loop
               Put (Data, Got, Character'Pos (C));
               Put (Data, Got, 0);
            end loop;
         end;
      else
         Ok := False;
      end if;
   end Descriptor;

   procedure Execute is
      A : DFU.Address;
   begin
      if Block = 0 and then Length = 5 and then Pending (0) = 16#21# then
         A := Word_At (Pending, 1);
         if In_Options (A, 1) and then Locked then
            State := Error;
            Code := Error_Vendor;
            return;
         elsif In_Flash (A, 1) or else In_Options (A, 1) then
            Pointer := A;
            State := Download_Idle;
            return;
         end if;
      elsif Block = 0 and then Length = 1 and then Pending (0) = 16#92# then
         Flash := (others => 16#FF#);
         Locked := False;
         State := Gone;
         return;
      elsif Block = 0 and then Length = 5 and then Pending (0) = 16#41# then
         A := Word_At (Pending, 1);
         for P in 1 .. Layout.Pages loop
            if Layout.First (P) = A then
               Fill (A, Natural (Layout.Last (P) - A) + 1, 16#FF#);
               Erases := Erases + 1;
               State := Download_Idle;
               return;
            end if;
         end loop;
      elsif Block >= 2 then
         A := Pointer + DFU.Address (Block - 2) * DFU.Address (Block_Size);
         if In_Flash (A, Length) then
            for I in 0 .. Length - 1 loop
               Flash (Natural (A - Base) + I) := Flash (Natural (A - Base) + I) and Pending (I);
            end loop;
            State := Download_Idle;
            return;
         end if;
      end if;
      State := Error;
      Code := Error_Target;
   end Execute;

   procedure Out_Request (Request : DFU.Byte; Value : Interfaces.Unsigned_16; Data : DFU.Byte_Array; Ok : out Boolean)
   is
   begin
      Ok := False;
      if not Present or else State = Gone then
         return;
      end if;
      case Request is
         when 1 =>
            if State /= Idle and then State /= Download_Idle then
               State := Error;
            elsif Data'Length = 0 then
               if State = Download_Idle then
                  State := Manifest_Sync;
                  Ok := True;
               else
                  State := Error;
               end if;
            elsif Data'Length > Block_Size then
               State := Error;
            else
               Pending (0 .. Data'Length - 1) := Data;
               Length := Data'Length;
               Block := Value;
               Executed := False;
               State := Download_Sync;
               Ok := True;
            end if;
         when 4 =>
            if State = Error then
               State := Idle;
               Code := 0;
               Ok := True;
            elsif State = Download_Busy then
               State := Error;
               Ok := True;
            else
               State := Error;
            end if;
         when 6 =>
            if State in Idle | Download_Idle | Upload_Idle then
               State := Idle;
               Ok := True;
            else
               State := Error;
            end if;
         when others =>
            State := Error;
      end case;
   end Out_Request;

   procedure In_Request
     (Request : DFU.Byte; Value : Interfaces.Unsigned_16; Data : out DFU.Byte_Array; Got : out Natural;
      Ok : out Boolean)
   is
      Reported : State_Kind := State;
      Poll     : Natural := 0;
      A        : DFU.Address;
   begin
      Data := (others => 0);
      Got := 0;
      Ok := False;
      if not Present or else State = Gone then
         return;
      end if;
      case Request is
         when 3 =>
            case State is
               when Download_Sync =>
                  State := Download_Busy;
                  Reported := Download_Busy;
                  Poll := (if Block = 0 and then Pending (0) = 16#41# then 25 else 1);
               when Download_Busy =>
                  if not Executed then
                     Executed := True;
                     Execute;
                     if State = Download_Idle and then Stuck > 0 and then Block = 0 and then Pending (0) = 16#41# then
                        Stuck := Stuck - 1;
                        State := Download_Busy;
                     end if;
                  end if;
                  if State = Gone then
                     return;
                  end if;
                  Reported := State;
               when Manifest_Sync =>
                  Reported := Manifest_Sync;
                  Has_Left := True;
                  Left_Ptr := Pointer;
                  State := Gone;
               when others =>
                  null;
            end case;
            Put (Data, Got, Code);
            Put (Data, Got, DFU.Byte (Poll mod 256));
            Put (Data, Got, DFU.Byte (Poll / 256 mod 256));
            Put (Data, Got, DFU.Byte (Poll / 65_536 mod 256));
            Put (Data, Got, State_Code (Reported));
            Put (Data, Got, 0);
            Ok := True;
         when 2 =>
            if (State = Idle or else State = Upload_Idle) and then Value >= 2 and then Data'Length <= Block_Size then
               A := Pointer + DFU.Address (Value - 2) * DFU.Address (Block_Size);
               if In_Options (A, Data'Length) and then not Locked then
                  for I in 0 .. Data'Length - 1 loop
                     Put (Data, Got, Option_Data (Natural (A - Option_Base) + I));
                  end loop;
                  State := Upload_Idle;
                  Ok := True;
                  return;
               elsif In_Flash (A, Data'Length) and then not Locked then
                  for I in 0 .. Data'Length - 1 loop
                     Put (Data, Got, Flash (Natural (A - Base) + I));
                  end loop;
                  State := Upload_Idle;
                  Ok := True;
                  return;
               end if;
            end if;
            State := Error;
         when others =>
            State := Error;
      end case;
   end In_Request;

end Model_Device;
