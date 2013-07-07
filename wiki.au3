#include-once
#include <String.au3>
#include "shorturl.au3"



Func COMMANDX_wiki($who, $where, $what, $acmd)
	$page=StringMid($what,1+StringLen("@wiki "))
	Local $url="http://otp22.referata.com/w/index.php?title=Special%3ASearch&search="&__SU_URIEncode($page)&"&go=Go"
	Local $data=InetRead($url)
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
	Return "I couldn't find `"&$page&"` on the wiki. Try searching for it: "&COMMAND_tinyurl($url)
EndFunc


Func _Wiki_Link($canonical)
	Return 'http://otp22.referata.com'&$canonical&' (mirror: '&COMMAND_tinyurl('http://otp22.zoxid.com'&$canonical)&' )'
EndFunc

Func _Wiki_Name($s)
	$s=StringUpper(StringLeft($s,1))&StringMid($s,2)
	$s=StringReplace($s,' ','_')
	Return $s
EndFunc
