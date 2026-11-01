with Ada.Real_Time;
package body Adaflight.Host_Clock is
   use type Ada.Real_Time.Time;
   use type Interfaces.Unsigned_64;

   Epoch : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

   function Real_Ns return Interfaces.Unsigned_64 is
     (Interfaces.Unsigned_64 (Long_Float (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Epoch)) * 1.0e9));

   --  The scaled time is a base plus the real time since that base at the
   --  rate; a rate change rebases, so the tasks that read the clock share
   --  one consistent pair and keep no state of their own.
   protected Scaled is
      function Elapsed_Ns return Interfaces.Unsigned_64;
      function Rate return Float;
      procedure Set_Rate (New_Rate : Float);
   private
      Base_Out  : Interfaces.Unsigned_64 := 0;
      Base_Real : Interfaces.Unsigned_64 := 0;
      Scale     : Float := 1.0;
   end Scaled;

   protected body Scaled is
      function Elapsed_Ns return Interfaces.Unsigned_64 is
         Now : constant Interfaces.Unsigned_64 := Real_Ns;
      begin
         if Now > Base_Real then
            return Base_Out + Interfaces.Unsigned_64 (Long_Float (Now - Base_Real) * Long_Float (Scale));
         end if;
         return Base_Out;
      end Elapsed_Ns;

      function Rate return Float is (Scale);

      procedure Set_Rate (New_Rate : Float) is
      begin
         if New_Rate > 0.0 and then New_Rate /= Scale then
            Base_Out := Elapsed_Ns;
            Base_Real := Real_Ns;
            Scale := New_Rate;
         end if;
      end Set_Rate;
   end Scaled;

   procedure Set_Rate (Rate : Float) is
   begin
      Scaled.Set_Rate (Rate);
   end Set_Rate;

   function Rate return Float is (Scaled.Rate);

   function Elapsed_Ns return Interfaces.Unsigned_64 is (Scaled.Elapsed_Ns);
end Adaflight.Host_Clock;
