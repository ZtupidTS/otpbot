#include-once
;http://www.autoitscript.com/autoit3/docs/functions/
#include <Array.au3>
#include "HTTP.au3"
;#include "GeneralCommands.au3"
#include "calc.au3"

;Opt('TrayIconDebug',1)
Global $_Au3_Funcs[1]=['']
Global $_Udf_Funcs[1]=['']

Global $_Au3_Commands=''
Global $_Udf_Commands=''




;; TODO:  Updating help entries via callback


Func _Au3_HelpCallBack($command,$subcommand='')
	Local $iAU3=_ArraySearch($_Au3_Commands,$command,0,0,0,0,1,0)
	Local $iUDF=_ArraySearch($_Udf_Commands,$command,0,0,0,0,1,0)
	ConsoleWrite($command&' '&$iAU3&' '&$iUDF&@CRLF)
	If $iAU3<0 And $iUDF<0 Then Return ''; no indexes match - Not an AutoIt command.
	If StringLen($subcommand) Then Return "No help available for subcommand `"&$subcommand&"` available."
	Local $fmtHelp="%s %s - %s"
	Local $cmd, $usg, $dsc
	If $iAU3>=0 Then; AU3 match!
		If $_Au3_Commands[$iAU3][2]="###autoit###" Then _Au3_UpdateHelpEntry($iAU3)
		$cmd=$_Au3_Commands[$iAU3][0]
		$usg=$_Au3_Commands[$iAU3][1]
		$dsc=$_Au3_Commands[$iAU3][2]
	Else; UDF match!
		If $_Udf_Commands[$iUDF][2]="###udf###" Then _Au3_UpdateHelpEntryUDF($iUDF)
		$cmd=$_Udf_Commands[$iUDF][0]
		$usg=$_Udf_Commands[$iUDF][1]
		$dsc=$_Udf_Commands[$iUDF][2]
	EndIf
	Return '%!%'&StringFormat($fmtHelp,$cmd,$usg,$dsc)
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
Func _Au3_UpdateHelpEntry($i)
	Local $sfunc=$_Au3_Commands[$i][0]
	Local $url=_Au3_GetLink($_Au3_Funcs,$sfunc)
	ConsoleWrite($i&' '&$sfunc&' '&$url&@CRLF)
	If $url="" Then Return SetError(2,0,False)

	Local $desc,$usage,$notes
	_Au3_ScrapeInfo($url,$sfunc, $desc, $usage,$notes)
	$desc=$desc&' | '&$notes&' | source: '&$url

	$_Au3_Commands[$i][1]=$usage
	$_Au3_Commands[$i][2]=$desc
	Return True
EndFunc
Func _Au3_UpdateHelpEntryUDF($i)
	Local $sfunc=$_Udf_Commands[$i][0]
	Local $url=_Au3_GetLinkUDF($_Udf_Funcs,$sfunc)
	ConsoleWrite($i&' '&$sfunc&' '&$url&@CRLF)
	If $url="" Then Return SetError(2,0,False)

	Local $desc,$usage,$notes
	_Au3_ScrapeInfo($url,$sfunc, $desc, $usage,$notes)
	$desc=$desc&' | '&$notes&' | source: '&$url

	$_Udf_Commands[$i][1]=$usage
	$_Udf_Commands[$i][2]=$desc
	Return True
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