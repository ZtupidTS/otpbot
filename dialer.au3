
#include <Array.au3>
#include "shorturl.au3"
;#include "GeneralCommands.au3"
#include "userinfo.au3"

; Note to reviewers: this only lists information from a website hosting recordings.
Local $_Dial_Commands[3][3]=[ _
["dial","<agentcode> [line]","Posts an agent number (DTMF extension) request to the OTP22 auto-dialer. (NOTE: %!%CALL will place a call without an agent code). Completely numeric agent codes will have `#` automatically appended to them. Use the line parameter to specify which number to dial by keyword. (See %!%LINES for a list) Note: Uses your account saved dialer password. (see %!%OPTION GET DIALERPASS )"], _
["call","<line>","Posts a call request to the OTP22 auto-dialer. No agent number is used for this call. Use the line parameter to specify which number to dial by keyword. (See %!%LINES for a list.  Use %!%DIAL to input an agent code/DTMF extension) Note: Uses your account saved dialer password. (see %!%OPTION GET DIALERPASS )"], _
["lines","","Lists the valid phone line keywords for use with the %!%DIAL and %!%CALL commands."]   ]

_UserInfo_Option_Add('dialerpass','Password to use for the OTP22 AutoDialer, This is automatically used when you use the %!%DIAL <agentnumber> or %!%CALL <line> commands.',True)


Global $dialer_enable = 1

Global $otp22_sizeMin
Global $otp22_wavemax = 20
Global $otp22_timeMax
Global $dialer_checktime

Global $otp22_time = 0
Global $otp22_timeOld = 0
Global $otp22_waves[$otp22_wavemax][2];size,filename
Global $otp22_wavesOld[$otp22_wavemax][2];size,filename
Global $otp22_downloadMax=50000

Global $dialer_reportfunc = ''

Global $dial_event = ''


Global $dialer_numbers[8]=[ _
"+1 202-999-3335", _
"+1 303-309-0004", _
"+1 709-700-0122", _
"+48 22-307-1061", _
"+1 888-854-2402", _
"+1 202-204-2303", _
"+1 202-999-3337", _
"+1 720-897-0004"  ]

Global $dialer_keywords[8]=[ _
"202|WA|agent|agent system|Washington|two|3335", _
"303|AS|AS36|CO|Colorado|three|0004", _
"709|CA|NF|0122", _
"48|Poland|concern|1061", _
"888|FL|MOD|FLL|material desk|material order desk|2402", _
"*202|MD|message desk|204|2303", _
"*202|Controller|Control|Melter|ctrl|3337", _
"720|AS27|Announcement"]

Global $dialer_defaultline_0b=1
;Global $dialer_defaultline_1b=$dialer_defaultline_0b+1




Func dialer_getShortName($i)
	Local $kws=StringSplit($dialer_keywords[$i],"|")
	Return StringReplace($kws[1]&'/'&$kws[2],'*','')
EndFunc
Func dialer_getIndexFromKeyword($kw)
	For $i=0 To UBound($dialer_keywords)-1
		Local $kws=StringSplit($dialer_keywords[$i],"|")
		For $j=1 To UBound($kws)-1
			If StringLeft($kws[$j],1)="*" Then $kws[$j]=StringTrimLeft($kws[$j],1)
			If $kw=$kws[$j] Then Return $i
		Next
	Next
	Return SetError(1,0,-1)
EndFunc
Func dialer_getIndexFromNumber($num)
	$num=StringRegexpReplace($num,"\D","")
	For $i=0 To UBound($dialer_numbers)-1
		Local $sNum=$dialer_numbers[$i]
		Local $aNum=StringSplit($sNum,' ')
		Local $sNum1=StringRegexpReplace($sNum,"\D",""); just digits
		Local $sNum2=StringRegexpReplace($aNum[2],"\D","");just the end digits.
		; possibly get the last four digits also?
		If $num=$sNum1 Or $num=$sNum2 Then Return $i
	Next
	Return SetError(1,0,-1)
EndFunc
Func dialer_getIndexFromInput($in)
	If $in="" Then Return $dialer_defaultline_0b
	Local $i=dialer_getIndexFromNumber($in)
	If $i=-1 Then $i=dialer_getIndexFromKeyword($in)
	If $i=-1 Then Return SetError(1,0,-1)
	Return $i
EndFunc


Func COMMAND_lines()
	Local $out=""
	For $i=0 To UBound($dialer_keywords)-1
		Local $sNum=$dialer_numbers[$i]
		Local $kws=StringSplit($dialer_keywords[$i],"|")
		If $i>0 Then $out&=@LF
		$out&=$sNum&" (keywords: "
		For $j=1 To UBound($kws)-1
			If Not (StringLeft($kws[$j],1)="*") Then
				If $j>1 Then $out&=", "
				$out&=$kws[$j]
			EndIf
		Next
		$out&=")"
	Next
	Return $out
EndFunc


;Func COMMAND_dial($agent, $number=1)
Func COMMANDX_call($who, $where, $what, $acmd)
	If Not $dialer_enable Then Return "Error: dialer support not enabled"
	Local $sInLine=__element($acmd,2)
	Local $iLine=dialer_getIndexFromInput($sInLine)
	If $iLine=-1 Then Return "call: unknown line to call. Try using a keyword listed in %!%LINES"
	Local $number=$iLine+1; shifted for form input values.


	dialer_userdial($who,$number,'')
	Switch @error
		Case 0;userdial success
			Return "Queued Call "&dialer_getShortName($iLine)&" ("&$dialer_numbers[$iLine]&")."
		Case 1;userdial not recognized
			Return "You must be logged in to NickServ to use this command. If you think you are logged in, you might try the IDENTIFY command to refresh your information."
		Case 2;userdial password option not set
			Return "You have not set a dialer password for your account. To do this, Open a Private Message to the bot and use the command %!%OPTION SET DIALERPASS <password> (without brackets).  DO NOT use the password in the chatroom.  Setting your this password lets you use the command easily while you are logged in without exposing sensitive information."
		Case 3;dial rejected
			Return "Your request was rejected by the server."
		Case 4;dial failed
			Return "There was an error submitting your request."
	EndSwitch
EndFunc
Func COMMANDX_dial($who, $where, $what, $acmd)
	If Not $dialer_enable Then Return "Error: dialer support not enabled"
	Local $agent=__element($acmd,2)
	If $agent="" Then Return "dial: not eneough parameters.  Usage: %!%DIAL <agentnumber> [line]"
	Local $sInLine=__element($acmd,3)
	Local $iLine=dialer_getIndexFromInput($sInLine)
	If $iLine=-1 Then Return "dial: unknown line to call. Try using a keyword listed in %!%LINES"
	Local $number=$iLine+1; shifted for form input values.



	Local $sAcct=_UserInfo_Whois($who)
	Local $iAcct=@extended
	Local $isRecognized=(@error=0)
	If Not $isRecognized Then Return "You must be logged in to NickServ to use this command. If you think you are logged in, you might try the IDENTIFY command to refresh your information."
	Local $pass=_UserInfo_GetOptValue($iAcct, 'dialerpass')
	If $pass="" Then Return "You have not set a dialer password for your account. To do this, Open a Private Message to the bot and use the command %!%OPTION SET DIALERPASS <password> (without brackets).  DO NOT use the password in the chatroom.  Setting your this password lets you use the command easily while you are logged in without exposing sensitive information."




	If StringRegexp($agent,"^[0-9ABCD]+$") Then $agent&='#'

	;element_2=1&element_1=18004%23&element_3=melter3&form_id=486303&submit=Submit
	;element_2 == 1(+1 202-999-3335) 2(+1 303-309-0004) 3(+1 709-700-0122) 4(+48 22-307-1061)
	dialer_userdial($who,$number,$agent)
	Switch @error
		Case 0;userdial success
			If StringLen($dial_event) Then Call($dial_event,$who,$where,$what)
			Return "Queued Code "&$agent&" on line "&dialer_getShortName($iLine)&" ("&$dialer_numbers[$iLine]&")."
		Case 1;userdial not recognized
			Return "You must be logged in to NickServ to use this command. If you think you are logged in, you might try the IDENTIFY command to refresh your information."
		Case 2;userdial password option not set
			Return "You have not set a dialer password for your account. To do this, Open a Private Message to the bot and use the command %!%OPTION SET DIALERPASS <password> (without brackets).  DO NOT use the password in the chatroom.  Setting your this password lets you use the command easily while you are logged in without exposing sensitive information."
		Case 3;dial rejected
			Return "Your request was rejected by the server."
		Case 4;dial failed
			Return "There was an error submitting your request."
	EndSwitch
EndFunc

Func dialer_userdial($who,$line=2,$agent="")
	Local $sAcct=_UserInfo_Whois($who)
	Local $iAcct=@extended
	Local $isRecognized=(@error=0)
	If Not $isRecognized Then Return SetError(1,0,0)
	Local $pass=_UserInfo_GetOptValue($iAcct, 'dialerpass')
	If $pass="" Then Return SetError(2,0,0)

	Local $ret=dialer_dial($line,$agent,$pass)
	Local $err=@error
	Local $ext=@extended
	If $err<>0 Then $err+=2
	Return SetError($err,$ext,$ret)
EndFunc

Func dialer_dial($line=2,$agent="",$pass="")
	;element_2=1&element_1=18004%23&element_3=melter3&form_id=486303&submit=Submit
	;element_2 == 1(+1 202-999-3335) 2(+1 303-309-0004) 3(+1 709-700-0122) 4(+48 22-307-1061)
	Local $headers='Referer: http://dialer.otp22.com/live/'&@CRLF&'Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text=''
	Local $aReq=__HTTP_Req('POST','http://dialer.otp22.com/live/call.php', StringFormat("element_2=%s&element_1=%s&element_3=%s&form_id=486303&submit=Submit",_URIEncode($line),_URIEncode($agent),_URIEncode($pass)),$headers)
	__HTTP_Transfer($aReq,$text,5000)
	$text=StringReplace($text,Chr(0),'')
	If StringInStr($text,'Invalid Password') Then Return SetError(1,0,0)
	If StringLen($text)=0 Then Return SetError(2,0,0)
	Return SetError(0,$agent,$line)
EndFunc





#region ;-----AutoDialer polling

Func otp22_dialler_report()
	If Not $dialer_enable Then Return
	otp22_getentries()
	Local $ret = otp22_checknew()
	If StringLen($ret) Then Call($dialer_reportfunc, $ret)
EndFunc   ;==>otp22_dialler_report

Func otp22_checknew()
	If Not $dialer_enable Then Return ""
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
		Local $phone=$auri[2];202, 709, 303
		Local $agent=$auri[3]

		Local $iLine=dialer_getIndexFromNumber($phone)
		If $iLine>-1 Then $phone=dialer_getShortName($iLine)


		$sNew &= StringFormat("%dkb (%s on %s) %s"&@LF, $otp22_waves[$i][0], $agent,$phone, _ShortUrl_Retrieve($url,0)); 0->do not cache shorturl
	Next
	If $bNew = False Then Return ""
	;ConsoleWrite($sNew & @CRLF)
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


	$entries = _StringBetween($text, "<tt>", "</tt>" ,$STR_ENDNOTSTART)
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
	Local $array = _StringBetween($sInput, $sFirst, $sLast,$STR_ENDNOTSTART )
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