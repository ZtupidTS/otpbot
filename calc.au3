#cs ----------------------------------------------------------------------------

	AutoIt Version: 3.3.6.1
	Author:         crashdemons

	Script Function:
	Simple expression calculation wrapper for using Execute() safely

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

Global Const $srQuote = '["' & "']"
Global Const $srSlash = '[\\/]'
Global Const $srNQuote = '[^"' & "']"
Global Const $srNSlash = '[^\\/]'

Local $_Calc_Whitelist[97] = [ _
		'factor', 'StringToBinary', 'TCPNameToIP', 'TCPIpToName',
		'BaseToBase',
		'Degree', 'Radian',
		'vargettype', 'timerinit', 'timerdiff',
		'binarytostring', 'binarylen', 'binarymid', 'UBound',
		'ArrayToString', 'ArrayAdd', 'ArrayDelete', 'ArraySearch', 'ArraySort', 'ArrayPop', 'ArrayPush',
		'stringtohex', 'hextostring', 'stringreverse', 'stringencrypt',
		'StringSplit', 'stringinstr', 'stringformat', 'Stringlower', 'stringupper',
		'stringlen', 'stringlower', 'stringleft', 'stringright', 'stringtrimleft',
		'stringtrimright', 'stringmid', 'stringregexp', 'stringreplace', 'stringregexpreplace','stringreverse',
		'binary', 'string', 'float', 'while', 'return', 'fraction',
		'bitand', 'bitnot', 'bitor', 'bitrotate', 'bitshift', 'bitxor',
		'srandom', 'string', 'number', 'random', 'round', 'floor', 'ceiling', 'false', 'Default',
		'reduce', 'frac', 'comb', 'perm', 'fact', 'void', 'asin', 'acos', 'atan', 'sqrtV', 'sqrt', 'true',
		'int', 'gcf', 'chrw', 'chr', 'asc', 'dec', 'hex', 'mod', 'abs', 'exp', 'log',
		'sin', 'cos', 'tan', 'min', 'max',
		'not', 'and', 'or', ''
		]


Func COMMANDX_Cstr($who, $where, $what, $acmd)
	$s = StringTrimLeft($what, StringInStr($what, " "))
	Return _Calc_Sanitize($s)
EndFunc   ;==>COMMANDX_Cstr
Func COMMANDX_Calc($who, $where, $what, $acmd)
	$s = StringTrimLeft($what, StringInStr($what, " "))
	Return _Calc_Evaluate($s)
EndFunc   ;==>COMMANDX_Calc



Func _Calc_Evaluate($s)
	Local $ret = Execute(_Calc_Sanitize($s))
	Local $err = @error
	Local $ext = @extended
	Local $typ = VarGetType($ret)

	If $err <> 0 Then Return SetError(3, $err, 'Expression Syntax Incorrect');since we only allow simple expressions, this can only be an input error.
	If $ext <> 0 Then Return SetError(0, $ext, StringFormat("(%s) %s | extended=%s", $typ, $ret, $ext))
	Return SetError(0, 0, StringFormat("(%s) %s", $typ, $ret))
EndFunc   ;==>_Calc_Evaluate


Func _Calc_Sanitize($s)
	Local $srSimple = '^(\-|\+|\*|/|\^|\&|<|>|=|[0-9.]|\(|\)|\s)+$';numbers, operators and parenthesis. no functions or variables.
	If StringRegExp($s, $srSimple) Then Return $s; expression is already safe.

	Local $isReference = False
	Local $isString = False
	Local $stReference = ""
	Local $chStringEnd = ""
	Local $stSanitized = ""

	For $i = 1 To StringLen($s)
		Local $c = StringMid($s, $i, 1)
		If $c = '"' Or $c = "'" Then; toggling string mode, which exempts characters from filtering.
			If $isString Then
				If $c = $chStringEnd Then $isString = False
			Else
				$chStringEnd = $c
				$isString = True
			EndIf
		EndIf
		If Not $isString Then
			If (Not $isReference) And _Calc_IsLetter($c) Then $isReference = True; starting a reference - functions have to start with letters.
			If $isReference And (Not _Calc_IsRefChr($c)) Then
				$isReference = False;				ending a reference
				$stSanitized &= _Calc_Whitelist($stReference)
				$stReference = ""
			EndIf
			If $isReference Then
				$stReference &= $c
				ContinueLoop
			EndIf
		EndIf
		$stSanitized &= $c
	Next
	If $isReference Then $stSanitized &= _Calc_Whitelist($stReference); reference was not followed by a symbol
	Return $stSanitized
EndFunc   ;==>_Calc_Sanitize

Func _Calc_Whitelist($sRef)
	For $i = 1 To UBound($_Calc_Whitelist) - 1
		If $_Calc_Whitelist[$i] = $sRef Then Return $sRef
	Next
	Return "_REF_" & $sRef; prefixing with _REF_ invalidates functions and variables unless we actually define it.
EndFunc   ;==>_Calc_Whitelist

Func _Calc_IsRefChr(ByRef $c)
	Return StringRegExp($c, '^[a-zA-Z0-9_]$')
EndFunc   ;==>_Calc_IsRefChr
Func _Calc_IsLetter(ByRef $c)
	Return StringRegExp($c, '^[a-zA-Z]$')
EndFunc   ;==>_Calc_IsLetter

Func _Calc_MakeLiteral($s)
	If StringRegExp($s,"^-?[0-9]+(\.[0-9]+)?$") Then Return $s
	$s='"'&StringReplace($s, '"',  '"&Chr(34)&"')&'"'
	$s=StringReplace($s,@CR,'"&Chr(13)&"')
	$s=StringReplace($s,@LF,'"&Chr(10)&"')
	Return $s
EndFunc

;------------------------------



