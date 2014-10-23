#include-once
;#include "GeneralCommands.au3"
Global $_More_Entries=10
Global $_More_Buffer[$_More_Entries][2]; session name[0] and buffered overflow text[1]
Global $_More_NextEntry=0

Global $_More_Commands[1][3]=[["more","","Provides more text from the end of a previous post that was cut off. Using `%!%more` will not clear the original text held unless the new text is also too long or the text held is the oldest cached entry. Note: `%!%more` results are specific to PM username and channel name."]]


Func _More_SessionName($who, $where)
	Local $location=$where
	If Not (StringLeft($location,1)="#") Then $location=$who
	Return $location
EndFunc
Func _More_SessionExists($sess)
	For $i=0 To $_More_Entries-1
		If $_More_Buffer[$i][0]=$sess Then Return $i;case insensitive?
	Next
	Return -1
EndFunc

Func _More_Store($who, $where, $what)
	Local $sess=_More_SessionName($who, $where)
	Local $i=_More_SessionExists($sess)
	If $i<0 Then; if i>0, the session already exists, so update its data.  If i<0, this is a new session, so add it to the FIFO.
		$i=$_More_NextEntry
		$_More_NextEntry=Mod($_More_NextEntry+1,$_More_Entries);0 through $_More_Entries-1 looping FIFO
	EndIf
;MsgBox(0,$sess,$what)
	$_More_Buffer[$i][0]=$sess
	$_More_Buffer[$i][1]=$what
EndFunc
Func _More_Retrieve($who, $where, $what)
	Local $sess=_More_SessionName($who, $where)
	Local $i=_More_SessionExists($sess)
	If $i<0 Then Return "Error: I could not find any More data for a conversation with `"&$sess&"`."
	Return $_More_Buffer[$i][1]
EndFunc

Func COMMANDX_more($who, $where, $what, $acmd)
	Return _More_Retrieve($who, $where, $what)
EndFunc