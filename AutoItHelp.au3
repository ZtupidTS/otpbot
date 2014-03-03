#include-once
;http://www.autoitscript.com/autoit3/docs/functions/
#include <Array.au3>
#include "HTTP.au3"
#include "GeneralCommands.au3"

Global $_Au3_Funcs[1]=['']

TCPStartup()
_Au3_Startup()




Func _Au3_Startup()
	Local $html=BinaryToString(InetRead('http://www.autoitscript.com/autoit3/docs/functions/'))
	$_Au3_Funcs=StringRegExp($html,"(?s)(\w+)\.htm",3)
	$_Au3_Funcs=_ArrayUnique($_Au3_Funcs)

	_Help_RegisterGroup('AutoIt')
	For $func In $_Au3_Funcs
		_Help_Register($func,'',"###autoit###")
	Next
EndFunc
Func _Au3_UpdateHelpEntry($i,$sfunc)
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

Func _Au3_GetLink(ByRef $funcs,$func)
	Local $i=_ArraySearch($funcs,$func)
	If $i=-1 Then Return ""
	Return 'http://www.autoitscript.com/autoit3/docs/functions/'&$funcs[$i]&'.htm'
EndFunc

Func _Au3_ScrapeInfo($url,$func,ByRef $desc, ByRef $usage, ByRef $notes)
	Local $html=BinaryToString(InetRead($url))
	$html=StringReplace($html,"<br />","")
	$html=StringReplace(StringStripCR($html),@LF,' ')
	$desc=__SB0($html,'<p class="funcdesc">','</p>')
	$usage=__SB0($html,'<p class="codeheader">','</p>')
	$notes=__SB0($html,'<h2>Return Value</h2>','<h2>')
	$usage=StringReplace($usage,$func,'')
EndFunc

Func __SB0(ByRef $in, $begin, $end)
	Local $arr=_StringBetween($in,$begin,$end)
	If IsArray($arr) Then Return SetError(0,0,$arr[0])
	Return SetError(1,0,'')
EndFunc