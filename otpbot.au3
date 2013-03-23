#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=bot.ico
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Description=OTP22 Utility Bot
#AutoIt3Wrapper_Res_Fileversion=4.2.0.11
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_LegalCopyright=Crash_demons
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <Array.au3>
#include <String.au3>
#include <Process.au3>
#include <UTM.au3>
TCPStartup()


#region ;------------CONFIG
Global $TestMode=0
Global $SERV = Get("server", "irc.freenode.net", "config")
Global $PORT = Get("port", 6667, "config")
Global $CHANNEL = Get("channel", "#ARG", "config");persistant channel, will rejoin. can be invited to others (not persistant)
Global $NICK = Get("nick", "OTPBot22", "config")
Global $PASS = Get("password", "", "config"); If not blank, sends password both as server command and Nickserv identify; not tested though.
Global $USERNAME = Get("username", $NICK, "config");meh

Global $ReconnectTime = Get("reconnecttime", 5 * 60 * 1000, "config")
Global $VersionInfoExt = Get("versioncomment", "", "config")
Global $QuitText = Get("quitmessage", "EOM", "config")
Global $CommandChar = StringLeft(Get("commandchar", "@", "config"), 1); Command character prefix - limit to 1 char

Global $AutoDecoderKeyfile = Get("defaultkey", "elpaso.bin")
Global $NewsInterval = Get("newsinterval", 15 * 60 * 1000); 15 minutes = 900000ms
Global $otp22_sizeMin = Get("dialersizemin", 1);300;kb
Global $otp22_wavemax = Get("dialercomparemax", 20)
Global $otp22_timeMax = Get("dialercomparetime", 5 * 60 * 1000);5 minutes
Global $dialer_checktime = Get("dialerchecktime", 2 * 60 * 1000);5 minutes

Global $news_url=Get("newsurl","http://otp22.referata.com/wiki/Special:Ask/-5B-5BDisplay-20tag::News-20page-20entry-5D-5D/-3FOTP22-20NI-20full-20date/-3FSummary/format%3Dcsv/limit%3D3/sort%3DOTP22-20NI-20full-20date/order%3Ddescending/offset%3D0")


#endregion ;------------CONFIG

#region ;------------------INTERNAL VARIABLES
Global Enum $S_UNK = -1, $S_OFF, $S_INIT, $S_ON, $S_CHAT, $S_INVD
Global Const $PARAM_START = 2

Global Const $VERSION = "4.2"; if you modify the bot, please note so here with "modified" etc


Global $HOSTNAME = "xxxxxxxxxxxxxxxxxxx";in-IRC hostname. effects message length - becomes set later
Global $ADDR = ''
Global $SOCK = -1
Global $BUFF = ""
Global $STATE = $S_OFF

Global $otp22_time = 0
Global $otp22_timeOld = 0
Global $otp22_waves[$otp22_wavemax][2];size,filename
Global $otp22_wavesOld[$otp22_wavemax][2];size,filename

#endregion ;------------------INTERNAL VARIABLES


#region ;------------------BOT MAIN
FileChangeDir(@ScriptDir)
AdlibRegister("otp22_dialler", $dialer_checktime)
OnAutoItExitRegister("Quit")
$ADDR = TCPNameToIP($SERV)
Msg('START')
Open()
If $STATE < $S_INIT Then Msg('FAIL')



While 1
	Read()
	Process()
	Sleep(50)
	If $STATE < $S_INIT Then
		If TCheck($ReconnectTime) Then Open()
	EndIf
WEnd
Exit;this loop never ends, so we don't need this.


Func Process_Message($who, $where, $what); called by Process() which parses IRC commands; if you return a string, Process() will form a reply.
	Global $PM_Overflow
	Local $isPM = ($where = $NICK)
	Local $isChannel = (StringLeft($where, 1) = '#')
	Local $isCommand = (StringLeft($what, 1) = $CommandChar)

	If Not $isCommand Then;automatic responses to non-commands
		If StringInStr($what, "pastebin", 2) Then Return pastebindecode($what, $AutoDecoderKeyfile)
		If $what="any news?" Then
			Reply_Message($who, $who, OTP22News_Read())
			Return ''
		EndIf
	Else;command processing
		Local $params = StringSplit($what, ' ')
		Local $paramn = UBound($params) - 2; [0]=count [1]=~command [2]=param1,  ubound=3;  ubound-2=1
		Local $pfx = $what
		If (UBound($params) - 1) >= 1 Then $pfx = $params[1]
		$pfx = StringTrimLeft($pfx, 1); trim off the @ or whatever

		Switch $pfx
			Case 'help'
				Return 'Commands are: update updatechan more help version debug | ' & _
						'Pastebin Decoder commands: bluehill elpaso littlemissouri | ' & _
						'Coordinates: UTM LL | NATO Decoding: 5GramFind 5Gram WORM | Other: ITA2 ITA2S lengthstobits flipbits ztime'
			Case 'version'
				Return "OTPBOT v" & $VERSION & " by Crash_Demons | " & $VersionInfoExt
			Case 'more'
				Return $PM_Overflow
			Case 'updatechan', 'update_chan'
				Return OTP22News_Read()
			Case 'update'
				Reply_Message($who, $who, OTP22News_Read());redirect reply to PM
				Return '';disable any automatic reply
			Case 'debug'
				Return StringFormat("DBG: WHO=%s WHERE=%s WHAT=%s Compiled=%s data.bin=%s elpaso.bin=%s littlemissouri=%s p1.txt=%s p2.txt=%s p3.txt=%s p4.txt=%s", $who, $where, $what, @Compiled, _
    				FileGetSize('data.bin'), FileGetSize('elpaso.bin'), FileGetSize('littlemissouri.bin'), _
					FileGetSize('p1.txt'), FileGetSize('p2.txt'), FileGetSize('p3.txt'), FileGetSize('p4.txt'))


				;commands that aren't servicable.
			Case "admins"
				Return "This bot has no admin-servicable features."
			Case "newupdate", "new_update"
				Return "Updates cannot be set from the bot. Please edit this page: http://otp22.referata.com/wiki/News"
			Case 'dialer'
				otp22_dialler(); force recheck for debugging purposes
				Return "Dialer mode cannot be toggled in this version."


				;xor decoder commands
			Case 'elpaso', 'blackotp1'
				Return pastebindecode($what, 'elpaso.bin')
			Case 'databin', 'data.bin', 'bluehill', 'maine', 'truecrypt'
				Return pastebindecode($what, 'data.bin')
			Case 'littlemissouri', 'nd', 'northdakota'
				Return pastebindecode($what, 'littlemissouri.bin')
			Case Else;command functions!
				Return TryCommandFunc($who, $where, $what, $params); looks for a COMMAND_namehere() function with the right number of parameters
		EndSwitch
	EndIf
	Return ''
EndFunc   ;==>Process_Message


Func OnStateChange($oldstate, $newstate)
	If $oldstate = $newstate Then Return
	Switch $newstate
		Case $S_OFF
		Case $S_INIT
			If StringLen($PASS) Then Cmd("PASS " & $PASS)
			If StringLen($PASS) Then Cmd("PRIVMSG NICKSERV :IDENTIFY " & $NICK & " " & $PASS); this was made for Freenode, it'll fail other places - different NS services.
			Cmd("NICK " & $NICK)
			Cmd("USER " & $USERNAME & " X * :OTP22 Utility Bot")
		Case $S_ON
			Cmd('JOIN ' & $CHANNEL)
		Case $S_CHAT
			If $TestMode Then; whatever needs debugging at the moment.
				Msg('TEST='&Process_Message('who','where','@UTM 10/501830/5006349'))
				Msg('TEST='&Process_Message('who','where','@LL 45.21062621390015, -122.97669561655198'))
				Exit
			EndIf
	EndSwitch
EndFunc   ;==>OnStateChange

#endregion ;------------------BOT MAIN


#region ;------------------UTILITIES



#region ;-----misc

Func COMMANDX_UTM($who, $where, $what, $acmd)
	Local $x=UBound($acmd) - 1
	If $x=$PARAM_START Then
		Return _UTM_ToLLF($acmd[$PARAM_START])
	ElseIf $x=($PARAM_START+2) Then
		Return _UTM_ToLLF($acmd[$PARAM_START+0]&'/'&$acmd[$PARAM_START+1]&'/'&$acmd[$PARAM_START+2]);lazy!
	Else
		Return "Returns the Latitude and Longitude for a UTM coordinate.  Usage: UTM zone/easting/northing   or   UTM zone easting northing "
	EndIf
EndFunc
Func COMMAND_LL($lat,$lon)
	Local $result=to_utm($lat,$lon);
	For $i=0 To UBound($result)-1
		$result[$i]=Round($result[$i],0)
	Next
	Return $result[2]&'/'&$result[0]&'/'&$result[1]
EndFunc



Func COMMANDX_Worm($who, $where, $what, $acmd)
	Local $o = ""
	For $i = $PARAM_START To UBound($acmd) - 1
		$o &= IniRead(@ScriptDir & "\worm.ini", "worm", $acmd[$i], "?")
	Next
	Return $o
EndFunc   ;==>COMMANDX_Worm

Func COMMAND_ztime($s)
	Return StringRegExpReplace($s, "Z?([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{0,2})Z?", "Zulu time: \2:\3:\4, day \1")
EndFunc   ;==>COMMAND_ztime
#endregion ;-----misc


#region ;---NATO 5gram Decoding
Func COMMAND_5gramfind($num,$in)
	Local $key=FileGetShortName(@ScriptDir&"\p"&Int($num)&".txt")
	Local $prg=FileGetShortName(@ScriptDir&"\otpnato.exe")
	If Not FileExists($key) Then Return "p"&Int($num)&".txt Not Found"
	If Not FileExists($prg) Then Return "otpnato.exe Not Found"

	$in=StringRegExpReplace($in,"(?s)[^a-zA-Z]","")

	Local $out=@ScriptDir&'\outOTP.txt'
	FileDelete($out)
	_RunDos(StringFormat($prg&' f %s %s > "%s"',$key,$in,$out)); I was skeptical, but this seems to work fine.
	Return FileRead($out)
EndFunc
Func COMMANDX_5gram($who, $where, $what, $acmd);;;;$num,$message)
	If (UBound($acmd)-1)<3 Then Return "5gram: not enough parameters: filenumber 5grams"
	$num=$acmd[2]
	Local $message=CommandToString($acmd,3,-1)


	Local $key=FileGetShortName(@ScriptDir&"\p"&Int($num)&".txt")
	Local $prg=FileGetShortName(@ScriptDir&"\otpnato.exe")
	If Not FileExists($key) Then Return "p"&Int($num)&".txt Not Found"
	If Not FileExists($prg) Then Return "otpnato.exe Not Found"

	Local $in=@ScriptDir&'\msgOTP.txt'
	Local $out=@ScriptDir&'\outOTP.txt'
	FileDelete($in)
	FileDelete($out)
	FileWrite($in,$message)
	_RunDos(StringFormat($prg&' d %s %s > "%s"',$key,$in,$out))
	Return FileRead($out)
EndFunc
#endregion

#region ;--------ITA2 and bits

Func COMMAND_ITA2S($bits)
	Local $o = ""
	For $i = 0 To 4
		$o &= "Shift " & $i & ' ' & COMMAND_ITA2(_StringRepeat('0', $i) & $bits) & ' | '
	Next
	Return $o
EndFunc   ;==>COMMAND_ITA2S

Func COMMAND_ITA2($bits, $printmodes = 0)
	Local $figures = False
	Local $o = ""
	For $i = 1 To StringLen($bits) Step 5
		$o &= ITA2_Byte(StringMid($bits, $i, 5), $figures, $printmodes)
	Next
	Return $o
EndFunc   ;==>COMMAND_ITA2

Func ITA2_Byte($5bits, ByRef $figures, $printmodes = 0)
	Switch $5bits
		Case '00000'
			Return '[NULL]'
		Case '00100'
			Return '_'
		Case '10111'
			Return COMMAND_Ternary(Not $figures, 'Q', '1')
		Case '10011'
			Return COMMAND_Ternary(Not $figures, 'W', '2')
		Case '00001'
			Return COMMAND_Ternary(Not $figures, 'E', '3')
		Case '01010'
			Return COMMAND_Ternary(Not $figures, 'R', '4')
		Case '10000'
			Return COMMAND_Ternary(Not $figures, 'T', '5')
		Case '10101'
			Return COMMAND_Ternary(Not $figures, 'Y', '6')
		Case '00111'
			Return COMMAND_Ternary(Not $figures, 'U', '7')
		Case '00110'
			Return COMMAND_Ternary(Not $figures, 'I', '8')
		Case '11000'
			Return COMMAND_Ternary(Not $figures, 'O', '9')
		Case '10110'
			Return COMMAND_Ternary(Not $figures, 'P', '0')
		Case '00011'
			Return COMMAND_Ternary(Not $figures, 'A', '-')
		Case '00101'
			Return COMMAND_Ternary(Not $figures, 'S', '[BELL]')
		Case '01001'
			Return COMMAND_Ternary(Not $figures, 'D', '$')
		Case '01101'
			Return COMMAND_Ternary(Not $figures, 'F', '!')
		Case '11010'
			Return COMMAND_Ternary(Not $figures, 'G', '&')
		Case '10100'
			Return COMMAND_Ternary(Not $figures, 'H', '#')
		Case '01011'
			Return COMMAND_Ternary(Not $figures, 'J', "'")
		Case '01111'
			Return COMMAND_Ternary(Not $figures, 'K', '(')
		Case '10010'
			Return COMMAND_Ternary(Not $figures, 'L', ')')
		Case '10001'
			Return COMMAND_Ternary(Not $figures, 'Z', '"')
		Case '11101'
			Return COMMAND_Ternary(Not $figures, 'X', '/')
		Case '01110'
			Return COMMAND_Ternary(Not $figures, 'C', ':')
		Case '11110'
			Return COMMAND_Ternary(Not $figures, 'V', ';')
		Case '11001'
			Return COMMAND_Ternary(Not $figures, 'B', '?')
		Case '01100'
			Return COMMAND_Ternary(Not $figures, 'N', ',')
		Case '11100'
			Return COMMAND_Ternary(Not $figures, 'M', '.')
		Case '01000'
			Return COMMAND_Ternary(Not $figures, '[CR]', '[CR]')
		Case '00010'
			Return COMMAND_Ternary(Not $figures, '[LF]', '[LF]')
		Case '11011'
			$figures = True
			If Int($printmodes) Then Return '[FIGS]'
		Case '11111'
			$figures = False
			If Int($printmodes) Then Return '[LTRS]'
		Case Else
			Return " [Fragment bits=" & $5bits & "]"
	EndSwitch
	Return ''
EndFunc   ;==>ITA2_Byte

Func COMMAND_Ternary($cond, $a, $b)
	If $cond Then Return $a
	Return $b
EndFunc   ;==>COMMAND_Ternary

Func COMMAND_lengthstobits($l, $flip = 0)
	Local $b = ""
	For $i = 1 To StringLen($l)
		For $j = 1 To Int(StringMid($l, $i, 1))
			$b &= Mod($i, 2)
		Next
	Next
	If $flip Then Return COMMAND_flipbits($b)
	Return $b
EndFunc   ;==>COMMAND_lengthstobits
Func COMMAND_flipbits($b)
	Local $o = ""
	For $i = 1 To StringLen($b)
		$o &= Mod(StringMid($b, $i, 1) + 1, 2)
	Next
	Return $o
EndFunc   ;==>COMMAND_flipbits



#endregion ;--------ITA2 and bits


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

#region ;-----AutoDialer polling

Func otp22_dialler()
	otp22_getentries()
	Local $ret = otp22_checknew()
	If StringLen($ret) Then SendAutoText($CHANNEL, $ret)
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

#region ;----- autodecoder for  black OTP1

Func Trans2Bytes($trans)
	$trans = StringStripWS($trans, 1 + 2 + 4)
	Local $arr = StringSplit($trans, ' ', 2)
	Local $bytes = ""
	For $key In $arr
		$bytes &= Chr(Int($key))
		If $key = "salt" Then ExitLoop
		If $key = "offset" Then ExitLoop
	Next
	Return $bytes
EndFunc   ;==>Trans2Bytes

Func getpastebin($message)
	Msg("getpastebin")
	Local $id = StringRegExpReplace($message, "(?s)^.*?pastebin.com/([\d\w]+).*$", "\1")
	If @extended = 0 Then Return SetError(1, 0, "")
	Return SetError(0, 0, $id)
EndFunc   ;==>getpastebin

Func pastebindecode($message, $keyfile = "elpaso.bin")
	Msg("pastebindecode")
	Local $id = getpastebin($message)
	If @error <> 0 Then Return SetError(1, 0, "")
	Local $link = "http://pastebin.com/raw.php?i=" & $id
	Local $data = BinaryToString(InetRead($link))
	If Not StringRegExp($data, "(?s)[\d\s]+offset[\d\s]+") Then Return SetError(1, 0, "")
	Return decodebin($data, $keyfile)
EndFunc   ;==>pastebindecode


Func decodebin($message, $key = "elpaso.bin")
	Msg("decodebin")
	$message = StringStripWS($message, 1 + 2 + 4)
	$bytes = Trans2Bytes($message)
	$offset = StringRegExpReplace($message, "^(?s).*?\soffset\s(\d+).*$", "\1")
	If @extended = 0 Then Return "I need an Offset at the end of your message. Like: 11 170 2 offset 50"
	$offset = Int($offset)

	$key = @ScriptDir & '\' & $key
	Local $in = @TempDir & "\msgOTP.txt"
	Local $out = @TempDir & "\outOTP.txt"
	Local $dbg = @TempDir & "\dbgOTP.txt"
	Local $exe = @ScriptDir & "\OtpXor.exe"
	FileDelete($in)
	FileDelete($out)
	FileWrite($in, $bytes)
	;Return StringFormat("C:\Users\Crash\Desktop\otp22\otpdox\OtpXor\Release\OtpXor.exe e %s %s %s %s",$key,$in,$offset,$out)

	Local $run = StringFormat('"%s" e "%s" "%s" %s "%s" > "%s"', $exe, $key, $in, $offset, $out, $dbg)
	Msg("Run: " & $run)
	;Msg("CWD: "&@WorkingDir)
	;_RunDos($run)
	RunWait($run, @WorkingDir, @SW_HIDE)
	Return FileRead($out)
EndFunc   ;==>decodebin




Func scanbin($message, $key = "elpaso.bin");;; not fixed!
	$message = StringStripWS($message, 1 + 2 + 4)
	$bytes = Trans2Bytes($message)
	$offset = Int(StringRegExpReplace($message, "^(?s).*?\soffset\s(\d+).*$", "\1"))


	Local $in = @TempDir & "\msgOTP.txt"
	Local $out = @TempDir & "\outOTP.txt"
	FileDelete($in)
	FileDelete($out)
	FileWrite($in, $bytes)
	;Return StringFormat("C:\Users\Crash\Desktop\otp22\otpdox\OtpXor\Release\OtpXor.exe e %s %s %s %s",$key,$in,$offset,$out)
	_RunDos(StringFormat("OtpXor.exe s %s %s > %s", $key, $in, $out))
	Return FileRead($out)
EndFunc   ;==>scanbin

#endregion ;----- autodecoder for  black OTP1

#region
#endregion

#endregion ;------------------UTILITIES

#region ;------------------BOT INTERNALS

Func COMMAND_test($a = "default", $b = "default", $c = "default")
	Return "This is a test command function. Params: a=" & $a & " b=" & $b & " c=" & $c
EndFunc   ;==>COMMAND_test



Func TryCommandFunc($who, $where, $what, ByRef $acmd)
	Local $paramn = UBound($acmd) - 2
	If Not (StringLeft($what, 1) == $CommandChar) Then Return ""
	If $paramn < 0 Then Return "Error processing command."
	Local $ret = ""
	Local $err = 0xDEAD
	Local $ext = 0xBEEF
	Local $info = ""
	$acmd[1] = StringTrimLeft($acmd[1], 1)
	Switch $paramn; this way sucks, but there's no way to
		Case 0
			$ret = Call('COMMAND_' & $acmd[1])
			$err = @error
			$ext = @extended
		Case Else
			Local $CallArgArray[$paramn + 1]
			$CallArgArray[0] = 'CallArgArray'
			For $i = 1 To $paramn
				$CallArgArray[$i] = $acmd[$i + 1]
				If IsNumeric($CallArgArray[$i]) Then $CallArgArray[$i] = Number($CallArgArray[$i])
			Next
			$ret = Call('COMMAND_' & $acmd[1], $CallArgArray)
			$err = @error
			$ext = @extended
	EndSwitch
	If $err = 0xDEAD And $ext = 0xBEEF Then; no simple command exists, try an extended command, which takes all the parameters.
		$ret = Call('COMMANDX_' & $acmd[1], $who, $where, $what, $acmd)
		$err = @error
		$ext = @extended
	EndIf
	If $err = 0xDEAD And $ext = 0xBEEF Then Return "Command `" & $acmd[1] & "` (with " & $paramn & " parameters) not found."
	Return $ret
EndFunc   ;==>TryCommandFunc

Func SendAutoText($where, $what); bad naming from old bot
	PRIVMSG($where, $what)
EndFunc   ;==>SendAutoText

Func PRIVMSG($where, $what)
	Global $PM_Overflow

	$what = StringReplace(StringStripCR($what), @LF, ' ')
	$what = StringStripWS($what, 1 + 2);leading/trailing whitespace
	If StringLen($what) = 0 Then $what = "ERROR: I tried to send a blank message. Report this to crash_demons along with the input used."


	Local $lenMax = 496 - StringLen($NICK & $USERNAME & $HOSTNAME & $where);512 - (":" + nick + "!" + user + "@" + host + " PRIVMSG " + channel + " :" + CR + LF) == 496 - nick - user - host - channel
	Local $lenMsg = StringLen($what)

	If $lenMsg > $lenMax Then
		Local $notifier = " [type @more]"
		Local $lenOver = ($lenMsg - $lenMax) + StringLen($notifier) + 1; the +1 shouldn't be necessary but for unexplained reasons the text cut off by 1 char
		$PM_Overflow = StringRight($what, $lenOver)
		$what = StringTrimRight($what, $lenOver) & $notifier
	EndIf

	Cmd("PRIVMSG " & $where & " :" & $what)
EndFunc   ;==>PRIVMSG

Func Reply_Message($who, $where, $what);called by Process() based on conditions around Process_Message() calls
	If $where = $NICK Then $where = $who;send reply PM's to the original sender; their PM's were addressed to us.
	If StringLen($what) = 0 Then Return; don't send blank lines, ffs.
	PRIVMSG($where, $what)
EndFunc   ;==>Reply_Message


Func TCheck($tolerance)
	Global $gl_TS
	Local $diff = TimerDiff($gl_TS)
	If $diff > $tolerance Then $gl_TS = TimerInit()
	Return ($diff > $tolerance)
EndFunc   ;==>TCheck


Func IsNumeric($value)
	Return (StringRegExp($value, "^-?[0-9]+(\.[0-9]+)?$") And StringLen($value) <= 10)
EndFunc   ;==>IsNumeric
Func Set($key, $value = "", $section = "utility")
	Return IniWrite(@ScriptDir & '\otpbot.ini', $section, $key, $value)
EndFunc   ;==>Set
Func Get($key, $default = "", $section = "utility")
	Local $value = IniRead(@ScriptDir & '\otpbot.ini', $section, $key, $default)
	If IsNumeric($value) Then Return Number($value);base type conversion
	If StringLen($value) = 0 Then Return $default
	Return $value
EndFunc   ;==>Get


Func Quit()
	Msg('QUITTING')
	Cmd('QUIT :' & $QuitText)
	;Sleep(1000);having issues with socket closing before message arrives.
	Close()
	Exit
EndFunc   ;==>Quit



Func Read()
	If $TestMode Then Return True
	If $SOCK < 0 Then Return SetError(9999, 0, "")
	$BUFF &= TCPRecv($SOCK, 10000)
	If @error Then
		Msg('Recv Error [' & @error & ',' & @extended & ']')
		Close()
	EndIf
EndFunc   ;==>Read


Func Process()
	; this is a very cut-down IRC message parser, it is not RFC-compliant or even efficient, but it's much slimmer than the original bot core.
	If $STATE < $S_INIT Then Return False

	If $TestMode And $STATE<$S_CHAT Then
		State($STATE+1)
		Return True
	EndIf


	Local $p = StringInStr($BUFF, @LF)
	If $p Then
		Local $cmd = StringLeft($BUFF, $p)
		$BUFF = StringTrimLeft($BUFF, $p)
		Local $acmd = Split($cmd)
		Local $isBasic = (UBound($acmd) >= 2);     COMMAND content
		Local $isRegular = (UBound($acmd) >= 3);     :from COMMAND to ...
		Local $isMessage = (UBound($acmd) >= 4);     :from COMMAND to payload ...

		If $isBasic Then
			If $acmd[0] = "PING" Then Return Cmd(StringReplace($cmd, 'PING ', 'PONG '));because laziness but also to prevent losing the ":"
		EndIf

		If $isRegular Then
			Local $from = $acmd[0]
			Local $fromShort = NameShorten($from)
			Local $cmdtype = $acmd[1]


			If $cmdtype = "372" Then Return;server spamming us.
			If Int($cmdtype) > 001 Then Return;server spamming us.
			Switch $STATE
				Case $S_INIT
					Switch $cmdtype
						Case '001'
							State($S_ON)
					EndSwitch
				Case $S_ON
					Msg('IN=' & $cmd)
					Switch $cmdtype
						Case 'JOIN'
							If $fromShort = $NICK And StringLeft($acmd[2], 1) = "#" Then
								$HOSTNAME = NameGetHostname($from)
								State($S_CHAT)
							EndIf
					EndSwitch
				Case $S_CHAT

			EndSwitch
		EndIf
		If $isMessage Then
			Local $who = NameShorten($acmd[0])
			Local $cmdtype = $acmd[1]
			Local $where = $acmd[2]
			Local $what = $acmd[3]

			Switch $cmdtype
				Case 'PRIVMSG', 'NOTICE'
					Reply_Message($who, $where, Process_Message($who, $where, $what))
				Case 'INVITE';:crash_demons!~crashdemo@unaffiliated/crashdemons INVITE AutoBit :##proggit
					If $where = $NICK Then
						$where = $what
						Cmd("JOIN :" & $where)
						Sleep(1000);laziness.
						PRIVMSG($where, "I am a bot. I was invited here by: " & $who)
					EndIf
				Case 'KICK';:WiZ!jto@tolsun.oulu.fi KICK #Finnish John
					If $where = $CHANNEL And $what = $NICK Then State($S_ON)
			EndSwitch
		EndIf

		;; do something with commands

	EndIf
	Return True
EndFunc   ;==>Process

Func Open()
	If $TestMode Then
		$SOCK=65536
		State($S_INIT)
		Return True
	EndIf
	If $SOCK >= 0 Then Return SetError(9999, 0, "")
	$BUFF = ''
	$SOCK = TCPConnect($ADDR, 6667)
	If @error Then
		Msg("Conn Error " & @error)
		State($S_OFF)
		Return False
	Else
		State($S_INIT)
		Return True
	EndIf
EndFunc   ;==>Open
Func Close()
	TCPCloseSocket($SOCK)
	$SOCK = -1
	State($S_OFF)
EndFunc   ;==>Close
Func Msg($s)
	$s = StringStripWS($s, 1 + 2)
	$s = StringFormat("%15s %15s %6s %6s", $SERV, $ADDR, $SOCK, StateGetName($STATE)) & ' : ' & $s & @CRLF
	ConsoleWrite($s)
EndFunc   ;==>Msg


Func State($newstate = $S_UNK)
	If $STATE = $newstate Then Return
	If $newstate <> $S_UNK Then
		Msg(StateGetName($newstate))
		Local $oldstate = $STATE
		$STATE = $newstate
		OnStateChange($oldstate, $newstate)
	EndIf
	Return $STATE
EndFunc   ;==>State
Func StateGetName($STATE)
	Switch $STATE
		Case $S_UNK
			Return 'S_UNK'
		Case $S_OFF
			Return 'S_OFF'
		Case $S_INIT
			Return 'S_INIT'
		Case $S_ON
			Return 'S_ON'
		Case $S_CHAT
			Return 'S_CHAT'
		Case $S_INVD
			Return 'S_INVD'
		Case Else
			Return 'S_UNK?'
	EndSwitch
EndFunc   ;==>StateGetName


Func Cmd($scmd)
	If $SOCK < 0 Then Return SetError(9999, 0, "")
	If $STATE < $S_CHAT Then Msg('OT=' & $scmd)
	If $TestMode Then Return True
	TCPSend($SOCK, $scmd & @CRLF)
	If @error Then
		Msg('Send Error [' & @error & ',' & @extended & ']')
		Close()
	EndIf
EndFunc   ;==>Cmd

Func CommandToString($acmd,$start=1,$end=-1)
	If $end=-1 Then $end=UBound($acmd)-1
	Local $out=""
	For $i=$start To $end
		If StringLen($out) Then $out&=' '
		$out&=$acmd[$i]
	Next
	Return $out
EndFunc

Func Split($scmd)
	$scmd = StringStripWS($scmd, 1 + 2)
	Local $parts = StringSplit($scmd, ' ')

	Local $iStr = 0

	Local $max = UBound($parts) - 1
	For $i = 1 To $max
		If $i > $max Then ExitLoop
		If $i > 1 And StringLeft($parts[$i], 1) == ':' Then; beginning of string section
			$parts[$i] = StringTrimLeft($parts[$i], 1)
			$iStr = $i
		EndIf
		If $iStr And $i > $iStr Then; continuing string section
			$parts[$iStr] &= ' ' & $parts[$i];append to string section
			;$parts[$i]=''
			_ArrayDelete($parts, $i)
			$i -= 1;  negate the effects of the for loop's incrementing the next item will have the same index as this one (since we just deleted this one)
			$max -= 1
		EndIf
	Next
	_ArrayDelete($parts, 0)
	Return $parts
EndFunc   ;==>Split


Func NameShorten($name)
	If StringLeft($name, 1) = ':' Then $name = StringTrimLeft($name, 1)
	Local $pExcl = StringInStr($name, '!')
	If $pExcl Then $name = StringLeft($name, $pExcl - 1)
	Return $name
EndFunc   ;==>NameShorten
Func NameGetHostname($name)
	If StringLeft($name, 1) = ':' Then $name = StringTrimLeft($name, 1)
	Local $pAt = StringInStr($name, '@')
	If $pAt Then Return StringTrimLeft($name, $pAt)
	Return ''
EndFunc   ;==>NameGetHostname



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
Func __HTTP_Transfer(ByRef $aReq, ByRef $sRecv_Out, $limit = 0)
	;ConsoleWrite($aReq[2]&@CRLF)
	Local $error = 0
	Local $SOCK = TCPConnect(TCPNameToIP($aReq[0]), $aReq[3])
	;ConsoleWrite('HTTPSock: '&$aReq[0]&'//'&$aReq[3]&'//'&$sock&'//'&@error&@CRLF)
	TCPSend($SOCK, $aReq[2])
	$sRecv_Out = ""
	While $SOCK <> -1
		Local $recv = TCPRecv($SOCK, 10000, 1)
		If @error <> 0 Then $error = @error
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


#endregion ;------------------BOT INTERNALS
