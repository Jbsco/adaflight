package body Adaflight.Flash_Device with SPARK_Mode is

   use type Interfaces.Unsigned_32;

   procedure Ready_Poll_Done (F : in out Device; Status : Byte; Result : out Bus_Result) is
   begin
      if (Status and Write_In_Progress) /= 0 then
         Result := Busy;
         return;
      end if;
      F.Could_Be_Busy := False;
      Result := Ready;
   end Ready_Poll_Done;

   procedure Write_Enable_Done (F : in out Device) is
   begin
      F.Could_Be_Busy := True;
   end Write_Enable_Done;

   procedure Write_Done (F : in out Device; Notify : out Boolean) is
   begin
      F.Current_Write_Address := F.Current_Write_Address + F.Bytes_Written;
      Notify := F.Has_Callback;
   end Write_Done;

end Adaflight.Flash_Device;
