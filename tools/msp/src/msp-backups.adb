with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body MSP.Backups is

   use Ada.Strings.Unbounded;

   package Maps is new Ada.Containers.Indefinite_Ordered_Maps (String, String);

   function Trimmed (Line : String) return String is
      First : Natural := Line'First;
      Last  : Natural := Line'Last;
      function Blank (C : Character) return Boolean
      is (C = ' ' or else C = Ada.Characters.Latin_1.CR or else C = Ada.Characters.Latin_1.HT);
   begin
      while First <= Last and then Blank (Line (First)) loop
         First := First + 1;
      end loop;
      while Last >= First and then Blank (Line (Last)) loop
         Last := Last - 1;
      end loop;
      return Line (First .. Last);
   end Trimmed;

   function Starts_With (Line, Prefix : String) return Boolean
   is (Line'Length >= Prefix'Length and then Line (Line'First .. Line'First + Prefix'Length - 1) = Prefix);

   function Split (Text : String) return Lines is
      Result : Lines;
      Start  : Natural := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = Ada.Characters.Latin_1.LF then
            Result.Append (Trimmed (Text (Start .. I - 1)));
            Start := I + 1;
         end if;
      end loop;
      if Start <= Text'Last then
         Result.Append (Trimmed (Text (Start .. Text'Last)));
      end if;
      return Result;
   end Split;

   function Reply_Lines (Text : String) return Lines is
      Result : Lines := Split (Text);
   begin
      if not Result.Is_Empty then
         Result.Delete_First;
      end if;
      if not Result.Is_Empty and then Result.Last_Element = "#" then
         Result.Delete_Last;
      end if;
      return Result;
   end Reply_Lines;

   function Is_Command (Line : String) return Boolean is
      T : constant String := Trimmed (Line);
   begin
      return T'Length > 0 and then T (T'First) /= '#' and then Ada.Characters.Handling.To_Lower (T) /= "save";
   end Is_Command;

   --  Whether a line is part of a backup's content, which leaves out the lines that frame it.
   function Is_Content (Line : String) return Boolean
   is (Is_Command (Line)
       and then Ada.Characters.Handling.To_Lower (Trimmed (Line))
                not in "batch start" | "batch end" | "defaults nosave");

   --  A backup's content by key: a setting by its name with its value, any other line by itself, each under
   --  the profile selection above it. A profile selection is itself a key by its kind, so the last one of a
   --  kind, which a backup ends with, is the selection the board keeps.
   function Entries (Backup : Lines) return Maps.Map is
      Result  : Maps.Map;
      Section : Unbounded_String;
   begin
      for Line of Backup loop
         declare
            T      : constant String := Trimmed (Line);
            Equals : constant Natural := Ada.Strings.Fixed.Index (T, " = ");
            Space  : constant Natural := Ada.Strings.Fixed.Index (T, " ");
         begin
            if not Is_Content (T) then
               null;
            elsif Starts_With (T, "profile ") or else Starts_With (T, "rateprofile ")
              or else Starts_With (T, "battery_profile ")
            then
               Section := To_Unbounded_String (T & ": ");
               Result.Include (T (T'First .. Space - 1), T (Space + 1 .. T'Last));
            elsif Starts_With (T, "set ") and then Equals > 0 then
               Result.Include (To_String (Section) & T (T'First .. Equals - 1), T (Equals + 3 .. T'Last));
            else
               Result.Include (To_String (Section) & T, "");
            end if;
         end;
      end loop;
      return Result;
   end Entries;

   function Differences (First, Second : Lines) return Lines is
      A      : constant Maps.Map := Entries (First);
      B      : constant Maps.Map := Entries (Second);
      Keys   : Maps.Map := A;
      Result : Lines;
      function Shown (Key, Value : String) return String
      is (if Value = "" then Key elsif Starts_With (Key, "set ") or else Ada.Strings.Fixed.Index (Key, ": set ") > 0
          then Key & " = " & Value else Key & " " & Value);
   begin
      for C in B.Iterate loop
         Keys.Include (Maps.Key (C), "");
      end loop;
      for C in Keys.Iterate loop
         declare
            Key : constant String := Maps.Key (C);
         begin
            if not B.Contains (Key) then
               Result.Append ("- " & Shown (Key, A.Element (Key)));
            elsif not A.Contains (Key) then
               Result.Append ("+ " & Shown (Key, B.Element (Key)));
            elsif A.Element (Key) /= B.Element (Key) then
               Result.Append ("~ " & Key & ": " & A.Element (Key) & " -> " & B.Element (Key));
            end if;
         end;
      end loop;
      return Result;
   end Differences;

end MSP.Backups;
