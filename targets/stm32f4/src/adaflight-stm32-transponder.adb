with Adaflight.Transponder;
with Adaflight.STM32.Transponder_Output;
package body Adaflight.STM32.Transponder is
   use Interfaces;
   package Core renames Adaflight.Transponder;
   package Output renames Adaflight.STM32.Transponder_Output;
   use type Core.Provider;

   Set_Up   : Boolean := False;
   Coding   : Core.Provider := Core.None;
   Schedule : Core.Schedule;

   function Provider_Of (C : Adaflight.Config_Groups.Configuration) return Core.Provider is
     (if C.Transponder_Config.Provider <= 3 then Core.Provider'Val (C.Transponder_Config.Provider) else Core.None);

   function Code_Of (C : Adaflight.Config_Groups.Configuration) return Core.Code is
      Data : Core.Code;
   begin
      for I in Data'Range loop
         Data (I) := C.Transponder_Config.Data (C.Transponder_Config.Data'First + I);
      end loop;
      return Data;
   end Code_Of;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      P     : constant Core.Provider := Provider_Of (C);
      Found : Boolean;
   begin
      Set_Up := False;
      Coding := Core.None;
      if C.Transponder_Config.Io_Tag = 0 or else P = Core.None then
         return;
      end if;
      Output.Take (C.Transponder_Config.Io_Tag, Found);
      if not Found then
         return;
      end if;
      Output.Configure (P);
      Coding := P;
      Set_Up := True;
      Output.Load (Code_Of (C));
   end Init;

   procedure Update_Data (C : Adaflight.Config_Groups.Configuration) is
      P : constant Core.Provider := Provider_Of (C);
   begin
      if P = Core.None or else not Set_Up then
         return;
      end if;
      if P /= Coding then
         Output.Configure (P);
         Coding := P;
      end if;
      Output.Load (Code_Of (C));
   end Update_Data;

   procedure Run (C : Adaflight.Config_Groups.Configuration; Now_Us : Unsigned_32) is
      Transmit : Boolean;
   begin
      if not Set_Up then
         return;
      end if;
      Core.Update (Schedule, Provider_Of (C), Now_Us, Output.Ready, Transmit);
      if Transmit then
         Output.Transmit;
      end if;
   end Run;

   function Stream_Number return Natural is (Output.Stream_Number);

end Adaflight.STM32.Transponder;
