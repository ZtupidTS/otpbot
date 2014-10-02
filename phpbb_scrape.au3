#include <Array.au3>
#include <String.au3>
#include "shorturl.au3"
#include "HTTP.au3"
#include-once

Global $PHPBB_URL="http://forums.unfiction.com/forums/"
Global $PHPBB_TopicID=36166
Global $PHPBB_PostsPerPage=15
Global $PHPBB_ReportFunc=''
;----------------------------------------------------------
Global $PHPBB_TopicURL=''
Global $PHPBB_TopicHTML=''
Global $PHPBB_TopicPostCount=''
;----------------------------------------------------------
;MsgBox(0,0,$PHPBB_TopicHTML)

Local $_Forum_Commands[2][3]=[ _
["lastforumpage","","ALIAS: %!%FORUM - Retrieves the URL for the current last page of the forum topic."], _
["forumdebug","","forces a new-reply notification with at least the last 10 posts."]]
Func PHPBB_Startup()
	ConsoleWrite('@@ (21) :(' & @MIN & ':' & @SEC & ') PHPBB_Startup()' & @CR) ;### Function Trace
	If $PHPBB_URL="" Then Return
	Global $PHPBB_TopicURL=phpbb_url_viewtopic($PHPBB_URL,$PHPBB_TopicID)
	Global $PHPBB_TopicHTML=BinaryToString(_InetRead($PHPBB_TopicURL,1))
	Global $PHPBB_TopicPostCount=phpbb_scrape_postcount($PHPBB_TopicHTML)
EndFunc

Func COMMAND_forum()
	ConsoleWrite('@@ (28) :(' & @MIN & ':' & @SEC & ') COMMAND_forum()' & @CR) ;### Function Trace
	Return COMMAND_lastforumpage()
EndFunc
Func COMMAND_lastforumpage()
	ConsoleWrite('@@ (32) :(' & @MIN & ':' & @SEC & ') COMMAND_lastforumpage()' & @CR) ;### Function Trace
	If $PHPBB_URL="" Then Return "Error: Forum not set"
	phpbb_report_NewPostsAndLink();refresh the HTML content.
	Local $start=phpbb_calc_lastpagestart($PHPBB_TopicPostCount,$PHPBB_PostsPerPage);$PHPBB_TopicPostCount is set by phpbb_get_newpostinfo
	Local $lastpageurl=phpbb_url_viewtopic($PHPBB_URL,$PHPBB_TopicID,$start)
	Return _ShortUrl_Retrieve($lastpageurl)&' | '&$lastpageurl
EndFunc

Func COMMAND_forumdebug()
	ConsoleWrite('@@ (41) :(' & @MIN & ':' & @SEC & ') COMMAND_forumdebug()' & @CR) ;### Function Trace
	If $PHPBB_URL="" Then Return "Error: Forum not set"
	Local $old=$PHPBB_TopicPostCount
	$PHPBB_TopicPostCount-=10
	Local $new=$PHPBB_TopicPostCount
	phpbb_report_NewPostsAndLink()
	Return StringFormat("Old: %s, New: %s, Callback $PHPBB_ReportFunc = %s",$old,$new,$PHPBB_ReportFunc)
EndFunc



Func phpbb_report_NewPostsAndLink()
	ConsoleWrite('@@ (53) :(' & @MIN & ':' & @SEC & ') phpbb_report_NewPostsAndLink()' & @CR) ;### Function Trace
	If $PHPBB_URL="" Then Return SetError(1,0,'')
	Local $ret=phpbb_get_NewPostsAndLink($PHPBB_URL,$PHPBB_TopicID,$PHPBB_PostsPerPage,$PHPBB_TopicPostCount)
	Local $err=@error
	If $err=0 And StringLen($ret) Then Call($PHPBB_ReportFunc,$ret)
EndFunc

Func phpbb_get_NewPostsAndLink($url,$topicid,$postsperpage,$lastpostcount)
	ConsoleWrite('@@ (61) :(' & @MIN & ':' & @SEC & ') phpbb_get_NewPostsAndLink()' & @CR) ;### Function Trace
	If $PHPBB_URL="" Then Return SetError(1,0,"")
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
	ConsoleWrite('@@ (81) :(' & @MIN & ':' & @SEC & ') phpbb_url_viewtopic()' & @CR) ;### Function Trace
	Return StringFormat($url&'viewtopic.php?t=%s&start=%s',Int($topicid),Int($startpostcount))
EndFunc
Func phpbb_stringify_newpostinfo($newposts,$authors)
	ConsoleWrite('@@ (85) :(' & @MIN & ':' & @SEC & ') phpbb_stringify_newpostinfo()' & @CR) ;### Function Trace
	Local $out=StringFormat("%s New Forum Posts by: ",$newposts)
	If $newposts=0 Then Return SetError(1,0,"")
	$out&=_ArrayToString($authors,', ')
	Return $out
EndFunc
Func phpbb_get_newpostinfo($url,$topicid,$lastpostcount)
	ConsoleWrite('@@ (92) :(' & @MIN & ':' & @SEC & ') phpbb_get_newpostinfo()' & @CR) ;### Function Trace
	$PHPBB_TopicURL=phpbb_url_viewtopic($url,$topicid)
	$PHPBB_TopicHTML=BinaryToString(_InetRead($PHPBB_TopicURL,1))
	Local $tmpCount=phpbb_scrape_postcount($PHPBB_TopicHTML)

	If $tmpCount<=0 Then Return SetError(0xBAD,0,0)

	$PHPBB_TopicPostCount=$tmpCount
	Local $newposts=$PHPBB_TopicPostCount-$lastpostcount

	If $newposts<=0 Then Return SetError(0xF00D,0,0)

	Local $start=$PHPBB_TopicPostCount-$newposts; start post index of only the new posts.
	$PHPBB_TopicHTML=BinaryToString(_InetRead(phpbb_url_viewtopic($url,$topicid,$start),1))
	Local $authors=phpbb_scrape_authors($PHPBB_TopicHTML)

	Return SetError(0,$newposts,$authors)
EndFunc


Func phpbb_scrape_postcount($html)
	ConsoleWrite('@@ (113) :(' & @MIN & ':' & @SEC & ') phpbb_scrape_postcount()' & @CR) ;### Function Trace
	;&nbsp;[654 Posts]
	Local $sPosts=StringRegExpReplace($html,"(?s).*?&nbsp;\[([0-9]+) Posts\].*","\1")
	If @extended=0 Then Return SetError(1,0,0)
	Local $nPosts=Int($sPosts)
	If $nPosts=0 Then Return SetError(2,0,0)
	Return $nPosts
EndFunc
Func phpbb_scrape_author($html)
	ConsoleWrite('@@ (122) :(' & @MIN & ':' & @SEC & ') phpbb_scrape_author()' & @CR) ;### Function Trace
	;&nbsp;[654 Posts]
	Local $sHTML_Name=StringRegExpReplace($html,'(?s).*?<span class="name">(.*?)</span>.*',"\1")
	If @extended=0 Then Return SetError(1,0,'')
	Local $sName=StringRegExpReplace($sHTML_Name,'(?s).*?<b>(.*?)</b>.*',"\1")
	If @extended=0 Then Return SetError(2,0,'')
	$sName=StringStripWS($sName,1+2+4)
	Return $sName
EndFunc
Func phpbb_scrape_authors($html)
	ConsoleWrite('@@ (132) :(' & @MIN & ':' & @SEC & ') phpbb_scrape_authors()' & @CR) ;### Function Trace
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
	ConsoleWrite('@@ (149) :(' & @MIN & ':' & @SEC & ') phpbb_calc_pagecount()' & @CR) ;### Function Trace
	Return Ceiling($postcount/$postsperpage)
EndFunc
Func phpbb_calc_lastpagestart($postcount,$postsperpage);start post of the last page
	ConsoleWrite('@@ (153) :(' & @MIN & ':' & @SEC & ') phpbb_calc_lastpagestart()' & @CR) ;### Function Trace
	; the start post of the newest page is equivalent to the post count UP TO it (post count including previous pages only) - or 0 if there is no previous page.
	Return (Ceiling($postcount/$postsperpage)-1)*$postsperpage
EndFunc

