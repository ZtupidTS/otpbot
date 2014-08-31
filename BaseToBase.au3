#include <Array.au3>
#include <String.au3>

Global $BaseDefaultCharset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~'

Global $Base29[29]=['F','U','TH','O','R','K','G','W','H','N','I','J','EO','P','X','S','T','B','E','M','L','NG','OE','D','A','AE','Y','IA','EA']
Global $Base30[30]=['-','F','U','TH','O','R','K','G','W','H','N','I','J','EO','P','X','S','T','B','E','M','L','NG','OE','D','A','AE','Y','IA','EA']

Global $Base[86]
For $b = 2 To 85
	$Base[$b] = StringLeft($BaseDefaultCharset, $b)
	If $b = 15 Then $Base[$b] = '0123456789ABCD*'
	If $b = 26 Then $Base[$b] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	If $b = 29 Then $Base[$b] = $Base29
	If $b = 30 Then $Base[$b] = $Base30
	If $b = 64 Then $Base[$b] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
Next



;MsgBox(0,0,BaseToString('0110100001100101',2))

Func StringToBase($s,$to)
	Local $o=''
	For $i=1 To StringLen($s)
		Local $byte=BaseToBase(Asc(StringMid($s,$i,1)), 10, $to)
		If $to=2 Then $byte=_StringRepeat('0',8-StringLen($byte))&$byte
		$o&=$byte
		If $to<>16 Then $o&=' '
	Next
	Return $o
EndFunc
Func BaseToString($s,$from)
	$s=StringStripWS($s,1+2+4)
	Local $isSpaced=StringInStr($s,' ')>1
	Local $o=''

;MsgBox(0,$isSpaced,$from)
	If $from=2 And (Not $isSpaced) Then
		;ConsoleWrite("x")
		For $i=1 To StringLen($s) Step 8
			Local $byte=StringMid($s,$i,8)
			;ConsoleWrite($byte&@CRLF)
			$o&=Chr(BaseToDec($byte,$from))
		Next
	Else
		Local $a=StringSplit($s,' ',2)
		For $byte In $a
			$o&=Chr(BaseToDec($byte,$from))
		Next
	EndIf

	Return $o
EndFunc



Func DecToBase($d, $b = 32)
	If $b=1 Then Return _StringRepeat('1',$d)
	Return __itoa($d, $Base[$b])
EndFunc   ;==>DecToBase
Func BaseToDec($s, $b = 32)
	Local $bCaseSense = False
	If $b > 36 Then $bCaseSense = True
	Return __atoi($s, $Base[$b], $bCaseSense)
EndFunc   ;==>BaseToDec
Func BaseToBase($s, $b1 = 32, $b2 = 32)
	If $b1=$b2 Then Return $s
	If $b1=10 Then Return DecToBase($s, $b2)
	If $b2=10 Then Return BaseToDec($s,$b1)
	Return DecToBase(BaseToDec($s, $b1), $b2)
EndFunc   ;==>BaseToBase
Func Charset($b)
	Return $Base[$b]
EndFunc   ;==>Charset



Func __atoax($sIntegerA, $sCharsetA, $sCharsetB, $iCaseSense = 0); changes an integer in one set to a different set
	Local $i = __atoi($sIntegerA, $sCharsetA, $iCaseSense)
	If @error <> 0 Then Return SetError(@error, 1, '')
	Local $s = __itoa($i, $sCharsetB)
	Return SetError(@error, 0, $s)
EndFunc   ;==>__atoa


Func __itoa($iInteger, $vCharset = '0123456789', $fOutputString = True); NOTE: this function assumes the Most-significant char is on the left!
	Local $bNeg = $iInteger < 0
	If $bNeg Then $iInteger = -$iInteger

	Local $iCharsetStart = 0
	If IsArray($vCharset) = 0 Then
		$vCharset = StringSplit($vCharset, '')
		$iCharsetStart = 1
	EndIf
	Local $iCharsetLen = UBound($vCharset)
	Local $iCharsetRadix = $iCharsetLen - $iCharsetStart
	If $iCharsetRadix < 2 Then Return SetError(1, 0, '')
	If $iInteger < 0 Then $iInteger = -$iInteger;make iInteger positive, not sure if this is faster than just ABS'ing it.

	Local $sInteger = ''
	Local $aInteger[1] = [0]
	Local $iArrayDim = 1
	Do
		Local $remainder = Mod($iInteger, $iCharsetRadix)
		$iInteger = Int($iInteger / $iCharsetRadix)

		;If ($remainder+$iCharsetStart)<0 Or ($remainder+$iCharsetStart)>($iCharsetLen-1) Then
		;	MsgBox(0,$remainder&'/'&$iCharsetLen,'F('&$iInteger&','&$vCharset&','&$fOutputString&')')
		;EndIf

		Local $sDigit = $vCharset[$remainder + $iCharsetStart]

		If $fOutputString Then
			;prepend digits
			$sInteger = $sDigit & $sInteger
		Else
			;there's no great way to prepend an array, so lets append and reverse later
			If $iArrayDim > 1 Then ReDim $aInteger[$iArrayDim]
			$aInteger[$iArrayDim - 1] = $sDigit
			$iArrayDim += 1
		EndIf
	Until $iInteger = 0

	If $fOutputString Then
		If StringLen($sInteger) < 1 Then $sInteger = $iCharsetStart[$iCharsetStart]
		If $bNeg Then Return '-' & $sInteger
		Return $sInteger
	Else
		_ArrayReverse($aInteger)
		Return $aInteger
	EndIf
EndFunc   ;==>__itoa

Func __atoi($vInteger, $vCharset, $iCaseSense = 0); NOTE: this function assumes the Most-significant char is on the left!
	Local $bNeg = StringLeft($vInteger, 1) == '-'
	If $bNeg Then $vInteger = StringTrimLeft($vInteger, 1)


	Local $iInteger = 0, $iIntegerStart = 0, $iCharsetStart = 0
	If IsArray($vInteger) = 0 Then
		$vInteger = StringSplit($vInteger, '')
		$iIntegerStart = 1
	EndIf
	If IsArray($vCharset) = 0 Then
		$vCharset = StringSplit($vCharset, '')
		$iCharsetStart = 1
	EndIf
	Local $iIntegerLen = UBound($vInteger)
	Local $iCharsetLen = UBound($vCharset)
	Local $iIntegerMax = $iIntegerLen - 1
	Local $iCharsetRadix = $iCharsetLen - $iCharsetStart
	If $iCharsetRadix < 2 Then Return SetError(1, 0, 0); array does not have 2 entries from start position

	For $i = $iIntegerStart To $iIntegerMax
		Local $iPower = $iIntegerMax - $i
		Local $cIntChar = $vInteger[$i]
		Local $iCharVal = _ArraySearch($vCharset, $cIntChar, $iCharsetStart, 0, $iCaseSense) - $iCharsetStart
		If $iCharVal < 0 Then Return SetError(2, Asc($cIntChar), 0); would only happen if part of sInt isn't in the Charset
		Local $iValue = $iCharVal * ($iCharsetRadix ^ $iPower)
		$iInteger += $iValue
	Next
	If $bNeg Then Return -$iInteger
	Return $iInteger
EndFunc   ;==>__atoi