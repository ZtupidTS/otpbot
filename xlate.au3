#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.6.1
 Author:         myName

 Script Function:
	Template AutoIt script.

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include <String.au3>
#include "GeneralCommands.au3"

_Help_RegisterGroup("Xlate")
_Help_RegisterCommand("xhex","<hex digits>","Converts hex data to a string.  Similar to inbuilt %!%_HexToString or %!%BinaryToString but allows spacing.")
_Help_RegisterCommand("xdec","<decimal bytes>","Converts decimal bytes to a string.  Alias: %!%xascii.  Example: %!%xdec 68 82 79 80  results in `DROP`")






Func COMMANDV_xhex($h)
	$h=StringStripWS($h,8)
	Local $o=""
	If Not (Mod(StringLen($h),2)=0) Then
		$o&="(Odd Length - 1 digit cut) "
		$h=StringTrimRight($h,1)
	EndIf
	$o&=_HexToString($h)
	Return $o
EndFunc
Func COMMANDV_xascii($d)
	$d=StringStripWS($d,1+2+4)
	$arr=StringSplit($d," ",2)
	Local $o=""
	For $asc In $arr
		$o&=Chr($asc)
	Next
	Return $o
EndFunc
Func COMMANDV_xdec($d)
	Return COMMANDV_xascii($d)
EndFunc