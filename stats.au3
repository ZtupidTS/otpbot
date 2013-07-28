Func COMMAND_stats()
	Local $mem=MemGetStats ( );
	Local $drvf=DriveSpaceFree (@ScriptDir)
	Local $drvt=DriveSpaceTotal (@ScriptDir)
	Return StringFormat("Memory %s/%s KB %s/%s KB | Disk %s/%s | Log: %s B", _
	Int($array[6]),Int($array[5]), Int($array[2]),Int($array[1]), Int($drvf),Int($drvt), FileGetSize("otplog.txt"));
EndFunc