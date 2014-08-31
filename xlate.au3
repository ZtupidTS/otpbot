#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.6.1
 Author:         myName

 Script Function:
	Template AutoIt script.

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include <String.au3>
#include "GeneralCommands.au3"
#include "BaseToBase.au3"
#include "Base32.au3"
#include "Base64.au3"

_Help_RegisterGroup("Xlate")

_Help_RegisterCommand("base2base","<from base A> <to base B> <integer in baseA>","Converts an integer string from BaseA to BaseB. Note: does not accept spaces.  Example %!%base2base 10 8 123 outputs `173` as it converted decimal to octal.  Note: only Base 2-64 supported [without encoding].")
;_Help_RegisterCommand("string2base","<to base B> <integer in baseA>","Converts a string from Base256 to BaseB. Example %!%string2base 10 8 123 outputs `173` as it converted decimal to octal.  Note: only Base 2-64 supported [without encoding].")


_Help_RegisterCommand("BinD","<binary digits>","Converts binary digits to a string.  Note: If you include spaces, these are used for byte separation.  Without spaces, 8-bit encoding is assumed.  Use %!%BinE to encode.")
_Help_RegisterCommand("BinE","<string>","Converts a string to binary digits. Use %!%binD to decode.")

_Help_RegisterCommand("OctE","<text>","Converts a string to octal data. Use %!%octD to decode")
_Help_RegisterCommand("OctD","<octal bytes>","Converts octal data to a string. Use %!%octE to encode.")



_Help_RegisterCommand("DecD","<decimal bytes>","Converts decimal bytes to a string.   Example: %!%decd 68 82 79 80  results in `DROP` Deprecated aliases: %!%xascii, %!%xdec")
_Help_RegisterCommand("DecE","<string>","Converts a string to decimal bytes. Equivalent to perfoming %!%Asc on each character. Only supports values 0-255. Decode with %!%decd.")

_Help_RegisterCommand("HexD","<hex digits>","Converts hex data to a string.  Similar to inbuilt %!%_HexToString or %!%BinaryToString but allows spacing. Deprecated aliases: %!%xhex. Encode with %!%hexe")
_Help_RegisterCommand("HexE","<string>","Converts a string to hex data.  Alias for inbuilt command %!%_StringToHex.  Decode with %!%hexd.")



_Help_RegisterCommand("B32e","<text>","Converts a string to the base32 data encoding. Use %!%B32d to decode")
_Help_RegisterCommand("B32d","<base32string>","Converts base32 data encoding to a string. use %!%B32e to encode.")

_Help_RegisterCommand("B64e","<text>","Converts a string to the base32 data encoding. Use %!%B64d to decode")
_Help_RegisterCommand("B64d","<base64string>","Converts base32 data encoding to a string. use %!%B64e to encode.")



Func COMMAND_base2base($from,$to, $integer)
	Return BaseToBase($integer, $from,$to)
EndFunc
;Func COMMAND_string2base($to, $integer)
;	BaseToBase($integer, $from,$to)
;EndFunc

Func COMMANDV_bind($s)
	Return BaseToString($s,2)
EndFunc
Func COMMANDV_bine($s)
	Return StringToBase($s,2)
EndFunc



Func COMMANDV_octd($s)
	Return BaseToString($s,8)
EndFunc
Func COMMANDV_octe($s)
	Return StringToBase($s,8)
EndFunc




Func COMMANDV_decd($h)
	Return COMMANDV_xdec($h)
EndFunc
Func COMMANDV_dece($s)
	Return StringToBase($s,10)
EndFunc



Func COMMANDV_hexd($h)
	Return COMMANDV_xhex($h)
EndFunc
Func COMMANDV_hexe($s)
	Return _StringToHex($s)
EndFunc

Func COMMANDV_B32d($s)
	Return _Base32_DecodeP($s)
EndFunc
Func COMMANDV_B32e($s)
	Return _Base32_EncodeP($s)
EndFunc

Func COMMANDV_B64e($s)
	Return _Base64Encode($s)
EndFunc
Func COMMANDV_B64d($s)
	Return _Base64Decode($s)
EndFunc






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