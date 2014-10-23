;#include <Math.au3>
#include <Array.au3>
#cs
$text=StringReplace("this\n\nis\na\n12345678901\nthis\nis\na\ntest\n","\n",@LF)
$wrap=TextWrap_LINE($text, 10,4)
$wrap[0]=StringReplace($wrap[0],@LF,"X")
$wrap[1]=StringReplace($wrap[1],@LF,"X")
_ArrayDisplay($wrap)
$wrap=TextWrap_LINE($wrap[1], 11,2)
_ArrayDisplay($wrap)
#ce

Func TextWrap_Hard($str, $maxLen); wraps the text by letter according to a maximum length
	Local $arr[2] = [StringMid($str, 1, $maxLen), StringTrimLeft($str, $maxLen)]
	Return SetError(0,StringLen($arr[1]),$arr)
EndFunc   ;==>TextWrap_Hard

Func TextWrap_Word($str, $maxLen);wraps the text by word (space delimited) to a maximum length. Does not break words apart unless there is no other option.
	Local $arr = TextWrap_Hard($str, $maxLen);wrap the text by letter and reassemble any broken words
	If StringRegExp(StringRight($arr[0], 1), "(?s)\S") And StringRegExp(StringLeft($arr[1], 1), "(?s)\S") Then
		;if the wrap breaks any word/sequence of symbols without spaces
		Local $tmparr0=StringRegExpReplace($arr[0],"(?s)\s",' '); change all whitespace to spaces ...
		Local $pSpace = StringInStr($tmparr0, ' ', 2, -1); .. so that we can find the position of any whitespace
		If $pSpace > 1 Then ;and if there is a space somewhere in the first part
			Local $middle = StringMid($arr[0], $pSpace + 1)
			$arr[0] = StringMid($arr[0], 1, $pSpace)
			;then shunt the end of the first part (middle) into the second part
			$arr[1] = $middle & $arr[1]
		EndIf
	EndIf

	Return SetError(0,StringLen($arr[1]),$arr)
EndFunc   ;==>TextWrap_Word

Func TextWrap_Line($str, $maxLineLen, $maxLines=3)
	$str=StringStripWS(StringStripCR($str),1+2);removing CR's, leading and trailing spaces/newlines
	$str=StringRegExpReplace($str,"(?s)\n+",@LF);remove any duplicate newlines
	$lines=StringSplit($str,@LF)

	;TextWrap_Word($str,$maxLineLen)

	;If $lines[0]<2 Then Return TextWrap_Word($str,$maxLineLen)

	Local $wrap[2]=['','']
	Local $n=1
	While $n<=(UBound($lines)-1); for each word, append as much as we can to the output (char count resets per-line) - not using $lines[0] because this changes
		;;ConsoleWrite($n&'/'&(UBound($lines)-1)&' limit:'&$maxLines&@CRLF)
		If $n>$maxLines Then ExitLoop; if we reach the max line limit, shove the rest to the wrap[1] buffer
		If StringLen($lines[$n])>$maxLineLen Then; if we reach the char limit for this line
			Local $lwrap=TextWrap_Word($lines[$n],$maxLineLen); wordwrap the line
			$wrap[0]&=$lwrap[0]&@LF;append the first part to the output as accepted
			_ArrayInsert($lines,$n+1,$lwrap[1]);process the remainder (wrapped) part as a new line
			$n+=1
			ExitLoop
		Else
			$wrap[0]&=$lines[$n]&@LF
		EndIf
		$n+=1; not using a FOR because the maximum argument is not re-evaluated.
	WEnd
	For $n=$n To UBound($lines)-1; append any remaining lines to the remainder (wrapped) part.
		$wrap[1]&=@LF&$lines[$n]
	Next

	Return SetError(0,StringLen($wrap[1]),$wrap)

	;Return TextWrap_Word($str, $out)
EndFunc