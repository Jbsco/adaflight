with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_LED_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_32;

   Color_Count    : constant := 16;
   Led_Count      : constant := 32;
   Hue_Max        : constant := 359;
   Function_Count : constant := 10;
   Overlay_Bits   : constant := 7;

   --  Sixteen colors, each a hue up to 359, a saturation and a value.
   procedure Set_Colors (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
   begin
      if (for some K in 0 .. Color_Count - 1 => U16 (Request, 4 * K) > Hue_Max) then
         R := Error;
         return;
      end if;
      for K in 0 .. Color_Count - 1 loop
         C.Led_Strip_Status_Mode_Config.Colors (K) :=
           (H => Interfaces.Unsigned_16 (U16 (Request, 4 * K)),
            S => Byte (U8 (Request, 4 * K + 2)),
            V => Byte (U8 (Request, 4 * K + 3)));
      end loop;
      R := Ack;
   end Set_Colors;

   --  A LED and its packed configuration, in exactly five bytes; the
   --  function must be one of the ten and the overlays among the seven.
   procedure Set_Strip_Config (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Led    : constant Integer_64 := U8 (Request, 0);
      Config : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (U32 (Request, 1));
   begin
      if Led >= Led_Count
        or else Request'Length /= 5
        or else Interfaces.Shift_Right (Config, 8) mod 16 >= Function_Count
        or else Interfaces.Shift_Right (Config, 12) mod 1024 >= 2 ** Overlay_Bits
      then
         R := Error;
         return;
      end if;
      C.Led_Strip_Status_Mode_Config.Led_Configs (Natural (Led)) := Config;
      E.Layout := True;
      R := Ack;
   end Set_Strip_Config;

   --  A mode, a direction or special color index, and a color, as the
   --  command line's mode_color takes them.
   procedure Set_Mode_Color (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Mode  : constant Integer_64 := U8 (Request, 0);
      Index : constant Integer_64 := U8 (Request, 1);
      Color : constant Integer_64 := U8 (Request, 2);
   begin
      if Color >= Color_Count then
         R := Error;
         return;
      end if;
      if Mode <= 5 and then Index <= 5 then
         C.Led_Strip_Status_Mode_Config.Mode_Colors (Natural (Mode)).Color (Natural (Index)) := Byte (Color);
      elsif Mode = 6 and then Index <= 10 then
         C.Led_Strip_Status_Mode_Config.Special_Colors.Color (Natural (Index)) := Byte (Color);
      elsif Mode = 7 and then Index = 0 then
         C.Led_Strip_Status_Mode_Config.Ledstrip_Aux_Channel := Byte (Color);
      else
         R := Error;
         return;
      end if;
      R := Ack;
   end Set_Mode_Color;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
   is
   begin
      E := No_Effects;
      case Command is
         when Set_LED_Colors_Command =>
            Set_Colors (C, Request, R);
         when Set_LED_Strip_Config_Command =>
            Set_Strip_Config (C, Request, R, E);
         when Set_LED_Strip_Mode_Color_Command =>
            Set_Mode_Color (C, Request, R);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_LED_In;
