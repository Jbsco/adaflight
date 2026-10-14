pragma SPARK_Mode (On);
--  The command line over a reply record.
with Adaflight.CLI_Reply;
with Adaflight.Command_Line;

package Adaflight.Reply_Command_Line is new Adaflight.Command_Line
  (Sink => Adaflight.CLI_Reply.Reply, Put => Adaflight.CLI_Reply.Put);
