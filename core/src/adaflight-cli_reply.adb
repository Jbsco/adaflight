package body Adaflight.CLI_Reply with SPARK_Mode is

   procedure Put (Into : in out Reply; Text : String) is
   begin
      for Ch of Text loop
         if Into.Length < Size then
            Into.Length := Into.Length + 1;
            Into.Text (Into.Length) := Ch;
         else
            Into.Overflow := True;
         end if;
      end loop;
   end Put;

end Adaflight.CLI_Reply;
