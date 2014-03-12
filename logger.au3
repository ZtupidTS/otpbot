#include "HTTP.au3"

Global $_Logger_Enable=False
Global $_Logger_Key=''
Global $_Logger_Posts=''
Global $_Logger_Channel=''


Func _Logger_Append($sUser,$sText, $fAction=0, $sTextEx="")
	If Not $_Logger_Enable Then Return
	Local $fmtPost="%s:%s <%s> %s"
	If $fAction=1 Then $fmtPost="%s:%s %s* %s"
	If $fAction=2 Then $fmtPost="%s:%s %s %s"
	If $fAction=3 Then $fmtPost="%s:%s %s %s ("&$sTextEx&")"
	Local $line=StringFormat($fmtPost,@HOUR,@MIN,$sUser,$sText)
	$_Logger_Posts&=$line&@CRLF
EndFunc

Func _Logger_SubmitLogs(); Return value: True (log submit succeeded) False (submit failed);  @error=1: Logged disabled 2:Key rejected 3:Unknown error.
	If Not $_Logger_Enable Then Return SetError(1,0,False)
	Local $headers='Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text=''
	Local $aReq=__HTTP_Req('POST','http://mirror.otp22.com/logger.php', _
		StringFormat("key=%s&channel=%s&posts=", _URIEncode($_Logger_Key), _URIEncode($_Logger_Channel))&_URIEncode($_Logger_Posts) _
		, $headers)
	__HTTP_Transfer($aReq,$text,5000)
	;ConsoleWrite(">>>"&$text&"<<<"&@CRLF)
	_HTTP_StripToContent($text)
	$text=StringStripWS($text,8);all Whitespace stripped
	If $text=="no"  Then
		$_Logger_Posts=''
		Return SetError(2,0,False)
	EndIf
	If $text=="yes" Then
		$_Logger_Posts=''
		Return SetError(0,0,True)
	EndIf
	Return SetError(3,0,False)
EndFunc