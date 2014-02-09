#include-once
Global Enum $_INETREAD_BUILTIN=0, $_INETREAD_MANUAL,$_INETREAD_MODES
Global $_INETREAD_MODE=$_INETREAD_MANUAL
Global $_HTTP_Event_Debug=''
;TCPStartup()



Func _InetRead($url,$opt=0)
	Local $ts=TimerInit()
	Local $ret,$err,$ext
	Switch $_INETREAD_MODE
		Case $_INETREAD_BUILTIN
			$ret=InetRead($url,$opt)
			$err=@error
			$ext=@extended
		Case $_INETREAD_MANUAL
			$ret=_InetRead_Manual($url,$opt)
			$err=@error
			$ext=@extended
	EndSwitch
	If TimerDiff($ts)>11000 And StringLen($_HTTP_Event_Debug) Then
		Call($_HTTP_Event_Debug,"HTTP: Took more than 10s to load url="&$url&" opt="&$opt&" inetreadmode="&$_INETREAD_MODE)
		$_INETREAD_MODE=Mod($_INETREAD_MODE+1,$_INETREAD_MODES)
	EndIf
	Return SetError($err,$ext,$ret)
EndFunc


Func _InetRead_Manual($url,$opt=0)
	Local $sRecv_Out=''
	Local $req=__HTTP_Req('GET', $url)
	__HTTP_Transfer($req, $sRecv_Out,10000);10s max
	If StringLen($sRecv_Out)=0 Then Return SetError(1,0,'')

	Local $iPos=StringInStr($sRecv_Out,@LF&@LF)+2
	If $iPos<=2 Then $iPos=StringInStr($sRecv_Out,@CRLF&@CRLF)+4
	If $iPos>4 Then
		$sRecv_Out=StringMid($sRecv_Out,$iPos)
	Else
		$sRecv_Out=""
	EndIf


	Return StringToBinary($sRecv_Out)
EndFunc

Func __HTTP_Req($Method = 'GET', $url = 'http://example.com/', $Content = '', $extraHeaders = '')
	Local $aRet[4]
	$url = StringTrimLeft($url, StringInStr($url, '://') + 2)
	Local $pos = StringInStr($url, '/')
	Local $HOST = StringLeft($url, $pos - 1)

	Local $PORT = 80
	Local $pColon = StringInStr($HOST, ':')
	If $pColon > 0 Then
		$PORT = StringMid($HOST, $pColon + 1)
		$HOST = StringLeft($HOST, $pColon - 1)
	EndIf

	$url = StringMid($url, $pos)
	Local $HTTPRequest = $Method & ' ' & $url & ' HTTP/1.0' & @CRLF & _
			'Accept-Language: en' & @CRLF & _
			'Accept: */*' & @CRLF & _
			'Host: ' & $HOST & @CRLF & _
			'Cache-Control: no-cache' & @CRLF & _
			'User-Agent: Mozilla/1.0' & @CRLF & _
			'Connection: close' & @CRLF & _
			'Accept-Encoding: ' & @CRLF & _
			'Accept-Language: en' & @CRLF
	If StringLen($extraHeaders) > 0 Then $HTTPRequest &= $extraHeaders
	If StringLen($Content) > 0 Then
		$HTTPRequest &= 'Content-Length: ' & StringLen($Content) & @CRLF
		$HTTPRequest &= @CRLF & $Content;&@CRLF
	Else
		$HTTPRequest &= @CRLF
	EndIf
	$aRet[0] = $HOST
	$aRet[1] = $url; now a URI
	$aRet[2] = $HTTPRequest
	$aRet[3] = $PORT
	Return $aRet
EndFunc   ;==>__HTTP_Req
Func __HTTP_Transfer(ByRef $aReq, ByRef $sRecv_Out, $limit = 0, $timeout=0)
	;ConsoleWrite($aReq[2]&@CRLF)
	Local $error = 0
	Local $SOCK = TCPConnect(TCPNameToIP($aReq[0]), $aReq[3])
	;ConsoleWrite('HTTPSock: '&$aReq[0]&'//'&$aReq[3]&'//'&$sock&'//'&@error&@CRLF)
	TCPSend($SOCK, $aReq[2])
	$sRecv_Out = ""
	Local $ts=TimerInit()
	While $SOCK <> -1
		Local $recv = TCPRecv($SOCK, 10000, 1)
		If @error <> 0 Then $error = @error
		If $timeout > 0 And TimerDiff($ts)>$timeout Then $error=0xB33F
		If $limit > 0 And StringLen($sRecv_Out) > $limit Then $error = 0xBEEF
		If IsBinary($recv) Then $recv = BinaryToString($recv)
		$sRecv_Out &= $recv
		If $error <> 0 Then
			TCPCloseSocket($SOCK)
			$SOCK = -1
			ExitLoop
		EndIf
		;Sleep(50)
	WEnd
	;ConsoleWrite('HTTPSockError: '&$error&@CRLF)
EndFunc   ;==>__HTTP_Transfer



; Thanks Progandy
Func _URIEncode($sData)
	; Prog@ndy
	Local $aData = StringSplit(BinaryToString(StringToBinary($sData, 4), 1), "")
	Local $nChar
	$sData = ""
	For $i = 1 To $aData[0]
		$nChar = Asc($aData[$i])
		Switch $nChar
			Case 45, 46, 48 To 57, 65 To 90, 95, 97 To 122, 126
				$sData &= $aData[$i]
			Case 32
				$sData &= "+"
			Case Else
				$sData &= "%" & Hex($nChar, 2)
		EndSwitch
	Next
	Return $sData
EndFunc   ;==>_URIEncode
