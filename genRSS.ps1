# Copyright (c) 2024 endkb (https://github.com/endkb)
# MIT License (see README.htm for details)

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

$Config = Get-Content -Raw -Path $Profile | ConvertFrom-StringData

ForEach ($key in $($Config.keys)) {
    $Config[$key] = $Config[$key] -Replace "^[`"`']" -Replace "[`"`']$"
	}

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

$CheckMediaDirectoryHash = $Config['CheckMediaDirectoryHash']															 
$CheckProfileHash = $Config['CheckProfileHash']

$_filename = $Directory + "\" + $RSSFileName

If ($Test) {
	$_filename = $Test
	}

If ($CheckMediaDirectoryHash -eq "yes") {
	$MediaFileList = Get-ChildItem -Path $MediaDirectory -Recurse | Sort-Object Name | Select -Expand FullName
	$md5hash = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
	$utf = New-Object -TypeName System.Text.UTF8Encoding
	$MediaDirectoryHash = [System.BitConverter]::ToString($md5hash.ComputeHash($utf.GetBytes($MediaFileList)))
	$MediaDirectoryHash = $MediaDirectoryHash.Replace("-", "")
	}

If ($CheckProfileHash -eq "yes") {
	$ProfileHash = $(Get-FileHash -Algorithm MD5 -Path $Profile).Hash
	}

If ((!$Force) -AND (Test-Path $_filename)) {
	$ExitFlag++
	[xml]$RSSData = Get-Content $_filename
	If ($CheckMediaDirectoryHash -eq "yes") {
		If ($($RSSData.rss.MediaDirectoryHash).InnerText -eq $MediaDirectoryHash) {
			$ExitFlag--
			$UpdateMessage = "MediaDirectoryHash: $MediaDirectoryHash matches"
			}
		} Else {
			$LatestMediaFile = Get-ChildItem -Path $MediaDirectory\* -Include $MediaFilter -Recurse:$Recurse | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
			If ($([datetime]$RSSData.rss.channel.lastBuildDate).ToUniversalTime() -gt $([datetime]$LatestMediaFile.LastWriteTimeUtc)) {
				$ExitFlag--
				$UpdateMessage = "Last built: $(([datetime]$RSSData.rss.channel.lastBuildDate).ToUniversalTime()) & Latest file: $([datetime]$LatestMediaFile.LastWriteTimeUtc)"
				}
			}
	If ($CheckProfileHash -eq "yes") {
		$ExitFlag++
		If ($($RSSData.rss.ProfileHash).InnerText -eq $ProfileHash) {
			$ExitFlag--
			}
		}
	If ($ExitFlag -le 0) {
		Write-Output $UpdateMessage
		If ($CheckProfileHash -eq "yes") {
			Write-Output "ProfileHash: $ProfileHash matches"
			}
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

Function createHashElement {
	param(
		[string]$elementName,
		[string]$value,
		$parent
		)
	$thisNode = $rss.CreateElement($elementName, 'urn:genRSS:hash')
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
$rssTag = $rss.AppendChild($root)
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
		If ($cat.Contains(">")) {
			$SubCategoryArray = $cat.Split(">")
			$counter = 0
			:CategoryLoop ForEach ($subcat in $SubCategoryArray) {
				If ($counter -eq 0) {$counter++; Continue CategoryLoop}
				$subcategory = createitunesRssElement -elementName 'itunes:category' -value '' -parent $category
				$null = $subcategory.SetAttribute('text', $subcat)
				$counter++
				}
			}
			$null = $category.SetAttribute('text', $cat.Split(">")[0])
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
$AutoDetectReruns = $Config['AutoDetectReruns']
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

	If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Website'}).value) {
		$Link = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'WEBSITE'}).value
		} Else {
			If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'WOAR'}).value) {
				$Link = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'WOAR'}).value
				}
			}

	$EpisodeCode = $Link.split('/')[-1]
	try {$SpecialTitle = $Config[$EpisodeCode]} catch {}
	If (($SpecialTitle) -AND ($Link -like "*$EpisodeCode*")) {
		$Title = $SpecialTitle
		}

	If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Release Date'}).value) {
		[DateTime]$ReleaseDate = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Release Date'}).value
		} Else {
			If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'TOAL'}).value) {
				[DateTime]$ReleaseDate = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'TOAL'}).value
				}
			}		
	If (!$ReleaseDate) {
		[DateTime]$ReleaseDate = $item.CreationTime.ToUniversalTime()
		}

	If (($RerunLabel) -AND ($RerunFiles)) {
		$FlaggedRerun = $false
		ForEach ($RerunItem in $RerunFiles) {
			If ($item -like "*$RerunItem*") {
				$Title = "$RerunLabel$Title"
				$FlaggedRerun = $true
				Break
				}
			}
		}
	If (($RerunLabel) -AND ($RerunTitles) -AND (!$FlaggedRerun)) {
		ForEach ($RerunItem in $RerunTitles) {
			If ($Title -like "*$RerunItem*") {
				$Title = "$RerunLabel$Title"
    				$FlaggedRerun = $true
				Break
				}
			}
		}

	If (($RerunLabel) -AND (($AutoDetectReruns -eq "yes") -OR (($AutoDetectReruns -match "^[\d\.]+$") -AND ($AutoDetectReruns -gt 0))) -AND (!$FlaggedRerun)) {
		If ($AutoDetectReruns -eq "yes") {$AutoDetectReruns = 90}
		If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Original Date'}).value) {
		[DateTime]$OriginalDate = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'Original Date'}).value
		} Else {
			If ($($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'TDOR'}).value) {
				[DateTime]$OriginalDate = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'TDOR'}).value
				}
			}
		If (((New-TimeSpan -Start $OriginalDate -End $ReleaseDate).Days) -gt [int]$AutoDetectReruns) {
			$Title = "$RerunLabel$Title"
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

	$ItemCover = $($kid3json.result.taggedFile.tag2.frames | Where {$_.Name -eq 'AlbumArt'}).value

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

If ($CheckMediaDirectoryHash -eq "yes") {
	$null = createHashElement -elementName 'MediaDirectoryHash' -value $MediaDirectoryHash -parent $rssTag
	}

If ($CheckProfileHash -eq "yes") {
	$null = createHashElement -elementName 'ProfileHash' -value $(Get-FileHash -Algorithm MD5 -Path $Profile).Hash -parent $rssTag
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

Write-Output "Output: $_filename"

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
