--  The configuration file of the BMI270 maximum FIFO variant, which the gyro
--  initialization loads into the chip: bmi270_maximum_fifo_config_file of Bosch
--  Sensortec's BMI270 Sensor API, release v2.113.0, under the license below.
--
--  Copyright (c) 2023 Bosch Sensortec GmbH. All rights reserved.
--
--  BSD-3-Clause
--
--  Redistribution and use in source and binary forms, with or without
--  modification, are permitted provided that the following conditions are met:
--
--  1. Redistributions of source code must retain the above copyright
--     notice, this list of conditions and the following disclaimer.
--
--  2. Redistributions in binary form must reproduce the above copyright
--     notice, this list of conditions and the following disclaimer in the
--     documentation and/or other materials provided with the distribution.
--
--  3. Neither the name of the copyright holder nor the names of its
--     contributors may be used to endorse or promote products derived from
--     this software without specific prior written permission.
--
--  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
--  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--  COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
--  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
--  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
--  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
--  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
--  IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--  POSSIBILITY OF SUCH DAMAGE.
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.BMI270_Config with SPARK_Mode, Pure is

   Maximum_FIFO : constant Byte_Array (0 .. 327) :=
     (16#C8#, 16#2E#, 16#00#, 16#2E#, 16#80#, 16#2E#, 16#1A#, 16#00#, 16#C8#, 16#2E#, 16#00#, 16#2E#,
      16#C8#, 16#2E#, 16#00#, 16#2E#, 16#C8#, 16#2E#, 16#00#, 16#2E#, 16#C8#, 16#2E#, 16#00#, 16#2E#,
      16#C8#, 16#2E#, 16#00#, 16#2E#, 16#C8#, 16#2E#, 16#00#, 16#2E#, 16#90#, 16#32#, 16#21#, 16#2E#,
      16#59#, 16#F5#, 16#10#, 16#30#, 16#21#, 16#2E#, 16#6A#, 16#F5#, 16#1A#, 16#24#, 16#22#, 16#00#,
      16#80#, 16#2E#, 16#3B#, 16#00#, 16#C8#, 16#2E#, 16#44#, 16#47#, 16#22#, 16#00#, 16#37#, 16#00#,
      16#A4#, 16#00#, 16#FF#, 16#0F#, 16#D1#, 16#00#, 16#07#, 16#AD#, 16#80#, 16#2E#, 16#00#, 16#C1#,
      16#80#, 16#2E#, 16#00#, 16#C1#, 16#80#, 16#2E#, 16#00#, 16#C1#, 16#80#, 16#2E#, 16#00#, 16#C1#,
      16#80#, 16#2E#, 16#00#, 16#C1#, 16#80#, 16#2E#, 16#00#, 16#C1#, 16#80#, 16#2E#, 16#00#, 16#C1#,
      16#80#, 16#2E#, 16#00#, 16#C1#, 16#80#, 16#2E#, 16#00#, 16#C1#, 16#80#, 16#2E#, 16#00#, 16#C1#,
      16#80#, 16#2E#, 16#00#, 16#C1#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#11#, 16#24#,
      16#FC#, 16#F5#, 16#80#, 16#30#, 16#40#, 16#42#, 16#50#, 16#50#, 16#00#, 16#30#, 16#12#, 16#24#,
      16#EB#, 16#00#, 16#03#, 16#30#, 16#00#, 16#2E#, 16#C1#, 16#86#, 16#5A#, 16#0E#, 16#FB#, 16#2F#,
      16#21#, 16#2E#, 16#FC#, 16#F5#, 16#13#, 16#24#, 16#63#, 16#F5#, 16#E0#, 16#3C#, 16#48#, 16#00#,
      16#22#, 16#30#, 16#F7#, 16#80#, 16#C2#, 16#42#, 16#E1#, 16#7F#, 16#3A#, 16#25#, 16#FC#, 16#86#,
      16#F0#, 16#7F#, 16#41#, 16#33#, 16#98#, 16#2E#, 16#C2#, 16#C4#, 16#D6#, 16#6F#, 16#F1#, 16#30#,
      16#F1#, 16#08#, 16#C4#, 16#6F#, 16#11#, 16#24#, 16#FF#, 16#03#, 16#12#, 16#24#, 16#00#, 16#FC#,
      16#61#, 16#09#, 16#A2#, 16#08#, 16#36#, 16#BE#, 16#2A#, 16#B9#, 16#13#, 16#24#, 16#38#, 16#00#,
      16#64#, 16#BB#, 16#D1#, 16#BE#, 16#94#, 16#0A#, 16#71#, 16#08#, 16#D5#, 16#42#, 16#21#, 16#BD#,
      16#91#, 16#BC#, 16#D2#, 16#42#, 16#C1#, 16#42#, 16#00#, 16#B2#, 16#FE#, 16#82#, 16#05#, 16#2F#,
      16#50#, 16#30#, 16#21#, 16#2E#, 16#21#, 16#F2#, 16#00#, 16#2E#, 16#00#, 16#2E#, 16#D0#, 16#2E#,
      16#F0#, 16#6F#, 16#02#, 16#30#, 16#02#, 16#42#, 16#20#, 16#26#, 16#E0#, 16#6F#, 16#02#, 16#31#,
      16#03#, 16#40#, 16#9A#, 16#0A#, 16#02#, 16#42#, 16#F0#, 16#37#, 16#05#, 16#2E#, 16#5E#, 16#F7#,
      16#10#, 16#08#, 16#12#, 16#24#, 16#1E#, 16#F2#, 16#80#, 16#42#, 16#83#, 16#84#, 16#F1#, 16#7F#,
      16#0A#, 16#25#, 16#13#, 16#30#, 16#83#, 16#42#, 16#3B#, 16#82#, 16#F0#, 16#6F#, 16#00#, 16#2E#,
      16#00#, 16#2E#, 16#D0#, 16#2E#, 16#12#, 16#40#, 16#52#, 16#42#, 16#00#, 16#2E#, 16#12#, 16#40#,
      16#52#, 16#42#, 16#3E#, 16#84#, 16#00#, 16#40#, 16#40#, 16#42#, 16#7E#, 16#82#, 16#E1#, 16#7F#,
      16#F2#, 16#7F#, 16#98#, 16#2E#, 16#6A#, 16#D6#, 16#21#, 16#30#, 16#23#, 16#2E#, 16#61#, 16#F5#,
      16#EB#, 16#2C#, 16#E1#, 16#6F#);

end Adaflight.BMI270_Config;
