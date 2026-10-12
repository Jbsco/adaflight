--  The video transmitter table: up to eight bands of eight channels with
--  their frequencies, names and letters, the factory band flags, and up to
--  eight power levels with their values and labels. The lookups give the
--  frequency of a band and channel, the band and channel of a frequency
--  searched from the last band down, and the value of a power index.
with Interfaces;

package Adaflight.VTX_Table with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Unsigned_16 is Interfaces.Unsigned_16;

   Max_Bands        : constant := 8;
   Max_Channels     : constant := 8;
   Max_Power_Levels : constant := 8;

   subtype Band_Index is Positive range 1 .. Max_Bands;
   subtype Channel_Index is Positive range 1 .. Max_Channels;
   subtype Power_Index is Positive range 1 .. Max_Power_Levels;
   subtype Band_Count is Natural range 0 .. Max_Bands;
   subtype Channel_Count is Natural range 0 .. Max_Channels;
   subtype Power_Count is Natural range 0 .. Max_Power_Levels;

   Min_User_Frequency : constant := 5000;
   Max_User_Frequency : constant := 5999;

   subtype Band_Name is String (1 .. 8);
   subtype Power_Label is String (1 .. 3);

   No_Band_Name    : constant Band_Name := "--------";
   No_Band_Letter  : constant Character := '-';
   No_Channel_Name : constant Character := '-';
   No_Power_Label  : constant Power_Label := "---";

   type Frequencies is array (Band_Index, Channel_Index) of Unsigned_16;
   type Band_Names is array (Band_Index) of Band_Name;
   type Band_Letters is array (Band_Index) of Character;
   type Channel_Names is array (Channel_Index) of Character;
   type Band_Flags is array (Band_Index) of Boolean;
   type Power_Values is array (Power_Index) of Unsigned_16;
   type Power_Labels is array (Power_Index) of Power_Label;

   --  An entry of zero is an empty channel.
   type Table is record
      Bands        : Band_Count := 0;
      Channels     : Channel_Count := 0;
      Frequency    : Frequencies := (others => (others => 0));
      Names        : Band_Names := (others => No_Band_Name);
      Letters      : Band_Letters := (others => No_Band_Letter);
      Channel_Name : Channel_Names := (others => No_Channel_Name);
      Is_Factory   : Band_Flags := (others => False);
      Power_Levels : Power_Count := 0;
      Power_Value  : Power_Values := (others => 0);
      Label        : Power_Labels := (others => No_Power_Label);
   end record;

   --  The frequencies of a band from the channel on are cleared.
   procedure Clear_Channels (T : in out Table; Band : Band_Index; From : Channel_Count);

   --  A band is cleared: no frequencies, the channel names of every band
   --  renumbered, the band named and lettered by its number, not factory.
   procedure Clear_Band (T : in out Table; Band : Band_Index);

   procedure Clear_Power_Values (T : in out Table; From : Power_Count);

   --  The labels from the level on are numbered from zero.
   procedure Clear_Power_Labels (T : in out Table; From : Power_Count);

   --  The cleared table of the defaults.
   function Default return Table;

   --  Zero outside the band and channel counts.
   function Frequency_Of (T : Table; Band, Channel : Natural) return Unsigned_16 is
     (if Band in 1 .. T.Bands and then Channel in 1 .. T.Channels then T.Frequency (Band, Channel) else 0);

   --  The band and channel of a frequency, the last band first, zero when
   --  the table has none.
   procedure Band_Channel_Of (T : Table; Freq : Unsigned_16; Band : out Band_Count; Channel : out Channel_Count);

   function Has_Power_Value (T : Table; Index : Natural) return Boolean is
     (Index in 1 .. T.Power_Levels);

   function Power_Value_Of (T : Table; Index : Natural) return Unsigned_16 is (T.Power_Value (Index))
     with Pre => Has_Power_Value (T, Index);

   function Band_Name_Of (T : Table; Band : Natural) return String is
     (if Band in 1 .. T.Bands then T.Names (Band) else "?");

   function Band_Letter_Of (T : Table; Band : Natural) return Character is
     (if Band in 1 .. T.Bands then T.Letters (Band) else '?');

   function Channel_Name_Of (T : Table; Channel : Natural) return Character is
     (if Channel in 1 .. T.Channels then T.Channel_Name (Channel) else '?');

   function Power_Label_Of (T : Table; Index : Natural) return String is
     (if Index in 1 .. T.Power_Levels then T.Label (Index) else "?");

end Adaflight.VTX_Table;
