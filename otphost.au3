#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=host.ico
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Fileversion=1.0.0.8
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

TCPStartup();to connect to otpbot local command socket.
FileChangeDir (@ScriptDir)

If @Compiled=0 Then Exit(MsgBox(16, 'otphost', 'This program must be compiled to work properly.'))

; OtpHost itself needs to run from a temporary copy so that OtpHost can update itself
; so on normal run, it will copy itself to otphost-session and run from there instead.

; otphost-session will detect its filename and run as desired.
; when updating, otphost-session will run otphost with a command-line parameter to tell it it has just been updated, and to wait for otphost-session to close.

If StringInStr(@ScriptName, '-session') Then
	If Not StringInStr($CmdLineRaw,"CHILD-5A881D") Then Exit(MsgBox(16, 'otphost-session', 'This program is not meant to be ran directly. Run otphost.exe instead.'))
Else
	If StringInStr($CmdLineRaw,"UPDATE-5A881D") Then
		ProcessWaitClose("otphost-session.exe",3000)
		ProcessClose("otphost-session.exe")
		Sleep(500)
	EndIf
	FileDelete('otphost-session.exe')
	FileCopy(@ScriptFullPath,'otphost-session.exe')
	Run('otphost-session.exe CHILD-5A881D',@ScriptDir)
	Exit
EndIf




OnAutoItExitRegister("quit")
Global $RemoteVer=0
Global $PID=0
While 1
	If check() Then update()
	If Not (ProcessExists($PID) Or cmd('ping')) Then
		$PID=Run("otpbot.exe",@ScriptDir)
		Sleep(2000)
	EndIf
	Sleep(10*1000)
WEnd
;------------------------------------------

Func update()
	l("UPDATING")
	cmd('quit','Updating to r'&$RemoteVer&'...')
	Sleep(2000)
	ProcessClose($PID)

	updatefile('Readme.txt')
	updatefile('otpbot.exe')
	updatefile('otphost.exe')
	updatefile('otpxor.exe')
	updatefile('otpnato.exe')

	FileDelete("Release.ver")
	FileWrite("Release.ver",$RemoteVer)

	Run("otphost.exe UPDATE-5A881D",@ScriptDir)
	Exit
EndFunc

Func updatefile($file)
	If look($file,$RemoteVer) Then
		FileMove($file,$file&'_old',1)
		FileDelete($file)
		get($file,$RemoteVer)
	EndIf
EndFunc


Func look($file,$revision)
	Return InetGetSize("http://otpbot.googlecode.com/svn/trunk/"&$file&"?r="&Int($revision))
EndFunc
Func get($file,$revision)
	Local $r=InetGet("http://otpbot.googlecode.com/svn/trunk/"&$file&"?r="&Int($revision),@ScriptDir&'\'&$file)
EndFunc

Func cmd($cmd,$data="")
	Local $sk=TCPConnect('127.0.0.1',12917)
	Local $bSuccess=($sk>=0)
	l("CMD "&$cmd&" "&$sk&' '&@error)
	If $sk>=0 Then TCPSend($sk,'<!'&$cmd&'|'&$data&'!>')
	If $sk>=0 Then TCPCloseSocket($sk)
	Return $bSuccess
EndFunc


Func quit()
	cmd('quit','OtpHost closed.')
	TCPShutdown()
	Sleep(1000)
	ProcessClose($PID)
	Exit
EndFunc

Func check()
	Local $lv=locver()
	Local $le=@error

	Local $rv=remver()
	Local $re=@error

	l(StringFormat("VERCHECK l%06d:r%06d",$lv,$rv))

	If $re<>0 Or $le<>0 Then SetError(1,0,False)

	$RemoteVer=$rv

	Return ($rv>$lv)
EndFunc

Func remver()
	;http://otpbot.googlecode.com/svn/trunk/
	Local $b=InetRead ( "http://otpbot.googlecode.com/svn/trunk/Release.ver", 1)
	Local $s=BinaryToString($b)
	ConsoleWrite($b&@CRLF&$s&@CRLF)
	Local $r=ver($s)
	Local $e=@error
	Return SetError($e,0,$r)
EndFunc
Func locver()
	Local $s=FileRead("Release.ver")
	Local $r=ver($s)
	Local $e=@error
	Return SetError($e,0,$r)
EndFunc

Func ver($s)
	$s=StringStripWS($s,8)
	If StringLen($s)=0 Then Return SetError(1,0,0)
	Local $a=StringSplit($s,':')
	Local $max=0
	For $i=1 To UBound($a)-1
		$a[$i]=Int($a[$i])
		If $a[$i]>$max Then $max=$a[$i]
	Next
	If $max=0 Then Return SetError(2,0,0)
	Return SetError(0,0,$max)
EndFunc

Func l($s)
	ConsoleWrite(StringFormat("%02d:%02d %02d-%02d-%04d %s",@HOUR,@MIN,@MDAY,@MON,@YEAR,$s)&@CRLF)
EndFunc
