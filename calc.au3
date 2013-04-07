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

Func COMMAND_Calc($s)
	Local $srSimple='^(\-|\+|\*|/|\^|\&|<|>|=|[0-9.]|\(|\)|\s)+$';numbers, operators and parenthesis. no functions or variables.
	Local $isValueExpr=(StringRegExp($s, '^[\+\-]?[0-9.]+$') Or StringRegExp($s, '^\s*' & $srQuote & $srNQuote & '*' & $srQuote & '\s*$'));numeric or quoted literals are not allowed as entire expressions: their evaluations are trivial.
	Local $isSimpleExpr=StringRegExp($s,$srSimple)

	If     $isValueExpr  Then Return SetError(1,0,'Literal Expression')
	If Not $isSimpleExpr Then Return SetError(2,0,'Unsupported Operation')

	Local $ret=Execute($s)
	Local $err=@error
	Local $ext=@extended
	Local $typ=VarGetType($ret)

	If @error<>0 Then Return SetError(3,0,'Expression Syntax Incorrect');since we only allow simple expressions, this can only be an input error.

	If @extended<>0 Then Return SetError(0,0,StringFormat("(%s) %s | @extended=%s",$typ,$ret,$ext))
	Return SetError(0,0,StringFormat("(%s) %s",$typ,$ret))
EndFunc