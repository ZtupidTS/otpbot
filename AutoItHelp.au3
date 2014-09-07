#include-once
;http://www.autoitscript.com/autoit3/docs/functions/
#include <Array.au3>
#include "HTTP.au3"
#include "GeneralCommands.au3"
#include "calc.au3"

;Opt('TrayIconDebug',1)
Global $_Au3_Funcs[1]=['']
Global $_Udf_Funcs[1]=['']

Global $_Au3_Commands=''
Global $_Udf_Commands=''

;TCPStartup()
;_Au3_Startup()\

;; TODO:  Updating help entries via callback


Func _Au3_HelpCallBack($group,$command,$subcommand='',$vdata='')
	; not implemented
EndFunc

Func _Au3_Startup ()
	$_Au3_Funcs=StringSplit(StringStripCR(FileRead(@ScriptDir&"\functions.txt")),@LF,2)
	$_Udf_Funcs=StringSplit(StringStripCR(FileRead(@ScriptDir&"\libfunctions.txt")),@LF,2)
	;_ArrayDisplay($_Au3_Funcs)
	Local $tmpA[UBound($_Au3_Funcs)][3]
	Local $tmpB[UBound($_Udf_Funcs)][3]
	$_Au3_Commands=$tmpA
	$_Udf_Commands=$tmpB


	_Calc_Startup()


	For $i=0 To UBound($_Au3_Funcs)-1
		If StringInStr(_Calc_Sanitize($_Au3_Funcs[$i]),'_REF_') Then
			$_Au3_Commands[$i][0]=''
		Else
			$_Au3_Commands[$i][0]=$_Au3_Funcs[$i]
			$_Au3_Commands[$i][1]='###autoit###'
			$_Au3_Commands[$i][2]='###autoit###'
		EndIf
	Next

	For $i=0 To UBound($_Udf_Funcs)-1
		If StringInStr(_Calc_Sanitize($_Udf_Funcs[$i]),'_REF_') Then
			$_Udf_Commands[$i][0]=''
		Else
			$_Udf_Commands[$i][0]=$_Udf_Funcs[$i]
			$_Udf_Commands[$i][1]='###udf###'
			$_Udf_Commands[$i][2]='###udf###'
		EndIf
	Next
EndFunc
Func _Au3_UpdateHelpEntry($i,$sfunc)
	;Global $_Au3_Funcs, $_Udf_Funcs
	;ConsoleWrite($i&' '&$sfunc&@CRLF)
	;_ArrayDisplay($_Au3_Funcs)
	For $func In $_Au3_Funcs

		If $func=$sfunc Then
			Local $url=_Au3_GetLink($_Au3_Funcs,$func)
			If $url="" Then Return SetError(2,0,False)
			Local $desc,$usage,$notes
			_Au3_ScrapeInfo($url,$func, $desc, $usage,$notes)
			$desc=$desc&' | '&$notes&' | source: '&$url
			;_Help_Set($i,$func,$usage,$desc)
			Return True
		EndIf
	Next
	Return SetError(3,0,False)
EndFunc
Func _Au3_UpdateHelpEntryUDF($i,$sfunc)
	For $func In $_Udf_Funcs
		If $func=$sfunc Then
			Local $url=_Au3_GetLinkUDF($_Udf_Funcs,$func)
			If $url="" Then Return SetError(2,0,False)
			Local $desc,$usage,$notes
			_Au3_ScrapeInfo($url,$func, $desc, $usage,$notes)
			$desc=$desc&' | '&$notes&' | source: '&$url
			;_Help_Set($i,$func,$usage,$desc)
			Return True
		EndIf
	Next
	Return SetError(3,0,False)
EndFunc

Func _Au3_GetLinkUDF(ByRef $funcs,$func)
	Local $i=_ArraySearch($funcs,$func)
	If $i=-1 Then Return ""
	Return 'http://www.autoitscript.com/autoit3/docs/libfunctions/'&$funcs[$i]&'.htm'
EndFunc
Func _Au3_GetLink(ByRef $funcs,$func)
	Local $i=_ArraySearch($funcs,$func)
	If $i=-1 Then Return ""
	Return 'http://www.autoitscript.com/autoit3/docs/functions/'&$funcs[$i]&'.htm'
EndFunc

Func _Au3_ScrapeInfo($url,$func,ByRef $desc, ByRef $usage, ByRef $notes)
	Local $html=BinaryToString(InetRead($url))
	$html=StringReplace($html,"<br />","")
	$html=StringReplace(StringStripCR($html),@LF,' ')
	$html=StringReplace($html,'&nbsp;',' ')
	$html=StringReplace($html,'&gt;','>')
	$html=StringReplace($html,'&lt;','<')
	$desc=__SB0($html,'<p class="funcdesc">','</p>')
	$usage=__SB0($html,'<p class="codeheader">','</p>')
	$notes=__SB0($html,'<h2>Return Value</h2>','<h2>')

	$usage=StringRegExpReplace($usage,"#include\s*<([\w\.]+)>","{in \1 Library}")

	$notes=StringRegexpReplace($notes,"<[^>]+>"," ")
	$notes=StringStripWS($notes,1+2+4);leading, trailing, double.

	$usage=StringReplace($usage,$func,'')
EndFunc

Func __SB0(ByRef $in, $begin, $end)
	Local $arr=_StringBetween($in,$begin,$end)
	If IsArray($arr) Then Return SetError(0,0,$arr[0])
	Return SetError(1,0,'')
EndFunc