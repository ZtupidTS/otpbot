#include <Array.au3>
#include <String.au3>
#include "shorturl.au3"
#include "HTTP.au3"
#include "Wiki.au3"
#include "GeneralCommands.au3"
#include-once

Global $_MDI_LastTS = -1;initial request without a TS, just acquires the current TS
Global $_MDI_URL = 'http://sukasa.rustedlogic.net/MD/'
Global $_MDI_ReportFunc=''

Global $_MDI_PostEvent=''

Global $_MDI_ResponseTypes[9]=['Hang Up','Coordinates','Referral','Named Location','Book','Number','Pointless Response','Return Call Request','Unknown']
Global $_MDI_ResponseTypes2[9]=['Hangup','Coord','Referral','location','Book','Number','Pointless','Return','Unknown']




_Help_RegisterGroup("MessageDesk")
_Help_RegisterCommand("md","<input code> <response type> <response> [notes]","Submits an entry to the Message Desk Indexer noting the outcome of a call to Message Desk that you made"& _
' with an input and a response. . If you need to use spaces in any of the fields, surround the text with "double quotes".'& _
'The Response Type can be one of the following: '&_ArrayToString($_MDI_ResponseTypes2,',')&' - However, some partial matches are accepted also.')
_Help_RegisterCommand("MDIDebug","",'Returns internal state information about MessageDeskIndexer polling.')


Func COMMAND_MDIDebug()
	Return $_MDI_LastTS&' : '&$_MDI_ReportFunc
EndFunc

;TCPStartup()
;_MDI_Submit('DUMMY','Bot Test','notes','Named Location')

;MsgBox(0,0,COMMAND_MD('DUMMY','loc','resp','notes'))

Func COMMAND_MD($input,$type,$response,$notes="")
	Local $ret=_MDI_UserInput($input,$response,$notes,$type)
	Local $err=@error
	Switch @error
		Case 0
			;NOT IMPLEMENTED!: If StringLen($_MDI_PostEvent) Then Call($_MDI_PostEvent,$who,$where,$what)
			Return "Message Desk Indexer entry submitted. You can find it at: http://sukasa.rustedlogic.net/MD/?Details="&_URIEncode($input)
		Case 1
			Return "MD: Your Response Type was not understood, try one of the following: "&_ArrayToString($_MDI_ResponseTypes2,',')
		Case Else
			Return "MD: An unknown error has occured."
	EndSwitch
EndFunc


Func _MDI_UserInput($input,$response,$notes,$type)
	Local $iType=-1
	For $i=0 To UBound($_MDI_ResponseTypes)-1
		If $type=$_MDI_ResponseTypes[$i] Or $type=StringReplace($_MDI_ResponseTypes[$i],' ','') Then $iType=$i
	Next
	If StringLen($type)>=3 Then $iType=_ArraySearch($_MDI_ResponseTypes,$type,0,0,0,1);partial search
	If $iType=-1 Then Return SetError(1,0,'')
	Local $ret=_MDI_Submit(StringLeft($input,256),StringLeft($response,1024),StringLeft($notes,1024),$_MDI_ResponseTypes[$iType])
	Local $err=@error
	Return SetError($err,0,$ret)
	;If $type="coord" Or $type="coords" Then $iType=_ArraySearch(
EndFunc

Func _MDI_Submit($input,$response,$notes,$type)
	Local $headers='Referer: http://sukasa.rustedlogic.net/MD/Index.aspx'&@CRLF&'Content-Type: application/x-www-form-urlencoded'&@CRLF
	Local $text=''
	Local $aReq=__HTTP_Req('POST','http://sukasa.rustedlogic.net/MD/Index.aspx', _
		StringFormat("txtCode=%s&txtResponse=%s&txtNotes=%s&lstResponseTypes=%s&btnSave=Save&txtPassword=U", _
			_URIEncode($input),_URIEncode($response),_URIEncode($notes),_URIEncode($type)) _
		,$headers)
	__HTTP_Transfer($aReq,$text,5000)
EndFunc



Func _MDI_Report_NewEntries()
	Local $s=_MDI_GetNewEntriesString()
	If StringLen($s) And StringLen($_MDI_ReportFunc) Then Call($_MDI_ReportFunc,$s)
EndFunc

Func _MDI_GetNewEntriesString()
	Local $entries=_MDI_GetNewEntries()
	Local $count=@extended
	If $count<1 Then Return ""
	Local $out=$count&' new Message Desk Indexer entries: '
	For $i=0 To UBound($entries)-1
		Local $link=_ShortUrl_Retrieve('http://sukasa.rustedlogic.net/MD/Index.aspx?Details='&$entries[$i][0],0)
		$out&=$entries[$i][0]&' = '&WikiText_Translate($entries[$i][2], "http://otp22.referata.com/wiki/")&' ('&$entries[$i][1]&') '&$link&' | '
	Next
	Return $out
EndFunc

Func _MDI_GetNewEntries()
	Global $_MDI_LastTS
	Local $url, $data, $update, $count, $j=0


	$url = $_MDI_URL & 'Updates.aspx?last=' & $_MDI_LastTS
	$data = BinaryToString(_InetRead($url),4);request our data (this server returns UTF8, so convert that...)
	If StringLen($data) < 1 Then Return SetError(1, 0, 0);error on null responses
	ConsoleWrite($data)
	$data=StringStripCR($data)

	$update = StringSplit($data, @LF, 2); Format is line-delimited:  0=newTS, 1=Count 2=Entries 3=Entries ...
	If UBound($update) < 2 Then Return SetError(2, 0, 0); we require at least the NewTS and Count fields.

	$_MDI_LastTS = StringStripWS($update[0],8);use this new one for the next request
	$count = Int($update[1])
	If $count<1 Then Return SetError(0,0,0); there were no new entries - return no results array, no error.

	Local $results[$count][3]
	For $i = 2 To UBound($update) - 1 Step 3
		$results[$j][0] = $update[$i + 0];Code ;; could use a For here also, but I don't reduce the line count.
		$results[$j][1] = $update[$i + 1];type
		$results[$j][2] = $update[$i + 2];response
		$j += 1
	Next
	Return SetError(0, $count, $results)
EndFunc   ;==>_MDI_GetNewEntries