
#include <Array.au3>
#include "shorturl.au3"
#include "GeneralCommands.au3"
#include "userinfo.au3"

; Note to reviewers: this only lists information from a website hosting recordings.
_Help_RegisterGroup("Dialer")
_Help_RegisterCommand("dial","<agentcode>","Posts a dial request to the OTP22 auto-dialer. Completely numeric agent codes will have `#` automatically appended to them. Note: Uses your account saved dialer password. (see %!%OPTION GET DIALERPASS )")

_UserInfo_Option_Add('dialerpass','Password to use for the OTP22 AutoDialer, This is automatically used when you use the %!%DIAL <agentnumber> command.',True)




Global $otp22_sizeMin
Global $otp22_wavemax = 20
Global $otp22_timeMax
Global $dialer_checktime

Global $otp22_time = 0
Global $otp22_timeOld = 0
Global $otp22_waves[$otp22_wavemax][2];size,filename
Global $otp22_wavesOld[$otp22_wavemax][2];size,filename
Global $otp22_downloadMax=20000

Global $dialer_reportfunc = ''



;Func COMMAND_dial($agent, $number=1)
Func COMMANDX_dial($who, $where, $what, $acmd)
	Local $agent=__element($acmd,2)
	If $agent="" Then Return "dial: not eneough parameters.  Usage: %!%DIAL <agentnumber>"
	Local $number=__element($acmd,3)
	If $number="" Then $number=1

	Local $sAcct=_UserInfo_Whois($who)
	Local $iAcct=@extended
	Local $isRecognized=(@error=0)
	If Not $isRecognized Then Return "You must be logged in to NickServ to use this command. If you think you are logged in, you might try the IDENTIFY command to refresh your information."
	Local $pass=_UserInfo_GetOptValue($iAcct, 'dialerpass')
	If $pass="" Then Return "You have not set a dialer password for your account. To do this, Open a Private Message to the bot and use the command OPTION SET DIALERPASS <password> (without brackets).  DO NOT use the password in the chatroom.  Setting your this password lets you use the command easily while you are logged in without exposing sensitive information."



	Local $headers='Referer: http://dialer.otp22.com/live/'&@CRLF&'Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text='error'

	If StringRegexp($agent,"^[0-9ABCD]+$") Then $agent&='#'

	;element_2=1&element_1=18004%23&element_3=melter3&form_id=486303&submit=Submit
	;element_2 == 1(+1 202-999-3335) 2(+1 303-309-0004) 3(+1 709-700-0122) 4(+48 22-307-1061)
	Local $aReq=__HTTP_Req('POST','http://dialer.otp22.com/live/call.php', StringFormat("element_2=%s&element_1=%s&element_3=%s&form_id=486303&submit=Submit",_URIEncode($number),_URIEncode($agent),_URIEncode($pass)),$headers)
	__HTTP_Transfer($aReq,$text,5000)
	$text=StringReplace($text,Chr(0),'')
	If StringLen($text)=0 Then Return "Error Submitting"
	Return "Queued Request for "&$agent&" with your password."
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
		If StringLen($otp22_waves[$i][1])<1 Then ContinueLoop
		If _ArraySearch($otp22_wavesOld, $otp22_waves[$i][1], 0, 0, 0, 0, 1, 1) > -1 Then ContinueLoop;;;
		$bNew = True
		Local $url=StringFormat("http://dialer.otp22.com/"&@YEAR&"-"&@MON&".dir/%s", $otp22_waves[$i][1])
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
	Local $aReq = __HTTP_Req('GET', 'http://dialer.otp22.com/'&@YEAR&"-"&@MON&".dir/")
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
		Local $p=StringInStr($entries[$i],"</a>")
		If $p>0 Then $entries[$i]=StringMid($entries[$i],1,$p+3)


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