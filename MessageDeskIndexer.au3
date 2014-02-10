#include <Array.au3>
#include <String.au3>
#include "shorturl.au3"
#include "HTTP.au3"
#include "Wiki.au3"
#include-once

Global $_MDI_LastTS = -1;initial request without a TS, just acquires the current TS
Global $_MDI_URL = 'http://sukasa.rustedlogic.net/MD/'


;;---------- TEST
TCPStartup()
Local $foo = _MDI_GetNewEntries()
Local $arraydisplay_title = $_MDI_LastTS; should be updated now
_ArrayDisplay($foo, $arraydisplay_title)
;;----------

Func _MDI_GetNewEntries()
	Global $_MDI_LastTS
	Local $url, $data, $update, $count, $j=0


	$url = $_MDI_URL & 'LastDemo1.txt?last=' & $_MDI_LastTS
	$data = BinaryToString(_InetRead($url), 4);request our data (this server returns UTF8, so convert that...)
	If StringLen($data) < 1 Then Return SetError(1, 0, 0);error on null responses

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
	Return SetError(0, 0, $results)
EndFunc   ;==>_MDI_GetNewEntries