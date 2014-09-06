#include-once
#include "GeneralCommands.au3"


Local $_Stats_Commands[1][3]=[["stats","","Provides otpbot host system information."]]
_Help_RegisterGroup("General","","_Stats_Commands")


Func COMMAND_stats()
	Local $mem=MemGetStats ( );
	Local $drvf=DriveSpaceFree (@ScriptDir)
	Local $drvt=DriveSpaceTotal (@ScriptDir)
	Return StringFormat("Free Memory %s/%s KB | Free RAM %s/%s KB | Free Disk Space %s/%s MB | Log: %s B", _
	Int($mem[6]),Int($mem[5]), Int($mem[2]),Int($mem[1]), Int($drvf),Int($drvt), FileGetSize("otplog.txt"));
EndFunc