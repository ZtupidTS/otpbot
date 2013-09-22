#include <Process.au3>

#region ;---NATO 5gram Decoding


Func COMMAND_5gramfind($num, $in)
	Local $key = FileGetShortName(@ScriptDir & "\p" & Int($num) & ".txt")
	Local $prg = FileGetShortName(@ScriptDir & "\otpnato.exe")
	If Not FileExists($key) Then Return "p" & Int($num) & ".txt Not Found"
	If Not FileExists($prg) Then Return "otpnato.exe Not Found"

	$in = StringRegExpReplace($in, "(?s)[^a-zA-Z]", "")

	Local $out = @ScriptDir & '\outOTP.txt'
	FileDelete($out)
	_RunDos(StringFormat($prg & ' f %s %s > "%s"', $key, $in, $out)); I was skeptical, but this seems to work fine.
	Return FileRead($out)
EndFunc   ;==>COMMAND_5gramfind
Func COMMANDX_5gram($who, $where, $what, $acmd);;;;$num,$message)
	If (UBound($acmd) - 1) < 3 Then Return "5gram: not enough parameters: filenumber 5grams"
	$nums = $acmd[2]
	Local $message = CommandToString($acmd, 3, -1)

	Local $mode='d'
	If StringLeft($nums,1)='d' Or StringLeft($nums,1)='e' Then
		$mode=StringLeft($nums,1)
		$nums=StringTrimLeft($nums,1)
	EndIf

	If StringLen($nums)>6 Then Return "Error: too many decoding parameters. Please use less decoding options"

	Local $in = @ScriptDir & '\msgOTP.txt'
	Local $out = @ScriptDir & '\outOTP.txt'
	Local $prg = FileGetShortName(@ScriptDir & "\otpnato.exe")
	Local $ret="ERROR"
	For $i=1 To StringLen($nums)
		Local $num=StringMid($nums,$i,1)
		If $num="*" Then
			$ret=""
			For $i=1 To 4
				$acmd=StringSplit("5gram "&$mode&$i&" "&$message, ' ')
				$ret&=$i&": "&COMMANDX_5gram($who, $where, $what, $acmd)&" | "
			Next
			Return $ret
		Else
			Local $key = FileGetShortName(@ScriptDir & "\p" & Int($num) & ".txt")
			If Not FileExists($key) Then Return "p" & Int($num) & ".txt Not Found"
			If Not FileExists($prg) Then Return "otpnato.exe Not Found"

			FileDelete($in)
			FileDelete($out)
			FileWrite($in, $message)
			_RunDos(StringFormat($prg & ' %s %s %s > "%s"', $mode, $key, $in, $out))
			$ret=FileRead($out)
		EndIf
		$message=$ret
	Next
	Return $ret
EndFunc   ;==>COMMANDX_5gram
#endregion ;---NATO 5gram Decoding