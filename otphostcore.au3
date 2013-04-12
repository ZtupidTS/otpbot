Global $_OtpHost_OnCommand = ""
Global Const $_OtpHost_Port = 12917


Func _OtpHost_CreateListener()
	Return TCPListen('127.0.0.1', $_OtpHost_Port)
EndFunc   ;==>_OtpHost_CreateListener


Func _OtpHost_OnCommand($cmd, $data, $socket)
	ConsoleWrite("ONCMD: "&$cmd&" "&$socket&@CRLF)
	If StringLen($_OtpHost_OnCommand) Then Call($_OtpHost_OnCommand, $cmd, $data, $socket)
EndFunc   ;==>_OtpHost_OnCommand


Func _OtpHost_PollReply($skOutgoing, $ms)
	Local $timer = TimerInit()
	While TimerDiff($timer) < $ms
		Local $r = _OtpHost_GetReply($skOutgoing)
		Local $e = @error
		;_OtpHost_hlog("poll: "&$r&" "&$e)
		If $e <> 0 Then Return SetError($e, 0, 0)
		If $r > 1 Then Return SetError(0, 0, $r)
		Sleep(50)
	WEnd
	Return SetError(0xDEAD, 0xBEEF, 0)
EndFunc   ;==>_OtpHost_PollReply

Func _OtpHost_GetReply($skOutgoing)
	Local Static $buffer = ""
	If $skOutgoing >= 0 Then
		$buffer &= TCPRecv($skOutgoing, 1000)
		If @error <> 0 Then Return SetError(1, 0, 0)
		If StringLen($buffer) Then ConsoleWrite($buffer & @CRLF)
		Local $cmd, $data
		If _OtpHost_bufsplit($buffer, $cmd, $data) Then
			_OtpHost_OnCommand($cmd, $data, $skOutgoing)
			$buffer = ""
			Return SetError(0, 0, 1)
		EndIf
		Return SetError(0, 0, 0)
	EndIf
	Return SetError(2, 0, 0)
EndFunc   ;==>_OtpHost_GetReply


Func _OtpHost_Listen($skListener,$closeSocket=True)
	Local Static $skIncoming = -1
	Local Static $buffer = ""
	If $skIncoming >= 0 Then
		$buffer &= TCPRecv($skIncoming, 1000)
		If StringLen($buffer) Then ConsoleWrite($buffer & @CRLF)
		Local $cmd, $data
		If _OtpHost_bufsplit($buffer, $cmd, $data) Then
			_OtpHost_OnCommand($cmd, $data,$skIncoming)
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


Func _OtpHost_scmd($cmd, $data,$closeSocket=True)
	Local $sk = TCPConnect('127.0.0.1', 12917)
	Local $r=_OtpHost_ccmd($cmd, $data, $sk)
	If $closeSocket Then
		TCPCloseSocket($sk)
		$sk=-1
	EndIf
	Return SetError(0,$sk,$r)
EndFunc   ;==>_OtpHost_scmd
Func _OtpHost_ccmd($cmd, $data, $sk)
	Local $bSuccess = ($sk >= 0)
	If $sk >= 0 Then
		TCPSend($sk, _OtpHost_cmd($cmd, $data))
		$bSuccess = (@error = 0)
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