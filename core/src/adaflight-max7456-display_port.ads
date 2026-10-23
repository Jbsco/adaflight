--  The MAX7456 display port: the display layer's calls on the MAX7456 driver.
--  Initialization runs the driver's and, when the chip has a select pin, sets
--  up the port and clears the screen; a chip that answered sets the rows from
--  the video system and both dimensions with the profile's adjustments. A
--  clear sets the profile's inversion and brightness first. A redraw draws
--  the whole screen while disarmed, the heartbeat runs the driver's stall
--  and signal checks, and a readiness check with rescan initializes a chip
--  that did not answer before and redraws.
generic
package Adaflight.MAX7456.Display_Port with SPARK_Mode is
   use type Interfaces.Integer_8;

   --  The profile: the column and row adjustments, the pixel inversion and
   --  the black and white brightness.
   type Display_Profile is record
      Col_Adjust       : Interfaces.Integer_8 := 0;
      Row_Adjust       : Interfaces.Integer_8 := 0;
      Invert           : Boolean := False;
      Black_Brightness : Byte := 0;
      White_Brightness : Byte := 2;
   end record;

   --  The port as the display layer keeps it: its dimensions, the grab
   --  count, the cleared flag and the cursor row.
   type Port is record
      Rows       : Byte := 0;
      Cols       : Byte := 0;
      Grab_Count : Interfaces.Integer_8 := 0;
      Cleared    : Boolean := False;
      Cursor_Row : Interfaces.Integer_8 := 0;
   end record;

   subtype Character_Data is Byte_Array (0 .. 63);

   --  Available tells whether the port exists, Ready whether the chip
   --  answered.
   procedure Init
     (D             : in out SPI_Device;
      S             : in out State;
      P             : out Port;
      C             : Config;
      Video         : Video_Profile;
      Display       : Display_Profile;
      CPU_Overclock : Boolean;
      Available     : out Boolean;
      Ready         : out Boolean);

   procedure Grab (D : in out SPI_Device; S : in out State; P : in out Port; Display : Display_Profile)
     with Pre => P.Grab_Count < Interfaces.Integer_8'Last;

   procedure Release (P : in out Port)
     with Global => null,
          Pre    => P.Grab_Count > Interfaces.Integer_8'First;

   procedure Release_All (P : in out Port)
     with Global => null;

   procedure Clear_Screen (D : in out SPI_Device; S : in out State; P : in out Port; Display : Display_Profile);

   --  The text at the column and row; an empty text writes nothing.
   procedure Write_String (S : in out State; X : Byte; Y : Byte; Text : Byte_Array)
     with Global => null;

   procedure Heartbeat (D : in out SPI_Device; S : in out State; Stalled : out Boolean);

   procedure Redraw (D : in out SPI_Device; S : in out State; Armed : Boolean);

   function Tx_Bytes_Free return Interfaces.Unsigned_16 is (Interfaces.Unsigned_16'Last);

   --  Every display supports the foreground; the chip supports no other.
   function Port_Layer_Supported (Layer : Natural) return Boolean is (Layer = 0);

   procedure Port_Layer_Copy (S : in out State; Destination : Natural; Source : Natural; Copied : out Boolean)
     with Global => null;

   --  The character's first 54 bytes at the low byte of the address.
   procedure Write_Font_Character
     (D       : in out SPI_Device;
      S       : in out State;
      Address : Interfaces.Unsigned_16;
      Data    : Character_Data;
      Written : out Boolean);

   procedure Check_Ready
     (D             : in out SPI_Device;
      S             : in out State;
      C             : Config;
      Video         : Video_Profile;
      CPU_Overclock : Boolean;
      Armed         : Boolean;
      Rescan        : Boolean;
      Ready         : out Boolean);

end Adaflight.MAX7456.Display_Port;
