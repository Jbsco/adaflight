with Adaflight.Menu_Draw;

package body Adaflight.Menu_Nav with SPARK_Mode is
   use type Adaflight.Menu.Table;
   use type Adaflight.Menu.Page_State;
   use type Adaflight.Menu.Layout;

   package Drawing is new Adaflight.Menu_Draw
     (Write => Write, Write_Char => Write_Char, Display_Update => On_Display_Update);

   procedure Register_Display (S : in out State; D : Adaflight.Menu.Display) is
   begin
      if S.Port_Count < Adaflight.Menu.Max_Displays then
         S.Ports (S.Port_Count) := D;
         S.Port_Count := S.Port_Count + 1;
      end if;
   end Register_Display;

   --  The display layer's clear with a wait, and its grab, which clears.
   procedure Clear (S : in out State; On : Adaflight.Menu.Display_Index) is
   begin
      Act (On, Adaflight.Menu.Clear, 1);
      Adaflight.Menu.Clear_Screen (S.Ports (On));
   end Clear;

   procedure Grab (S : in out State; On : Adaflight.Menu.Display_Index) is
   begin
      Act (On, Adaflight.Menu.Grab, 0);
      Clear (S, On);
   end Grab;

   procedure Count_Pages (S : in out State) is
   begin
      S.Page_Count := Adaflight.Menu.Pages (S.Table, S.Layout);
   end Count_Pages;

   procedure Page_Select (S : in out State; Number : Adaflight.Menu.Page_Request) is
   begin
      Adaflight.Menu.Select_Page (S.Table, S.Layout, Number, S.Page);
      Clear (S, S.Port);
   end Page_Select;

   --  A leave hook asked with its answer unread, as the exit asks them.
   procedure Ask_Leave (Id : Adaflight.Menu.Menu_Id; Self : Integer) is
      Ignore : Boolean;
   begin
      On_Leave (Id, Self, Ignore);
   end Ask_Leave;

   --  The way back: the leave hook may refuse it; else the stacked menu,
   --  if any, is restored, and otherwise the menu, its lines and its page
   --  stay as they were.
   procedure Way_Back (S : in out State; Restored : out Boolean)
     with Pre  => S.In_Menu and then Layout_Consistent (S) and then S.Table.Count >= 1
                  and then Adaflight.Menu.Fixed_In_Range (S.Table),
          Post => S.In_Menu and then Layout_Consistent (S) and then S.Layout = S.Layout'Old
                  and then (if Restored
                            then S.Has_Menu and then Page_Consistent (S)
                            else S.Has_Menu = S.Has_Menu'Old and then S.Table = S.Table'Old
                              and then S.Page = S.Page'Old and then S.Page_Count = S.Page_Count'Old)
   is
      Chain_Back : Boolean;
   begin
      Restored := False;
      if S.Hooks.Leave then
         On_Leave (S.Id, S.Page.Top + S.Draw.Cursor_Row, Chain_Back);
         if Chain_Back then
            return;
         end if;
      end if;
      S.Save_Inhibited := False;
      if S.Depth = 0 then
         return;
      end if;
      declare
         F : constant Frame := S.Stack (S.Depth);
      begin
         S.Depth := S.Depth - 1;
         S.Id := F.Id;
         S.Hooks := F.Hooks;
         S.Has_Menu := True;
         S.Draw.Cursor_Row := F.Cursor;
         Load (F.Id, S.Table);
         Count_Pages (S);
         Page_Select (S, F.Page);
         Restored := True;
      end;
   end Way_Back;

   procedure Back (S : in out State) is
      Ignore_Restored : Boolean;
   begin
      Way_Back (S, Ignore_Restored);
   end Back;

   procedure Change (S : in out State; Target : Adaflight.Menu.Menu_Id) is
      Chain_Back : Boolean;
      Restored   : Boolean;
   begin
      if not S.Has_Menu or else Target /= S.Id then
         S.Save_Inhibited := False;
         if S.Has_Menu and then Target /= Adaflight.Menu.Main_Menu then
            if S.Depth >= Stack_Limit - 1 then
               return;
            end if;
            S.Depth := S.Depth + 1;
            S.Stack (S.Depth) := (Id => S.Id, Hooks => S.Hooks, Page => S.Page.Page, Cursor => S.Draw.Cursor_Row);
         end if;
         S.Id := Target;
         S.Hooks := Hooks_Of (Target);
         S.Draw.Cursor_Row := 0;
         Load (Target, S.Table);
         S.Has_Menu := True;
         if S.Hooks.Enter then
            On_Enter (Target, Chain_Back);
            if Chain_Back then
               Way_Back (S, Restored);
               if not Restored then
                  Count_Pages (S);
                  Page_Select (S, 0);
               end if;
               return;
            end if;
         end if;
         Count_Pages (S);
         Page_Select (S, 0);
      else
         declare
            Cursor_Abs : constant Adaflight.Menu.Cursor := S.Draw.Cursor_Row;
         begin
            S.Draw.Cursor_Row := Cursor_Abs mod S.Layout.Max_Items;
            Count_Pages (S);
            Page_Select (S, Cursor_Abs / S.Layout.Max_Items);
         end;
      end if;
   end Change;

   procedure Open (S : in out State; Start : Adaflight.Menu.Menu_Id; Background : Natural) is
      Start_Menu : Adaflight.Menu.Menu_Id;
   begin
      if not S.In_Menu then
         if S.Port_Count = 0 then
            return;
         end if;
         if S.Port < 0 then
            S.Port := 0;
         end if;
         S.In_Menu := True;
         S.Has_Menu := False;
         S.Id := Adaflight.Menu.Main_Menu;
         S.Page.Page := 0;
         S.Draw.Cursor_Row := 0;
         Start_Menu := Start;
         S.Depth := 0;
         Act (S.Port, Adaflight.Menu.Arming_Disabled, 1);
         Act (S.Port, Adaflight.Menu.Layer_Select, 0);
         if Background /= 0 then
            Act (S.Port, Adaflight.Menu.Background, Background);
         end if;
      else
         declare
            Next : constant Adaflight.Menu.Display_Index := (S.Port + 1) mod S.Port_Count;
         begin
            Start_Menu := S.Id;
            if Next /= S.Port then
               S.Draw.Cursor_Row := (S.Draw.Cursor_Row + S.Page.Page * S.Layout.Max_Items) mod 256;
               Act (S.Port, Adaflight.Menu.Background, 0);
               Act (S.Port, Adaflight.Menu.Release, 0);
               S.Port := Next;
               Act (S.Port, Adaflight.Menu.Background, Background);
            else
               return;
            end if;
         end;
      end if;
      Grab (S, S.Port);
      S.Layout :=
        Adaflight.Menu.Layout_Of (S.Ports (S.Port).Columns, S.Ports (S.Port).Rows, S.Ports (S.Port).Full_Screen);
      Change (S, Start_Menu);
   end Open;

   procedure Select_Page (S : in out State; Number : Adaflight.Menu.Page_Request) is
   begin
      Page_Select (S, Number);
   end Select_Page;

   procedure Draw (S : in out State; Sl : Adaflight.Menu.Slider_Settings; Now_Us, Now_Ms, Room : Unsigned_32) is
      P              : constant Adaflight.Menu.Display_Index := S.Port;
      Back_Requested : Boolean;
   begin
      Drawing.Draw
        (P, S.Table, S.Id, S.Hooks.Update, S.Layout, S.Page, S.Draw, S.Ports (P), Sl, Now_Us, Now_Ms, Room,
         Back_Requested);
      if Back_Requested then
         Back (S);
      end if;
   end Draw;

   procedure Exit_Menu (S : in out State; Kind : Exit_Kind) is
      P           : constant Adaflight.Menu.Display_Index := S.Port;
      Ignore_Cost : Unsigned_32;
   begin
      case Kind is
         when Save | Save_Reboot | Popup_Save | Popup_Save_Reboot =>
            if S.Hooks.Leave then
               Ask_Leave (S.Id, -1);
            end if;
            if Kind in Popup_Save | Popup_Save_Reboot then
               for I in reverse 1 .. S.Depth loop
                  if S.Stack (I).Hooks.Leave then
                     Ask_Leave (S.Stack (I).Id, -1);
                  end if;
               end loop;
            end if;
            Act (P, Adaflight.Menu.Save_Config, 0);
         when Plain | Popup_Exit_Reboot =>
            null;
      end case;
      S.In_Menu := False;
      Act (P, Adaflight.Menu.Background, 0);
      Act (P, Adaflight.Menu.Release, 0);
      S.Has_Menu := False;
      if Kind in Save_Reboot | Popup_Save_Reboot | Popup_Exit_Reboot then
         Clear (S, P);
         Write (P, 5, 3, Drawing.Normal, "REBOOTING...", Ignore_Cost);
         Act (P, Adaflight.Menu.Redraw, 0);
         Act (P, Adaflight.Menu.Stop_Motors, 0);
         Act (P, Adaflight.Menu.Motor_Shutdown, 0);
         Act (P, Adaflight.Menu.Delay_Ms, 200);
         Act (P, Adaflight.Menu.System_Reset, 0);
      end if;
      Act (P, Adaflight.Menu.Arming_Disabled, 0);
   end Exit_Menu;

end Adaflight.Menu_Nav;
