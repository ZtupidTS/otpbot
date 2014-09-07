#cs ----------------------------------------------------------------------------

	AutoIt Version: 3.3.6.1
	Author:         crashdemons

	Script Function:
	Simple expression calculation wrapper for using Execute() safely

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include-once
#include "GeneralCommands.au3"
#include "ArrayEx.au3"

Global Const $srQuote = '["' & "']"
Global Const $srSlash = '[\\/]'
Global Const $srNQuote = '[^"' & "']"
Global Const $srNSlash = '[^\\/]'

Global $_Calc_Whitelist[1]=[''];whitelist nothing by default if nothing gets loaded - prevent array errors.

Global $_Calc_HangTimer=0
Global $_Calc_HangLimit=60*1000
Global $_Calc_HangExec=''

;------------------------------------
Local $_Calc_Commands[3][3]=[ _
["calc","<AutoIt or Numeric Expression>","Performs a calculation or executes an expression. Input strings are sanitized against a whitelist of function names."], _
["calc_sanitize","<AutoIt or Numeric Expression>","Sanitizes an expression against a whitelist of function names and returns the sanitized version. Used to debug expressions. See `%!%help calc`"], _
["calc_dump","<AutoIt or Numeric Expression>","Performs a calculation or executes an expression like %!%CALC, but with full type information and formatting."]  ]



_Calc_Startup()
_Help_RegisterGroup('General','','_Calc_Commands')

#include "convert.au3"
;------------------------------------

Func _REF_TakeTooMuchTime()
	Sleep(10*60*1000)
EndFunc


Func _Calc_Startup()
	If IsDeclared('CALC_STARTUP') Then Return
	Assign('CALC_STARTUP',1,2)
	AdlibRegister('_Calc_HangDetector',1000)

	Global $_Calc_Whitelist
	_Calc_LoadWhitelist($_Calc_Whitelist, "calc_whitelist.txt")
	_ArraySort($_Calc_Whitelist);sort the array alphabetically.
	_Calc_SaveWhitelist($_Calc_Whitelist, "calc_whitelist.txt");save alphabetically sorted version
EndFunc

Func _Calc_HangDetector()
	If $_Calc_HangTimer<>0 And TimerDiff($_Calc_HangTimer)>$_Calc_HangLimit Then
		Execute($_Calc_HangExec)
		Exit
	EndIf
EndFunc
Func _Calc_StartHangTimer()
	$_Calc_HangTimer=TimerInit()
EndFunc
Func _Calc_StopHangTimer()
	$_Calc_HangTimer=0
EndFunc




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




Func COMMANDX_Calc($who, $where, $what, $acmd)
	$s = StringTrimLeft($what, StringInStr($what, " "))
	Return _Calc_Evaluate($s)
EndFunc   ;==>COMMANDX_Calc
Func COMMANDX_Calc_sanitize($who, $where, $what, $acmd)
	$s = StringTrimLeft($what, StringInStr($what, " "))
	Return _Calc_Sanitize($s)
EndFunc   ;==>COMMANDX_Cstr
Func COMMANDX_Calc_dump($who, $where, $what, $acmd)
	$s = StringTrimLeft($what, StringInStr($what, " "))
	Return _Calc_Evaluate($s,'full')
EndFunc   ;==>COMMANDX_Calc



Func _Calc_Evaluate($s,$fmtstyle='default')
	Local $style=$ArrayFmt_Default
	If $fmtstyle='quick' Then $style=$ArrayFmt_Quick
	If $fmtstyle='full' Then $style=$ArrayFmt_Full

	_Calc_StartHangTimer()
	Local $san=_Calc_Sanitize($s)
	Local $ret = Execute($san)
	Local $err = @error
	Local $ext = @extended
	_Calc_StopHangTimer()
	;Local $typ = VarGetType($ret)
	Local $fmt=_ValueFmt($ret,$style)

	If $err <> 0 Then Return SetError(3, $err, 'Expression Syntax Incorrect: '&$san)
	If $ext <> 0 Then Return SetError(0, $ext, StringFormat($fmt&" | extended=%s", $ext))
	;Return SetError(0, 0, StringFormat("(%s) %s", $typ, $ret))
	Return SetError(0,0,$fmt)
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



