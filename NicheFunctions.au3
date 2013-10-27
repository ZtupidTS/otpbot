#include <String.au3>
#include <Array.au3>
#include "GeneralCommands.au3"
_Help_RegisterGroup("Niche")
_Help_Register("Worm","<5gram entries>","Decodes 5gram messages using the OTP22 Green Book QR-Code table.  eg: `worm FNAIU YPBIE`")
_Help_Register("ZTime","<date string>","Attempts to present PRJMLPL-style date codes in a readable format. eg: `ztime 31125959Z`")
_Help_Register("ITA2","<binary string>","Decodes ITA2 bits into a string. eg: `ITA2 10100001101101110000` (see http://en.wikipedia.org/wiki/Baudot_code#ITA2 )")
_Help_Register("ITA2S","<binary string>","Decodes ITA2 bits into strings using various bit shifts on the input. See `help ita2` for more information.")
_Help_Register("Ternary","<condition> <value A> <value B>","Performs a ternary operation. Note: all condition strings except for 0 and empty (blank parameter) evaluate to True internally.   eg: `ternary 1 a b` or `ternary 0 a b`")
_Help_Register("LengthsToBits","<numeric string> [flip]","Translates a list of single-digit bit lengths into a binary string.  That is, every digit (`length`) represents the number of bits to print, and the value (1 or 0) alternates with each length.  If the `flip` paramter is given (as 1) then the binary string will be inverted in value.  eg: `lengthstobits 4412 1`")
_Help_Register("FlipBits","<binary string>","Inverts a binary string switching 1's and 0's similar to a binary NOT operation.  eg: `flipbits 1011`")


Func COMMANDX_Worm($who, $where, $what, $acmd)
	Local $o = ""
	Local $PARAM_START=2; we're not transcluding that.
	For $i = $PARAM_START To UBound($acmd) - 1
		$o &= IniRead(@ScriptDir & "\worm.ini", "worm", $acmd[$i], "?")
	Next
	Return $o
EndFunc   ;==>COMMANDX_Worm

Func COMMAND_ztime($s)
	Return StringRegExpReplace($s, "Z?([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{0,2})Z?", "Zulu time: \2:\3:\4, day \1")
EndFunc   ;==>COMMAND_ztime
#endregion ;-----misc



#region ;--------ITA2 and bits

Func COMMAND_ITA2S($bits)
	Local $o = ""
	For $i = 0 To 4
		$o &= "Shift " & $i & ' ' & COMMAND_ITA2(_StringRepeat('0', $i) & $bits) & ' | '
	Next
	Return $o
EndFunc   ;==>COMMAND_ITA2S

Func COMMAND_ITA2($bits, $printmodes = 0)
	Local $figures = False
	Local $o = ""
	For $i = 1 To StringLen($bits) Step 5
		$o &= ITA2_Byte(StringMid($bits, $i, 5), $figures, $printmodes)
	Next
	Return $o
EndFunc   ;==>COMMAND_ITA2

Func ITA2_Byte($5bits, ByRef $figures, $printmodes = 0)
	Switch $5bits
		Case '00000'
			Return '[NULL]'
		Case '00100'
			Return '_'
		Case '10111'
			Return COMMAND_Ternary(Not $figures, 'Q', '1')
		Case '10011'
			Return COMMAND_Ternary(Not $figures, 'W', '2')
		Case '00001'
			Return COMMAND_Ternary(Not $figures, 'E', '3')
		Case '01010'
			Return COMMAND_Ternary(Not $figures, 'R', '4')
		Case '10000'
			Return COMMAND_Ternary(Not $figures, 'T', '5')
		Case '10101'
			Return COMMAND_Ternary(Not $figures, 'Y', '6')
		Case '00111'
			Return COMMAND_Ternary(Not $figures, 'U', '7')
		Case '00110'
			Return COMMAND_Ternary(Not $figures, 'I', '8')
		Case '11000'
			Return COMMAND_Ternary(Not $figures, 'O', '9')
		Case '10110'
			Return COMMAND_Ternary(Not $figures, 'P', '0')
		Case '00011'
			Return COMMAND_Ternary(Not $figures, 'A', '-')
		Case '00101'
			Return COMMAND_Ternary(Not $figures, 'S', '[BELL]')
		Case '01001'
			Return COMMAND_Ternary(Not $figures, 'D', '$')
		Case '01101'
			Return COMMAND_Ternary(Not $figures, 'F', '!')
		Case '11010'
			Return COMMAND_Ternary(Not $figures, 'G', '&')
		Case '10100'
			Return COMMAND_Ternary(Not $figures, 'H', '#')
		Case '01011'
			Return COMMAND_Ternary(Not $figures, 'J', "'")
		Case '01111'
			Return COMMAND_Ternary(Not $figures, 'K', '(')
		Case '10010'
			Return COMMAND_Ternary(Not $figures, 'L', ')')
		Case '10001'
			Return COMMAND_Ternary(Not $figures, 'Z', '"')
		Case '11101'
			Return COMMAND_Ternary(Not $figures, 'X', '/')
		Case '01110'
			Return COMMAND_Ternary(Not $figures, 'C', ':')
		Case '11110'
			Return COMMAND_Ternary(Not $figures, 'V', ';')
		Case '11001'
			Return COMMAND_Ternary(Not $figures, 'B', '?')
		Case '01100'
			Return COMMAND_Ternary(Not $figures, 'N', ',')
		Case '11100'
			Return COMMAND_Ternary(Not $figures, 'M', '.')
		Case '01000'
			Return COMMAND_Ternary(Not $figures, '[CR]', '[CR]')
		Case '00010'
			Return COMMAND_Ternary(Not $figures, '[LF]', '[LF]')
		Case '11011'
			$figures = True
			If Int($printmodes) Then Return '[FIGS]'
		Case '11111'
			$figures = False
			If Int($printmodes) Then Return '[LTRS]'
		Case Else
			Return " [Fragment bits=" & $5bits & "]"
	EndSwitch
	Return ''
EndFunc   ;==>ITA2_Byte

Func COMMAND_Ternary($cond, $a, $b)
	If $cond Then Return $a
	Return $b
EndFunc   ;==>COMMAND_Ternary

Func COMMAND_lengthstobits($l, $flip = 0)
	Local $b = ""
	For $i = 1 To StringLen($l)
		For $j = 1 To Int(StringMid($l, $i, 1))
			$b &= Mod($i, 2)
		Next
	Next
	If $flip Then Return COMMAND_flipbits($b)
	Return $b
EndFunc   ;==>COMMAND_lengthstobits
Func COMMAND_flipbits($b)
	Local $o = ""
	For $i = 1 To StringLen($b)
		$o &= Mod(StringMid($b, $i, 1) + 1, 2)
	Next
	Return $o
EndFunc   ;==>COMMAND_flipbits



#endregion ;--------ITA2 and bits