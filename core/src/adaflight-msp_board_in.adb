with Adaflight.Config_Reset;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Board_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_8;

   --  The request's byte at an offset, zero past its end.
   function Byte_At (Request : Byte_Array; Offset : Natural) return Byte is
     (if Offset < Request'Length then Request (Request'First + Offset) else 0)
     with Pre => Request'Length <= Max_Request;

   --  The request's bytes from an offset, up to a count and before the
   --  first zero, as text.
   function Text_At (Request : Byte_Array; Offset : Natural; Count : Natural) return String
     with Pre  => Request'Length <= Max_Request and then Offset <= 256 and then Count <= Board_Info.Identity_Max,
          Post => Text_At'Result'First = 1 and then Text_At'Result'Length <= Count
   is
      Text : String (1 .. Count) := (others => ' ');
      Last : Natural := 0;
   begin
      for K in 0 .. Count - 1 loop
         pragma Loop_Invariant (Last = K);
         exit when Offset + K >= Request'Length or else Request (Request'First + Offset + K) = 0;
         Last := Last + 1;
         Text (Last) := Character'Val (Request (Request'First + Offset + K));
      end loop;
      return Text (1 .. Last);
   end Text_At;

   --  A name and a manufacturer, each a length byte and that many bytes,
   --  kept to their first 20 and 4, set once and stored.
   procedure Set_Information
     (C : in out Configuration; Board : in out Board_Info.State; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then Board = Board'Old)
   is
      Name_Size  : constant Natural := Natural (U8 (Request, 0));
      Maker_Size : constant Natural := Natural (Byte_At (Request, 1 + Name_Size));
   begin
      if Board.Information_Set or else Request'Length < 2 + Name_Size + Maker_Size then
         R := Error;
         return;
      end if;
      Board.Name :=
        Board_Info.To_Identity (Text_At (Request, 1, Natural'Min (Name_Size, Board_Info.Board_Name_Length)));
      Board.Manufacturer :=
        Board_Info.To_Identity
          (Text_At (Request, 2 + Name_Size, Natural'Min (Maker_Size, Board_Info.Manufacturer_Length)));
      Board_Info.Persist_Information (C, Board);
      R := Ack;
   end Set_Information;

   --  Thirty-two signature bytes, zero past the request's end, set once and
   --  stored.
   procedure Set_Signature
     (C : in out Configuration; Board : in out Board_Info.State; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then Board = Board'Old)
   is
   begin
      if Board.Signature_Set then
         R := Error;
         return;
      end if;
      for K in Board.Signature'Range loop
         Board.Signature (K) := Byte_At (Request, K);
      end loop;
      Board_Info.Persist_Signature (C, Board);
      R := Ack;
   end Set_Signature;

   procedure Process
     (C : in out Configuration; Board : in out Board_Info.State; Command : Interfaces.Unsigned_16;
      Request : Byte_Array; Armed : Boolean; R : out Result; E : out Effects)
   is
   begin
      E := No_Effects;
      case Command is
         when Set_Board_Info_Command =>
            Set_Information (C, Board, Request, R);
         when Set_Signature_Command =>
            Set_Signature (C, Board, Request, R);
         when Reset_Config_Command =>
            if not Armed then
               C := Config_Reset.Reset (Board);
               E.Save := True;
               E.Reboot := True;
               E.Reply_Value := 1;
            end if;
            E.Reply := True;
            R := Ack;
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Board_In;
