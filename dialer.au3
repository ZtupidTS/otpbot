Global $otp22_sizeMin
Global $otp22_wavemax=20
Global $otp22_timeMax
Global $dialer_checktime

Global $otp22_time = 0
Global $otp22_timeOld = 0
Global $otp22_waves[$otp22_wavemax][2];size,filename
Global $otp22_wavesOld[$otp22_wavemax][2];size,filename

Global $dialer_reportfunc=''



#region ;-----AutoDialer polling

Func otp22_dialler_report()
	otp22_getentries()
	Local $ret = otp22_checknew()
	If StringLen($ret) Then Call($dialer_reportfunc,$ret)
EndFunc   ;==>otp22_dialler

Func otp22_checknew()
	If TimerDiff($otp22_timeOld) > $otp22_timeMax Then Return ""
	Local $sNew = "New Entries: "
	Local $bNew = False
	For $i = 0 To $otp22_wavemax - 1
		If $otp22_waves[$i][0] < $otp22_sizeMin Then ContinueLoop
		If _ArraySearch($otp22_wavesOld, $otp22_waves[$i][1], 0, 0, 0, 0, 1, 1) > -1 Then ContinueLoop
		$bNew = True
		$sNew &= StringFormat("%dkb http://dialer.otp22.com/%s | ", $otp22_waves[$i][0], $otp22_waves[$i][1])
	Next
	If $bNew = False Then Return ""
	ConsoleWrite($sNew & @CRLF)
	Return $sNew
EndFunc   ;==>otp22_checknew


Func otp22_getentries()
	$otp22_timeOld = $otp22_time
	$otp22_time = TimerInit()
	$otp22_wavesOld = $otp22_waves;;;; copy current array so that we can compare later


	Local $text
	Local $aReq = __HTTP_Req('GET', 'http://dialer.otp22.com/')
	__HTTP_Transfer($aReq, $text, 5000)
	If StringLen($text) < 2000 Then Return SetError(1, 0, "")
	$text = StringReplace($text, '&nbsp;', ' ')
	$text = StringReplace($text, ' ', '')
	$text = StringReplace($text, ',', '')
	$text = StringReplace($text, '<br>', @CRLF)


	$entries = _StringBetween($text, "<tt>", "</tt>")
	Local $limit = UBound($entries)
	If $limit > $otp22_wavemax Then $limit = $otp22_wavemax
	For $i = 0 To $limit - 1
		$otp22_waves[$i][0] = Int(StringStripWS(StringLeft($entries[$i], StringInStr($entries[$i], '<a')), 8))
		$otp22_waves[$i][1] = _StringBetweenFirst($entries[$i], 'href="', '"')
	Next
	For $i = $limit To $otp22_wavemax - 1
		$otp22_waves[$i][0] = 0
		$otp22_waves[$i][1] = ""
	Next
EndFunc   ;==>otp22_getentries
Func _StringBetweenFirst(ByRef $sInput, $sFirst, $sLast)
	Local $array = _StringBetween($sInput, $sFirst, $sLast)
	If UBound($array) > 0 Then Return $array[0]
	Return ""
EndFunc   ;==>_StringBetweenFirst

#endregion ;-----AutoDialer polling