--  The SPI receiver layer's choices: the receiver family each protocol
--  number of the setting runs on, what a family's packet check answers,
--  and the layer's packet flag and channel data.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.RX_SPI with SPARK_Mode is
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;

   --  No build compiles the KN receiver, so its protocol has no family.
   type Family is
     (None, V202, Syma, CX10, H8_3D, Ack_Payload, FrSky, Redpine, FlySky, SFHSS, Spektrum, ExpressLRS);

   --  The protocol numbers in order: V202 at 250K and 1M, SYMA X and X5C,
   --  CX10 and CX10A, H8_3D, acknowledgment payload, FrSky D, FrSky X,
   --  FlySky, FlySky 2A, KN, SFHSS, Spektrum DSM, FrSky X LBT, Redpine,
   --  FrSky X V2, FrSky X LBT V2 and ExpressLRS.
   function Family_Of (Protocol : Unsigned_8) return Family is
     (case Protocol is
         when 0 | 1                => V202,
         when 2 | 3                => Syma,
         when 4 | 5                => CX10,
         when 6                    => H8_3D,
         when 7                    => Ack_Payload,
         when 8 | 9 | 15 | 17 | 18 => FrSky,
         when 10 | 11              => FlySky,
         when 13                   => SFHSS,
         when 14                   => Spektrum,
         when 16                   => Redpine,
         when 19                   => ExpressLRS,
         when others               => None);

   type Received is record
      Bind                : Boolean := False;
      Data                : Boolean := False;
      Processing_Required : Boolean := False;
   end record;

   type Channel_Data is array (Receiver.Channel) of Unsigned_16;

   type State is record
      Selected   : Family := None;
      New_Packet : Boolean := False;
      Data       : Channel_Data := (others => 0);
   end record;

end Adaflight.RX_SPI;
