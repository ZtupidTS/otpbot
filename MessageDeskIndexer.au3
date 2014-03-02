#include <Array.au3>
#include <String.au3>
#include "shorturl.au3"
#include "HTTP.au3"
#include "Wiki.au3"
#include-once

Global $_MDI_LastTS = -1;initial request without a TS, just acquires the current TS
Global $_MDI_URL = 'http://sukasa.rustedlogic.net/MD/'
Global $_MDI_ReportFunc=''


Func COMMAND_MDIDebug()
	Return $_MDI_LastTS&' : '&$_MDI_ReportFunc
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

	$_MDI_LastTS = $update[0];use this new one for the next request
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