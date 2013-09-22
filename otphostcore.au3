Global $_OtpHost_OnCommand = ""
Global $_OtpHost_OnLogWrite=""
Global Const $_OtpHost_Port = 12917
Global Enum $_OtpHost_Instance_Bot, $_OtpHost_Instance_Host

Global $_OtpHost__Instance=-99999

Func _OtpHost_Create($instance); returns a value of unknown type, to be used as a Handle.  takes an input of an instance type Index.
	TCPStartup()
	Local $arr[2]=[$instance,_OtpHost_CreateListener($instance)]
	_OtpHost_flog("OtpHost_Create ("&$arr[0]&","&$arr[1]&") :: "& ($_OtpHost_Port+$instance) &' '& _OtpHost_GetCompanionPort($instance))

	Return $arr
EndFunc
Func _OtpHost_Destroy($hOtphost)
	_OtpHost_flog("OtpHost_Destroy ("&$hOtphost[0]&","&$hOtphost[1]&")")
	TCPCloseSocket($hOtphost[1])
	TCPShutdown()
	Return 1
EndFunc


Func _OtpHost_GetCompanionPort($instance)
	$instance=Mod($instance+1,2)+(Int($instance/2)*2); Pairs of ports 0=1  1=0   2=3  3=2
	Return $_OtpHost_Port+$instance
	Local $port=$_OtpHost_Port+$instance
EndFunc
Func _OtpHost_CreateListener($instance=0); user index is the
	Local $port=$_OtpHost_Port+$instance
	Local $ret=TCPListen('127.0.0.1', $port)
	If @error<>0 Then _OtpHost_flog('_OtpHost_CreateListener LISTEN ERROR '&@error)
	Return $ret
EndFunc   ;==>_OtpHost_CreateListener
Func _OtpHost_OnCommand($cmd, $data, $socket)
	_OtpHost_hlog("ONCMD: " & $cmd & " " & $socket & @CRLF)
	If StringLen($_OtpHost_OnCommand) Then Call($_OtpHost_OnCommand, $cmd, $data, $socket)
EndFunc   ;==>_OtpHost_OnCommand

Func _OtpHost_Listen($hOtphost, $closeSocket = True)
	If Not IsArray($hOtphost) Then Return -1
	Local $skListener=$hOtphost[1]
	Local $buffer = ""
	$skIncoming = TCPAccept($skListener)
	If $skIncoming >= 0 Then
		_OtpHost_hlog("Host Conn: " & $skIncoming)
		$buffer = TCPRecv($skIncoming, 4096)
		If @error<>0 Then _OtpHost_flog('_OtpHost_Listen RECV ERROR '&@error)
		;If StringLen($buffer) Then _OtpHost_hlog($buffer & @CRLF)
		Local $cmd, $data
		If _OtpHost_bufsplit($buffer, $cmd, $data) Then
			_OtpHost_OnCommand($cmd, $data, $skIncoming)
			TCPCloseSocket($skIncoming)
			Return 1
		EndIf
		Return 0
	Else
		Return -1
	EndIf
EndFunc   ;==>_OtpHost_Listen
Func _OtpHost_SendCompanion($hOtphost, $cmd, $data="")
	If Not IsArray($hOtphost) Then Return False
	Local $instance=$hOtphost[0]
	Local $port=_OtpHost_GetCompanionPort($instance)

	Local $sk = TCPConnect('127.0.0.1', $port)
	If @error<>0 Then _OtpHost_flog('_OtpHost_SendCompanion CONNECT ERROR '&@error)
	;Local $r = _OtpHost_ccmd($cmd, $data, $sk)


	Local $bSuccess = ($sk >= 0)
	If  $bSuccess Then
		TCPSend($sk, _OtpHost_cmd($cmd, $data))
		Local $err=@error
		If $err<>0 Then _OtpHost_flog('_OtpHost_SendCompanion SEND ERROR '&@error)
		$bSuccess = ($err = 0)
		TCPCloseSocket($sk)
		;_OtpHost_hlog("CMD " & $cmd & " " & $sk & ' ' & $bSuccess)
	EndIf
	Return $bSuccess
EndFunc





Func _OtpHost_bufsplit(ByRef $buffer, ByRef $cmd_out, ByRef $data_out)
	Local $pCmd1 = StringInStr($buffer, '<!')
	If $pCmd1 Then
		$buffer = StringTrimLeft($buffer, $pCmd1 + 1); exclude trim= p-1   char trim=p    match trim=p+1;  trim the command prefix from the string
		Local $pCmd2 = StringInStr($buffer, '!>')
		Local $sCmd = StringLeft($buffer, $pCmd2 - 1);extract command without the prefix.
		$buffer = StringTrimLeft($buffer, $pCmd2 + 1);remove this command from the string.
		Local $aCmd = StringSplit($sCmd & "|", "|")
		$cmd_out = $aCmd[1]
		$data_out = $aCmd[2]
		Return True
	EndIf
	$cmd_out = ""
	$data_out = ""
	Return False
EndFunc   ;==>_OtpHost_bufsplit


Func _OtpHost_cmd($cmd, $data)
	Return '<!' & $cmd & '|' & $data & '!>'
EndFunc   ;==>_OtpHost_cmd

Func _OtpHost_hlog($s)
	$s=StringFormat("%02d:%02d %02d-%02d-%04d %s", @HOUR, @MIN, @MDAY, @MON, @YEAR, $s)
	If StringLen($_OtpHost_OnLogWrite) Then Call($_OtpHost_OnLogWrite,$s)
	ConsoleWrite($s & @CRLF)
EndFunc   ;==>_OtpHost_hlog
Func _OtpHost_flog($s)
	If Not IsDeclared('OTPLOG') Then
		Global $OTPLOG=Int(IniRead('otpbot.ini','config','debuglog','0'))
	EndIf
	_OtpHost_hlog($s)
	If Not $OTPLOG Then Return
	FileWriteLine('otplog.txt',StringFormat("%02d:%02d %02d-%02d-%04d %s %s", @HOUR, @MIN, @MDAY, @MON, @YEAR, @ScriptName, $s) & @CRLF)
EndFunc

