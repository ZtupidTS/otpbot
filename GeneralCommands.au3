#include-once
#include <String.au3>
#include <Array.au3>



Global $_Help_Commands[1]=['help']
Global $_Help_Usage[1]=['[command name]']
Global $_Help_Descriptions[1]=['Lists and provides help information for registered commands. '& _
'Use the syntax "help command" for information about the command. (eg: "help more" provides information about More.).  '& _
'The Usage information for each command displays the parameters you can use for the command. Brackets like [] incidate the parameter is optional. Nested brackets may imply that a series of optional parameters requires each previous one to be used first.']


Global $_More_Entries=10
Global $_More_Buffer[$_More_Entries][2]; session name[0] and buffered overflow text[1]
Global $_More_NextEntry=0



#include "stats.au3"; have to put this here because of initialization code using globals.
#include "Calc.au3"


;---------------------------------------
_Help_Register("more","","Provides more text from the end of a previous post that was cut off. Using `more` will not clear the original text held unless the new text is also too long or the text held is the oldest cached entry. Note: `more` results are specific to PM username and channel name.")


;------------------------------------------------------------------------------

Func _Help_RegisterGroup($group)
	_ArrayAdd($_Help_Commands,"| "&$group&":")
	_ArrayAdd($_Help_Usage,"<none>")
	_ArrayAdd($_Help_Descriptions,"This is a command group.")
EndFunc
Func _Help_Register($command,$usage="[parameters unknown]",$description="No help infomation is available for this command.")
	_ArrayAdd($_Help_Commands,$command)
	_ArrayAdd($_Help_Usage,$usage)
	_ArrayAdd($_Help_Descriptions,$description)
EndFunc
Func _Help_RegisterCommand($command,$usage="[parameters unknown]",$description="No help infomation is available for this command.")
	Return _Help_Register($command,$usage,$description)
EndFunc
Func _Help_List()
	Local $s="Commands:"
	For $i=0 To UBound($_Help_Commands)-1
		If (Not (StringLeft($_Help_Commands[$i],1)='|')) And StringInStr($_Help_Commands[$i],' ') Then ContinueLoop; show Groups, but skip subcommands.
		$s&=" "&$_Help_Commands[$i]
	Next
	Return $s&" ||| Use the command form `help commandname` for information about a specific command. (eg: `help more`)"
EndFunc
Func _Help_Command($command,$subcommand="")
	If StringLen($subcommand) Then $command&=" "&$subcommand
	For $i=0 To UBound($_Help_Commands)-1
		If $_Help_Commands[$i]=$command Then
			Return StringUpper($_Help_Commands[$i])&' '&$_Help_Usage[$i]&' - '&$_Help_Descriptions[$i]
		EndIf
	Next
	Return 'help: No information available for the command `'&$command&'`.'
EndFunc
Func COMMAND_Help($command="",$subcommand="")
	If $command="" Then Return _Help_List()
	Return _Help_Command($command,$subcommand)
EndFunc


;--------------------------------------------------------

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


