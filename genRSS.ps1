# Copyright (c) 2024 endkb (https://github.com/endkb)
# MIT License (see README.htm for details)

param(
	[String]$Profile,
	[String]$Test,
	[Switch]$Force,
	[Switch]$Logging,
	[String]$LogDirectory,
	[String]$LogFileNameFormat
	)

###################################### Configure options here ######################################

# Set the path to kid3.exe here
$kid3Exe = (Get-ChildItem -Path $PSScriptRoot -Filter "kid3-cli.exe" -Recurse |  Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })

# Set the path to rclone.exe here
$rcloneExe = (Get-ChildItem -Path $PSScriptRoot -Filter "rclone.exe" -Recurse | Select-Object -First 1 | % { $_.FullName })

# Set the file name format for the logs here: {0} = Profile name, {1} = Log ID, {2} = Script PID, {3} = Log file type, {4} = Date/time
$LogFileNameFormat = "{0}-{1}-{2}-genRSS_{3}.log"

####################################################################################################

Function Set-LogID {
	If ($GetLogIDFromTask -ne $false) {
		$TaskService = New-Object -ComObject('Schedule.Service')
		$TaskService.Connect()
		$runningTasks = $TaskService.GetRunningTasks(0)
		$Script:TaskGUID = $runningTasks | Where-Object{$_.EnginePID -eq $PID} | Select-Object -ExpandProperty InstanceGuid
		}
	If ($TaskGUID -ne $null) {
		$sha256 = [System.Security.Cryptography.SHA256]::Create()
		$hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($TaskGUID))
		$base64Hash = [Convert]::ToBase64String($hashBytes)
		$alphanumericHash = ($base64Hash.ToLower() -replace '[^a-z]', '')
		$Script:LogID = $alphanumericHash.Substring(0, [Math]::Min(4, $alphanumericHash.Length))
		} Else {
			$Script:LogID = -join ((97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
			}
	}

Function Set-LogFileName {
	Param ([String]$LogType)
	$LogFileNameFormatArray = $([io.path]::GetFileNameWithoutExtension($Profile)), $LogID, $PID, $LogType, $LogFileDate
	$LogFileName = $LogFileNameFormat -f $LogFileNameFormatArray
	Return $LogFileName
	}

If ($PSBoundParameters.ContainsKey('LogDirectory')) {
	$LogDirectory = $PSBoundParameters['LogDirectory']
	}
If ($PSBoundParameters.ContainsKey('LogFileNameFormat')) {
	$LogFileNameFormat = $PSBoundParameters['LogFileNameFormat']
	}

If (($Logging) -AND ($LogDirectory) -AND ($LogFileNameFormat)) {
	$LogFileDate = Get-Date
	Set-LogID
	$Script:LogFile = "$LogDirectory\$(Set-LogFileName -LogType 'Console+Vars')"
	Start-Transcript -Path $LogFile -Append -IncludeInvocationHeader -Verbose
	$TranscriptStarted = $true
	}

[Console]::OutputEncoding = [System.Text.Encoding]::utf8

$Recurse = $false

$Config = Get-Content -Raw -Path $Profile | ConvertFrom-StringData

ForEach ($key in $($Config.keys)) {
    $Config[$key] = $Config[$key] -Replace "^[`"`']" -Replace "[`"`']$"
	}

If ($Config['Logging'] -eq "yes") {
	$Logging = $true
	}

If (($Logging) -AND (!$TranscriptStarted)) {
	$LogFileDate = Get-Date
	If (($Config['LogDirectory'] -ne $null) -AND (-not $PSBoundParameters.ContainsKey('LogDirectory'))) {
		$LogDirectory = $Config['LogDirectory']
		}
	If (($Config['LogFileNameFormat']) -AND (-not $PSBoundParameters.ContainsKey('LogFileNameFormat'))) {
		$LogFileNameFormat = $Config['LogFileNameFormat']
		}
	Set-LogID
	$Script:LogFile = "$LogDirectory\$(Set-LogFileName -LogType 'Console+Vars')"
	Start-Transcript -Path $LogFile -Append -IncludeInvocationHeader -Verbose
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
		If ($Logging) {
			Stop-Transcript
			# Spit list of variables and values to file
			Get-Variable | Out-File $LogFile -Append -Encoding utf8 -Width 500
			}
		Exit
		}
    }

$nsHash = @{
	'atom' = 'http://www.w3.org/2005/Atom'
	'genRSS' = 'urn:genRSS:internal-data'
	'itunes' = 'http://www.itunes.com/dtds/podcast-1.0.dtd'
	'media' = 'http://search.yahoo.com/mrss/'
	'podcast' = 'https://podcastindex.org/namespace/1.0'
	}

Function Add-RssElement {
	param(
		[string]$elementName,
		[string]$ns,
		[string]$value,
		$parent
		)	
	$thisNode = $rss.CreateElement($elementName, $nsHash[$ns])
	$thisNode.InnerText = $value
	$null = $parent.AppendChild($thisNode)
	return $thisNode
	}

Function Add-CdataRssElement {
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
$null = $root.SetAttribute('xmlns:podcast','https://podcastindex.org/namespace/1.0')
$null = $root.SetAttribute('xmlns:atom','http://www.w3.org/2005/Atom')
$null = $root.SetAttribute('xmlns:content','http://purl.org/rss/1.0/modules/content/')
$null = $root.SetAttribute('xmlns:media','http://search.yahoo.com/mrss/')
$null = $root.SetAttribute('xmlns:itunes','http://www.itunes.com/dtds/podcast-1.0.dtd')
$rssTag = $rss.AppendChild($root)
$rssChannel  = $rss.CreateElement('channel')
$null = $root.AppendChild($rssChannel)

# Channel metadata
If ($Config['PodcastFeedURL']) {
	$atomlink = Add-RssElement -elementName 'atom:link' -ns 'atom' -value '' -parent $rssChannel
	$null = $atomlink.SetAttribute('href', $Config['PodcastFeedURL'])
	$null = $atomlink.SetAttribute('rel', "self")
	$null = $atomlink.SetAttribute('type', "application/rss+xml")
	}
$null = Add-RssElement -elementName 'title' -value $Config['PodcastTitle'] -parent $rssChannel
$null = Add-RssElement -elementName 'itunes:title' -ns 'itunes' -value $Config['PodcastTitle'] -parent $rssChannel
$poddesc = Add-RssElement -elementName 'description' -value '' -parent $rssChannel
$null = Add-CdataRssElement -elementName 'description' -value $Config['PodcastDescription'] -parent $poddesc
$poditunessum = Add-RssElement -elementName 'itunes:summary' -ns 'itunes' -value '' -parent $rssChannel
$null = Add-CdataRssElement -elementName 'itunes:summary' -value $Config['PodcastDescription'] -parent $poditunessum
$null = Add-RssElement -elementName 'itunes:author' -ns 'itunes' -value $Config['PodcastAuthor'] -parent $rssChannel
$null = Add-RssElement -elementName 'link' -value $Config['PodcastURL'] -parent $rssChannel
$null = Add-RssElement -elementName 'language' -value $Config['PodcastLanguage'] -parent $rssChannel
If ($Config['PodcastCopyright']) {
	$null = Add-RssElement -elementName 'copyright' -value $Config['PodcastCopyright'] -parent $rssChannel
	}
$null = Add-RssElement -elementName 'lastBuildDate' -value $([datetime]::Now.ToUniversalTime().ToString('r')) -parent $rssChannel
$null = Add-RssElement -elementName 'pubDate' -value $([datetime]::Now.ToUniversalTime().ToString('r')) -parent $rssChannel
If (($Config['OwnerName']) -And ($Config['OwnerEmail'])) {
	$owner = Add-RssElement -elementName 'itunes:owner' -ns 'itunes' -value '' -parent $rssChannel
	$null = Add-RssElement -elementName 'itunes:name' -ns 'itunes' -value $Config['OwnerName'] -parent $owner
	$null = Add-RssElement -elementName 'itunes:email' -ns 'itunes' -value $Config['OwnerEmail'] -parent $owner
	}
If ($Config['Category']) {
	$CategoryArray = $Config['Category'].Split(",")
	ForEach ($cat in $CategoryArray) {
		$category = Add-RssElement -elementName 'itunes:category' -ns 'itunes' -value '' -parent $rssChannel
		If ($cat.Contains(">")) {
			$SubCategoryArray = $cat.Split(">")
			$counter = 0
			:CategoryLoop ForEach ($subcat in $SubCategoryArray) {
				If ($counter -eq 0) {$counter++; Continue CategoryLoop}
				$subcategory = Add-RssElement -elementName 'itunes:category' -ns 'itunes' -value '' -parent $category
				$null = $subcategory.SetAttribute('text', $subcat)
				$counter++
				}
			}
			$null = $category.SetAttribute('text', $cat.Split(">")[0])
		}
	}
If (($Config['Explicit'] -eq "true") -OR ($Config['Explicit'] -eq "yes")) {
	$null = Add-RssElement -elementName 'itunes:explicit' -ns 'itunes' -value 'true' -parent $rssChannel
	} Else {$null = Add-RssElement -elementName 'itunes:explicit' -ns 'itunes' -value 'false' -parent $rssChannel}
If ($Config['Block']) {
	$BlockArray = $Config['Block'].Split(",")
	ForEach ($id in $BlockArray) {
		If (($id -eq "yes") -OR ($id -eq "no")) {
  				$blockelement = Add-RssElement -elementName 'itunes:block' -ns 'itunes' -value $id -parent $rssChannel
				$blockelement = Add-RssElement -elementName 'podcast:block' -ns 'podcast' -value $id -parent $rssChannel
				}
		If ($id.Contains(":")) {
			$BlockArray = $id.Split(":")
			$blockelement = Add-RssElement -elementName 'podcast:block' -ns 'podcast' -value $BlockArray[1] -parent $rssChannel
			$null = $blockelement.SetAttribute('id', $BlockArray[0])
			}
		}
	} Else {
 		$blockelement = Add-RssElement -elementName 'itunes:block' -ns 'itunes' -value 'no' -parent $rssChannel
		$blockelement = Add-RssElement -elementName 'podcast:block' -ns 'podcast' -value 'no' -parent $rssChannel
		}

# Channel image
$rssImage = Add-RssElement -elementName 'image' -value '' -parent $rssChannel
$null = Add-RssElement -elementName 'url' -value $Config['PodcastImage'] -parent $rssImage
$null = Add-RssElement -elementName 'link' -value $Config['PodcastURL'] -parent $rssImage
$null = Add-RssElement -elementName 'title' -value $Config['PodcastTitle'] -parent $rssImage
$itunesImage = Add-RssElement -elementName 'itunes:image' -ns 'itunes' -value '' -parent $rssChannel
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

	If ($ReleaseDate -gt $pubDate) {
		$pubDate = $ReleaseDate
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

	$thisItem = Add-RssElement -elementName 'item' -value '' -parent $rssChannel
	$null = Add-RssElement -elementName 'title' -value $Title -parent $thisItem
	$null = Add-RssElement -elementName 'itunes:title' -ns 'itunes' -value $Title -parent $thisItem
	$null = Add-RssElement -elementName 'link' -value $Link -parent $thisItem
	$itemDesc = Add-RssElement -elementName 'description' -value '' -parent $thisItem
	$null = Add-CdataRssElement -elementName 'description' -value $Comment.Replace("`r`n","<br>") -parent $itemDesc
	$itunesDesc = Add-RssElement -elementName 'itunes:summary' -ns 'itunes' -value '' -parent $thisItem
	$null = Add-CdataRssElement -elementName 'itunes:summary' -value $Comment.Replace("`r`n","<br>") -parent $itunesDesc
	$null = Add-RssElement -elementName 'itunes:duration' -ns 'itunes' -value $Duration -parent $thisItem
	$null = Add-RssElement -elementName 'guid' -value $Link -parent $thisItem
	$enclosure = Add-RssElement -elementName 'enclosure' -value '' -parent $thisItem
	$null = Add-RssElement -elementName 'category' -value "Podcasts" -parent $thisItem

	$null = Add-RssElement -elementName 'pubDate' -value $ReleaseDate.ToString('r') -parent $thisItem
	$null = Add-RssElement -elementName 'itunes:author' -ns 'itunes' -value $Config['PodcastAuthor'] -parent $thisItem
	# The URL is by default the file path.
	# You may want something like:
	$null = $enclosure.SetAttribute('url', "$url")
	#$null = $enclosure.SetAttribute('url',"file://$($item.FullName)")
	$null = $enclosure.SetAttribute('length',"$($item.Length)")
	$null = $enclosure.SetAttribute('type','audio/mpeg')
	$itemimage = Add-RssElement -elementName 'media:content' -ns 'media' -value '' -parent $thisItem
	$null = $itemimage.SetAttribute('url', $ItemCover)
	$null = $itemimage.SetAttribute('type', 'image/jpg')
	$null = $itemimage.SetAttribute('medium', 'image')
	}

If ($CheckMediaDirectoryHash -eq "yes") {
	$null = Add-RssElement -elementName 'MediaDirectoryHash' -ns 'genRSS' -value $MediaDirectoryHash -parent $rssTag
	}

If ($CheckProfileHash -eq "yes") {
	$null = Add-RssElement -elementName 'ProfileHash' -ns 'genRSS' -value $(Get-FileHash -Algorithm MD5 -Path $Profile).Hash -parent $rssTag
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
$rss.rss.channel.pubDate = $pubDate.ToString('r')
$rss.Save($xmlWriter)
$xmlWriter.Close()
Write-Verbose ("Tabbify finish " + ("*" * 60))

Write-Output "Output: $_filename"

If (($Config['rcloneConfig']) -and ($Config['RemotePublishDirectory']) -and ($Config['RemoteRSSFileName']) -and (!$Test)) {
	$RemotePublishFile = $Config['RemotePublishDirectory'] + "\" + $Config['RemoteRSSFileName']
	$rcloneConfig = $Config['rcloneConfig']
	& $rcloneExe copyto $_filename $RemotePublishFile --header-upload "Content-type: text/xml; charset=utf-8" --progress --config $rcloneConfig -v
    }

If ($Logging) {
	Stop-Transcript
	# Spit list of variables and values to file
	Get-Variable | Out-File $LogFile -Append -Encoding utf8 -Width 500
	}

Exit
