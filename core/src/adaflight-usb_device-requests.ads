--  The standard requests of a USB device and its events, for a class that
--  brings its state, its configuration descriptor, its names and its own
--  procedures: a start and an end with a configuration, the requests the
--  class takes, a packet from the host on one of its endpoints and a
--  transmission that ended on one.
generic
   type Class_State is private;
   Configuration_Descriptor : Byte_Array;
   Manufacturer_Name : String;
   Configuration_Name : String;
   Interface_Name : String;
   with procedure Class_Init (C : in out Core; S : in out Class_State; A : in out Actions);
   with procedure Class_Deinit (C : in out Core; S : in out Class_State; A : in out Actions);
   with procedure Class_Setup (C : in out Core; S : in out Class_State; A : in out Actions; R : Request);
   with procedure Class_Data_Out
     (C : in out Core; S : in out Class_State; A : in out Actions; EP : Endpoint_Number; Packet : Byte_Array);
   with procedure Class_Data_In (C : in out Core; S : in out Class_State; A : in out Actions; EP : Endpoint_Number);
package Adaflight.USB_Device.Requests with SPARK_Mode is

   --  A setup packet, the bytes of an OUT packet and an IN transfer done.
   procedure Setup (C : in out Core; S : in out Class_State; Packet : Setup_Packet; A : out Actions);
   procedure Data_Out
     (C : in out Core; S : in out Class_State; EP : Endpoint_Number; Packet : Byte_Array; A : out Actions)
     with Pre => Packet'Length <= Packet_Size;
   procedure Data_In (C : in out Core; S : in out Class_State; EP : Endpoint_Number; A : out Actions);

end Adaflight.USB_Device.Requests;
