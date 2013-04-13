#include "shorturl.au3"

Global $NewsInterval
Global $OTPNEWS
Global $OTPNEWSTIMER
Global $news_url = "http://otp22.referata.com/wiki/Special:Ask/-5B-5BDisplay-20tag::News-20page-20entry-5D-5D/-3FOTP22-20NI-20full-20date/-3FSummary/format%3Dcsv/limit%3D3/sort%3DOTP22-20NI-20full-20date/order%3Ddescending/offset%3D0"




#region ;--------@UPDATE
Func OTP22News_Read()
	Global $OTPNEWS
	Global $OTPNEWSTIMER
	If TimerDiff($OTPNEWSTIMER) > $NewsInterval Or StringLen($OTPNEWS) = 0 Then
		$OTPNEWS = OTP22News_Retrieve()
		$OTPNEWSTIMER = TimerInit()
	EndIf
	Return $OTPNEWS
EndFunc   ;==>OTP22News_Read

Func OTP22News_Retrieve()
	Global $news_url
	;,\x22OTP22 NI full date\x22,\x22OTP22 NI summary\x22\n
	;\x22News#Tue,_12_Feb_2013_07:43:00_+0000\x22,
	;\x2212 February 2013 07:43:00\x22,\x22[[Second Knights of Pythias Cemetery drop]] picked up!\x22\n
	;\x22News#Mon,_11_Feb_2013_01:52:00_+0000\x22,\x2211 February 2013 01:52:00\x22,\x22Multiple new [[Agent_Systems/Investigation/Black_OTP1_messages#Messages_from_11_February|OTP messages]]. Pictures of drop locations, references to [[Zeus]] and a need for new keys.\x22\n
	;\x22News#Thu,_07_Feb_2013_23:17:00_+0000\x22,\x227 February 2013 23:17:00\x22,\x22Two new [[Black_OTP1_messages#Messages_from_7_February|OTP messages]].  Used 99985 to request more time picking up drop.\x22\n
	Local $s = InetRead($news_url, 1)
	$s = BinaryToString($s)
	$s = StringReplace($s, @LF, ',')
	;ConsoleWrite("DLd"&@CRLF)


	;ConsoleWrite($s&@CRLF)
	CSV_PopField($s);Header:Subobject link
	CSV_PopField($s);Header:Date
	CSV_PopField($s);Header:Summary

	Local $out = "Last 3 Updates: "
	For $i = 1 To 3
		Local $page = CSV_PopField($s)
		Local $date = CSV_PopField($s)
		Local $summary = WikiText_Translate(CSV_PopField($s), "http://otp22.referata.com/wiki/")
		$out &= $i & '. ' & $summary & '  '
	Next
	Return $out & ' - Retrieved ' & @MON & '/' & @MDAY & '/' & @YEAR & ' ' & @HOUR & ':' & @MIN
EndFunc   ;==>OTP22News_Retrieve

Func WikiText_Translate($s, $BaseWikiURL = "http://otp22.referata.com/wiki/")
	Local $s2 = ""
	For $i = 1 To StringLen($s)
		Local $c = StringMid($s, $i, 1)
		Switch $c
			Case '['
				Local $iEnd = _MatchBracket($s, $i)
				If @error <> 0 Then ContinueCase
				Local $lenInside = ($iEnd - $i) - 1
				If $lenInside <= 0 Then ContinueCase
				Local $strInside = StringMid($s, $i + 1, $lenInside)
				$s2 &= WikiText_TranslateLink($strInside, $BaseWikiURL)
				$i = $iEnd
			Case Else
				$s2 &= $c
		EndSwitch
	Next
	Return $s2
EndFunc   ;==>WikiText_Translate
Func WikiText_TranslateLink($s, $BaseWikiURL = "http://otp22.referata.com/wiki/")
	Local $url = ""
	Local $text = ""
	If StringLeft($s, 1) == '[' Then;internal links [[pagename]] [[pagename|display text]]
		$s = StringTrimLeft($s, 1)
		$s = StringTrimRight($s, 1)


		Local $iPipe = StringInStr($s, '|')
		If $iPipe Then
			$url = $BaseWikiURL & StringReplace(StringLeft($s, $iPipe - 1), ' ', '_')
			$text = StringTrimLeft($s, $iPipe)
		Else
			$url = $BaseWikiURL & StringReplace($s, ' ', '_')
			$text = $s
		EndIf
	Else;external links [http://....]  [http://... displaytext]
		Local $iSpace = StringInStr($s, ' ')
		If $iSpace Then
			$url = StringLeft($s, $iSpace - 1)
			$text = StringTrimLeft($s, $iSpace)
		Else
			$url = $s
		EndIf
	EndIf
	$url=_ShortUrl_Retrieve($url)
	If StringLen($text) Then Return StringFormat("[%s]( %s )", $text, $url)
	Return $url
EndFunc   ;==>WikiText_TranslateLink



Func CSV_PopField(ByRef $s)
	Local $field = ""
	Local $terminated = False
	Local $quoted = False
	For $i = 1 To StringLen($s)
		Local $c = StringMid($s, $i, 1)
		Switch $c
			Case '"'
				If $quoted And StringMid($s, $i, 2) = '""' Then
					$i += 1
				Else
					$quoted = Not $quoted
				EndIf
				$field &= $c
			Case ','
				If $quoted Then ContinueCase
				$s = StringTrimLeft($s, $i)
				$terminated = True
				ExitLoop
			Case Else
				$field &= $c
		EndSwitch
	Next
	If Not $terminated Then $s = ""


	$field = StringStripWS($field, 1 + 2)
	If StringLeft($field, 1) == '"' Then $field = StringTrimLeft($field, 1)
	If StringRight($field, 1) == '"' Then $field = StringTrimRight($field, 1)
	$field = StringReplace($field, '""', '"')

	Return $field
EndFunc   ;==>CSV_PopField

Func _MatchBracket($Code, $iStart = 1, $iEnd = 0)
	;@extended 	Number of open brackets
	;@error   	0=No error; 1=Unbalanced closing bracket; 2=Unbalanced opening brackets
	;Return   	0=No brackets in specified range; i=Position of Error or Outer bracket match
	If $iEnd < 1 Then $iEnd = StringLen($Code)
	Local $Open = 0
	For $i = $iStart To $iEnd
		Switch StringMid($Code, $i, 1)
			Case '['
				$Open += 1
			Case ']'
				$Open -= 1
				If $Open = 0 Then Return SetError(0, $Open, $i)
				If $Open < 0 Then Return SetError(1, $Open, $i);only possible if there is no opening bracket - this function returns on the outer balance
		EndSwitch
	Next
	If $Open > 0 Then Return SetError(2, $Open, $i)
	Return SetError(0, $Open, 0)
EndFunc   ;==>_MatchBracket


#endregion ;--------@UPDATE