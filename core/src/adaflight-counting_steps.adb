package body Adaflight.Counting_Steps with SPARK_Mode is

   procedure Step is
   begin
      Calls := (if Calls < Natural'Last then Calls + 1 else 0);
   end Step;

end Adaflight.Counting_Steps;
