--  The parts the MSP in messages that write the stored configuration share:
--  a request's fields read at their offsets, zero past its end, and a plan
--  of setting writes in the order a message makes them, checked together
--  against the settings' ranges before any is made.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.Settings_Table; use Adaflight.Settings_Table;

package Adaflight.MSP_Write_Plans with SPARK_Mode is
   use type Interfaces.Integer_64;
   subtype Integer_64 is Interfaces.Integer_64;

   Max_Request : constant := 255;

   subtype Offset_Range is Natural range 0 .. 64;

   --  The request's byte at an offset, zero past its end.
   function U8 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (if Offset < Request'Length then Integer_64 (Request (Request'First + Offset)) else 0)
     with Pre  => Request'Length <= Max_Request,
          Post => U8'Result in 0 .. 255;

   --  The request's little-endian 16-bit value at an offset.
   function U16 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (U8 (Request, Offset) + 256 * U8 (Request, Offset + 1))
     with Pre  => Request'Length <= Max_Request and then Offset < Offset_Range'Last,
          Post => U16'Result in 0 .. 65_535;

   --  The request's little-endian 32-bit value at an offset.
   function U32 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (U16 (Request, Offset) + 65_536 * U16 (Request, Offset + 2))
     with Pre  => Request'Length <= Max_Request and then Offset < Offset_Range'Last - 2,
          Post => U32'Result in 0 .. 2 ** 32 - 1;

   --  The byte read into a signed 8-bit field.
   function S8 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (if U8 (Request, Offset) >= 2 ** 7 then U8 (Request, Offset) - 2 ** 8 else U8 (Request, Offset))
     with Pre => Request'Length <= Max_Request;

   --  The 16-bit value read into a signed 16-bit field.
   function S16 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (if U16 (Request, Offset) >= 2 ** 15 then U16 (Request, Offset) - 2 ** 16 else U16 (Request, Offset))
     with Pre => Request'Length <= Max_Request and then Offset < Offset_Range'Last;

   --  Whether a value is within a setting's range: its bounds for a direct
   --  setting, a named value of its table for a lookup setting.
   function In_Range (S : Setting; V : Integer_64) return Boolean;

   Max_Writes : constant := 36;

   type Planned is record
      S       : Setting := P_Roll;
      Value   : Integer_64 := 0;
      Profile : Natural := 0;
      Index   : Natural := 0;
   end record;

   type Planned_List is array (1 .. Max_Writes) of Planned;

   type Plan is record
      Items : Planned_List;
      Count : Natural range 0 .. Max_Writes := 0;
   end record;

   function Fits (P : Plan) return Boolean is
     (for all K in 1 .. P.Count =>
        P.Items (K).Profile < Profile_Count (P.Items (K).S) and then P.Items (K).Index < Element_Count (P.Items (K).S));

   procedure Add (P : in out Plan; S : Setting; Value : Integer_64; Profile : Natural; Index : Natural := 0)
     with Pre  => P.Count < Max_Writes and then Fits (P) and then Profile < Profile_Count (S)
                  and then Index < Element_Count (S),
          Post => Fits (P) and then P.Count = P.Count'Old + 1;

   function Valid (P : Plan) return Boolean is
     (for all K in 1 .. P.Count => In_Range (P.Items (K).S, P.Items (K).Value));

   --  Every planned write, in order, as the command line makes it.
   procedure Apply (C : in out Configuration; P : Plan)
     with Pre => Fits (P);

end Adaflight.MSP_Write_Plans;
