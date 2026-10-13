with Adaflight.Clock;

package body Adaflight.Warning_LED with SPARK_Mode is
   use type Interfaces.Integer_32;

   Refresh_Us : constant := 500_000;

   procedure Enable (S : in out State) is
   begin
      S.Current := On;
   end Enable;

   procedure Disable (S : in out State) is
   begin
      S.Current := Off;
   end Disable;

   procedure Flash (S : in out State) is
   begin
      S.Current := Flashing;
   end Flash;

   -------------
   -- Refresh --
   -------------

   procedure Refresh (S : in out State; Now_Us : Unsigned_32; Call : out LED_Call) is
   begin
      Call := (case S.Current is
                  when Off      => Set_Off,
                  when On       => Set_On,
                  when Flashing => Toggle);
      S.Next_Us := Now_Us + Refresh_Us;
   end Refresh;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out State; Now_Us : Unsigned_32; Call : out LED_Call) is
   begin
      if Adaflight.Clock.Elapsed (Now_Us, S.Next_Us) < 0 then
         Call := None;
         return;
      end if;
      Refresh (S, Now_Us, Call);
   end Update;

end Adaflight.Warning_LED;
