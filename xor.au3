#include <Process.au3>
#include <String.au3>
#include "HTTP.au3"
#include "GeneralCommands.au3"


_Help_RegisterGroup("Xor")
_Help_RegisterCommand("pastebinxor","<pastebin link> [key filename]","Performs a XOR operation on a transcribed decimal NATO message with an offset (given as a pastebin entry), with a local keyfile. eg `%!%pastebinxor http://pastebin.com/djeUWxm elpaso.bin`")
_Help_RegisterCommand("elpaso","<pastebin link>","This command defaults the keyfile used in pastebin xor operations. See `%!%help pastebinxor`. ")
_Help_RegisterCommand("databin","<pastebin link>","This command defaults the keyfile used in pastebin xor operations. See `%!%help pastebinxor`. ")
_Help_RegisterCommand("littlemissouri","<pastebin link>","This command defaults the keyfile used in pastebin xor operations. See `%!%help pastebinxor`. ")
#region ;----- autodecoder for  black OTP1

Func COMMAND_pastebinxor($link,$keyfile="elpaso.bin")
	If (Not StringRegExp($keyfile,'^[a-zA-Z0-9_\-\.]+$')) Or StringInStr($keyfile,'..')>0 Then Return "Invalid keyfile name"
	Return pastebindecode($link, $keyfile)
EndFunc

Func Trans2Bytes($trans)
	$trans = StringStripWS($trans, 1 + 2 + 4)
	Local $arr = StringSplit($trans, ' ', 2)
	Local $bytes = ""
	For $key In $arr
		If StringLen($key) = 0 Then ContinueLoop
		If $key = "salt" Then ExitLoop
		If $key = "offset" Then ExitLoop
		If StringRegExp($key,"^[0-9]+$") Then $bytes &= Chr(Int($key))
	Next
	Return $bytes
EndFunc   ;==>Trans2Bytes

Func getpastebin($message)
	ConsoleWrite("getpastebin" & @CRLF)
	Local $id = StringRegExpReplace($message, "(?s)^.*?pastebin.com/([\d\w]+).*$", "\1")
	If @extended = 0 Then Return SetError(1, 0, "")
	Return SetError(0, 0, $id)
EndFunc   ;==>getpastebin

Func pastebindecode($message, $keyfile = "elpaso.bin")
	ConsoleWrite("pastebindecode" & @CRLF)
	Local $id = getpastebin($message)
	If @error <> 0 Then Return SetError(1, 0, "")
	Local $link = "http://pastebin.com/raw.php?i=" & $id
	Local $data = BinaryToString(_InetRead($link))
	If Not StringRegExp($data, "(?s)[\d\s]+offset[\d\s]+") Then Return SetError(1, 0, "")

	Local $autocorrect=StringInStr($message,'correct')
	Return decodebin($data, $keyfile,$autocorrect)
EndFunc   ;==>pastebindecode


Func decodebin($message, $key = "elpaso.bin", $autocorrect=1)
	ConsoleWrite("decodebin" & @CRLF)
	$message = StringStripWS($message, 1 + 2 + 4)
	$bytes = Trans2Bytes($message)
	$offset = StringRegExpReplace($message, "^(?s).*?\soffset\s(\d+).*$", "\1")
	If @extended = 0 Then Return "I need an Offset at the end of your message. Like: 11 170 2 offset 50"
	$offset = Int($offset)


	Local $mode='e'
	If $autocorrect Then $mode='a'

	$key = @ScriptDir & '\' & $key
	Local $in = @TempDir & "\msgOTP.txt"
	Local $out = @TempDir & "\outOTP.txt"
	Local $dbg = @TempDir & "\dbgOTP.txt"
	Local $exe = @ScriptDir & "\OtpXor.exe"
	FileDelete($in)
	FileDelete($out)
	FileWrite($in, $bytes)
	;Return StringFormat("C:\Users\Crash\Desktop\otp22\otpdox\OtpXor\Release\OtpXor.exe e %s %s %s %s",$key,$in,$offset,$out)

	Local $run = StringFormat('"%s" %s "%s" "%s" %s "%s" > "%s"', $exe, $mode, $key, $in, $offset, $out, $dbg)
	ConsoleWrite("Run: " & $run)
	ConsoleWrite(@CRLF)
	;ConsoleWrite("CWD: "&@WorkingDir&@CRLF))
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