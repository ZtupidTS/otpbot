#cs ----------------------------------------------------------------------------

	AutoIt Version: 3.3.6.1
	Author:         crashdemons

	Script Function:
	Simple expression calculation wrapper for using Execute() safely

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include-once
#include "GeneralCommands.au3"


_Help_Register("calc","<AutoIt or Numeric Expression>","Performs a calculation or executes an expression. Input strings are sanitized against a whitelist of function names.")
_Help_Register("cstr","<AutoIt or Numeric Expression>","Sanitizes an expression against a whitelist of function names and returns the sanitized version. Used to debug expressions. See `%!%help calc`")


Global Const $srQuote = '["' & "']"
Global Const $srSlash = '[\\/]'
Global Const $srNQuote = '[^"' & "']"
Global Const $srNSlash = '[^\\/]'

Global $_Calc_Whitelist[256] = [ _
		'factor', 'StringToBinary', 'TCPNameToIP', 'TCPIpToName', _
		'BaseToBase', _
		'Degree', 'Radian', _
		'vargettype', 'timerinit', 'timerdiff', _
		'binarytostring', 'binarylen', 'binarymid', 'UBound', _
		'ArrayToString', 'ArrayAdd', 'ArrayDelete', 'ArraySearch', 'ArraySort', 'ArrayPop', 'ArrayPush', _
		'stringtohex', 'hextostring', 'stringreverse', 'stringencrypt', _
		'StringSplit', 'stringinstr', 'stringformat', 'Stringlower', 'stringupper', _
		'stringlen', 'stringlower', 'stringleft', 'stringright', 'stringtrimleft', _
		'stringtrimright', 'stringmid', 'stringregexp', 'stringreplace', 'stringregexpreplace','stringreverse', _
		'binary', 'string', 'float', 'while', 'return', 'fraction', _
		'bitand', 'bitnot', 'bitor', 'bitrotate', 'bitshift', 'bitxor', _
		'srandom', 'string', 'number', 'random', 'round', 'floor', 'ceiling', 'false', 'Default', _
		'reduce', 'frac', 'comb', 'perm', 'fact', 'void', 'asin', 'acos', 'atan', 'sqrtV', 'sqrt', 'true', _
		'int', 'gcf', 'chrw', 'chr', 'asc', 'dec', 'hex', 'mod', 'abs', 'exp', 'log', _
		'sin', 'cos', 'tan', 'min', 'max', _
		'not', 'and', 'or','StringStripWS', _
		'' ]
$_Calc_Whitelist=''
_Calc_LoadWhitelist($_Calc_Whitelist, "calc_whitelist.txt")
_ArraySort($_Calc_Whitelist);sort the array alphabetically.
;_ArrayDisplay($_Calc_Whitelist)
_Calc_SaveWhitelist($_Calc_Whitelist, "calc_whitelist.txt");save alphabetically sorted version
_ArraySort_UserDefined($_Calc_Whitelist, '__cmp_length', 0, -1, False); sort the array by length (shortest first) this is necessary to prevent overlapping matches.
;_ArrayDisplay($_Calc_Whitelist)
MsgBox(0,0,_Calc_Sanitize("string + stringregexp + exp"))

Func _Calc_LoadWhitelist(ByRef $arr, $filename)
	$filename=@ScriptDir&'\'&$filename
	Local $str=FileRead($filename)
	$str=StringStripCR($str)
	$arr=StringSplit($str,@LF,2);flag = 2, disable the return the count in the first element - effectively makes the array 0-based (must use UBound() to get the size in this case).

	Local $iEnd=UBound($arr)-1
	For $i=0 To $iEnd;remove invalid items from the array
		;ConsoleWrite($i&', end='&$iEnd&@CRLF)
		$arr[$i]=StringStripWS($arr[$i],1+2);1 = strip leading white space, 2 = strip trailing white space
		If $arr[$i]=""  Then;match blank lines ;;;and comment lines  Or StringLeft($arr[$i],1)='#'
			;ConsoleWrite('   del '&$i&', end='&$iEnd&@CRLF)
			_ArrayDelete($arr,$i)
			If $i=$iEnd Then ExitLoop
			$iEnd=UBound($arr)-1
			$i-=1; repeat this iteration on next loop since the other elements have moved up.
		EndIf
	Next
	;MsgBox(0,0,$str)
EndFunc

Func _Calc_SaveWhitelist(ByRef $arr, $filename); copy $arr to local scope.
	$filename=@ScriptDir&'\'&$filename
	Local $str=_ArrayToString($arr,@CRLF)
	Local $fh=FileOpen($filename,2); 2 = Write mode (erase previous contents)
	FileWrite($fh,$str)
	FileClose($fh)
EndFunc


Func _ArraySort_UserDefined(ByRef $a, $cmpfunc, $iStart=0, $iEnd=-1, $bEmptyStringTerminatesArray=False)
	; sorts an array based on a function $cmpfunc that takes two elements a,b
	; if the function returns +1, A is sorted down, if the function returns -1, A is sorted UP (relative to B)
	If $iEnd=-1 Then $iEnd=UBound($a)-1

	If $bEmptyStringTerminatesArray Then
		For $i=$iStart To $iEnd
			If $a[$i]="" Then
				$iEnd=$i-1; do not include the empty string in comparisons.
				ExitLoop
			EndIf
		Next
	EndIf

	Local $swaps
	Do
		$swaps=0
		For $i=$iStart To $iEnd-1; go to the next to last, since we compare two items iterated by 1 eg:  [12]34, 1[23]4, 12[34] ...
			If Call($cmpfunc,$a[$i],$a[$i+1])=1 Then
				_ArraySwap($a[$i],$a[$i+1]); sort A down from B, which really just swaps the items - since sorting UP leaves them in-order.
				$swaps+=1
			EndIf
		Next
	Until $swaps=0

EndFunc
Func __cmp_length($a,$b)
	If StringLen($a)>StringLen($b) Then Return -1
	Return +1
EndFunc


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

	Local $isNumber=False
	Local $isReference = False
	Local $isString = False
	Local $isMacro = False
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
			If (Not ($isNumber Or $isReference Or $isMacro)) And $c=="0" Then $isNumber=True; if starting with an 0, then we allow for hex chars exempt from filtering (functions can't start with 0)
			If $isNumber And (Not _Calc_IsHex($c)) Then $isNumber=False; end hex.

			If (Not ($isNumber Or $isReference Or $isMacro)) And $c=="@" Then $isMacro=True
			If $isMacro And (Not _Calc_IsMacroChr($c)) Then $isMacro=False;end macro


			If Not ($isNumber Or $isMacro) Then
				If (Not $isReference) And _Calc_IsLetter($c) Then $isReference = True; starting a reference - functions have to start with letters.
				If $isReference And (Not _Calc_IsRefChr($c)) Then;function letters were started, but encountering a non-reference symbol - end of the function name
					$isReference = False;				ending a reference
					$stSanitized &= _Calc_Whitelist($stReference)
					$stReference = ""
				EndIf
				If $isReference Then;next char of function name
					$stReference &= $c
					ContinueLoop;skip the per-char appending, collect our reference chars and sanitize before outputting them. (see above)
				EndIf
			EndIf
		EndIf
		$stSanitized &= $c
	Next
	If $isReference Then $stSanitized &= _Calc_Whitelist($stReference); reference was not followed by a symbol
	Return $stSanitized
EndFunc   ;==>_Calc_Sanitize

Func _Calc_Whitelist($sRef)
	For $i = 0 To UBound($_Calc_Whitelist) - 1
		If $_Calc_Whitelist[$i] = $sRef Then Return $sRef
	Next
	Return "_REF_" & $sRef; prefixing with _REF_ invalidates functions and variables unless we actually define it.
EndFunc   ;==>_Calc_Whitelist
Func _Calc_IsMacroChr(ByRef $c)
	Return StringRegExp($c, '^[@a-zA-Z0-9_]$')
EndFunc   ;==>_Calc_IsRefChr
Func _Calc_IsRefChr(ByRef $c)
	Return StringRegExp($c, '^[a-zA-Z0-9_]$')
EndFunc   ;==>_Calc_IsRefChr
Func _Calc_IsLetter(ByRef $c)
	Return StringRegExp($c, '^[a-zA-Z]$')
EndFunc   ;==>_Calc_IsLetter
Func _Calc_IsHex(ByRef $c)
	Return StringRegExp($c, '^[0123456789abcdefABCDEFx]$')
EndFunc   ;==>_Calc_IsLetter

Func _Calc_MakeLiteral($s)
	If StringRegExp($s,"^-?[0-9]+(\.[0-9]+)?$") Then Return $s
	$s='"'&StringReplace($s, '"',  '"&Chr(34)&"')&'"'
	$s=StringReplace($s,@CR,'"&Chr(13)&"')
	$s=StringReplace($s,@LF,'"&Chr(10)&"')
	Return $s
EndFunc

;------------------------------



