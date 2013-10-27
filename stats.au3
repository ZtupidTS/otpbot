#include-once
#include "GeneralCommands.au3"

_Help_Register("stats","","Provides otpbot host system information.")

Func COMMAND_stats()
	Local $mem=MemGetStats ( );
	Local $drvf=DriveSpaceFree (@ScriptDir)
	Local $drvt=DriveSpaceTotal (@ScriptDir)
	Return StringFormat("Memory %s/%s | RAM %s/%s KB | Disk %s/%s MB | Log: %s B", _
	Int($mem[6]),Int($mem[5]), Int($mem[2]),Int($mem[1]), Int($drvf),Int($drvt), FileGetSize("otplog.txt"));
EndFunc