--  The MSP messages of simplified tuning: the sliders with the filter
--  cutoffs they act on, the gains or the filter cutoffs a slider set gives
--  without storing them, whether the gains and the filters in use match
--  their sliders, and the in message that stores a slider set and applies
--  it. A request reads zero past its end. A request with a field outside its
--  setting's range is an error that writes and changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;
with Adaflight.PID_Profile;
with Adaflight.Gyro_Filters;

package Adaflight.MSP_Simplified_Tuning with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Adaflight.PID_Profile.Profile;
   use type Adaflight.Gyro_Filters.Settings;

   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Simplified_Tuning_Command     : constant := 140;
   Set_Simplified_Tuning_Command : constant := 141;
   Calculate_PID_Command         : constant := 142;
   Calculate_Gyro_Command        : constant := 143;
   Calculate_Dterm_Command       : constant := 144;
   Validate_Command              : constant := 145;

   PID_Sliders_Length    : constant := 17;
   Filter_Sliders_Length : constant := 18;
   Max_Reply_Length      : constant := PID_Sliders_Length + 2 * Filter_Sliders_Length;

   subtype Request_Offset is Natural range 0 .. 64;

   --  The request's byte at an offset, zero past its end.
   function Byte_At (Request : Byte_Array; At_Offset : Request_Offset) return Byte is
     (if At_Offset < Request'Length then Request (Request'First + At_Offset) else 0);

   --  The request's little-endian 16-bit value at an offset.
   function U16_At (Request : Byte_Array; At_Offset : Request_Offset) return Natural is
     (Natural (Byte_At (Request, At_Offset)) + 256 * Natural (Byte_At (Request, At_Offset + 1)))
     with Pre => At_Offset < Request_Offset'Last;

   --  Whether the gain sliders at an offset are within their ranges: the
   --  mode, the master multiplier, the roll to pitch ratio, the I, D and PI
   --  gains, the D max gain, the feedforward gain and the pitch PI gain.
   function PID_Sliders_Valid (Request : Byte_Array; Base : Request_Offset) return Boolean is
     (Byte_At (Request, Base) <= 2
      and then Byte_At (Request, Base + 1) <= 200
      and then Byte_At (Request, Base + 2) <= 200
      and then Byte_At (Request, Base + 3) <= 200
      and then Byte_At (Request, Base + 4) <= 200
      and then Byte_At (Request, Base + 5) <= 200
      and then Byte_At (Request, Base + 6) <= 200
      and then Byte_At (Request, Base + 7) <= 200
      and then Byte_At (Request, Base + 8) <= 200)
     with Pre => Base <= Request_Offset'Last - PID_Sliders_Length;

   --  Whether the filter sliders at an offset are within their ranges: the
   --  slider's switch and multiplier, the two static cutoffs, and the
   --  dynamic range with its lower end off or at most its upper end.
   function Filter_Sliders_Valid (Request : Byte_Array; Base : Request_Offset) return Boolean is
     (Byte_At (Request, Base) <= 1
      and then Byte_At (Request, Base + 1) in 10 .. 200
      and then U16_At (Request, Base + 2) <= 1_000
      and then U16_At (Request, Base + 4) <= 1_000
      and then U16_At (Request, Base + 6) <= 1_000
      and then U16_At (Request, Base + 8) <= 1_000
      and then (U16_At (Request, Base + 6) = 0 or else U16_At (Request, Base + 6) <= U16_At (Request, Base + 8)))
     with Pre => Base <= Request_Offset'Last - Filter_Sliders_Length;

   --  Whether a message's request is within its ranges; a message without
   --  one always is.
   function Valid (Command : Unsigned_16; Request : Byte_Array) return Boolean is
     (case Command is
         when Calculate_PID_Command => PID_Sliders_Valid (Request, 0),
         when Calculate_Gyro_Command | Calculate_Dterm_Command => Filter_Sliders_Valid (Request, 0),
         when Set_Simplified_Tuning_Command =>
            PID_Sliders_Valid (Request, 0)
            and then Filter_Sliders_Valid (Request, PID_Sliders_Length)
            and then Filter_Sliders_Valid (Request, PID_Sliders_Length + Filter_Sliders_Length),
         when others => True);

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in Simplified_Tuning_Command | Calculate_PID_Command .. Validate_Command);

   --  The reply to one of the out messages with its request's payload, from
   --  the profile and the gyro settings in use. Ok is false for a request
   --  outside its ranges, which writes nothing; a command not handled writes
   --  nothing either.
   procedure Reply
     (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; Request : Byte_Array;
      P : PID_Profile.Profile; G : Gyro_Filters.Settings; Ok : out Boolean)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then Ok = (not Handles (Command) or else Valid (Command, Request))
                  and then (if not Ok or else not Handles (Command) then S.Next = S.Next'Old);

   --  The in message: the gain sliders, the D term filter sliders with the D
   --  term cutoffs and the gyro filter sliders with the gyro cutoffs from the
   --  request, then every slider applied. Ok is false for a request outside
   --  its ranges, which changes nothing.
   procedure Set
     (Request : Byte_Array; P : in out PID_Profile.Profile; G : in out Gyro_Filters.Settings; Ok : out Boolean)
     with Post => Ok = Valid (Set_Simplified_Tuning_Command, Request)
                  and then (if not Ok then P = P'Old and then G = G'Old);

end Adaflight.MSP_Simplified_Tuning;
