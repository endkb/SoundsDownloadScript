# Based on the format described at http://podcast411.com/howto_1.html

param(
	[String]$Profile,
	[String]$Test,
	[Switch]$Force,
	[Switch]$Debug,
	[String]$DebugDirectory
	)

###################################### Configure options here ######################################

# Set the path to kid3.exe here
$kid3Exe = (Get-ChildItem -Path $PSScriptRoot -Filter "kid3-cli.exe" -Recurse |  Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })

# Set the path to rclone.exe here
$rcloneExe = (Get-ChildItem -Path $PSScriptRoot -Filter "rclone.exe" -Recurse | Select-Object -First 1 | % { $_.FullName })

####################################################################################################

Function Get-DebugPath {Return "$DebugDirectory\genRSS_$([io.path]::GetFileNameWithoutExtension($Profile))-$PID-$i-Console+Vars.log"}

If ($Debug) {
	$i=0
	While (Test-Path $(Get-DebugPath)) {
		$i += 1
		}
	Start-Transcript -Path $(Get-DebugPath) -Append -IncludeInvocationHeader -Verbose
	$TranscriptStarted = $true
	}

[Console]::OutputEncoding = [System.Text.Encoding]::utf8

$Recurse = $false

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

$Config = Get-Content -Raw -Path $Profile | ConvertFrom-StringData

If (($Config['Debug'] -eq 'yes') -AND (!$Debug) -AND (!$TranscriptStarted)) {
	$Debug = $true
 	$DebugDirectory = $Config['DebugDirectory']
	}

If (($Debug) -AND (!$TranscriptStarted)) {
	$i=0
	While (Test-Path $(Get-DebugPath)) {
		$i += 1
		}
	Start-Transcript -Path $(Get-DebugPath) -Append -IncludeInvocationHeader -Verbose
	}

$MediaFilter = $("*." + $($Config['MediaExtension'].Split(",") -Join ",*.")).Split(",")

$MediaDirectory = $Config['MediaDirectory']

$Recursive = $Config['Recursive']
If ($Recursive -eq 'yes') {$Recurse = $true}
If ($Recursive -eq 'no') {$Recurse = $false}

$Directory = $Config['Directory']
$RSSFileName = $Config['RSSFileName']

$_filename = $Directory + "\" + $RSSFileName

If ($Test) {
	$_filename = $Test
	}

If ((!$Force) -AND (Test-Path $_filename)) {
    $LatestMediaFile = Get-ChildItem -Path $MediaDirectory\* -Include $MediaFilter -Recurse:$Recurse | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1	
	[xml]$RSSData = Get-Content $_filename
    If ($([datetime]$RSSData.rss.channel.lastBuildDate).ToUniversalTime() -gt $([datetime]$LatestMediaFile.LastWriteTimeUtc)) {
		Write-Host "Last built: $(([datetime]$RSSData.rss.channel.lastBuildDate).ToUniversalTime()) & Latest file: $([datetime]$LatestMediaFile.LastWriteTimeUtc)"
		If ($Debug) {
			Stop-Transcript
			# Spit list of variables and values to file
			Get-Variable | Out-File $(Get-DebugPath) -Append -Encoding utf8 -Width 500
			}
		Exit
		}
    }

Function createRssElement {
	param(
		[string]$elementName,
		[string]$value,
		$parent
		)
	$thisNode = $rss.CreateElement($elementName)
	$thisNode.InnerText = $value
	$null = $parent.AppendChild($thisNode)
	return $thisNode
	}

Function createiTunesRssElement {
	param(
		[string]$elementName,
		[string]$value,
		$parent
		)
	$thisNode = $rss.CreateElement($elementName, 'http://www.itunes.com/dtds/podcast-1.0.dtd')
	$thisNode.InnerText = $value
	$null = $parent.AppendChild($thisNode)
	return $thisNode
	}

Function createMediaRssElement {
	param(
		[string]$elementName,
		[string]$value,
		$parent
		)
	$thisNode = $rss.CreateElement($elementName, 'http://search.yahoo.com/mrss/')
	$thisNode.InnerText = $value
	$null = $parent.AppendChild($thisNode)
	return $thisNode
	}

Function createCDATAElement {
	param(
		[string]$elementName,
		[string]$value,
		$parent
		)
	$thisNode = $rss.CreateCDataSection($elementName)
	$thisNode.InnerText = $value
	$null = $parent.AppendChild($thisNode)
	return $thisNode
	}

$mp3s = gci $MediaDirectory\* -Include $MediaFilter -Recurse:$Recurse | Sort-Object CreationTime -Descending

[xml]$rss = ''

$root = $rss.CreateElement('rss')
$null = $root.SetAttribute('version','2.0')
$null = $root.SetAttribute('xmlns:media','http://search.yahoo.com/mrss/')
$null = $root.SetAttribute('xmlns:itunes','http://www.itunes.com/dtds/podcast-1.0.dtd')
$null = $rss.AppendChild($root)
$rssChannel  = $rss.CreateElement('channel')
$null = $root.AppendChild($rssChannel)

# Channel metadata 
$null = createRssElement -elementName 'title' -value $Config['PodcastTitle'] -parent $rssChannel
$null = createitunesRssElement -elementName 'itunes:title' -value $Config['PodcastTitle'] -parent $rssChannel
$poddesc = createRssElement -elementName 'description' -value '' -parent $rssChannel
$null = createCDATAElement -elementName 'description' -value $Config['PodcastDescription'] -parent $poddesc
$poditunessum = createitunesRssElement -elementName 'itunes:summary' -value '' -parent $rssChannel
$null = createCDATAElement -elementName 'itunes:summary' -value $Config['PodcastDescription'] -parent $poditunessum
$null = createitunesRssElement -elementName 'itunes:author' -value $Config['PodcastAuthor'] -parent $rssChannel
$null = createRssElement -elementName 'link' -value $Config['PodcastURL'] -parent $rssChannel
$null = createRssElement -elementName 'language' -value $Config['PodcastLanguage'] -parent $rssChannel
$null = createRssElement -elementName 'copyright' -value $Config['PodcastCopyright'] -parent $rssChannel
$null = createRssElement -elementName 'lastBuildDate' -value $([datetime]::Now.ToUniversalTime().ToString('r')) -parent $rssChannel
$null = createRssElement -elementName 'pubDate' -value $([datetime]::Now.ToUniversalTime().ToString('r')) -parent $rssChannel
If (($Config['OwnerName']) -And ($Config['OwnerEmail'])) {
	$owner = createitunesRssElement -elementName 'itunes:owner' -value '' -parent $rssChannel
	$null = createitunesRssElement -elementName 'itunes:name' -value $Config['OwnerName'] -parent $owner
	$null = createitunesRssElement -elementName 'itunes:email' -value $Config['OwnerEmail'] -parent $owner
	}
If ($Config['Category']) {
	$CategoryArray = $Config['Category'].Split(",")
	ForEach ($cat in $CategoryArray) {
		$category = createitunesRssElement -elementName 'itunes:category' -value '' -parent $rssChannel
		$null = $category.SetAttribute('text', $cat)
		}
	}
If ($Config['Explicit']) {
	$null = createitunesRssElement -elementName 'itunes:explicit' -value $Config['Explicit'] -parent $rssChannel
	}
If ($Config['Block'] -eq 'yes') {
	$null = createitunesRssElement -elementName 'itunes:block' -value 'yes' -parent $rssChannel
	}

# Channel image
$rssImage = createRssElement -elementName 'image' -value '' -parent $rssChannel
$null = createRssElement -elementName 'url' -value $Config['PodcastImage'] -parent $rssImage
$null = createRssElement -elementName 'link' -value $Config['PodcastURL'] -parent $rssImage
$null = createRssElement -elementName 'title' -value $Config['PodcastTitle'] -parent $rssImage
$itunesImage = createitunesRssElement -elementName 'itunes:image' -value '' -parent $rssChannel
$null = $itunesImage.SetAttribute('href', $Config['PodcastImage'])

$RerunLabel = $Config['RerunLabel']
try {$RerunFiles = $Config['RerunFiles'].Split(",")} catch {}
try {$RerunTitles = $Config['RerunTitles'].Split(",")} catch {}

try {$RerunTitles = $Config['RerunTitles'].Split(",")} catch {}
try {$SkipFiles = $Config['SkipFiles'].Split(",")} catch {}
try {$SkipTitles = $Config['SkipTitles'].Split(",")} catch {}

# Items in rss feed
:EpisodeLoop ForEach ($item in $mp3s) {

	$kid3data = & $kid3Exe -c '{\"method\":\"get\"}' $item
	$kid3json = $kid3data | ConvertFrom-Json

	If ($SkipFiles) {
		ForEach ($SkipItem in $SkipFiles) {
			If ($item -like "*$SkipItem*") {
				Continue EpisodeLoop
				}
			}
		}

	$Title = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Title'}).value

	If ($SkipTitles) {
		ForEach ($SkipItem in $SkipTitles) {
			If ($Title -like "*$SkipItem*") {
				Continue EpisodeLoop
				}
			}
		}

	If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'WEBSITE'}).value) {
		$Link = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'WEBSITE'}).value
		}
	If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'User-defined URL'}).value) {
		$Link = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'User-defined URL'}).value
		}

	$EpisodeCode = $Link.split('/')[-1]
	try {$SpecialTitle = $Config[$EpisodeCode]} catch {}
	If (($SpecialTitle) -AND ($Link -like "*$EpisodeCode*")) {
		$Title = $SpecialTitle
		}

	If (($RerunLabel) -AND ($RerunFiles)) {
		$FlaggedRerun = $false
		ForEach ($RerunItem in $RerunFiles) {
			If ($item -like "*$RerunItem*") {
				$Title = "$RerunLabel $Title"
				$FlaggedRerun = $true
				Break
				}
			}
		}
	If (($RerunLabel) -AND ($RerunTitles) -AND (!$FlaggedRerun)) {
		ForEach ($RerunItem in $RerunTitles) {
			If ($Title -like "*$RerunItem*") {
				$Title = "$RerunLabel $Title"
				Break
				}
			}
		}

	$Comment = $(($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Comment'}).value).Replace("`n","<br>")

	$FormatArray = $($kid3json.result.taggedFile.format).Split(" ")
	[array]::Reverse($FormatArray)
	ForEach ($elem in $FormatArray) {
		If ([string]$elem -match '^[0-9:]+:\d{2}$') {
			[string[]]$formats = 'm\:ss', 'mm\:ss', 'h\:mm\:ss', 'hh\:mm\:ss'
			try{$Duration = $("{0:hh\:mm\:ss}" -f [TimeSpan]::ParseExact($elem, $formats, $null))} catch {}
			Break
			}
		}

	$ItemCover = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'albumart'}).value

	If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'TOAL'}).value) {
		[DateTime]$ReleaseDate = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'TOAL'}).value
		}
	If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Original Album'}).value) {
		[DateTime]$ReleaseDate = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Original Album'}).value
		}
	If (!$ReleaseDate) {
		[DateTime]$ReleaseDate = $item.CreationTime.ToUniversalTime()
		}

	$url = $(($item -Replace [regex]::Escape($MediaDirectory.Trim('\')), $Config['MediaRootURL'].Trim('/')).Replace('\','/'))

	$thisItem = createRssElement -elementName 'item' -value '' -parent $rssChannel
	$null = createRssElement -elementName 'title' -value $Title -parent $thisItem
	$null = createitunesRssElement -elementName 'itunes:title' -value $Title -parent $thisItem
	$null = createRssElement -elementName 'link' -value $Link -parent $thisItem
	$itemDesc = createRssElement -elementName 'description' -value '' -parent $thisItem
	$null = createCDATAElement -elementName 'description' -value $Comment.Replace("`r`n","<br>") -parent $itemDesc
	$itunesDesc = createitunesRssElement -elementName 'itunes:summary' -value '' -parent $thisItem
	$null = createCDATAElement -elementName 'itunes:summary' -value $Comment.Replace("`r`n","<br>") -parent $itunesDesc
	$null = createitunesRssElement -elementName 'itunes:duration' -value $Duration -parent $thisItem
	$null = createRssElement -elementName 'guid' -value $Link -parent $thisItem
	$enclosure = createRssElement -elementName 'enclosure' -value '' -parent $thisItem
	$null = createRssElement -elementName 'category' -value "Podcasts" -parent $thisItem

	$null = createRssElement -elementName 'pubDate' -value $ReleaseDate.ToString('r') -parent $thisItem
	$null = createitunesRssElement -elementName 'itunes:author' -value $Config['PodcastAuthor'] -parent $thisItem
	# The URL is by default the file path.
	# You may want something like:
	$null = $enclosure.SetAttribute('url', "$url")
	#$null = $enclosure.SetAttribute('url',"file://$($item.FullName)")
	$null = $enclosure.SetAttribute('length',"$($item.Length)")
	$null = $enclosure.SetAttribute('type','audio/mpeg')
	$itemimage = createMediaRssElement -elementName 'media:content' -value '' -parent $thisItem
	$null = $itemimage.SetAttribute('url', $ItemCover)
	$null = $itemimage.SetAttribute('type', 'image/jpg')
	$null = $itemimage.SetAttribute('medium', 'image')
	}

$xmlWriterSettings =  New-Object System.Xml.XmlWriterSettings
$xmlWriterSettings.CloseOutput = $true
$xmlWriterSettings.Encoding = [System.Text.Encoding]::UTF8
# 4 space indent
$xmlWriterSettings.IndentChars = '    '
$xmlWriterSettings.Indent = $true
# $xmlWriterSettings.ConformanceLevel = 2
Write-Verbose  $('xml formatting - writing to ' + $_filename)
$xmlWriter = [System.Xml.XmlWriter]::Create($_filename, $xmlWriterSettings)
$rss.Save($xmlWriter)
$xmlWriter.Close()
Write-Verbose ("Tabbify finish " + ("*" * 60))

Write-Host "Output: $_filename"

If (($Config['rcloneConfig']) -and ($Config['RemotePublishDirectory']) -and ($Config['RemoteRSSFileName']) -and (!$Test)) {
	$RemotePublishFile = $Config['RemotePublishDirectory'] + "\" + $Config['RemoteRSSFileName']
	$rcloneConfig = $Config['rcloneConfig']
	& $rcloneExe copyto $_filename $RemotePublishFile --header-upload "Content-type: text/xml; charset=utf-8" --progress --config $rcloneConfig -v
    }

If ($Debug) {
	Stop-Transcript
	# Spit list of variables and values to file
	Get-Variable | Out-File $(Get-DebugPath) -Append -Encoding utf8 -Width 500
	}

Exit
