#include-once
#include "DNS.au3"
Global Const $_DNS_ENTRIES=50
Global $_DNS_CACHE[$_DNS_ENTRIES][3]; we only cache these so that we can cycle through
Global $_DNS_IDX=0


Func _Dns_Cache_Cycle($i)
	Local $response=$_DNS_CACHE[$i][1]
	If IsArray($response) Then
		Local $entry=$_DNS_CACHE[$i][2]
		Local $entries=$response[0][0]


		Local $entry_old=$entry
		Do
			$entry=Mod($entry+1,$entries)
		Until ($response[$entry+1][1] = $DNS_TYPE_A) Or ($entry=$entry_old); cycle to the next A record, but don't loop past the element we're on already.

		$_DNS_CACHE[$i][2]=$entry
	EndIf
EndFunc

Func _Dns_Cache_Set($i,$hostname, ByRef $response)
	$_DNS_CACHE[$i][0]=$hostname
	$_DNS_CACHE[$i][1]=$response
	$_DNS_CACHE[$i][2]=__dnsgetfirstrecord($response)
	Return $i
EndFunc
Func _Dns_Cache_Add($hostname, ByRef $response)
	Local $i=$_DNS_IDX
	_Dns_Cache_Set($i,$hostname,$response)
	$_DNS_IDX=Mod($_DNS_IDX+1,$_DNS_ENTRIES)
	Return $i
EndFunc
Func _Dns_Cache_Find($hostname)
	For $i=0 To $_DNS_ENTRIES-1
		If $hostname=$_DNS_CACHE[$i][0] Then Return $i
	Next
	Return -1
EndFunc
Func _Dns_Cache_Update($hostname, ByRef $response)
	Local $i=_Dns_Cache_Find($hostname)
	If $i=-1 Then Return _Dns_Cache_Add($hostname, $response)
	Return _Dns_Cache_Set($i,$hostname, $response)
EndFunc
;----------------------
Func _Dns_Request_New($hostname)
	Local $response = _Dns_Query($hostname, $DNS_TYPE_A)
	Local $i=_Dns_Cache_Update($hostname,$response)
	If $i=-1 Then Return SetError(3,'','')
	If IsArray($response) Then
		Local $entry=$_DNS_CACHE[$i][2]
		Return SetError(0,$entry,$response[$entry+1][2])
	Else
		Return SetError(2,'',0)
	EndIf
EndFunc
Func _Dns_Request_Cached($hostname,$doCycle=True)
	Local $i=_Dns_Cache_Find($hostname)
	If $i=-1 Then Return SetError(1,'','')
	If $doCycle Then _Dns_Cache_Cycle($i)
	Local $response=$_DNS_CACHE[$i][1]
	If IsArray($response) Then
		Local $entry=$_DNS_CACHE[$i][2]
		;ConsoleWrite("DNS: "&$hostname&" -> "&$response[$entry+1][0]&" ["&$response[$entry+1][2]&"]"&@CRLF)
		Return SetError(0,$entry,$response[$entry+1][2])
	Else
		Return SetError(2,'',0)
	EndIf
EndFunc

Func _Dns_Request_Any($hostname,$doCycle=True)
	Local $r=_Dns_Request_Cached($hostname,$doCycle)
	Local $e=@error
	If $e=1 Then
		$r=_Dns_Request_New($hostname)
		$e=@error
	EndIf
	If $e=0 Then
		Return $r
	Else
		ConsoleWrite("DNS Error ("&$e&"): "&$hostname&@CRLF)
		Return SetError($e,0,'')
	EndIf
EndFunc


Func __dnsgetfirstrecord(ByRef $response)
	For $i = 1 To $response[0][0]
		If $response[$i][1] = $DNS_TYPE_A Then Return $i-1
	Next
	Return -1
EndFunc

Func _TCPNameToIP($hostname)
	Return _Dns_Request_Any($hostname,True)
EndFunc