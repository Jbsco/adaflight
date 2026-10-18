--  The board as a USB joystick. While disarmed the receiver task sends a
--  report of eight axes and eight buttons from the receiver's channels: the
--  roll, pitch, third auxiliary, yaw, first auxiliary, throttle, fourth
--  and second auxiliary channels as axes from -127 to 127 with the pitch
--  inverted, and the fifth to twelfth auxiliary channels as buttons that
--  are on from 1504 microseconds. Each channel is cut to a whole number of
--  microseconds and held to the 1000 to 2000 range first. The board may be
--  in use as a joystick when its USB device is the composite one and
--  connected and either no battery is present or no voltage meter is set,
--  which stops the stick commands and the menu's stick entry.
with Interfaces;

package Adaflight.USB_Joystick with SPARK_Mode is

   Channel_Count : constant := 18;
   subtype Channel_Index is Natural range 0 .. Channel_Count - 1;
   type Channel_Data is array (Channel_Index) of Float;

   Report_Length : constant := 9;
   subtype Report_Index is Natural range 0 .. Report_Length - 1;
   type Report is array (Report_Index) of Interfaces.Unsigned_8;

   function Report_Of (Data : Channel_Data) return Report
     with Global => null;

   function May_Be_Active
     (Composite : Boolean; Connected : Boolean; Battery_Absent : Boolean; No_Voltage_Meter : Boolean)
      return Boolean
   is (Composite and then Connected and then (Battery_Absent or else No_Voltage_Meter));

end Adaflight.USB_Joystick;
