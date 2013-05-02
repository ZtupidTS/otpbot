#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=host.ico
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Fileversion=1.0.0.14
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include "otphostcore.au3"

Global $_OtpHost_OnCommand = "OnClientReply";configure library to use this function

Global $TestMode = 0

TCPStartup();to connect to otpbot local command socket.
FileChangeDir(@ScriptDir)

If @Compiled = 0 And $TestMode = 0 Then Exit (MsgBox(16, 'otphost', 'This program must be compiled to work properly.'))

; OtpHost itself needs to run from a temporary copy so that OtpHost can update itself
; so on normal run, it will copy itself to otphost-session and run from there instead.

; otphost-session will detect its filename and run as desired.
; when updating, otphost-session will run otphost with a command-line parameter to tell it it has just been updated, and to wait for otphost-session to close.




If StringInStr(@ScriptName, '-session') Or $TestMode Then
	If Not (StringInStr($CmdLineRaw, "CHILD-5A881D") Or $TestMode) Then Exit (MsgBox(16, 'otphost-session', 'This program is not meant to be ran directly. Run otphost.exe instead.'))
Else
	If StringInStr($CmdLineRaw, "UPDATE-5A881D") Then
		ProcessWaitClose("otphost-session.exe", 3000)
		ProcessClose("otphost-session.exe")
		Sleep(500)
	EndIf
	FileDelete('otphost-session.exe')
	FileCopy(@ScriptFullPath, 'otphost-session.exe')
	Run('otphost-session.exe CHILD-5A881D', @ScriptDir)
	Exit
EndIf




OnAutoItExitRegister("Quit")
Global $RemoteVer = 0
Global $PID = 0
Global $KeepAliveTimer = 0
Global $UpdateTimer = 0
Global $LastVerCmp = ""

While 1
	If TimeElapsed($UpdateTimer, 15 * 60 * 1000) Then
		If check() Then update()
	EndIf
	If TimeElapsed($KeepAliveTimer, 4 * 60 * 1000, True) Then kill('Bot Not Responding')
	If Not (Cmd('ping', $LastVerCmp) Or ProcessExists($PID)) Then restart()
	Sleep(1 * 60 * 1000)
WEnd
;------------------------------------------


Func TimeElapsed(ByRef $timer, $ms, $skipinitial = False)
	If $skipinitial And $timer = 0 Then Return False
	If TimerDiff($timer) > $ms Then
		$timer = TimerInit()
		Return True
	EndIf
	Return False
EndFunc   ;==>TimeElapsed


Func restart()
	Global $PID
	Global $KeepAliveTimer
	$PID = Run("otpbot.exe", @ScriptDir)
	Sleep(2000)
	$KeepAliveTimer = 0
EndFunc   ;==>restart

Func kill($reason = "Killed by OtpHost")
	Global $PID
	Global $KeepAliveTimer
	Cmd('quit', $reason)
	Sleep(2000)
	ProcessClose($PID)
	ProcessClose('otpbot.exe')
	$KeepAliveTimer = 0
EndFunc   ;==>kill


Func OnClientReply($cmd, $data, $socket)
	Global $KeepAliveTimer
	If $cmd = 'pong' Then $KeepAliveTimer = TimerInit()
EndFunc   ;==>OnClientReply


Func update()
	l("UPDATING")
	kill('Updating to r' & $RemoteVer & '...')
	If $TestMode Then Return
	Sleep(5000)

	updatefile('Readme.txt')
	updatefile('otpbot.exe')
	updatefile('otpbot.ini')
	updatefile('otphost.exe')
	updatefile('otpxor.exe')
	updatefile('otpnato.exe')

	FileDelete("Release.ver")
	FileWrite("Release.ver", $RemoteVer)

	Run("otphost.exe UPDATE-5A881D", @ScriptDir)
	Exit
EndFunc   ;==>update

Func updatefile($file)
	If look($file, $RemoteVer) Then
		FileMove($file, $file & '_old', 1)
		FileDelete($file)
		Get($file, $RemoteVer)
	EndIf
EndFunc   ;==>updatefile


Func look($file, $revision)
	Return InetGetSize("http://otpbot.googlecode.com/svn/trunk/" & $file & "?r=" & Int($revision))
EndFunc   ;==>look
Func Get($file, $revision)
	Local $r = InetGet("http://otpbot.googlecode.com/svn/trunk/" & $file & "?r=" & Int($revision), @ScriptDir & '\' & $file)
EndFunc   ;==>get

Func Cmd($cmd, $data = "")
	Local $r = _OtpHost_scmd($cmd, $data, False); send command and keep socket open for reuse
	Local $s = @extended
	_OtpHost_PollReply($s, 2000)
	TCPCloseSocket($s)
	Return $r
EndFunc   ;==>cmd


Func Quit()
	kill('OtpHost closed.')
	TCPShutdown()
	Sleep(1000)
	ProcessClose($PID)
	Exit
EndFunc   ;==>quit

Func check()
	Global $LastVerCmp
	Local $lv = locver()
	Local $le = @error

	Local $rv = remver()
	Local $re = @error

	l(StringFormat("VERCHECK l%06d:r%06d", $lv, $rv))
	$LastVerCmp = StringFormat("l%06d:r%06d", $lv, $rv)

	If $re <> 0 Or $le <> 0 Then SetError(1, 0, False)

	$RemoteVer = $rv

	Return ($rv > $lv)
EndFunc   ;==>check

Func remver()
	;http://otpbot.googlecode.com/svn/trunk/
	Local $b = InetRead("http://otpbot.googlecode.com/svn/trunk/Release.ver", 1)
	Local $s = BinaryToString($b)
	ConsoleWrite($b & @CRLF & $s & @CRLF)
	Local $r = ver($s)
	Local $e = @error
	Return SetError($e, 0, $r)
EndFunc   ;==>remver
Func locver()
	Local $s = FileRead("Release.ver")
	Local $r = ver($s)
	Local $e = @error
	Return SetError($e, 0, $r)
EndFunc   ;==>locver

Func ver($s)
	$s = StringStripWS($s, 8)
	If StringLen($s) = 0 Then Return SetError(1, 0, 0)
	Local $a = StringSplit($s, ':')
	Local $max = 0
	For $i = 1 To UBound($a) - 1
		$a[$i] = Int($a[$i])
		If $a[$i] > $max Then $max = $a[$i]
	Next
	If $max = 0 Then Return SetError(2, 0, 0)
	Return SetError(0, 0, $max)
EndFunc   ;==>ver

Func l($s)
	_OtpHost_hlog($s)
EndFunc   ;==>l