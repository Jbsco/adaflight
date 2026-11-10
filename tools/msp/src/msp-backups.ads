with Ada.Containers.Indefinite_Vectors;

--  Backups of a configuration as a flight controller's command line prints them, read as lines and compared
--  setting by setting.
package MSP.Backups is

   package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
   subtype Lines is Line_Vectors.Vector;

   --  The lines of a text, without their line ends.
   function Split (Text : String) return Lines;

   --  A command's output: the lines between the echoed command and the prompt.
   function Reply_Lines (Text : String) return Lines;

   --  Whether a restore sends a backup's line: not empty, not a comment, and not the save, which a restore
   --  sends itself once no line failed.
   function Is_Command (Line : String) return Boolean;

   --  The differences between two backups in the order of their keys, a line each: "- " for a line the first
   --  alone has, "+ " for a line the second alone has, and "~ " for a setting with two values. A setting's
   --  key is its name under the profile selection above it, and any other line is its own key. Comments and
   --  the lines that frame a backup (the batch markers, the reset to defaults and the save) are no part of
   --  the comparison.
   function Differences (First, Second : Lines) return Lines;

end MSP.Backups;
