with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;
with Adaflight.VTX_Table_Store;

package body Adaflight.MSP_VTX_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   Encoded_Max   : constant := 63;
   Max_Frequency : constant := 5999;
   Table_Size    : constant := VTX_Table_Store.Table_Size;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; D : Device;
      T : VTX_Table.Table; R : out Result; E : out Effects)
   is
      pragma Unreferenced (Command);
      Length   : constant Natural := Request'Length;
      Word     : constant Integer_64 := U16 (Request, 0);
      Pos      : Natural range 2 .. 11 := 2;
      Pit      : Integer_64 := -1;
      Counts   : Boolean := False;
      Bands    : Integer_64 := 0;
      Channels : Integer_64 := 0;
      Powers   : Integer_64 := 0;
      Clear    : Integer_64 := 0;
      P        : Plan;

      --  The bytes the request holds past a position.
      function Remaining (At_Pos : Natural) return Natural is (if Length > At_Pos then Length - At_Pos else 0);

      --  The running table's frequency when a transmitter is present.
      function Lookup (Band : Integer_64; Channel : Integer_64) return Integer_64 is
        (if D.Present then Integer_64 (VTX_Table.Frequency_Of (T, Natural (Band), Natural (Channel))) else 0)
        with Pre => Band in 0 .. 256 and then Channel in 0 .. 256;
   begin
      E := No_Effects;
      if Word <= Encoded_Max then
         Add (P, Vtx_Band, Word / 8 + 1, 0);
         Add (P, Vtx_Channel, Word mod 8 + 1, 0);
         Add (P, Vtx_Freq, Lookup (Word / 8 + 1, Word mod 8 + 1), 0);
      elsif Word <= Max_Frequency then
         Add (P, Vtx_Band, 0, 0);
         Add (P, Vtx_Freq, Word, 0);
      end if;
      if Remaining (Pos) >= 2 then
         Add (P, Vtx_Power, U8 (Request, Pos), 0);
         Pit := U8 (Request, Pos + 1);
         Pos := Pos + 2;
      end if;
      if Remaining (Pos) >= 1 then
         Add (P, Vtx_Low_Power_Disarm, U8 (Request, Pos), 0);
         Pos := Pos + 1;
      end if;
      if Remaining (Pos) >= 2 then
         Add (P, Vtx_Pit_Mode_Freq, U16 (Request, Pos), 0);
         Pos := Pos + 2;
      end if;
      if Remaining (Pos) >= 4 then
         declare
            Band    : constant Integer_64 := U8 (Request, Pos);
            Channel : constant Integer_64 := U8 (Request, Pos + 1);
         begin
            Add (P, Vtx_Band, Band, 0);
            Add (P, Vtx_Channel, Channel, 0);
            Add (P, Vtx_Freq, (if Band /= 0 then Lookup (Band, Channel) else U16 (Request, Pos + 2)), 0);
         end;
         Pos := Pos + 4;
      end if;
      if Remaining (Pos) >= 4 then
         Counts := True;
         Bands := U8 (Request, Pos);
         Channels := U8 (Request, Pos + 1);
         Powers := U8 (Request, Pos + 2);
         Clear := U8 (Request, Pos + 3);
      end if;
      if (Counts and then (Bands > Table_Size or else Channels > Table_Size or else Powers > Table_Size))
        or else not Valid (P)
      then
         R := Error;
         return;
      end if;
      Apply (C, P);
      if Pit >= 0 and then D.Known_Type and then D.Pit_Mode /= (Pit /= 0) then
         E.Pit_Mode_Set := True;
         E.Pit_Mode_Value := Byte (Pit);
      end if;
      if Counts then
         C.Vtx_Table_Config.Bands := Byte (Bands);
         C.Vtx_Table_Config.Channels := Byte (Channels);
         C.Vtx_Table_Config.Power_Levels := Byte (Powers);
         if Clear /= 0 then
            for B in VTX_Table_Store.Band loop
               VTX_Table_Store.Clear_Band (C.Vtx_Table_Config, B);
               VTX_Table_Store.Clear_Channels (C.Vtx_Table_Config, B, 0);
            end loop;
            VTX_Table_Store.Clear_Power_Labels (C.Vtx_Table_Config, 0);
            VTX_Table_Store.Clear_Power_Values (C.Vtx_Table_Config, 0);
         end if;
      end if;
      E.VTX_Ready := True;
      R := Ack;
   end Process;

end Adaflight.MSP_VTX_In;
