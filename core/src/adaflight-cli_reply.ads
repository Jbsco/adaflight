--  Command line reply: the text the commands put, kept up to the reply's
--  size, with a flag for text that did not fit.
package Adaflight.CLI_Reply with SPARK_Mode is

   Size : constant := 4_096;

   type Reply is record
      Text     : String (1 .. Size) := (others => ' ');
      Length   : Natural range 0 .. Size := 0;
      Overflow : Boolean := False;
   end record;

   procedure Put (Into : in out Reply; Text : String);

end Adaflight.CLI_Reply;
