#include "HTTP.au3"
#include <Array.au3>
;#include "GeneralCommands.au3"

Global $_Logger_Enable=False
Global $_Logger_Key=''
Global $_Logger_AppID='Undefined_AutoIt'

Global Enum $_Logger_Channel_Name=0, $_Logger_Channel_PostCount, $_Logger_Channel_Log, $_Logger_Channel_Fields
Global $_Logger_Channels[1][3]=[['',0,'']]


Global $_Logger_MinSize_Posts=0x10; number of bytes a log without chat posts must be to submit.
Global $_Logger_MinSize_NoPosts=0x100; number of bytes a log without chat posts must be to submit.

Global Enum $FLD_LOG=0,$FLD_NICK,$FLD_USER,$FLD_HOST, $FIELD_COUNT
Global $LOG_RESULT_FIELDS[$FIELD_COUNT]=['Full log line','Nickname','Username text','Hostname']

Global Enum $_Logger_Type_Post=0, $_Logger_Type_Action, $_Logger_Type_Command, $_Logger_Type_CommandEx

Local $_Log_Commands[3][3]=[ _
["last","<search>","Find the last posts containing a phrase in the logs."], _
["lastby","<user> [search]","Find the last posts by a user in the logs. Optionally, you may supply a search phrase to narrow the results."], _
["aliases","<nickname> [doUserMatch]","Find possible aliases for a nickname using the logs. If 'doUserMatch' argument is entered as anything, a username search is also done. (takes longer) Note that this has possible false-positives and Username-text matches are even less reliable."]  ]


#cs
Global $_Logger_Posts=''
Global $_Logger_Post_Count=0
Global $_Logger_Channel=''
#ce





;$s="xxx12 : xxx12xxx34"
;_Logger_Strip($s)
;MsgBox(0,0,_URIEncode($s))
Func COMMAND_aliases($nick,$dousermatch='')
	Return _Logger_Aliases($nick,$dousermatch)
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
	__HTTP_Transfer($aReq,$text,50000)
	ConsoleWrite(">>>"&$text&"<<<"&@CRLF)
	_HTTP_StripToContent($text)

	$text=StringStripWS($text,1+2)

	$posts=StringSplit($text,@LF,2)
	If Not IsArray($posts) Then Return "No results to display."

	For $i=0 To UBound($posts)-1
		If $i>(UBound($posts)-1) Then ExitLoop
		If StringInStr($posts[$i], "@last") Or StringRegexp($posts[$i], ".{4,}\[\d\d:\d\d\]") Then
			_ArrayDelete($posts,$i)
			$i-=1
		EndIf
	Next
	;_ArrayDisplay
	$text=_ArrayToString($posts,@LF)



	;$text=StringReplace($text,@LF,' | ')



	Return $text
EndFunc

Func _Logger_Strip(ByRef $sIn)
	$sIn=StringRegExpReplace($sIn,"([^[:print:][:graph:]])"," ");
	;StringRegexp("abc d!"&Chr(1),"^[[:print:][:graph:]]+$"); rgx replace NOT group to " "
EndFunc


Func _Logger_Start($channelCSV)
	Local $channels=StringSplit($channelCSV,',',2)
	Local $tmpArr[UBound($channels)][$_Logger_Channel_Fields]
	$_Logger_Channels=$tmpArr

	For $i=0 To UBound($channels)-1
		If $channels[$i]='' Then ContinueLoop
		$_Logger_Channels[$i][$_Logger_Channel_Name]=$channels[$i]
		$_Logger_Channels[$i][$_Logger_Channel_PostCount]=1
		$_Logger_Channels[$i][$_Logger_Channel_Log]=StringFormat("Log Session Start: %s-%s-%s %s:%s:%s"&@CRLF, @YEAR, @MON, @MDAY,  @HOUR, @MIN, @SEC)
	Next
	;$_Logger_Posts&=StringFormat("Log Session Start: %s-%s-%s %s:%s:%s"&@CRLF, @YEAR, @MON, @MDAY,  @HOUR, @MIN, @SEC)
	;$_Logger_Post_Count+=1
EndFunc

Func _Logger_Append($sChannel,$sUser,$sText, $fAction=0, $sTextEx="")
	If Not $_Logger_Enable Then Return
	Local $iChan=_ArraySearch($_Logger_Channels,$sChannel,0,0,0,0,1,$_Logger_Channel_Name)
	If $iChan<0 Then Return;
	;ConsoleWrite("logged"&@CRLF)
	_Logger_Strip($sText)
	Local $fmtPost="[%s:%s] <%s> %s"
	If $fAction=1 Then $fmtPost="[%s:%s] %s* %s"
	If $fAction=2 Then $fmtPost="[%s:%s] %s %s"
	If $fAction=3 Then $fmtPost="[%s:%s] %s %s";deprecated option

	If $fAction>=0 And $fAction<=1 Then $_Logger_Channels[$iChan][$_Logger_Channel_PostCount]+=1


	Local $line=StringFormat($fmtPost,@HOUR,@MIN,$sUser,$sText)
	If StringLen($sTextEx) Then $line&=" ("&$sTextEx&")"
	$_Logger_Channels[$iChan][$_Logger_Channel_Log]&=$line&@CRLF
EndFunc
Func _Logger_SubmitLogs()
	For $iChan=0 To UBound($_Logger_Channels)-1
		If $_Logger_Channels[$iChan][$_Logger_Channel_Name]='' Then ContinueLoop
		Local $r=_Logger_SubmitLog($iChan)
		Local $e=@error
		Local $x=@extended
		ConsoleWrite("Log Submit: I:"&$iChan&' R:'&$r&' E:'&$e&' X:'&$x&@CRLF)
	Next
EndFunc
Func _Logger_SubmitLog($iChan); Return value: True (log submit succeeded) False (submit failed);  @error=1: Logged disabled 2:Key rejected 3:Unknown error. 4: Invalid channel index
	If $iChan<0 Then Return SetError(4,0,False)
	If Not $_Logger_Enable Then Return SetError(1,0,False)
	Local $postcount=$_Logger_Channels[$iChan][$_Logger_Channel_PostCount]
	Local $postlen=StringLen($_Logger_Channels[$iChan][$_Logger_Channel_Log])
	ConsoleWrite($postcount&' '&$postlen&' '&$_Logger_MinSize_Posts&' '&@CRLF)

	If $postcount=0 And $postlen<$_Logger_MinSize_NoPosts Then Return SetError(0,1,True);we don't submit null logs under 256 bytes
	If $postcount>0 And $postlen<$_Logger_MinSize_Posts   Then Return SetError(0,2,True);we don't submit any logs under 16 bytes


	Local $headers='Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text=''
	Local $aReq=__HTTP_Req('POST','http://mirror.otp22.com/logger.php?APPID='&_URIEncode($_Logger_AppID), _
		StringFormat("key=%s&channel=%s&posts=", _URIEncode($_Logger_Key), _URIEncode($_Logger_Channels[$iChan][$_Logger_Channel_Name])) & _URIEncode($_Logger_Channels[$iChan][$_Logger_Channel_Log]) _
		, $headers)
	__HTTP_Transfer($aReq,$text,5000)
	ConsoleWrite(">>>"&$text&"<<<"&@CRLF)
	_HTTP_StripToContent($text)
	$text=StringStripWS($text,8);all Whitespace stripped
	If $text=="no"  Then
		$_Logger_Channels[$iChan][$_Logger_Channel_Log]=''
		$_Logger_Channels[$iChan][$_Logger_Channel_PostCount]=0
		Return SetError(2,0,False)
	EndIf
	If $text=="yes" Then
		$_Logger_Channels[$iChan][$_Logger_Channel_Log]=''
		$_Logger_Channels[$iChan][$_Logger_Channel_PostCount]=0
		Return SetError(0,0,True)
	EndIf
	Return SetError(3,0,False)
EndFunc




Func _Logger_Aliases($nick,$dousermatch='')
	Local $ret="Nicks with matching "
	Local $nicks=0
	If StringLen($dousermatch)=0 Then
		$nicks=_Logger_UserCrossRef($nick,$FLD_NICK,   $FLD_HOST)
		$ret&="hosts: "
	Else
		$nicks=_Logger_UserCrossRef($nick,$FLD_NICK,   $FLD_USER)
		$ret&="usernames (less reliable): "
	EndIf
	$ret&=_ArrayToString($nicks, " ")
	Return $ret
EndFunc

Func _Logger_UserCrossRef($value,$fieldvalue,$fieldref)
	; finds entries of line[fieldref]  where  line[fieldvalue]=value   (return results of Y where we match a given property X)
	; then for each ref, find the associated line[fieldref]s and return an array - the results will be equal to or more than the input.
	Local $refs=_Logger_UserSearchAll($value,$fieldvalue,   $fieldref)
	Local $values[1]=['']
	;_ArrayDisplay($refs,'crossref intermediate')

	Local $refs_str=''
	For $i=0 To UBound($refs)-1
		If StringLen($refs[$i])<3 Then ContinueLoop
		If $refs[$i]='update' Then ContinueLoop
		If $refs[$i]='Set' Then ContinueLoop
		If $refs[$i]='Topic' Then ContinueLoop
		If StringLen($refs_str) Then $refs_str&=' '
		$refs_str&=$refs[$i]
	Next
	$values=_Logger_UserSearchAll($refs_str,$fieldref,   $fieldvalue,  1);compound query for all refs - looped for each year.
	$values=_ArrayUnique0($values)

	For $i=0 To UBound($values)-1
		If $values[$i]='Set' Then $values[$i]=''
		If $values[$i]='Topic' Then $values[$i]=''
		If $values[$i]='update' Then $values[$i]=''
		If StringRegExp($values[$i],"^Guest\d+$") Then $values[$i]=''
	Next

	;For $i=0 To UBound($refs)-1
	;	If StringLen($refs[$i])<3 Then ContinueLoop
	;	If $refs[$i]='update' Then ContinueLoop
	;	Local $a_tmp=_Logger_UserSearchAll($refs[$i],$fieldref,   $fieldvalue)
	;	_ArrayConcatenate($values,$a_tmp)
	;Next
	;_ArrayDisplay($values,'crossref results')
	Return $values
EndFunc

Func _Logger_UserSearchAll($search,$fieldsearch,$fieldresult,$compound=0)
	ConsoleWrite(StringFormat("QUERYALL: search=%s (%s)  results=%s",$search,FieldName($fieldsearch),FieldName($fieldresult))&@CRLF)
	Local $results[1]=['']
	For $year=@YEAR To 2011 Step -1; append all hostnames for nick
		Local $a_tmp=_Logger_UserSearch($year,$search,$fieldsearch,$fieldresult,1,$compound); find fieldref results where line[fieldvalue] = value
		_ArrayConcatenate($results,$a_tmp)
	Next
	$results=_ArrayUnique0($results)
	Return $results
EndFunc
Func _Logger_UserSearch($year,$search,$fieldsearch,$fieldresult,$stripcount=0,$compound=0); fields:  0=>chat line 1=>nickname 2=>usernametext 3=>hostname
	ConsoleWrite(StringFormat("   QUERY: year=%s search=%s (%s)  results=%s",$year,$search,FieldName($fieldsearch),FieldName($fieldresult))&@CRLF)
	If StringLen($search)<1 Then
		Local $tmp[1]=['0 results.']
		Return $tmp
	EndIf
	Local $action=6

	Local $url='http://mirror.otp22.com/logapi.php?APPID='&$_Logger_APPID&''
	Local $arg=StringFormat("key=%s&action=%s&year=%s&text=%s&fieldsearch=%s&fieldresult=%s&compound=%s", _URIEncode($_Logger_Key), _URIEncode($action), $year,_URIEncode($search),$fieldsearch,$fieldresult,$compound)

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
		Local $b=_ArrayUnique0($a)
		_ArraySort($b,0,1)
	Else
		$b=$a
	EndIf
	ConsoleWrite(_ArrayToString($b)&@CRLF)
	Return $b

EndFunc

Func _ArrayUnique0(ByRef $array)
	Local $tmp=_ArrayUnique($array)
	Local $num=UBound($tmp)
	If $num=1 Then
		$tmp[0]=''
	Else
		_ArrayDelete($tmp,0)
	EndIf
	Return $tmp;
	;$array=$tmp
EndFunc


Func FieldName($fld)
	Return $LOG_RESULT_FIELDS[$fld]
EndFunc