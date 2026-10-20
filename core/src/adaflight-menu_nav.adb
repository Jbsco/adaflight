with Adaflight.Menu_Draw;

package body Adaflight.Menu_Nav with SPARK_Mode is
   use type Adaflight.Menu.Table;
   use type Adaflight.Menu.Page_State;
   use type Adaflight.Menu.Layout;
   use type Adaflight.Menu.Hook_Set;
   use type Adaflight.Menu.Context;
   use type Interfaces.Integer_32;

   package Drawing is new Adaflight.Menu_Draw
     (Target_State => Target_State, Write => Write, Write_Char => Write_Char, Display_Update => On_Display_Update,
      Refresh => Refresh);

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

   --  The display operations a hook made, in order, then its save menu
   --  inhibition.
   procedure Show (S : in out State; A : Adaflight.Menu.Answer)
     with Pre  => S.Port >= 0 and then S.Port < S.Port_Count,
          Post => S.In_Menu = S.In_Menu'Old and then S.Has_Menu = S.Has_Menu'Old and then S.Port = S.Port'Old
                  and then S.Port_Count = S.Port_Count'Old and then S.Table = S.Table'Old
                  and then S.Layout = S.Layout'Old and then S.Page = S.Page'Old
                  and then S.Page_Count = S.Page_Count'Old and then S.Id = S.Id'Old and then S.Hooks = S.Hooks'Old
                  and then S.Depth = S.Depth'Old and then S.Stack = S.Stack'Old and then S.Draw = S.Draw'Old
                  and then (for all I in Adaflight.Menu.Display_Index =>
                              Adaflight.Menu.Same_Size (S.Ports (I), S.Ports'Old (I)))
   is
      Ignore_Cost : Unsigned_32;
   begin
      for K in 1 .. A.Screens loop
         pragma Loop_Invariant
           (S.In_Menu = S.In_Menu'Loop_Entry and then S.Has_Menu = S.Has_Menu'Loop_Entry
            and then S.Port = S.Port'Loop_Entry and then S.Port_Count = S.Port_Count'Loop_Entry
            and then S.Table = S.Table'Loop_Entry and then S.Layout = S.Layout'Loop_Entry
            and then S.Page = S.Page'Loop_Entry and then S.Page_Count = S.Page_Count'Loop_Entry
            and then S.Id = S.Id'Loop_Entry and then S.Hooks = S.Hooks'Loop_Entry
            and then S.Depth = S.Depth'Loop_Entry and then S.Stack = S.Stack'Loop_Entry
            and then S.Draw = S.Draw'Loop_Entry
            and then (for all I in Adaflight.Menu.Display_Index =>
                        Adaflight.Menu.Same_Size (S.Ports (I), S.Ports'Loop_Entry (I))));
         case A.Screen (K).Kind is
            when Adaflight.Menu.Clear_Wait =>
               Clear (S, S.Port);
            when Adaflight.Menu.Write_Text =>
               Write (S.Port, A.Screen (K).X, A.Screen (K).Y, A.Screen (K).Attr,
                      A.Screen (K).Text (1 .. A.Screen (K).Length), Ignore_Cost);
            when Adaflight.Menu.Redraw =>
               Act (S.Port, Adaflight.Menu.Redraw, 0);
            when Adaflight.Menu.Set_Background =>
               Act (S.Port, Adaflight.Menu.Background, Integer (A.Screen (K).Attr));
            when Adaflight.Menu.Save_Config =>
               Act (S.Port, Adaflight.Menu.Save_Config, 0);
         end case;
      end loop;
      if A.Inhibit_Save then
         S.Save_Inhibited := True;
      end if;
   end Show;

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
   procedure Ask_Leave (T : in out Target_State; Id : Adaflight.Menu.Menu_Id; Self : Integer) is
      Ignore : Boolean;
   begin
      On_Leave (T, Id, Self, Ignore);
   end Ask_Leave;

   --  The way back: the leave hook may refuse it; else the stacked menu,
   --  if any, is restored, and otherwise the menu, its lines and its page
   --  stay as they were.
   procedure Way_Back (S : in out State; T : in out Target_State; Restored : out Boolean)
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
         On_Leave (T, S.Id, S.Page.Top + S.Draw.Cursor_Row, Chain_Back);
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
         Load (T, F.Id, S.Table);
         Count_Pages (S);
         Page_Select (S, F.Page);
         Restored := True;
      end;
   end Way_Back;

   procedure Back (S : in out State; T : in out Target_State) is
      Ignore_Restored : Boolean;
   begin
      Way_Back (S, T, Ignore_Restored);
   end Back;

   --  The changes an enter hook can nest, more than the menu stack's limit
   --  lets the reference's changes nest before one returns at the full
   --  stack.
   Max_Nesting : constant := 2 * Stack_Limit + 1;
   subtype Nesting is Natural range 0 .. Max_Nesting;

   --  A change at a nesting level: an enter hook's change runs inside the
   --  change that asked the hook, as the reference's hook calls it there.
   --  A change that returns at the full stack leaves the page as it was.
   procedure Change_At (S : in out State; T : in out Target_State; Target : Adaflight.Menu.Menu_Id; Level : Nesting)
     with Pre                => S.In_Menu and then Layout_Consistent (S)
                               and then (if S.Has_Menu
                                         then S.Table.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (S.Table)),
          Post               => S.In_Menu and then S.Has_Menu and then Layout_Consistent (S)
                               and then S.Table.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (S.Table)
                               and then (Page_Consistent (S)
                                         or else (S.Has_Menu'Old and then Target /= S.Id'Old
                                                  and then S.Table = S.Table'Old and then S.Page = S.Page'Old
                                                  and then S.Page_Count = S.Page_Count'Old
                                                  and then S.Layout = S.Layout'Old)),
          Subprogram_Variant => (Decreases => Max_Nesting - Level)
   is
      use type Adaflight.Menu.Effect;
      Reply    : Adaflight.Menu.Answer;
      Restored : Boolean;
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
         Load (T, Target, S.Table);
         S.Has_Menu := True;
         if S.Hooks.Enter then
            On_Enter (T, Target, Reply);
            Show (S, Reply);
            Load (T, Target, S.Table);
            if Reply.Done = Adaflight.Menu.Changed and then Level < Max_Nesting then
               Change_At (S, T, Reply.Target, Level + 1);
            end if;
            if Reply.Chain_Back then
               Way_Back (S, T, Restored);
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
   end Change_At;

   procedure Change (S : in out State; T : in out Target_State; Target : Adaflight.Menu.Menu_Id) is
   begin
      Change_At (S, T, Target, 0);
   end Change;

   procedure Open (S : in out State; T : in out Target_State; Start : Adaflight.Menu.Menu_Id; Background : Natural) is
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
      Change (S, T, Start_Menu);
   end Open;

   procedure Select_Page (S : in out State; Number : Adaflight.Menu.Page_Request) is
   begin
      Page_Select (S, Number);
   end Select_Page;

   procedure Draw
     (S      : in out State;
      T      : in out Target_State;
      Sl     : Adaflight.Menu.Slider_Settings;
      Now_Us : Unsigned_32;
      Now_Ms : Unsigned_32;
      Room   : Unsigned_32)
   is
      Back_Requested : Boolean;
   begin
      if not S.In_Menu or else not S.Has_Menu then
         return;
      end if;
      declare
         P : constant Adaflight.Menu.Display_Index := S.Port;
      begin
         Drawing.Draw
           (T, P, S.Table, S.Id, S.Hooks.Update, S.Layout, S.Page, S.Draw, S.Ports (P), Sl, Now_Us, Now_Ms, Room,
            Back_Requested);
      end;
      if Back_Requested then
         Back (S, T);
      end if;
   end Draw;

   --  The line at an index of the current menu, the end marker past its
   --  lines.
   function Line_Of (S : State; Index : Natural) return Adaflight.Menu.Line is
     (if Index < S.Table.Count then S.Table.Lines (Index)
      else (Flags => Adaflight.Menu.Element'Pos (Adaflight.Menu.End_Marker), others => <>));

   --  A number wrapped into a width, as the reference's assignments to the
   --  narrower types do.
   function Wrapped (X : Interfaces.Integer_64; Bits : Positive; Signed : Boolean) return Interfaces.Integer_32
     with Pre  => Bits in 8 | 16 | 32,
          Post => (if not Signed and then Bits = 8 then Wrapped'Result in 0 .. 255)
                  and then (if not Signed and then Bits = 16 then Wrapped'Result in 0 .. 65_535)
                  and then (if Signed and then Bits = 8 then Wrapped'Result in -128 .. 127)
                  and then (if Signed and then Bits = 16 then Wrapped'Result in -32_768 .. 32_767)
   is
      use type Interfaces.Integer_64;
      Modulus : constant Interfaces.Integer_64 := (if Bits = 8 then 256 elsif Bits = 16 then 65_536 else 4_294_967_296);
      Half    : constant Interfaces.Integer_64 := Modulus / 2;
      U       : constant Interfaces.Integer_64 := X mod Modulus;
   begin
      if Signed or else Bits = 32 then
         return Interfaces.Integer_32 (if U >= Half then U - Modulus else U);
      else
         return Interfaces.Integer_32 (U);
      end if;
   end Wrapped;

   --  The unsigned reading of a word held as the reference's integer.
   function Unsigned_Word (X : Interfaces.Integer_32) return Interfaces.Unsigned_32 is
     (Interfaces.Unsigned_32'Mod (X));

   procedure Handle_Key
     (S               : in out State;
      T               : in out Target_State;
      Key             : Key_Code;
      K               : Key_Settings;
      Sl              : Adaflight.Menu.Slider_Settings;
      Reboot_Required : Boolean;
      Delay_Ms        : out Key_Delay)
   is
      use type Interfaces.Integer_64;
      use type Interfaces.Unsigned_8;
      use type Interfaces.Unsigned_16;
      use type Adaflight.Menu.Element;
      Reply : Adaflight.Menu.Answer;

      --  The menu change or exit a line's function made inside its call.
      procedure Perform (S : in out State; T : in out Target_State; A : Adaflight.Menu.Answer)
        with Pre  => Consistent (S) and then S.Port >= 0,
             Post => Consistent (S) and then S.Port >= 0
      is
      begin
         if not S.In_Menu or else not S.Has_Menu then
            return;
         end if;
         Show (S, A);
         case A.Done is
            when Adaflight.Menu.Nothing =>
               null;
            when Adaflight.Menu.Changed =>
               Change (S, T, A.Target);
            when Adaflight.Menu.Exited =>
               Exit_Menu (S, T, A.Kind);
         end case;
      end Perform;

      --  A value line's print mark, within the page's rows.
      procedure Mark_Print (S : in out State) is
      begin
         if S.Draw.Cursor_Row <= Adaflight.Menu.Row'Last then
            S.Page.Flags (S.Draw.Cursor_Row) := S.Page.Flags (S.Draw.Cursor_Row) or 16#20#;
         end if;
      end Mark_Print;

      --  A number stepped up on the right key and down on any other, within
      --  its range but wrapped in its width; a byte stays a byte.
      procedure Step_Number (E : in out Adaflight.Menu.Line; Bits : Positive; Signed : Boolean)
        with Pre  => Bits in 8 | 16 | 32,
             Post => E.Flags = E.Flags'Old
                     and then (if not Signed and then Bits = 8 then E.Value in 0 .. 255 or else E.Value = E.Value'Old)
      is
      begin
         if Signed then
            if Key = Right then
               if E.Value < E.Max then
                  E.Value := Wrapped (Interfaces.Integer_64 (E.Value) + Interfaces.Integer_64 (E.Step), Bits, True);
               end if;
            elsif E.Value > E.Min then
               E.Value := Wrapped (Interfaces.Integer_64 (E.Value) - Interfaces.Integer_64 (E.Step), Bits, True);
            end if;
         else
            if Key = Right then
               if Unsigned_Word (E.Value) < Unsigned_Word (E.Max) then
                  E.Value := Wrapped (Interfaces.Integer_64 (E.Value) + Interfaces.Integer_64 (E.Step), Bits, False);
               end if;
            elsif Unsigned_Word (E.Value) > Unsigned_Word (E.Min) then
               E.Value := Wrapped (Interfaces.Integer_64 (E.Value) - Interfaces.Integer_64 (E.Step), Bits, False);
            end if;
         end if;
      end Step_Number;
   begin
      Delay_Ms := Button_Time;
      if not S.Has_Menu then
         return;
      end if;
      if Key = Menu_Key then
         Open (S, T, K.Start, K.Background);
         Delay_Ms := Button_Pause;
         return;
      end if;
      if Key = Esc then
         if S.Draw.Element_Editing then
            S.Draw.Element_Editing := False;
         else
            Back (S, T);
         end if;
         Delay_Ms := Button_Pause;
         return;
      end if;
      if Key = Save_Menu and then not S.Save_Inhibited then
         S.Draw.Element_Editing := False;
         Change (S, T, (if Reboot_Required then K.Save_Exit_Reboot else K.Save_Exit));
         Delay_Ms := Button_Pause;
         return;
      end if;
      if Key = Down and then not S.Draw.Element_Editing then
         if S.Draw.Cursor_Row < S.Page.Max_Row then
            S.Draw.Cursor_Row := S.Draw.Cursor_Row + 1;
         else
            Page_Select (S, S.Page.Page + 1);
            S.Draw.Cursor_Row := 0;
         end if;
      end if;
      if Key = Up and then not S.Draw.Element_Editing then
         declare
            C : Integer range -1 .. Adaflight.Menu.Cursor'Last := S.Draw.Cursor_Row - 1;
         begin
            while C > 0 and then Adaflight.Menu.Skippable (Line_Of (S, S.Page.Top + C), Sl) loop
               pragma Loop_Invariant (C in 1 .. Adaflight.Menu.Cursor'Last);
               C := C - 1;
            end loop;
            if C = -1
              or else Adaflight.Menu.Element_Of (Line_Of (S, S.Page.Top + C).Flags) = Adaflight.Menu.Label
            then
               Page_Select (S, S.Page.Page - 1);
               C := S.Page.Max_Row;
            end if;
            S.Draw.Cursor_Row := C;
         end;
      end if;
      pragma Assert_And_Cut (Consistent (S) and then S.In_Menu and then S.Has_Menu);
      if (Key = Down or else Key = Up) and then not S.Draw.Element_Editing then
         return;
      end if;
      Refresh (T, S.Id, S.Table);
      declare
         Index : constant Natural := S.Page.Top + S.Draw.Cursor_Row;
      begin
         if Index < S.Table.Count then
            declare
               Element  : constant Adaflight.Menu.Element := Adaflight.Menu.Element_Of (S.Table.Lines (Index).Flags);
               Reboot   : constant Boolean := (S.Table.Lines (Index).Flags and Adaflight.Menu.Reboot_Required) /= 0;
               Has_Data : constant Boolean := S.Table.Lines (Index).Has_Data;
               Has_Func : constant Boolean := S.Table.Lines (Index).Has_Func;
               Previous : constant Interfaces.Integer_32 := S.Table.Lines (Index).Value;
            begin
               case Element is
                  when Adaflight.Menu.Submenu =>
                     if Key = Right then
                        if Previous in 0 .. Adaflight.Menu.Max_Menus - 1 then
                           Change (S, T, Adaflight.Menu.Menu_Id (Previous));
                        end if;
                        Delay_Ms := Button_Pause;
                     end if;
                  when Adaflight.Menu.Funcall =>
                     if Has_Func and then Key = Right then
                        Line_Call (T, S.Id, Index, Reply);
                        Perform (S, T, Reply);
                        if Reply.Chain_Back and then S.In_Menu and then S.Has_Menu then
                           Back (S, T);
                        end if;
                        if Reboot then
                           Act (S.Port, Adaflight.Menu.Set_Reboot_Required, 0);
                        end if;
                        Delay_Ms := Button_Pause;
                     end if;
                  when Adaflight.Menu.OSD_Exit =>
                     if Has_Func and then Key = Right then
                        Line_Call (T, S.Id, Index, Reply);
                        Perform (S, T, Reply);
                        Delay_Ms := Button_Pause;
                     end if;
                  when Adaflight.Menu.Back =>
                     Back (S, T);
                     Delay_Ms := Button_Pause;
                     S.Draw.Element_Editing := False;
                  when Adaflight.Menu.Bool =>
                     if Has_Data then
                        S.Table.Lines (Index).Value := (if Key = Right then 1 else 0);
                        Mark_Print (S);
                        Set_Value (T, S.Id, Index, S.Table.Lines (Index).Value);
                        if Reboot and then S.Table.Lines (Index).Value /= Previous then
                           Act (S.Port, Adaflight.Menu.Set_Reboot_Required, 0);
                        end if;
                        if Has_Func then
                           Line_Call (T, S.Id, Index, Reply);
                           Perform (S, T, Reply);
                        end if;
                     end if;
                  when Adaflight.Menu.Visible =>
                     if Has_Data then
                        declare
                           Bits : Interfaces.Unsigned_16 := Interfaces.Unsigned_16 (Previous mod 65_536);
                           Flag : constant Interfaces.Unsigned_16 :=
                             Interfaces.Shift_Left (1, S.Draw.Profile_Cursor - 1 + Drawing.Profile_Bits_Position);
                        begin
                           if Key = Right and then not S.Draw.Element_Editing then
                              S.Draw.Element_Editing := True;
                              S.Draw.Profile_Cursor := 1;
                           elsif S.Draw.Element_Editing then
                              if Key = Right and then S.Draw.Profile_Cursor < Adaflight.Menu.Profile_Count then
                                 S.Draw.Profile_Cursor := S.Draw.Profile_Cursor + 1;
                              end if;
                              if Key = Left and then S.Draw.Profile_Cursor > 1 then
                                 S.Draw.Profile_Cursor := S.Draw.Profile_Cursor - 1;
                              end if;
                              if Key = Up then
                                 Bits := Bits or Flag;
                              end if;
                              if Key = Down then
                                 Bits := Bits and not Flag;
                              end if;
                           end if;
                           S.Table.Lines (Index).Value := Interfaces.Integer_32 (Bits);
                        end;
                        Mark_Print (S);
                        Set_Value (T, S.Id, Index, S.Table.Lines (Index).Value);
                        if Reboot and then S.Table.Lines (Index).Value /= Previous then
                           Act (S.Port, Adaflight.Menu.Set_Reboot_Required, 0);
                        end if;
                     end if;
                  when Adaflight.Menu.UInt8 | Adaflight.Menu.Fixed | Adaflight.Menu.Int8 | Adaflight.Menu.UInt16
                     | Adaflight.Menu.Int16 | Adaflight.Menu.UInt32 | Adaflight.Menu.Int32 =>
                     if Has_Data then
                        case Element is
                           when Adaflight.Menu.UInt8 | Adaflight.Menu.Fixed =>
                              Step_Number (S.Table.Lines (Index), 8, False);
                           when Adaflight.Menu.Int8 =>
                              Step_Number (S.Table.Lines (Index), 8, True);
                           when Adaflight.Menu.UInt16 =>
                              Step_Number (S.Table.Lines (Index), 16, False);
                           when Adaflight.Menu.Int16 =>
                              Step_Number (S.Table.Lines (Index), 16, True);
                           when Adaflight.Menu.UInt32 =>
                              Step_Number (S.Table.Lines (Index), 32, False);
                           when others =>
                              Step_Number (S.Table.Lines (Index), 32, True);
                        end case;
                        Mark_Print (S);
                        Set_Value (T, S.Id, Index, S.Table.Lines (Index).Value);
                        if Reboot and then S.Table.Lines (Index).Value /= Previous then
                           Act (S.Port, Adaflight.Menu.Set_Reboot_Required, 0);
                        end if;
                        if Has_Func then
                           Line_Call (T, S.Id, Index, Reply);
                           Perform (S, T, Reply);
                        end if;
                     end if;
                  when Adaflight.Menu.Tab =>
                     if Key = Right then
                        if Previous < S.Table.Lines (Index).Max then
                           S.Table.Lines (Index).Value := Previous + 1;
                        end if;
                     elsif Previous > 0 then
                        S.Table.Lines (Index).Value := Previous - 1;
                     end if;
                     if S.Table.Lines (Index).Value in 0 .. 255 then
                        S.Table.Lines (Index).Value_Text :=
                          Lookup (T, S.Id, Index, Natural (S.Table.Lines (Index).Value));
                     end if;
                     Set_Value (T, S.Id, Index, S.Table.Lines (Index).Value);
                     declare
                        Edited : constant Interfaces.Integer_32 := S.Table.Lines (Index).Value;
                     begin
                        if Has_Func then
                           Line_Call (T, S.Id, Index, Reply);
                           Perform (S, T, Reply);
                        end if;
                        Mark_Print (S);
                        if Reboot and then Edited /= Previous then
                           Act (S.Port, Adaflight.Menu.Set_Reboot_Required, 0);
                        end if;
                     end;
                  when Adaflight.Menu.Str | Adaflight.Menu.Label | Adaflight.Menu.End_Marker | Adaflight.Menu.Guard =>
                     null;
               end case;
            end;
         end if;
         pragma Assert_And_Cut (Consistent (S));
      end;
   end Handle_Key;

   procedure Exit_Menu (S : in out State; T : in out Target_State; Kind : Exit_Kind) is
      use all type Adaflight.Menu.Exit_Kind;
      P           : constant Adaflight.Menu.Display_Index := S.Port;
      Ignore_Cost : Unsigned_32;
   begin
      case Kind is
         when Save | Save_Reboot | Popup_Save | Popup_Save_Reboot =>
            if S.Hooks.Leave then
               Ask_Leave (T, S.Id, -1);
            end if;
            if Kind in Popup_Save | Popup_Save_Reboot then
               for I in reverse 1 .. S.Depth loop
                  if S.Stack (I).Hooks.Leave then
                     Ask_Leave (T, S.Stack (I).Id, -1);
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

   procedure Set_Extern_Key (S : in out State; Key : Key_Code) is
   begin
      if S.Extern_Key = None then
         S.Extern_Key := Key;
      end if;
   end Set_Extern_Key;

   --  The sticks read as a key, in the reference's order: the menu gesture
   --  while disarmed, then pitch up or down, roll left or right, yaw left
   --  for escape and right for the save menu.
   function Stick_Key (Sticks : Stick_Inputs) return Key_Code is
     (if Sticks.Throttle > Stick_Low and then Sticks.Throttle < Stick_High and then Sticks.Yaw < Stick_Low
        and then Sticks.Pitch > Stick_High and then not Sticks.Armed
      then Menu_Key
      elsif Sticks.Pitch > Stick_High then Up
      elsif Sticks.Pitch < Stick_Low then Down
      elsif Sticks.Roll < Stick_Low then Left
      elsif Sticks.Roll > Stick_High then Right
      elsif Sticks.Yaw < Stick_Low then Esc
      elsif Sticks.Yaw > Stick_High then Save_Menu
      else None);

   --  The keys of a pass: the external key, or the sticks' key once the
   --  delay since the last key has run out, repeated while held, with the
   --  delay shortened the longer left or right is held, and the repeats
   --  grown once the delay is below the scheduling interval.
   procedure Scan_Keys
     (S               : in out State;
      T               : in out Target_State;
      K               : Key_Settings;
      Sl              : Adaflight.Menu.Slider_Settings;
      Sticks          : Stick_Inputs;
      Reboot_Required : Boolean;
      Now_Ms          : Unsigned_32)
     with Pre  => Consistent (S),
          Post => Consistent (S)
   is
      use type Interfaces.Integer_64;
      Key      : Key_Code;
      Delay_Ms : Key_Delay := 0;
   begin
      if S.Extern_Key /= None then
         Handle_Key (S, T, S.Extern_Key, K, Sl, Reboot_Required, Delay_Ms);
         S.Rc_Delay_Ms := Integer (Wrapped (Interfaces.Integer_64 (Delay_Ms), 16, True));
         S.Extern_Key := None;
         return;
      end if;
      Key := Stick_Key (Sticks);
      if Key = None then
         S.Hold_Count := 1;
         S.Repeat := 1;
         S.Repeat_Base := 0;
      else
         S.Hold_Count := Wrapped (Interfaces.Integer_64 (S.Hold_Count) + 1, 32, True);
      end if;
      if S.Rc_Delay_Ms > 0 then
         S.Rc_Delay_Ms :=
           Integer
             (Wrapped
                (Interfaces.Integer_64 (S.Rc_Delay_Ms) - Interfaces.Integer_64 (Now_Ms - S.Last_Called_Ms), 16, True));
      elsif Key /= None then
         for I in 1 .. S.Repeat loop
            pragma Loop_Invariant (Consistent (S));
            Handle_Key (S, T, Key, K, Sl, Reboot_Required, Delay_Ms);
         end loop;
         S.Rc_Delay_Ms := Integer (Wrapped (Interfaces.Integer_64 (Delay_Ms), 16, True));
         if (Key = Left or else Key = Right) and then S.Hold_Count > Hold_Repeat_Start then
            S.Rc_Delay_Ms := S.Rc_Delay_Ms / Integer (S.Hold_Count - Hold_Repeat_Start);
            if S.Rc_Delay_Ms <= Repeat_Delay_Limit then
               if S.Repeat_Base = 0 then
                  S.Repeat_Base := S.Hold_Count;
               end if;
               declare
                  Grown : constant Interfaces.Integer_64 :=
                    Interfaces.Integer_64 (S.Repeat)
                    + (Interfaces.Integer_64 (S.Hold_Count) - Interfaces.Integer_64 (S.Repeat_Base)) / 5;
               begin
                  S.Repeat :=
                    Repeat_Count (Interfaces.Integer_64'Max (1, Interfaces.Integer_64'Min (Repeat_Limit, Grown)));
               end;
            end if;
         end if;
      end if;
   end Scan_Keys;

   procedure Update
     (S               : in out State;
      T               : in out Target_State;
      K               : Key_Settings;
      Sl              : Adaflight.Menu.Slider_Settings;
      Sticks          : Stick_Inputs;
      Reboot_Required : Boolean;
      Now_Us          : Unsigned_32;
      Millis          : Unsigned_32;
      Room            : Unsigned_32)
   is
      Now_Ms : constant Unsigned_32 := Now_Us / 1000;
   begin
      if S.Port_Count = 0 then
         return;
      end if;
      if Sticks.Paralyzed or else Sticks.Device_In_Menu or else Sticks.Joystick_Active then
         return;
      end if;
      if not S.In_Menu then
         if Sticks.Throttle > Stick_Low and then Sticks.Throttle < Stick_High and then Sticks.Yaw < Stick_Low
           and then Sticks.Pitch > Stick_High and then not Sticks.Armed and then not Sticks.Stick_Commands_Disabled
         then
            Open (S, T, K.Start, K.Background);
            S.Rc_Delay_Ms := Button_Pause;
         end if;
      else
         Act (S.Port, Adaflight.Menu.Begin_Transaction, Reset_Drawing);
         Scan_Keys (S, T, K, Sl, Sticks, Reboot_Required, Now_Ms);
         Draw (S, T, Sl, Now_Us, Millis, Room);
         if S.Port >= 0 then
            if Now_Ms > S.Last_Beat_Ms + Heartbeat_Ms then
               Act (S.Port, Adaflight.Menu.Heartbeat, 0);
               S.Last_Beat_Ms := Now_Ms;
            end if;
            Act (S.Port, Adaflight.Menu.Commit_Transaction, 0);
         end if;
      end if;
      S.Last_Called_Ms := Millis;
   end Update;

end Adaflight.Menu_Nav;
