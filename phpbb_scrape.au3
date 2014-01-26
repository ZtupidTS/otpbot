#include <Array.au3>
#include <String.au3>
#include "shorturl.au3"
#include-once

Global $PHPBB_URL="http://forums.unfiction.com/forums/"
Global $PHPBB_TopicID=36166
Global $PHPBB_PostsPerPage=15
Global $PHPBB_ReportFunc=''
;----------------------------------------------------------
Global $PHPBB_TopicURL=phpbb_url_viewtopic($PHPBB_URL,$PHPBB_TopicID)
Global $PHPBB_TopicHTML=BinaryToString(InetRead($PHPBB_TopicURL,1))
Global $PHPBB_TopicPostCount=phpbb_scrape_postcount($PHPBB_TopicHTML)
;----------------------------------------------------------

_Help_RegisterGroup("Forum")
_Help_RegisterCommand("lastforumpage","","Retrieves the URL for the current last page of the forum topic.")
_Help_RegisterCommand("forumdebug","","forces a new-reply notification with at least the last 10 posts.")





Func COMMAND_lastforumpage()
	phpbb_report_NewPostsAndLink();refresh the HTML content.
	Local $start=phpbb_calc_lastpagestart($PHPBB_TopicPostCount,$PHPBB_PostsPerPage);$PHPBB_TopicPostCount is set by phpbb_get_newpostinfo
	Local $lastpageurl=phpbb_url_viewtopic($PHPBB_URL,$PHPBB_TopicID,$start)
	Return _ShortUrl_Retrieve($lastpageurl)&' | '&$lastpageurl
EndFunc

Func COMMAND_forumdebug()
	Local $old=$PHPBB_TopicPostCount
	$PHPBB_TopicPostCount-=10
	Local $new=$PHPBB_TopicPostCount
	phpbb_report_NewPostsAndLink()
	Return StringFormat("Old: %s, New: %s, Callback $PHPBB_ReportFunc = %s",$old,$new,$PHPBB_ReportFunc)
EndFunc



Func phpbb_report_NewPostsAndLink()
	Local $ret=phpbb_get_NewPostsAndLink($PHPBB_URL,$PHPBB_TopicID,$PHPBB_PostsPerPage,$PHPBB_TopicPostCount)
	Local $err=@error
	If $err=0 And StringLen($ret) Then Call($PHPBB_ReportFunc,$ret)
EndFunc

Func phpbb_get_NewPostsAndLink($url,$topicid,$postsperpage,$lastpostcount)
	Local $authors=phpbb_get_newpostinfo($url,$topicid,$lastpostcount)
	Local $newposts=@extended
	If $newposts=0 Then SetError(1,0,"")
	Local $out=phpbb_stringify_newpostinfo($newposts,$authors)
	Local $err=@error
	If $err<>0 Or StringLen($out)=0 Then Return SetError(2,0,"")


	Local $start=phpbb_calc_lastpagestart($PHPBB_TopicPostCount,$postsperpage);$PHPBB_TopicPostCount is set by phpbb_get_newpostinfo
	Local $lastpageurl=phpbb_url_viewtopic($url,$topicid,$start)
	$out&=" | "&_ShortUrl_Retrieve($lastpageurl)
	Return SetError(0,0,$out)
EndFunc




Func phpbb_url_viewtopic($url,$topicid,$startpostcount=0)
	Return StringFormat($url&'viewtopic.php?t=%s&start=%s',Int($topicid),Int($startpostcount))
EndFunc
Func phpbb_stringify_newpostinfo($newposts,$authors)
	Local $out=StringFormat("%s New Forum Posts by: ",$newposts)
	If $newposts=0 Then Return SetError(1,0,"")
	$out&=_ArrayToString($authors,', ')
	Return $out
EndFunc
Func phpbb_get_newpostinfo($url,$topicid,$lastpostcount)
	$PHPBB_TopicURL=phpbb_url_viewtopic($url,$topicid)
	$PHPBB_TopicHTML=BinaryToString(InetRead($PHPBB_TopicURL,1))
	$PHPBB_TopicPostCount=phpbb_scrape_postcount($PHPBB_TopicHTML)

	Local $newposts=$PHPBB_TopicPostCount-$lastpostcount

	If $newposts<=0 Then Return SetError(0xF00D,0,0)

	Local $start=$PHPBB_TopicPostCount-$newposts; start post index of only the new posts.
	$PHPBB_TopicHTML=BinaryToString(InetRead(phpbb_url_viewtopic($url,$topicid,$start),1))
	Local $authors=phpbb_scrape_authors($PHPBB_TopicHTML)

	Return SetError(0,$newposts,$authors)
EndFunc


Func phpbb_scrape_postcount($html)
	;&nbsp;[654 Posts]
	Local $sPosts=StringRegExpReplace($html,"(?s).*?&nbsp;\[([0-9]+) Posts\].*","\1")
	If @extended=0 Then Return SetError(1,0,0)
	Local $nPosts=Int($sPosts)
	If $nPosts=0 Then Return SetError(2,0,0)
	Return $nPosts
EndFunc
Func phpbb_scrape_author($html)
	;&nbsp;[654 Posts]
	Local $sHTML_Name=StringRegExpReplace($html,'(?s).*?<span class="name">(.*?)</span>.*',"\1")
	If @extended=0 Then Return SetError(1,0,'')
	Local $sName=StringRegExpReplace($sHTML_Name,'(?s).*?<b>(.*?)</b>.*',"\1")
	If @extended=0 Then Return SetError(2,0,'')
	$sName=StringStripWS($sName,1+2+4)
	Return $sName
EndFunc
Func phpbb_scrape_authors($html)
	;&nbsp;[654 Posts]
	Local $aHTML_Names=StringRegExp($html,'(?s).*?<span class="name">(.*?)</span>',3)
	If @error<>0 Then Return SetError(1,0,'')
	For $i=0 To UBound($aHTML_Names)-1
		;ConsoleWrite($aHTML_Names[$i]&@CRLF)
		$aHTML_Names[$i]=StringRegExpReplace($aHTML_Names[$i],'(?s).*?<b>(.*?)</b>.*',"\1")
		If @extended=0 Then $aHTML_Names[$i]=''
		;ConsoleWrite('   '&$aHTML_Names[$i]&@CRLF)
		$aHTML_Names[$i]=StringStripWS($aHTML_Names[$i],1+2+4)
		;ConsoleWrite('      '&$aHTML_Names[$i]&@CRLF)
	Next
	Return $aHTML_Names
EndFunc


Func phpbb_calc_pagecount($postcount,$postsperpage)
	Return Ceiling($postcount/$postsperpage)
EndFunc
Func phpbb_calc_lastpagestart($postcount,$postsperpage);start post of the last page
	; the start post of the newest page is equivalent to the post count UP TO it (post count including previous pages only) - or 0 if there is no previous page.
	Return (Ceiling($postcount/$postsperpage)-1)*$postsperpage
EndFunc

