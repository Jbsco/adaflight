--  The stored video transmitter table: a band, its channels, the power
--  values and the power labels cleared as the reference's table commands
--  clear them, and the running table taken from the stored one, as at
--  boot.
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.VTX_Table;

package Adaflight.VTX_Table_Store with SPARK_Mode is

   Table_Size : constant := 8;
   subtype Band is Natural range 0 .. Table_Size - 1;
   subtype Count is Natural range 0 .. Table_Size;

   --  A band's frequencies from a channel on set to zero.
   procedure Clear_Channels (T : in out Vtx_Table_Config_Record; B : Band; From : Count);

   --  A band cleared: its frequencies zero, every channel named by its
   --  number, the band named BAND and its number, lettered by its number,
   --  and custom.
   procedure Clear_Band (T : in out Vtx_Table_Config_Record; B : Band);

   --  The power values from a level on set to zero.
   procedure Clear_Power_Values (T : in out Vtx_Table_Config_Record; From : Count);

   --  The power labels from a level on named LV and the level's index.
   procedure Clear_Power_Labels (T : in out Vtx_Table_Config_Record; From : Count);

   --  The counts the running table can take.
   function Counts_Valid (T : Vtx_Table_Config_Record) return Boolean is
     (Natural (T.Bands) <= Table_Size and then Natural (T.Channels) <= Table_Size
      and then Natural (T.Power_Levels) <= Table_Size);

   --  The running table: the counts, frequencies, names, letters, factory
   --  flags, channel names, power values and labels of the stored one.
   function Running (T : Vtx_Table_Config_Record) return VTX_Table.Table
     with Pre => Counts_Valid (T);

end Adaflight.VTX_Table_Store;
