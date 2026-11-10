with Interfaces;
with MSP.Transport;

--  A flight controller's command line over the link: bytes sent, and the text read until its prompt ends
--  it.
package MSP.Console with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Max_Text : constant := 2 ** 16;
   subtype Text_Length is Natural range 0 .. Max_Text;
   subtype Text_Buffer is Byte_Array (1 .. Max_Text);

   Max_Line  : constant := 1024;
   Max_Reads : constant := 100_000;

   --  The prompt ended the text, no prompt came, or the bytes did not go out.
   type Status is (Prompted, No_Prompt, Not_Sent);

   --  The command line's prompt after a line end, which a text ends with once a command is done.
   function Ends_With_Prompt (Text : Text_Buffer; Last : Text_Length) return Boolean
   is (Last >= 4
       and then Text (Last - 3) = 13
       and then Text (Last - 2) = 10
       and then Text (Last - 1) = Character'Pos ('#')
       and then Text (Last) = Character'Pos (' '));

   --  Sends the bytes and reads the link. The text is done when it ends with the prompt and Quiet empty
   --  reads follow in a row, since a line of the text itself can start as the prompt does. Without a prompt
   --  the reads stop after Patience empty reads in a row. Text holds what arrived up to its size, Last is
   --  its length, and Cut says that more arrived than it holds.
   procedure Exchange
     (Line     : Byte_Array;
      Quiet    : Positive;
      Patience : Positive;
      Text     : out Text_Buffer;
      Last     : out Text_Length;
      Cut      : out Boolean;
      Result   : out Status)
   with
     Global => (In_Out => Transport.Link),
     Pre    => Line'Length <= Max_Line,
     Post   =>
       (if Result = Not_Sent then Last = 0)
       and then (if Result = Prompted and then not Cut then Ends_With_Prompt (Text, Last));

end MSP.Console;
