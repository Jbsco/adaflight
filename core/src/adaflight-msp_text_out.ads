--  The MSP out messages that answer with text, a table row or a profile:
--  the craft name, a text by its type, a video transmitter band or power
--  level from the frequency table, the LED strip's brightness and rainbow,
--  and a battery profile. A request carries the text type, the band, the
--  level or the profile; an invalid one is an error with nothing written.
--  The caller gathers the names, the build's strings, the table, the strip
--  settings and the battery profiles into a snapshot.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;

package Adaflight.MSP_Text_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Name_Command             : constant := 10;
   VTX_Table_Band_Command   : constant := 137;
   VTX_Table_Power_Command  : constant := 138;
   Get_Text_Command         : constant := 16#3006#;
   LED_Strip_Values_Command : constant := 16#3008#;
   Battery_Profile_Command  : constant := 16#300E#;

   Pilot_Name_Text         : constant := 1;
   Craft_Name_Text         : constant := 2;
   PID_Profile_Name_Text   : constant := 3;
   Rate_Profile_Name_Text  : constant := 4;
   Build_Key_Text          : constant := 5;
   Release_Name_Text       : constant := 6;
   Battery_Profile_Name_Text : constant := 11;

   Max_Text           : constant := 64;
   Band_Count         : constant := 8;
   Channel_Count      : constant := 8;
   Power_Count        : constant := 8;
   Band_Name_Length   : constant := 8;
   Power_Label_Length : constant := 3;
   Profile_Count      : constant := 3;
   Max_Reply_Length   : constant := 2 + Max_Text;

   subtype Text_Length is Natural range 0 .. Max_Text;
   type Text is record
      Length : Text_Length := 0;
      Data   : String (1 .. Max_Text) := (others => ' ');
   end record;

   --  A text the build may leave out.
   type Optional_Text is record
      Present : Boolean := False;
      Value   : Text;
   end record;

   subtype Band_Name is Byte_Array (1 .. Band_Name_Length);
   subtype Power_Label is Byte_Array (1 .. Power_Label_Length);
   type Band_Names is array (1 .. Band_Count) of Band_Name;
   type Band_Bytes is array (1 .. Band_Count) of Unsigned_8;
   type Channel_Frequencies is array (1 .. Channel_Count) of Unsigned_16;
   type Band_Frequencies is array (1 .. Band_Count) of Channel_Frequencies;
   type Power_Values is array (1 .. Power_Count) of Unsigned_16;
   type Power_Labels is array (1 .. Power_Count) of Power_Label;

   --  The frequency table when it is built: the channels each band carries,
   --  each band's name, letter, factory flag and frequencies, and each power
   --  level's value and label.
   type VTX_Table is record
      Built       : Boolean := False;
      Channels    : Natural range 0 .. Channel_Count := 0;
      Names       : Band_Names := (others => (others => 0));
      Letters     : Band_Bytes := (others => 0);
      Factory     : Band_Bytes := (others => 0);
      Frequencies : Band_Frequencies := (others => (others => 0));
      Powers      : Power_Values := (others => 0);
      Labels      : Power_Labels := (others => (others => 0));
   end record;

   --  A battery profile: the cell voltages in hundredths of a volt, the
   --  capacity in milliampere hours, the forced cell count, the consumption
   --  warning percentage and the name.
   type Battery_Profile is record
      Min_Cell            : Unsigned_16 := 0;
      Max_Cell            : Unsigned_16 := 0;
      Warning_Cell        : Unsigned_16 := 0;
      Full_Cell           : Unsigned_16 := 0;
      Capacity            : Unsigned_16 := 0;
      Force_Cell_Count    : Unsigned_8 := 0;
      Consumption_Warning : Unsigned_8 := 0;
      Name                : Text;
   end record;
   subtype Profile_Index is Natural range 0 .. Profile_Count - 1;
   type Battery_Profiles is array (Profile_Index) of Battery_Profile;

   type Snapshot is record
      Pilot_Name        : Text;
      Craft_Name        : Text;
      PID_Profile_Name  : Text;
      Rate_Profile_Name : Text;
      Build_Key         : Optional_Text;
      Release_Name      : Optional_Text;
      Batteries         : Battery_Profiles;
      Active_Battery    : Profile_Index := 0;
      LED_Strip         : Boolean := False;
      Brightness        : Unsigned_8 := 0;
      Rainbow_Delta     : Unsigned_16 := 0;
      Rainbow_Freq      : Unsigned_16 := 0;
      Table             : VTX_Table;
   end record;

   --  Whether the build answers the command here: the table rows need the
   --  table and the strip values the strip.
   function Handles (Command : Unsigned_16; V : Snapshot) return Boolean is
     (Command in Name_Command | Get_Text_Command | Battery_Profile_Command
      or else (Command in VTX_Table_Band_Command | VTX_Table_Power_Command and then V.Table.Built)
      or else (Command = LED_Strip_Values_Command and then V.LED_Strip));

   --  The reply to one of these out messages with its request's payload. Ok
   --  is false for an invalid request, which writes nothing; a command not
   --  handled writes nothing either.
   procedure Reply
     (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; Request : Byte_Array; V : Snapshot;
      Ok : out Boolean)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Ok or else not Handles (Command, V) then S.Next = S.Next'Old);

end Adaflight.MSP_Text_Out;
