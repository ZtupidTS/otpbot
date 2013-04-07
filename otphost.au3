#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=host.ico
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Fileversion=1.0.0.1
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

TCPStartup();to connect to otpbot local command socket.
FileChangeDir (@ScriptDir)
OnAutoItExitRegister("quit")
Global $RemoteVer=0
Global $PID=0
While 1
	If ProcessExists($PID) Or cmd('ping') Then
		If check() Then update()
	Else
		;$PID=Run("otpbot.exe",@ScriptDir)
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


	FileMove("Readme.txt","Readme.old",1)
	FileMove("Release.ver","Release.old",1)
	FileMove("otpbot.exe","otpbot.old",1)

	get('Readme.txt',$RemoteVer)
	get('otpbot.exe',$RemoteVer)
	get('Release.ver',$RemoteVer)

EndFunc

Func get($file,$revision)
	Return InetGet("http://otpbot.googlecode.com/svn/trunk/"&$file&"?r="&Int($revision),@ScriptDir&'\'&$file)
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
	Sleep(2000)
	ProcessClose($PID)
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
