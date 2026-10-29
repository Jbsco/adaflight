with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.PINIO_Box;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Pilot;
package body Adaflight.STM32.PINIO is
   use type Interfaces.Unsigned_8;
   package GPIO renames Adaflight.STM32.GPIO;
   package Box renames Adaflight.PINIO_Box;

   Inverted_Flag : constant Byte := 16#80#;
   Mode_Mask     : constant Byte := 16#7F#;
   Mode_Out_PP   : constant Byte := 16#01#;

   --  An output's pin, whether it is inverted, and the level it drives.
   type Output is record
      Present  : Boolean := False;
      Where    : Pin := (Port_A, 0);
      Inverted : Boolean := False;
      Level    : Boolean := False;
   end record;
   Outputs : array (Box.PINIO_Index) of Output;
   Boxes   : Box.State;

   function Tagged_Pin (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Byte) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   procedure Write (P : Pin; High : Boolean) is
   begin
      if High then
         GPIO.Set_High (P);
      else
         GPIO.Set_Low (P);
      end if;
   end Write;

   --  A push-pull output is preset high when inverted, so it does not drop
   --  for a moment, then each output starts at its idle level.
   procedure Init (C : Adaflight.Config_Groups.Configuration) is
   begin
      for I in Outputs'Range loop
         declare
            Tag    : constant Byte := C.Pinio_Config.Io_Tag (I);
            Config : constant Byte := C.Pinio_Config.Config (I);
            O      : Output renames Outputs (I);
         begin
            O := (others => <>);
            if Tagged_Pin (Tag) then
               O.Present := True;
               O.Where := Pin_Of (Tag);
               O.Inverted := (Config and Inverted_Flag) /= 0;
               GPIO.Enable_Port (O.Where.Port);
               if (Config and Mode_Mask) = Mode_Out_PP then
                  if O.Inverted then
                     GPIO.Set_High (O.Where);
                  end if;
                  GPIO.Set_Output (O.Where);
               end if;
               O.Level := O.Inverted;
               Write (O.Where, O.Level);
            end if;
         end;
      end loop;
   end Init;

   procedure Init_Boxes (C : Adaflight.Config_Groups.Configuration) is
      Ids : Box.Permanent_Ids;
   begin
      for I in Ids'Range loop
         Ids (I) := C.Pinio_Box_Config.Permanent_Id (I);
      end loop;
      Box.Init (Boxes, Ids);
   end Init_Boxes;

   function Task_Enabled return Boolean is
      Present : Box.Box_Flags;
   begin
      for B in Present'Range loop
         Present (B) := Adaflight.STM32.Pilot.Box_Configured (B);
      end loop;
      return Box.Task_Enabled (Boxes, Present);
   end Task_Enabled;

   --  An output changes only when its level does.
   procedure Update is
      On  : Box.Box_Flags;
      Set : Box.Output_Sets;
   begin
      for B in On'Range loop
         On (B) := Adaflight.STM32.Pilot.Box_Active (B);
      end loop;
      Set := Box.Update (Boxes, On);
      for I in Outputs'Range loop
         declare
            O     : Output renames Outputs (I);
            Level : constant Boolean := Set (I).Level xor O.Inverted;
         begin
            if Set (I).Set and then O.Present and then Level /= O.Level then
               Write (O.Where, Level);
               O.Level := Level;
            end if;
         end;
      end loop;
   end Update;

   procedure Set (Index : Natural; On : Boolean) is
   begin
      if Index not in Outputs'Range then
         return;
      end if;
      declare
         O     : Output renames Outputs (Index);
         Level : constant Boolean := On xor O.Inverted;
      begin
         if O.Present and then Level /= O.Level then
            Write (O.Where, Level);
            O.Level := Level;
         end if;
      end;
   end Set;

end Adaflight.STM32.PINIO;
