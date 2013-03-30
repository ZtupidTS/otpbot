#include <Process.au3>


#region ;----- autodecoder for  black OTP1

Func Trans2Bytes($trans)
	$trans = StringStripWS($trans, 1 + 2 + 4)
	Local $arr = StringSplit($trans, ' ', 2)
	Local $bytes = ""
	For $key In $arr
		$bytes &= Chr(Int($key))
		If $key = "salt" Then ExitLoop
		If $key = "offset" Then ExitLoop
	Next
	Return $bytes
EndFunc   ;==>Trans2Bytes

Func getpastebin($message)
	Msg("getpastebin")
	Local $id = StringRegExpReplace($message, "(?s)^.*?pastebin.com/([\d\w]+).*$", "\1")
	If @extended = 0 Then Return SetError(1, 0, "")
	Return SetError(0, 0, $id)
EndFunc   ;==>getpastebin

Func pastebindecode($message, $keyfile = "elpaso.bin")
	Msg("pastebindecode")
	Local $id = getpastebin($message)
	If @error <> 0 Then Return SetError(1, 0, "")
	Local $link = "http://pastebin.com/raw.php?i=" & $id
	Local $data = BinaryToString(InetRead($link))
	If Not StringRegExp($data, "(?s)[\d\s]+offset[\d\s]+") Then Return SetError(1, 0, "")
	Return decodebin($data, $keyfile)
EndFunc   ;==>pastebindecode


Func decodebin($message, $key = "elpaso.bin")
	Msg("decodebin")
	$message = StringStripWS($message, 1 + 2 + 4)
	$bytes = Trans2Bytes($message)
	$offset = StringRegExpReplace($message, "^(?s).*?\soffset\s(\d+).*$", "\1")
	If @extended = 0 Then Return "I need an Offset at the end of your message. Like: 11 170 2 offset 50"
	$offset = Int($offset)

	$key = @ScriptDir & '\' & $key
	Local $in = @TempDir & "\msgOTP.txt"
	Local $out = @TempDir & "\outOTP.txt"
	Local $dbg = @TempDir & "\dbgOTP.txt"
	Local $exe = @ScriptDir & "\OtpXor.exe"
	FileDelete($in)
	FileDelete($out)
	FileWrite($in, $bytes)
	;Return StringFormat("C:\Users\Crash\Desktop\otp22\otpdox\OtpXor\Release\OtpXor.exe e %s %s %s %s",$key,$in,$offset,$out)

	Local $run = StringFormat('"%s" e "%s" "%s" %s "%s" > "%s"', $exe, $key, $in, $offset, $out, $dbg)
	Msg("Run: " & $run)
	;Msg("CWD: "&@WorkingDir)
	;_RunDos($run)
	RunWait($run, @WorkingDir, @SW_HIDE)
	Return FileRead($out)
EndFunc   ;==>decodebin




Func scanbin($message, $key = "elpaso.bin");;; not fixed!
	$message = StringStripWS($message, 1 + 2 + 4)
	$bytes = Trans2Bytes($message)
	$offset = Int(StringRegExpReplace($message, "^(?s).*?\soffset\s(\d+).*$", "\1"))


	Local $in = @TempDir & "\msgOTP.txt"
	Local $out = @TempDir & "\outOTP.txt"
	FileDelete($in)
	FileDelete($out)
	FileWrite($in, $bytes)
	;Return StringFormat("C:\Users\Crash\Desktop\otp22\otpdox\OtpXor\Release\OtpXor.exe e %s %s %s %s",$key,$in,$offset,$out)
	_RunDos(StringFormat("OtpXor.exe s %s %s > %s", $key, $in, $out))
	Return FileRead($out)
EndFunc   ;==>scanbin

#endregion ;----- autodecoder for  black OTP1