Global $_OtpHost_OnCommand = ""
Global Const $_OtpHost_Port = 12917


Func _OtpHost_CreateListener()
	Local $ret=TCPListen('127.0.0.1', $_OtpHost_Port)
	If @error<>0 Then _OtpHost_flog('_OtpHost_CreateListener LISTEN ERROR '&@error)
	Return $ret
EndFunc   ;==>_OtpHost_CreateListener


Func _OtpHost_OnCommand($cmd, $data, $socket)
	ConsoleWrite("ONCMD: " & $cmd & " " & $socket & @CRLF)
	If StringLen($_OtpHost_OnCommand) Then Call($_OtpHost_OnCommand, $cmd, $data, $socket)
EndFunc   ;==>_OtpHost_OnCommand


Func _OtpHost_PollReply(ByRef $skOutgoing, $ms)
	Local $timer = TimerInit()
	While TimerDiff($timer) < $ms
		Local $r = _OtpHost_GetReply($skOutgoing)
		Local $e = @error
		;_OtpHost_hlog("poll: "&$r&" "&$e)
		If $e <> 0 Then
			;_OtpHost_flog('_OtpHost_PollReply(' &$skOutgoing&',' &$ms&') FAILED '&$e)
			Return SetError($e, 0, 0)
		EndIf
		If $r > 1 Then Return SetError(0, 0, $r)
		Sleep(50)
	WEnd
	_OtpHost_flog('_OtpHost_PollReply(' &$skOutgoing&',' &$ms&') TIMEOUT ')
	Return SetError(0xDEAD, 0xBEEF, 0)
EndFunc   ;==>_OtpHost_PollReply

Func _OtpHost_GetReply(ByRef $skOutgoing)
	Local Static $buffer = ""
	If $skOutgoing >= 0 Then
		$buffer &= TCPRecv($skOutgoing, 1000)
		Local $error=@error
		If StringLen($buffer) Then ConsoleWrite($buffer & @CRLF)
		Local $cmd, $data
		If _OtpHost_bufsplit($buffer, $cmd, $data) Then
			_OtpHost_OnCommand($cmd, $data, $skOutgoing)
			$buffer = ""
			Return SetError(0, 0, 1)
		EndIf
		If $error <> 0 Then
			;_OtpHost_flog('_OtpHost_GetReply('&$skOutgoing&') RECV ERROR '&$error)
			;$skOutgoing=-1
			Return SetError(1, 0, 0)
		EndIf
		Return SetError(0, 0, 0)
	EndIf
	Return SetError(2, 0, 0)
EndFunc   ;==>_OtpHost_GetReply


Func _OtpHost_Listen($skListener, $closeSocket = True)
	Local Static $skIncoming = -1
	Local Static $buffer = ""
	If $skIncoming >= 0 Then
		$buffer &= TCPRecv($skIncoming, 1000)
		If @error<>0 Then _OtpHost_flog('_OtpHost_Listen RECV ERROR '&@error)
		If StringLen($buffer) Then ConsoleWrite($buffer & @CRLF)
		Local $cmd, $data
		If _OtpHost_bufsplit($buffer, $cmd, $data) Then
			_OtpHost_OnCommand($cmd, $data, $skIncoming)
			If $closeSocket Then TCPCloseSocket($skIncoming)
			$skIncoming = -1
			$buffer = ""
			Return 1
		EndIf
		Return 0
	Else
		$skIncoming = TCPAccept($skListener)
		$buffer = ""
		If $skIncoming >= 0 Then _OtpHost_hlog("Host Conn: " & $skIncoming)
		Return -1
	EndIf
EndFunc   ;==>_OtpHost_Listen



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


Func _OtpHost_scmd($cmd, $data, $closeSocket = True)
	;_OtpHost_flog('_OtpHost_scmd('&$cmd&', '&$data&', '&$closeSocket&') ')
	Local $sk = TCPConnect('127.0.0.1', 12917)
	If @error<>0 Then _OtpHost_flog('_OtpHost_scmd CONNECT ERROR '&@error)
	Local $r = _OtpHost_ccmd($cmd, $data, $sk)
	If $closeSocket Then
		TCPCloseSocket($sk)
		$sk = -1
	EndIf
	Return SetError(0, $sk, $r)
EndFunc   ;==>_OtpHost_scmd
Func _OtpHost_ccmd($cmd, $data, $sk)
	Local $bSuccess = ($sk >= 0)
	If $sk >= 0 Then
		TCPSend($sk, _OtpHost_cmd($cmd, $data))
		Local $err=@error
		If $err<>0 Then _OtpHost_flog('_OtpHost_ccmd SEND ERROR '&@error)
		$bSuccess = ($err = 0)
	EndIf
	_OtpHost_hlog("CMD " & $cmd & " " & $sk & ' ' & $bSuccess)
	Return $bSuccess
EndFunc   ;==>_OtpHost_ccmd


Func _OtpHost_cmd($cmd, $data)
	Return '<!' & $cmd & '|' & $data & '!>'
EndFunc   ;==>_OtpHost_cmd

Func _OtpHost_hlog($s)
	ConsoleWrite(StringFormat("%02d:%02d %02d-%02d-%04d %s", @HOUR, @MIN, @MDAY, @MON, @YEAR, $s) & @CRLF)
EndFunc   ;==>_OtpHost_hlog
Func _OtpHost_flog($s)
	If Not IsDeclared('OTPLOG') Then
		Global $OTPLOG=Int(IniRead('otpbot.ini','config','debuglog','0'))
	EndIf
	If Not $OTPLOG Then Return
	FileWriteLine('otplog.txt',StringFormat("%02d:%02d %02d-%02d-%04d %s %s", @HOUR, @MIN, @MDAY, @MON, @YEAR, @ScriptName, $s) & @CRLF)
EndFunc

