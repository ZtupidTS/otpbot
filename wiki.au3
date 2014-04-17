#include-once
#include <String.au3>
#include "HTTP.au3"
#include "shorturl.au3"
#include "GeneralCommands.au3"
#include "userinfo.au3"

Global $NewsInterval
Global $OTPNEWS
Global $OTPNEWSTIMER
Global $wiki_url='http://otp22.referata.com'
Global $news_url = "http://otp22.referata.com/wiki/Special:Ask/-5B-5BDisplay-20tag::News-20page-20entry-5D-5D/-3FOTP22-20NI-20full-20date/-3FSummary/format%3Dcsv/limit%3D5/sort%3DOTP22-20NI-20full-20date/order%3Ddescending/offset%3D0"
Global $news_entries = 5
Global $query_url = "http://otp22.referata.com/wiki/Special:Ask/%s/format%3D%s/offset%3D0"
Global $query_formats[3]=['csv','json','broadtable']

Global $Wiki_User=''
Global $Wiki_Pass=''

Global $wiki_cookies=''
Global $wiki_edittoken=''
Global $wiki_login_ts=0


_Help_RegisterGroup("Wiki")
_Help_RegisterCommand("update","","Displays News information and current events.")
_Help_RegisterCommand("updatechan","","Displays News information and current events - sent to the channel.")
_Help_RegisterCommand("newupdate","summary","Posts a news update to the wiki. (alias: %!%new_update)  This command can only be used by registered IRC users from the public channel. Your account name will be recorded.")
_Help_RegisterCommand("query","<query string>","Performs a Semantic-MediaWiki query and results CSV results.")
_Help_RegisterCommand("page","<page name>","Looks up a page name on the wiki and provides a link. Provides the first title search result if no exact match is found.")
_Help_RegisterCommand("search","<search terms>","Performs a search of the wiki by title name. If no results are found, a Text search is done.")


;_UserInfo_Option_Add('notifyupdate')


Func COMMANDX_new_update($who, $where, $what, $acmd)
	Return COMMANDX_newupdate($who, $where, $what, $acmd)
EndFunc

Func COMMANDX_newupdate($who, $where, $what, $acmd)
	Local $sAcct=_UserInfo_Whois($who)
	Local $iAcct=@extended
	Local $isRecognized=(@error=0)
	If Not $isRecognized Then Return "You must be logged in to NickServ to use this command. If you think you are logged in, you might try the IDENTIFY command to refresh your information."

	Local $sig=" -- written by: "&$who
	If Not ($who=$sAcct) Then $sig&=' (Account '&$sAcct&')'

	Local $p=StringInStr($what,' ')
	If Not $p Then Return 'You must enter text for this update.'
	If Not (StringLeft($where,1)='#') Then Return 'This command can only be used in the channel.'

	If Wiki_AddNews(StringTrimLeft($what,$p)&$sig) Then Return "Posted news update"
	Return "News update failed"
EndFunc


Func COMMANDX_query($who, $where, $what, $acmd)
	$query=StringMid($what,1+StringLen("@query "))
	$query=StringReplace(StringReplace(StringReplace(__SU_URIEncode($query),"+","%20"),"-","-2D"),"%","-")
	$query=StringReplace($query,"-7C-3F","/-3F")
	$query=StringReplace($query,"-3D","%3D")

	Local $out=""
	For $i=0 To UBound($query_formats)-1
		Local $url=StringFormat($query_url,$query,$query_formats[$i])
		If $i=0 Then $out&=BinaryToString(_InetRead($url, 1))&' --'
		$out&=' '&StringUpper($query_formats[$i])&': '&COMMAND_tinyurl($url)

	Next
	Return $out
EndFunc

Func COMMANDX_search($who, $where, $what, $acmd)
	$terms=StringMid($what,1+StringLen("@search "))
	Local $arr=Wiki_Search($terms,"title")
	If UBound($arr)<1 Then $arr=Wiki_Search($terms,"text")
	If UBound($arr)<1 Then Return "I'm sorry. I couldn't find anything like that on the wiki."
	Local $out=UBound($arr)&' results: '
	For $i=0 To UBound($arr)-1
		$out&=($i+1)&'. '&_Wiki_Link('/wiki/'&_Wiki_Name($arr[$i]))&' '
	Next
	Return $out
EndFunc

;----------------------- active functions
Func Wiki_AddNews($summary)
	Local $template=	"{{News entry"&@CRLF& _
						"|date=%s"&@CRLF& _
						"|time=%s"&@CRLF& _
						"|summary=%s"&@CRLF& _
						"}}"

	$summary=StringReplace(StringStripCR($summary),@LF,'')
	$summary=StringReplace($summary,'|', '/')
	$summary=StringReplace($summary,'{', '(')
	$summary=StringReplace($summary,'[', '(')
	$summary=StringReplace($summary,'}', ')')
	$summary=StringReplace($summary,']', ')')

	$template=StringFormat($template, @YEAR&'-'&@MON&'-'&@MDAY,  @HOUR&':'&@MIN, $summary)

	Return Wiki_EditPrepend('News/'&@YEAR,$template&@CRLF&@CRLF)
EndFunc


Func Wiki_Edit($title,$text)
	Wiki_AutoLogin()
	Local $out=''
	Local $arg=StringFormat("format=xml&action=edit&title=%s&text=%s&token=%s&bot=1", _URIEncode($title), _URIEncode($text),_URIEncode($wiki_edittoken));nocreate
	Wiki_API_Request($out,$arg)
	Return StringInStr($out,'Success')>0
EndFunc
Func Wiki_EditPrepend($title,$text,$section='')
	Wiki_AutoLogin()
	Local $out=''
	Local $arg=StringFormat("format=xml&action=edit&title=%s&prependtext=%s&token=%s&bot=1", _URIEncode($title), _URIEncode($text),_URIEncode($wiki_edittoken));nocreate
	If StringLen($section) Then $arg&='&section='&_URIEncode($section)
	Wiki_API_Request($out,$arg)
	Return StringInStr($out,'Success')>0
EndFunc
Func Wiki_EditAppend($title,$text)
	Wiki_AutoLogin()
	Local $out=''
	Local $arg=StringFormat("format=xml&action=edit&title=%s&appendtext=%s&token=%s&bot=1", _URIEncode($title), _URIEncode($text),_URIEncode($wiki_edittoken));nocreate
	Wiki_API_Request($out,$arg)
	Return StringInStr($out,'Success')>0
EndFunc


Func Wiki_API_Request(ByRef $out,$args,$method='POST')
	Local $url=Wiki_URL_API()
	Local $headers='Cookie: '&$wiki_cookies&@CRLF
	If $method='GET' Then
		$url&='?'&$args
		$args=''
	EndIf
	If $method='POST' Then $headers&='Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $aReq=__HTTP_Req('POST',$url, $args, $headers)
	__HTTP_Transfer($aReq,$out,5000)
	Wiki_AddCookies($out)
	ConsoleWrite(">>>"&$out&"<<<"&@CRLF&@CRLF)
	ConsoleWrite("COOKIES: "&$wiki_cookies&@CRLF)
EndFunc

Func Wiki_ClearCookies()
	$wiki_edittoken=''
	$wiki_cookies=''
EndFunc
Func Wiki_URL_API()
	Return $wiki_url&'/w/api.php'
EndFunc
Func Wiki_AddCookies($text)
	Local $cookies=_StringBetween($text,'Set-Cookie:',';')
	For $i=0 To UBound($cookies)-1
		$wiki_cookies&=$cookies[$i]&'; '
	Next
EndFunc
Func Wiki_IsLoggedIn()
	Return (StringLen($wiki_cookies) And TimerDiff($wiki_login_ts)<(1000*60*60*24*2) And $wiki_login_ts<>0)
EndFunc
Func Wiki_AutoLogin()
	If Wiki_IsLoggedIn() Then Return SetError(0,0,1)
	Local $ret=Wiki_Login($Wiki_User,$Wiki_Pass)
	Local $err=@error
	Return SetError($err,0,$ret)
EndFunc
Func Wiki_Login($user,$pass)
	Wiki_ClearCookies()
	Local $text=''
	Local $arg=StringFormat("format=xml&action=login&lgname=%s&lgpassword=%s", _URIEncode($user), _URIEncode($pass))
	Wiki_API_Request($text,$arg)

	Local $tokens=_StringBetween($text,'token="','"')
	Local $token=''
	If IsArray($tokens) Then $token=$tokens[0]


	;_HTTP_StripToContent($text)

	If StringInStr($text,"Success") Then Return SetError(0,0,1)

	If StringInStr($text,"NeedToken") Then
		$arg&='&lgtoken='&_URIEncode($token)
		Wiki_API_Request($text,$arg)
		$wiki_login_ts=TimerInit()

		Local $textb
		$arg&='format=xml&action=tokens&type=edit'
		Wiki_API_Request($textb,$arg)
		$tokens=_StringBetween($textb,'edittoken="','"')
		If IsArray($tokens) Then $wiki_edittoken=$tokens[0]

		If StringInStr($text,"Success") Then Return SetError(0,0,1)
	EndIf
	Wiki_ClearCookies()
	Return SetError(1,0,0)
EndFunc


;---------------------------------------------passive functions
Func Wiki_Search($terms,$mode="title");text?
	Local $url="http://otp22.referata.com/w/api.php?action=query&list=search&srsearch="&__SU_URIEncode($terms)&"&srprop=timestamp&srredirects=true&format=xml&limit=10&srwhat="&__SU_URIEncode($mode)
	Local $data=_InetRead($url)
	If @error<>0 Then
		Return ""
	EndIf
	$data=BinaryToString($data)
	Return _StringBetween($data,'title="','"')
EndFunc

Func COMMANDX_page($who, $where, $what, $acmd)
	$page=StringMid($what,1+StringLen("@wiki "))
	Local $url="http://otp22.referata.com/w/index.php?title=Special%3ASearch&search="&__SU_URIEncode($page)&"&go=Go"
	Local $data=_InetRead($url)
	If @error<>0 Then
		Return "I couldn't check the page name at this time. Try this: "&_Wiki_Link('/wiki/'&_Wiki_Name($page))
	EndIf
	$data=BinaryToString($data)
	Local $a=_StringBetween($data,'class="selected"><a href="','"')
	Local $result=0
	If IsArray($a) Then
		If Not (StringInStr($a[0],"Special:Search") Or StringInStr($a[0],"Special%3ASearch")) Then $result=1
	EndIf
	If $result Then return _Wiki_Link($a[0])

	Local $arr=Wiki_Search($page,"title")
	If UBound($arr) Then Return 'Did you mean: '&_Wiki_Link('/wiki/'&_Wiki_Name($arr[0]))&' ?'
	Return "I couldn't find `"&$page&"` on the wiki, sorry.  Try %!%SEARCH instead."
EndFunc

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
	Local $s = _InetRead($news_url, 1)
	$s = BinaryToString($s)
	$s = StringReplace($s, @LF, ',')
	;ConsoleWrite("DLd"&@CRLF)


	;ConsoleWrite($s&@CRLF)
	CSV_PopField($s);Header:Subobject link
	CSV_PopField($s);Header:Date
	CSV_PopField($s);Header:Summary

	Local $out = "Last "&$news_entries&" Updates: "
	For $i = 1 To $news_entries
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



Func _Wiki_Link($canonical)
	Return 'http://otp22.referata.com'&$canonical;&' (mirror: '&COMMAND_tinyurl('http://otp22.zoxid.com'&$canonical)&' )'
EndFunc

Func _Wiki_Name($s)
	$s=StringUpper(StringLeft($s,1))&StringMid($s,2)
	$s=StringReplace($s,' ','_')
	Return $s
EndFunc
