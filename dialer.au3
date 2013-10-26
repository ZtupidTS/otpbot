
#include <Array.au3>
#include "shorturl.au3"

; Note to reviewers: this only lists information from a website hosting recordings.


Global $otp22_sizeMin
Global $otp22_wavemax = 20
Global $otp22_timeMax
Global $dialer_checktime

Global $otp22_time = 0
Global $otp22_timeOld = 0
Global $otp22_waves[$otp22_wavemax][2];size,filename
Global $otp22_wavesOld[$otp22_wavemax][2];size,filename
Global $otp22_downloadMax=5000

Global $dialer_reportfunc = ''


Func COMMAND_dial($agent, $pass, $number=1)
	Local $headers='Referer: http://dialer.otp22.com/live/'&@CRLF&'Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text='error'

	If StringRegexp($agent,"^[0-9ABCD]+$") Then $agent&='#'

	;element_2=1&element_1=18004%23&element_3=melter3&form_id=486303&submit=Submit
	;element_2 == 1(+1 202-999-3335) 2(+1 303-309-0004) 3(+1 709-700-0122) 4(+48 22-307-1061)
	Local $aReq=__HTTP_Req('POST','http://dialer.otp22.com/live/call.php', StringFormat("element_2=%s&element_1=%s&element_3=%s&form_id=486303&submit=Submit",_URIEncode($number),_URIEncode($agent),_URIEncode($pass)),$headers)
	__HTTP_Transfer($aReq,$text,5000)
	$text=StringReplace($text,Chr(0),'')
	If StringLen($text)=0 Then Return "Error Submitting"
	Return "Queued "&$agent
EndFunc





#region ;-----AutoDialer polling

Func otp22_dialler_report()
	otp22_getentries()
	Local $ret = otp22_checknew()
	If StringLen($ret) Then Call($dialer_reportfunc, $ret)
EndFunc   ;==>otp22_dialler_report

Func otp22_checknew()
	If TimerDiff($otp22_timeOld) > $otp22_timeMax Then Return "";;;
	Local $sNew = "New Entries: "
	Local $bNew = False
	For $i = 0 To $otp22_wavemax - 1
		If ($otp22_sizeMin>0) And ($otp22_waves[$i][0] < $otp22_sizeMin) Then ContinueLoop
		If _ArraySearch($otp22_wavesOld, $otp22_waves[$i][1], 0, 0, 0, 0, 1, 1) > -1 Then ContinueLoop;;;
		$bNew = True
		Local $url=StringFormat("http://dialer.otp22.com/%s", $otp22_waves[$i][1])
		Local $uri=__URIDecode($otp22_waves[$i][1])
		$uri=StringReplace($uri,'.wav','')
		Local $auri=StringSplit($uri&' - ? - ?',' - ',1)
		;_ArrayDisplay($auri)

		Local $time=$auri[1]
		Local $phone=StringLeft($auri[2],3);202, 709, 303
		Local $agent=$auri[3]

		$sNew &= StringFormat("%dkb (%s on %s) %s | ", $otp22_waves[$i][0], $agent,$phone, _ShortUrl_Retrieve($url,0)); 0->do not cache shorturl
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
	__HTTP_Transfer($aReq, $text, $otp22_downloadMax)
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


Func __URIDecode($s)
	Local $o=''
	For $i=1 To StringLen($s)
		Local $c=StringMid($s,$i,1)
		If $c="%" Then
			Local $sH=StringMid($s,$i+1,1)&StringMid($s,$i+2,1)
			If StringRegExp($sH,"^[0-9abcdefABCDEF]+$") Then
				$o&=Chr(Dec($sH))
				;%20_
				;+012
				$i+=2
			Else
				$o&=$c
			EndIf
		Else
			$o&=$c
		EndIf
	Next
	Return $o
EndFunc

#endregion ;-----AutoDialer polling