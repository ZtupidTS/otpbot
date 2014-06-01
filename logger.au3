#include "HTTP.au3"
#include "GeneralCommands.au3"

Global $_Logger_Enable=False
Global $_Logger_Key=''
Global $_Logger_Posts=''
Global $_Logger_Post_Count=0
Global $_Logger_Channel=''
Global $_Logger_AppID='Undefined_AutoIt'


Global $_Logger_MinSize_Posts=0x10; number of bytes a log without chat posts must be to submit.
Global $_Logger_MinSize_NoPosts=0x100; number of bytes a log without chat posts must be to submit.

Global Enum $FLD_LOG=0,$FLD_NICK,$FLD_USER,$FLD_HOST, $FIELD_COUNT
Global $LOG_RESULT_FIELDS[$FIELD_COUNT]=['Full log line','Nickname','Username text','Hostname']

Global Enum $_Logger_Type_Post=0, $_Logger_Type_Action, $_Logger_Type_Command, $_Logger_Type_CommandEx

_Help_RegisterGroup("log")
_Help_RegisterCommand("last","<search>","Find the last posts containing a phrase in the logs.")
_Help_RegisterCommand("lastby","<user> [search]","Find the last posts by a user in the logs. Optionally, you may supply a search phrase to narrow the results.")
_Help_RegisterCommand("aliases","<nickname>","Find possible aliases for a nickname using the logs. Note that this has possible false-positives and Username-text matches are even less reliable.")

_Logger_Start()

;$s="xxx12 : xxx12xxx34"
;_Logger_Strip($s)
;MsgBox(0,0,_URIEncode($s))
Func COMMAND_aliases($nick)
	Return _Logger_Aliases($nick)
EndFunc

Func COMMANDV_last($search)
	Return _Logger_FindPosts($search)
EndFunc
Func COMMANDV_lastby($input)
	Local $p=StringInStr($input,' ')
	Local $search=""
	Local $user=""
	If $p Then
		$user=StringLeft($input,$p-1)
		$search=StringMid($input,$p+1)
	Else
		$user=$input
	EndIf
	Return _Logger_FindPosts($search,$user)
EndFunc


Func _Logger_FindPosts($search,$username="")
	Local $action=1
	If StringLen($username) Then $action=2

	Local $url='http://mirror.otp22.com/logapi.php?APPID='&_URIEncode($_Logger_AppID)
	Local $arg=StringFormat("key=%s&action=%s&year=%s&text=%s&nick=%s", _URIEncode($_Logger_Key), _URIEncode($action), @YEAR, _URIEncode($search), _URIEncode($username))

	Local $headers='Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text=''
	Local $aReq=__HTTP_Req('POST',$url, $arg, $headers)
	__HTTP_Transfer($aReq,$text,5000)
	ConsoleWrite(">>>"&$text&"<<<"&@CRLF)
	_HTTP_StripToContent($text)

	$text=StringStripWS($text,1+2)
	$text=StringReplace($text,@LF,'|')

	Return $text
EndFunc

Func _Logger_Strip(ByRef $sIn)
	$sIn=StringRegExpReplace($sIn,"([^[:print:][:graph:]])"," ");
	;StringRegexp("abc d!"&Chr(1),"^[[:print:][:graph:]]+$"); rgx replace NOT group to " "
EndFunc

Func _Logger_Start()
	$_Logger_Posts&=StringFormat("Log Session Start: %s-%s-%s %s:%s:%s"&@CRLF, @YEAR, @MON, @MDAY,  @HOUR, @MIN, @SEC)
	$_Logger_Post_Count+=1
EndFunc

Func _Logger_Append($sUser,$sText, $fAction=0, $sTextEx="")
	If Not $_Logger_Enable Then Return
	;ConsoleWrite("logged"&@CRLF)
	_Logger_Strip($sText)
	Local $fmtPost="[%s:%s] <%s> %s"
	If $fAction=1 Then $fmtPost="[%s:%s] %s* %s"
	If $fAction=2 Then $fmtPost="[%s:%s] %s %s"
	If $fAction=3 Then $fmtPost="[%s:%s] %s %s";deprecated option

	If $fAction>=0 And $fAction<=1 Then $_Logger_Post_Count+=1


	Local $line=StringFormat($fmtPost,@HOUR,@MIN,$sUser,$sText)
	If StringLen($sTextEx) Then $line&=" ("&$sTextEx&")"
	$_Logger_Posts&=$line&@CRLF
EndFunc

Func _Logger_SubmitLogs(); Return value: True (log submit succeeded) False (submit failed);  @error=1: Logged disabled 2:Key rejected 3:Unknown error.
	If Not $_Logger_Enable Then Return SetError(1,0,False)

	If $_Logger_Post_Count=0 And StringLen($_Logger_Posts)<$_Logger_MinSize_NoPosts Then Return SetError(0,1,True);we don't submit null logs under 256 bytes
	If $_Logger_Post_Count>0 And StringLen($_Logger_Posts)<$_Logger_MinSize_Posts   Then Return SetError(0,2,True);we don't submit any logs under 16 bytes


	Local $headers='Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text=''
	Local $aReq=__HTTP_Req('POST','http://mirror.otp22.com/logger.php?APPID='&_URIEncode($_Logger_AppID), _
		StringFormat("key=%s&channel=%s&posts=", _URIEncode($_Logger_Key), _URIEncode($_Logger_Channel)) & _URIEncode($_Logger_Posts) _
		, $headers)
	__HTTP_Transfer($aReq,$text,5000)
	ConsoleWrite(">>>"&$text&"<<<"&@CRLF)
	_HTTP_StripToContent($text)
	$text=StringStripWS($text,8);all Whitespace stripped
	If $text=="no"  Then
		$_Logger_Posts=''
		$_Logger_Post_Count=0
		Return SetError(2,0,False)
	EndIf
	If $text=="yes" Then
		$_Logger_Posts=''
		$_Logger_Post_Count=0
		Return SetError(0,0,True)
	EndIf
	Return SetError(3,0,False)
EndFunc




Func _Logger_Aliases($nick)
	Local $nicksA=0;_Logger_UserCrossRef($nick,$FLD_NICK,   $FLD_HOST); get all other nicknames on the basis of a matching hostname.
	Local $nicksB=_Logger_UserCrossRef($nick,$FLD_NICK,   $FLD_USER); and by username text

	Return "Nick with matching hosts: "&_ArrayToString($nicksA," ")&' | Nicks with matching usernames (less reliable): '&_ArrayToString($nicksB, " ")
EndFunc

Func _Logger_UserCrossRef($value,$fieldvalue,$fieldref)
	; finds entries of line[fieldref]  where  line[fieldvalue]=value   (return results of Y where we match a given property X)
	; then for each ref, find the associated line[fieldref]s and return an array - the results will be equal to or more than the input.
	Local $refs=_Logger_UserSearchAll($value,$fieldvalue,   $fieldref)
	Local $values[1]=['']
	;_ArrayDisplay($refs,'crossref intermediate')
	For $i=0 To UBound($refs)-1
		If StringLen($refs[$i])<1 Then ContinueLoop
		Local $a_tmp=_Logger_UserSearchAll($refs[$i],$fieldref,   $fieldvalue)
		_ArrayConcatenate($values,$a_tmp)
	Next
	$values=_ArrayUnique($values)
	;_ArrayDisplay($values,'crossref results')
	Return $values
EndFunc

Func _Logger_UserSearchAll($search,$fieldsearch,$fieldresult)
	ConsoleWrite(StringFormat("QUERYALL: search=%s (%s)  results=%s",$search,FieldName($fieldsearch),FieldName($fieldresult))&@CRLF)
	Local $results[1]=['']
	For $year=@YEAR To 2011 Step -1; append all hostnames for nick
		Local $a_tmp=_Logger_UserSearch($year,$search,$fieldsearch,$fieldresult,1); find fieldref results where line[fieldvalue] = value
		_ArrayConcatenate($results,$a_tmp)
	Next
	$results=_ArrayUnique($results)
	If Int($results[0])=$results[0] Then _ArrayDelete($results,0)
	Return $results
EndFunc
Func _Logger_UserSearch($year,$search,$fieldsearch,$fieldresult,$stripcount=0); fields:  0=>chat line 1=>nickname 2=>usernametext 3=>hostname
	ConsoleWrite(StringFormat("   QUERY: year=%s search=%s (%s)  results=%s",$year,$search,FieldName($fieldsearch),FieldName($fieldresult))&@CRLF)
	If StringLen($search)<1 Then
		Local $tmp[1]=['0 results.']
		Return $tmp
	EndIf
	Local $action=6

	Local $url='http://mirror.otp22.com/logapi.php?APPID='&$_Logger_APPID&''
	Local $arg=StringFormat("key=%s&action=%s&year=%s&text=%s&fieldsearch=%s&fieldresult=%s", _URIEncode($_Logger_Key), _URIEncode($action), $year,_URIEncode($search),$fieldsearch,$fieldresult)

	Local $headers='Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text=''
	Local $aReq=__HTTP_Req('POST',$url, $arg, $headers)
	__HTTP_Transfer($aReq,$text,100000)
	If $_HTTP_DebugRequests Then ConsoleWrite(">>>"&$text&"<<<"&@CRLF)
	_HTTP_StripToContent($text)
	$text=StringStripWS($text,1+2)
	If $_HTTP_DebugRequests Then ConsoleWrite(StringInStr($text,@LF)&@CRLF)
	Local $a=StringSplit(StringStripCR($text),@LF,2)
	Local $b=''
	;_ArrayDisplay($a)
	If $fieldresult>0 Then
		Local $b=_ArrayUnique($a)
		If $stripcount Then
			If Int($b[0])=$b[0] Then _ArrayDelete($b,0)
		Else
			$b[0]&=' Results:'
		EndIf
		_ArraySort($b,0,1)
	Else
		$b=$a
	EndIf
	ConsoleWrite(_ArrayToString($b)&@CRLF)
	Return $b

EndFunc


Func FieldName($fld)
	Return $LOG_RESULT_FIELDS[$fld]
EndFunc