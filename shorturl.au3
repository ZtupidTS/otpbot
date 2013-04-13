#include <String.au3>
#include-once

Global $_ShortUrl_Max=100
Global $_ShortUrl_Idx=0




Func COMMAND_tinyurl($url)
	Return _ShortUrl_Retrieve($url)
EndFunc

Func _ShortUrl_Startup()
	Global $_ShortUrl_Idx
	FileChangeDir(@ScriptDir)
	$_ShortUrl_Idx=IniRead("shorturl.ini","info","idx",0)
EndFunc

Func _ShortUrl_Cache($url,$short)
	If StringLen($short)=0 Then Return
	ConsoleWrite("CCH: "&$short&' '&$url&@CRLF)
	IniWrite("shorturl.ini","cache",$_ShortUrl_Idx&'U',__SU_URIEncode($url))
	IniWrite("shorturl.ini","cache",$_ShortUrl_Idx&'S',_StringToHex($short))
	$_ShortUrl_Idx=Mod($_ShortUrl_Idx+1,$_ShortUrl_Max)
	IniWrite("shorturl.ini","info","idx",$_ShortUrl_Idx)
EndFunc
Func _ShortUrl_Retrieve($url)
	$UE_url=__SU_URIEncode($url)
	Local $short=""
	For $i=0 To $_ShortUrl_Max-1
		Local $cache=IniRead("shorturl.ini","cache",$i&'U','')
		If $cache="" Then ContinueLoop
		If $cache==$UE_url Then
			$short=_HexToString(IniRead("shorturl.ini","cache",$i&'S',''))
			ExitLoop
		EndIf
	Next
	If $short="" Then
		$short=_ShortUrl_Generate($url)
		ConsoleWrite("MIS: "&$short&' '&$url&@CRLF)
		If @error<>0 Or $short="" Then Return SetError(1,0,$url)
		_ShortUrl_Cache($url,$short)
		If StringLen($short)>=StringLen($url) Then Return SetError(2,0,$url)
		Return $short
	EndIf
	ConsoleWrite("HIT: "&$short&' '&$url&@CRLF)
	If StringLen($short)>=StringLen($url) Then Return SetError(2,0,$url)
	Return $short
EndFunc



Func _ShortUrl_Generate($url)
	$UE_url=__SU_URIEncode($url)
	;Local $s=InetRead("http://tinyurl.com/api-create.php?url="&$UE_url)
	Local $s=InetRead("http://is.gd/create.php?format=simple&url="&$UE_url)
	$s=StringStripWS(BinaryToString($s),8)
	If StringLeft($s,5)="http:" Then Return SetError(0,0, $s)
	Return SetError(1,0,'')
	;http://tinyurl.com/api-create.php?url=http://scripting.com/  Permalink to this paragraph
EndFunc


Func __SU_URIEncode($sData)
    ; Prog@ndy
    Local $aData = StringSplit(BinaryToString(StringToBinary($sData,4),1),"")
    Local $nChar
    $sData=""
    For $i = 1 To $aData[0]
        $nChar = Asc($aData[$i])
        Switch $nChar
            Case 45, 46, 48 To 57, 65 To 90, 95, 97 To 122, 126
                $sData &= $aData[$i]
            Case 32
                $sData &= "+"
            Case Else
                $sData &= "%" & Hex($nChar,2)
        EndSwitch
    Next
    Return $sData
EndFunc