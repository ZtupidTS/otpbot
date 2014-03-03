#include-once
;http://www.autoitscript.com/autoit3/docs/functions/
#include <Array.au3>
#include "HTTP.au3"
#include "GeneralCommands.au3"

;Opt('TrayIconDebug',1)
Global $_Au3_Funcs[1]=['']
Global $_Udf_Funcs[1]=['']

;TCPStartup()
;_Au3_Startup()




Func _Au3_Startup (ByRef $commands,ByRef $usage,ByRef $desc)
	$_Au3_Funcs=StringSplit(StringStripCR(FileRead(@ScriptDir&"\functions.txt")),@LF,2)
	$_Udf_Funcs=StringSplit(StringStripCR(FileRead(@ScriptDir&"\libfunctions.txt")),@LF,2)
	;_ArrayDisplay($_Au3_Funcs)

	Local $size=UBound($_Au3_Funcs)+UBound($_Udf_Funcs)+5
	Local $cmd[$size]
	Local $usg[$size]
	Local $dsc[$size]
	$cmd[1]="GRP:AutoIt"
	Local $n=2
	Local $nStart=$n
	For $i=0 To UBound($_Au3_Funcs)-1
		;ConsoleWrite($i&'/'&$size&@CRLF)
		$cmd[$i+$nStart]=$_Au3_Funcs[$i]
		$dsc[$i+$nStart]="###autoit###"
		$n+=1
		;_Help_Register($func,'',"###autoit###")
	Next
	$cmd[$n]="GRP:UDF"
	$n+=1
	$nStart=$n
	For $i=0 To UBound($_Udf_Funcs)-1
		;ConsoleWrite($i&'/'&($i+$nStart)&'/'&$size&@CRLF)
		$cmd[$i+$nStart]=$_Udf_Funcs[$i]
		$dsc[$i+$nStart]="###udf###"
		$n+=1
		;_Help_Register($func,'',"###autoit###")
	Next
	$cmd[$n]="GRP:General"
	$commands=$cmd
	$usage=$usg
	$desc=$dsc
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
			_Help_Set($i,$func,$usage,$desc)
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
			_Help_Set($i,$func,$usage,$desc)
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