package body Adaflight.USB_Joystick with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Axis is Integer range -127 .. 127;

   Axis_Channels : constant array (0 .. 7) of Channel_Index := (0, 1, 6, 2, 4, 3, 7, 5);
   Button_Channels : constant array (0 .. 7) of Channel_Index := (8, 9, 10, 11, 12, 13, 14, 15);
   Pitch : constant Channel_Index := 1;

   function Scaled (V : Float) return Axis
     with Global => null
   is
      Whole : constant Integer :=
        (if V <= 1000.0 then 1000 elsif V >= 2000.0 then 2000 else Integer (Float'Truncation (V)));
   begin
      return 254 * (Whole - 1000) / 1000 - 127;
   end Scaled;

   function Signed_Byte (V : Axis) return Interfaces.Unsigned_8 is
     (if V >= 0 then Interfaces.Unsigned_8 (V) else Interfaces.Unsigned_8 (256 + V));

   function Report_Of (Data : Channel_Data) return Report is
      R : Report := (others => 0);
   begin
      for I in Axis_Channels'Range loop
         declare
            Channel : constant Channel_Index := Axis_Channels (I);
            V       : constant Axis := Scaled (Data (Channel));
         begin
            R (I) := Signed_Byte (if Channel = Pitch then -V else V);
         end;
      end loop;
      for I in Button_Channels'Range loop
         if Scaled (Data (Button_Channels (I))) > 0 then
            R (8) := R (8) or Interfaces.Shift_Left (1, I);
         end if;
      end loop;
      return R;
   end Report_Of;

end Adaflight.USB_Joystick;
