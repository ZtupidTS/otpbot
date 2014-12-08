#include <Array.au3>
#include <String.au3>
Global $_Calc_External_Retval=""
Global $_Calc_External_Outfile=@TempDir&'\calcret.tmp'
Global $_Calc_External_Memory=100;MB
Global $_Calc_External_PID=-1

Global $_Calc_HangTimer=0
Global $_Calc_HangLimit=5*1000
Global $_Calc_HangExec=''



;------------------------------------------------------------------
If IsDeclared('_Calc_Host')<=0 Then
	AdlibRegister('_Calc_HangDetector',1000)
	_Calc_StartHangTimer()
EndIf


;;USERCODE;;


If IsDeclared('_Calc_Host')<=0 Then
	_Calc_External_Write()
	_Calc_StopHangTimer()
EndIf
;------------------------------------------------------------------



Func _Calc_External_Write()
	ConsoleWrite($_Calc_External_Outfile&@CRLF)
	FileWrite($_Calc_External_Outfile,VarGetType($_Calc_External_Retval)&"<!CALC!>"&$_Calc_External_Retval)
EndFunc
Func _Calc_External_Read()
	If FileGetSize($_Calc_External_Outfile)=0 Then Return ""
	Local $v=FileRead($_Calc_External_Outfile,1000)
	If IsBinary($v) Then $v=BinaryToString($v)
	Return $v
EndFunc
Func _Calc_External_Check()
	Local $errorA[2]=["Error","Script generated an AutoIt error and ended prematurely."]
	Local $errorB[2]=["Error","An internal error has occurred."]
	Local $v=_Calc_External_Read()
	If StringLen($v)=0 Then Return $errorA
	If StringInStr($v,"<!CALC!>")<1 Then Return $errorA
	Local $a=StringSplit($v,"<!CALC!>",1+2)
	If UBound($a)<2 Then Return $errorB
	Return $a
EndFunc

Func _Calc_External_Run($script)
	Global $_Calc_ScriptI
	$_Calc_ScriptI=Mod($_Calc_ScriptI,4)
	Local $fp=@TempDir&"\calcret"&$_Calc_ScriptI&".au3"

	Local $template=FileRead(@ScriptDir&'\CalcExternal.au3')
	$script=StringReplace($template,";;USER"&"CODE;;",$script)

	FileDelete($_Calc_External_Outfile)
	FileDelete($fp)
	FileWrite($fp,$script)
	Local $run=_Calc__FilepathQuote(@AutoItExe)&' /ErrorStdOut /AutoIt3ExecuteScript '&_Calc__FilepathQuote($fp)
	;Local $run=FilepathQuote(@AutoItExe)&' /AutoIt3ExecuteScript '&FilepathQuote($fp)
	$_Calc_External_PID=Run($run,@WorkingDir,@SW_HIDE,0)
	Return $_Calc_External_PID
EndFunc

Func _Calc__FilepathQuote($fp)
	If Not (StringLeft($fp,1)='"') Then
		If StringInStr($fp,' ') Then
			Return StringFormat('"%s"',$fp)
		EndIf
	EndIf
	Return $fp
EndFunc

Func _Calc_External_Monitor()
	;$_Calc_External_PID
	Global $_Calc_External_TS
	$_Calc_External_TS=TimerInit()
	Local $terminate=0
	While ProcessExists($_Calc_External_PID)
		Sleep(250)
		If TimerDiff($_Calc_External_TS)>$_Calc_HangLimit Then $terminate=1

		$memory=ProcessGetStats($_Calc_External_PID,0)
		If IsArray($memory) Then
			Local $ws=(($memory[0]/1000)/1000);megabytes
			If $ws<0 Or $ws>$_Calc_External_Memory Then $terminate=2
		EndIf
		If $terminate>0 Then ExitLoop
	WEnd
	If $terminate>0 Then ProcessClose($_Calc_External_PID)
	Return $terminate
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
;---------------------------------------
Func _REF_Return($v)
	$_Calc_External_Retval=$v
EndFunc
Func _REF_Clear($v)
	$_Calc_External_Retval=""
EndFunc
Func _REF_Print($v)
	$_Calc_External_Retval&=$v
EndFunc
Func _REF_Println($v)
	$_Calc_External_Retval&=$v&@CRLF
EndFunc
;--------------------------------------
Func _REF_TakeTooMuchTime();; limits test function
	Sleep(10*60*1000)
EndFunc
Func _REF_Set(ByRef $var,$value)
	$var=$value
EndFunc
Func _REF_Assign($name,$value)
	Assign('_REF_'&$name,$value,2)
EndFunc
Func _REF_Eval($name)
	Return Eval('_REF_'&$name)
EndFunc
Func _REF_Void($a=0,$b=0,$c=0,$d=0,$e=0,$f=0,$g=0,$h=0)
	Return SetError(0,0,'')
EndFunc






