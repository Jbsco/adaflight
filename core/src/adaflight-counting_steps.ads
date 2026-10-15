--  A unit step that counts its calls, so that a pass over such steps has
--  an effect the proof sees.
package Adaflight.Counting_Steps with SPARK_Mode, Initializes => Calls is

   Calls : Natural := 0;

   procedure Step
     with Global => (In_Out => Calls),
          Post   => Calls = (if Calls'Old < Natural'Last then Calls'Old + 1 else 0);

end Adaflight.Counting_Steps;
