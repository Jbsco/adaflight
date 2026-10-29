with Interfaces;

--  The serial passthrough's escape for a host link without DTR: three plus
--  signs from the host, the first after a second without a host byte, end
--  the forwarding with a reset. A host on the USB port has no escape.
package Adaflight.Passthrough_Escape
  with SPARK_Mode
is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   USB_VCP_Port : constant := 20;

   subtype Plus_Count is Natural range 0 .. 2;

   type State is record
      Enabled      : Boolean := False;
      Host_Idle_Ms : Interfaces.Unsigned_32 := 0;
      Count        : Plus_Count := 0;
   end record;

   --  The escape at the forwarding's start: off when the host's port is the
   --  USB port, with the clock as the time of the last host byte.
   function Start (Host_Port : Integer; Now_Ms : Interfaces.Unsigned_32) return State is
     ((Enabled => Host_Port /= USB_VCP_Port, Host_Idle_Ms => Now_Ms, Count => 0));

   --  A byte from the host at its time, and whether it completes the escape.
   procedure Host_Byte
     (S : in out State; C : Interfaces.Unsigned_8; Now_Ms : Interfaces.Unsigned_32; Reset : out Boolean)
     with Global => null,
          Post   => (if Reset then S.Enabled and then C = Character'Pos ('+') and then S'Old.Count = 2);

end Adaflight.Passthrough_Escape;
