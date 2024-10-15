# SoundsDownloadScript vX

# Copyright (c) 2024 endkb (https://github.com/endkb)
# MIT License (see README.htm for details)

# Expect the following variables to be set as parameters
param(
[String]$ProgramURL,                        # bbc.co.uk/programmes URL of the show to download the latest ep or bbc.co.uk/sounds/play
[String]$SaveDir,                           # Directory to publish the finished audio file
[String]$ShortTitle,                        # Short reference for the filename
[String]$TrackNoFormat,                     # Set track no as DateTime format string: c(r) = count up (recurs), o = one digit year, jjj = Julian date
[String]$TitleFormat,                       # Format the title: {0} = primary, {1} = secondary, {2} = tertiary, {3} = UTC release date, {4} = UK rel
[Switch]$UseOrigRelease,                    # Sets the release date of the episode to the original date the episode aired
[Int32]$Bitrate,                            # Download a specific available bitrate: 48, 96, 128, or 320, 0 = Download highest available
[Switch]$mp3,                               # Transcode the audio file to mp3 after downloading
[Int32]$Archive,                            # The number of episodes to keep - omit or set to 0 to keep everything
[Switch]$Days,                              # Measure -Archive by the number of days instead of the number of episodes to keep
[String]$VPNConfig,                         # Path to the ovpn file(s) separated by comma - also create and set auth-user-pass file if applicable
[String]$rcloneConfig,                      # Path to the rclone config file - rclone.exe config create
[String]$rcloneSyncDir,                     # Remote and directory rclone should upload to separated by comma if multiple - for AWS S3 use config:bucket\directory
[String]$DotSrcConfig,                      # Path to external .ps1 script file containing script configuration options
[Switch]$Logging,                           # Output the console to a text file in the LogDirectory
[String]$LogDirectory,                      # Directory path to save the log files if enabled
[String]$LogFileNameFormat,                 # Format log file names: {0} = shorttitle, {1} = task guid hash, {2} = PID, {3} = log type, {4} = date/time
[Switch]$NoDL,                              # Grab the metadata only - Don't download the episode
[Switch]$Force                              # Download the episode even if it's already downloaded - Will not overwrite existing
)

<#      ┌────────────────────────────────────────────────────────────────────────────────┐
        │                  ▼    Begin script configuration options    ▼                  │
        └────────────────────────────────────────────────────────────────────────────────┘      #>

$DefaultTrackNoFormat = 'c'                 # DateTime format string to set the track number if -TrackNoFormat is not set
$DefaultTitleFormat = '{1}'                 # Format string to set episode title to if -TitleFormat is not set
$DefaultBitrate = 96                        # Bitrate to download if -Bitrate is not set: 48, 96, 128, 320, 0 = Download highest available

$GenreTag = $true                           # Pull the genre(s) from the program page and set into the metadata

$DumpDirectory = $env:TEMP                  # Directory to save the stream to while working on it - to use the win temp dir: $env:TEMP

$VPNAdapter = 'OpenVPN TAP-Windows6'        # Name of the adapter used by OpenVPN
$VPNTimeout = 60                            # Number of seconds to wait before giving up on VPN if it doesn't connect

$ScriptInstanceControl = $true              # Allow only one instance of script to download at a time: Set to $true if using VPN
$LockFileDirectory = $env:TEMP              # If using ScriptInstanceControl: Specify non-env dir if running script under different users
$LockFileMaxDuration = 10800                # Max age in seconds before lock files are considered orphaned and deleted - 0 = Disabled

$ytdlpUpdate = $false                       # Download yt-dlp updates before running script
$rcloneUpdate = $false                      # Update rclone to the latest stable version

$Logging = $true                            # Force logging: $true = logging on, $false = no logging, $Logging > $null = read cmd line & don't force
$Printjson = $false                         # Print the episode metadata in json format to the console for troubleshooting
$LogDirectory = 'E:\FilesTemp\Debug'        # Directory to save/move logs to when -Logging switch is present
$LogFileNameFormat = "{0}-{1}-{2}-{3}.log"	# Format the log file name: {0} = ShortTitle, {1} = log id, {2} = PID, {3} = log type, {4} = date/time

<#	Paths to ffmpeg, ffprobe kid3-cli, openvpn (optional), rclone (optional), and yt-dlp executables - or use the following:
		(Get-ChildItem -Path $PSScriptRoot -Filter "<name-of.exe>" -Recurse | Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })
	to recurively search subdirectories for these files  #>
$ffmpegExe = (Get-ChildItem -Path $PSScriptRoot -Filter "ffmpeg.exe" -Recurse | Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })
$ffprobeExe = (Get-ChildItem -Path $PSScriptRoot -Filter "ffprobe.exe" -Recurse |  Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })
$kid3Exe = (Get-ChildItem -Path $PSScriptRoot -Filter "kid3-cli.exe" -Recurse |  Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })
$rcloneExe = (Get-ChildItem -Path $PSScriptRoot -Filter "rclone.exe" -Recurse |  Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })
$vpnExe = (Get-ChildItem -Path $env:Programfiles -Filter 'openvpn.exe' -Recurse -ErrorAction SilentlyContinue |  Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })
$ytdlpExe = (Get-ChildItem -Path $PSScriptRoot -Filter "yt-dlp.exe" -Recurse |  Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | % { $_.FullName })

$SortArticles =                             # String of definite articles to trim from fields for sorting tags - separate with a pipe, ^ is beginning of string
"^a |^an |^el |^l'|^la |^las |^le |^les |^lo |^los |^the |^un |^una |^une "

<#	SCRIPT BLOCKS: Configure script blocks below to run rclone commands depending on the remote backend. New ones can be included. Script blocks must be
	stored in vars that start with 'remote_'. Use the 'If' statement to match the remote type found in the rclone config file. See https://rclone.org/docs/	#>
# Internet Archive
$remote_ia = {If ($RemoteConfig.$Remote.type -eq "internetarchive") {
	# Build the headers to set the metadata - See https://archive.org/developers/metadata-schema/index.html and https://github.com/vmbrasseur/IAS3API/blob/master/metadata.md#setting-metadata-values-via-headers
	$iaHeaders = @( )
	$iaHeaders += "--header", "X-Archive-Meta-Collection: opensource_audio"
	$iaHeaders += "--header", "X-Archive-Meta-Creator: $(Format-rcloneCommandString($Station))"
	$iaHeaders += "--header", "X-Archive-Meta-Date: $($ReleaseDate.ToString("yyyy-MM-dd"))"
	$iaHeaders += "--header", "X-Archive-Meta-Description: $(Format-rcloneCommandString($Comment.Replace("`n","<br>")))"
	$iaHeaders += "--header", "X-Archive-Meta-Episode-Title: $(Format-rcloneCommandString($EpisodeTitle))"
	$iaHeaders += "--header", "X-Archive-Meta-External-Identifier: $EpisodePage"
	$iaHeaders += "--header", "X-Archive-Meta-MediaType: audio"
	$iaHeaders += "--header", "X-Archive-Meta-Notes: $SoundsPlayLink"
	$iaHeaders += "--header", "X-Archive-Meta-Program-Title: $(Format-rcloneCommandString($ShowTitle))"
	$iaHeaders += "--header", "X-Archive-Meta-Publisher: $(Format-rcloneCommandString($Station))"
	$iaHeaders += "--header", "X-Archive-Meta-Reviews-Allowed: none"
	$iaHeaders += "--header", "X-Archive-Meta-Source: $EpisodePage"
	$iaHeaders += "--header", "X-Archive-Meta-Title: $(Format-rcloneCommandString($ShowTitle)) | $(Format-rcloneCommandString($EpisodeTitle))"
	$iaHeaders += "--header", "X-Archive-Meta-Year: $($ReleaseDate.ToString("yyyy"))"

	# Create a page with the metadata and upload the cover art
	& $rcloneExe copyto "$DumpDirectory\$ImageName" "$rcloneSyncDir\$(([system.io.fileinfo]$MoveLoc).BaseName)\$(([system.io.fileinfo]$MoveLoc).BaseName)_itemimage.jpg" $iaHeaders --metadata --config $rcloneConfig --progress -v --dump headers $rcloneLoggingArgs
	# Upload the audio file to the page
	& $rcloneExe copyto $MoveLoc "$rcloneSyncDir$(([system.io.fileinfo]$MoveLoc).BaseName)\$(Split-Path $MoveLoc -leaf)" --metadata --config $rcloneConfig --progress -v --dump headers $rcloneLoggingArgs
	}}

# Cloudflare Storage
$remote_r2 = {If ($RemoteConfig.$Remote.provider -eq "Cloudflare") {
	# Sync the SaveDir with the remote dir
	& $rcloneExe sync $SaveDir $rcloneSyncDir --create-empty-src-dirs --progress --config $rcloneConfig -v $rcloneLoggingArgs
	}}

<#      ┌────────────────────────────────────────────────────────────────────────────────┐
        │                   ▲    End script configuration options    ▲                   │
        └────────────────────────────────────────────────────────────────────────────────┘      #>

Function Exit-Script {
	# Clean up the cover art from the DumpDirectory
	If ($ImageName) {Get-Childitem -Path $DumpDirectory -Filter $ImageName -Recurse | Remove-Item -Force}
	If ($Logging) {
		# Stop recording the console
		Stop-Transcript
		# Spit list of variables and values to file
		Get-Variable | Out-File "$LogDirectory\$(Set-LogFileName -LogType 'Console+Vars')" -Append -Encoding utf8 -Width 500
		}
	Exit
	}

Function Get-IniContent ($FilePath) {
	$ini = @{}
	Switch -regex -File $FilePath {
		# Parse section headers
		“^\[(.+)\]” {
			$Section = $matches[1]
			$ini[$section] = @{}
			$CommentCount = 0
			}
		# Parse comments
		“^(;.*)$” {
			$Value = $matches[1]
			$CommentCount = $CommentCount + 1
			$Name = “Comment” + $CommentCount
			$ini[$section][$name] = $Value.Trim()
			}
		# Parse keys
		“(.+?)\s*=(.*)” {
			$Name,$Value = $matches[1..2]
			$ini[$section][$name] = $value.Trim()
			}
		}
	Return $ini
	}

Function Get-LogID {
	If ($LogID -eq $null) {
		# Initiate a COM object and connect
		$TaskService = New-Object -ComObject('Schedule.Service')
		$TaskService.Connect()
		$runningTasks = $TaskService.GetRunningTasks(0)
		# Get the task associated with the PID of the script
		$Script:TaskGUID = $runningTasks | Where-Object{$_.EnginePID -eq $PID} | Select-Object -ExpandProperty InstanceGuid
		If ($TaskGUID -ne $null) {
			# Compute the SHA-256 hash of the input string
			$sha256 = [System.Security.Cryptography.SHA256]::Create()
			$hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($TaskGUID))
			# Convert the hash to a Base64 string
			$base64Hash = [Convert]::ToBase64String($hashBytes)
			# Convert to lowercase and remove non-alphanumeric characters
			$alphanumericHash = ($base64Hash.ToLower() -replace '[^a-z]', '')
			$LogID = $alphanumericHash.Substring(0, [Math]::Min(4, $alphanumericHash.Length))
			} Else {
				# If $TaskGUID is empty then it's not running in a task - make something up
				$LogID = -join ((97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
				}
			}
	Return $LogID
	}

Function Invoke-LoggingRoutine {
	# Create the directory to save/move logs to
	New-Item -ItemType Directory -Force -Path "$LogDirectory" > $null
	$Script:LogFileDate = Get-Date
	
	# Build a command line arguments for openvpn and rclone to output logs
	$Script:vpnLoggingArgs = "--log-append `"$LogDirectory\$(Set-LogFileName -LogType 'vpn')`""
	$Script:rcloneLoggingArgs = "--log-file", "$LogDirectory\$(Set-LogFileName -LogType 'rclone')"

	# Start recording the console
	Start-Transcript -Path "$LogDirectory\$(Set-LogFileName -LogType 'Console+Vars')" -Append -IncludeInvocationHeader -Verbose
	$Script:TranscriptStarted = $true
	Write-Output "**Logging: Saving log files to $LogDirectory\$(Set-LogFileName -LogType '*')"	
	}

Function Set-LogFileName {
	Param ([String]$LogType)
	$LogFileNameFormatArray = $ShortTitle, $(Get-LogID), $PID, $LogType, $LogFileDate
	$LogFileName = $LogFileNameFormat -f $LogFileNameFormatArray
	Return $LogFileName
	}

Function Start-ytdlp {
	# Use the default bitrate if not speficied in CL
	If (!$Bitrate) {
		$Bitrate = $DefaultBitrate
		}
	If ($Bitrate -ge 1) {
 		# Build the yt-dlp argument to specify the bitrate
		$ytdlpBitrate = "[abr=$Bitrate]"
		}
  	# Start yt-dlp
	& $ytdlpExe --ffmpeg-location $ffmpegExe --audio-quality 0 -f ba[ext=m4a]$ytdlpBitrate -o "$DumpFile.%(ext)s" $SoundsPlayLink
	}

# Use LogDirectory from the CL if it's there
If ($PSBoundParameters.ContainsKey('LogDirectory')) {
    $LogDirectory = $PSBoundParameters['LogDirectory']
    }

# Use LogFileNameFormat from the CL if it's there
If ($PSBoundParameters.ContainsKey('LogFileNameFormat')) {
    $LogFileNameFormat = $PSBoundParameters['LogFileNameFormat']
    }

# Turn off PS progress bars for speed
$ProgressPreference = 'SilentlyContinue'

# This will override any of the config options above with whatever is specified in $DotSrcConfig file
If ($DotSrcConfig) {
	If (Test-Path $DotSrcConfig) {
		$DotSrcConfig = Get-Item -Path $DotSrcConfig -ErrorAction SilentlyContinue
		If ([System.IO.Path]::GetExtension($DotSrcConfig) -eq '.ps1') {
			# Check for necessary variables before importing the script
			If ((Select-String -Path $DotSrcConfig -Pattern '^[\s]*(\$DumpDirectory)[\s]*=') -AND
				(Select-String -Path $DotSrcConfig -Pattern '^[\s]*(\$ffmpegExe)[\s]*=') -AND
				(Select-String -Path $DotSrcConfig -Pattern '^[\s]*(\$ffprobeExe)[\s]*=') -AND
				(Select-String -Path $DotSrcConfig -Pattern '^[\s]*(\$kid3Exe)[\s]*=') -AND
				(Select-String -Path $DotSrcConfig -Pattern '^[\s]*(\$ytdlpExe)[\s]*=')) {
				Write-Output "**Importing external script configuration options: $DotSrcConfig"
				# Import the script
				. $DotSrcConfig
				} Else {
					Write-Output "**Var(s) missing from external script configuration options: $DotSrcConfig"
					Exit-Script
					}
			} Else {
				Write-Output "**External script configuration options file must be .ps1: $DotSrcConfig"
				Exit-Script
				}
		} Else {
			Write-Output "**Couldn't access external script configuration options: $DotSrcConfig"
			Exit-Script
			}
	}

# Start logging if enabled in a $DotSrcConfig script and not enabled earlier
If (($Logging) -AND ($TranscriptStarted -ne $true)) {
	Invoke-LoggingRoutine
	}

# Don't bother searching the page if ProgramURL is already a Sounds link
If ($ProgramURL -like "https://www.bbc.co.uk/sounds/play/*") {
	$SoundsPlayLink = $ProgramURL
	}

If (!$SoundsPlayLink) {
	# Get the content of the program page
	$ProgramPageHTML = (Invoke-WebRequest –Uri $ProgramURL -UseBasicParsing)
	# Search the program page for the Sounds link to the latest episode
	$SoundsPlayLink = ($ProgramPageHTML.Links | Where-Object {$_.href -like "https://www.bbc.co.uk/sounds/play/*"} | Select-Object -First 1).href
	}

Write-Output "**Sounds URL: $SoundsPlayLink"

# Parse the program ID from the Sounds link
$ProgramID = $($SoundsPlayLink -split "/")[-1]

If (($ScriptInstanceControl) -AND (!$NoDL)) {
	# Function to delete the lock file to release control
	Function Unlock-Control {
		Remove-Item -Path $Script:LockFile -Force
		If (!(Test-Path $Script:TestLockFile)) {Write-Output "**Released control at $(Get-Date)"}
		}
	# Non-VPN DLs can run simultaneously with other non-VPN DLs - VPN DLs can only run one at a time
	If ($VPNConfig) {
		# Set lock file parameters - If VPN is used heed any lock files
		$Script:LockFile = $(Join-Path -Path $LockFileDirectory -ChildPath $([String]$PID+'.vpn.lock'))
		$Script:TestLockFile = $(Join-Path -Path $LockFileDirectory -ChildPath $('*.lock'))
		} Else {
			# If VPN is not used only care about vpn lock files
			$Script:LockFile = $(Join-Path -Path $LockFileDirectory -ChildPath $([String]$PID+'.lock'))
			$Script:TestLockFile = $(Join-Path -Path $LockFileDirectory -ChildPath $('*.vpn.lock'))
			}
	# See if control is locked by looking for any lock files
	If (Test-Path $Script:TestLockFile) {
		Write-Output "**Waiting for control at $(Get-Date)"
		# Generate random milliseconds up to 2 secs as the sleep interval - reduces chance of control collisions
		$RandomInterval = Get-Random -Minimum 2000 -Maximum 5000
		Do {
			# Routine to clean up orphaned lock files
			If (($LockFileMaxDuration -gt 0) -AND ($DoCount -eq $NextCheck)) {
				# Check the lock file directory for old lock files
				$GetLockFiles = Get-ChildItem -Path $LockFileDirectory -Filter "*.lock" -Force | Where-Object {$_.CreationTime -lt (Get-Date).AddSeconds($LockFileMaxDuration*-1)}
				# Delete each one
				ForEach ($OrphanedLockFile in $GetLockFiles) {
					Remove-Item $OrphanedLockFile.FullName
					Write-Output "**Released $OrphanedLockFile (possibly orphaned)"
					}
				# Only check every 4 instances to save resources
				$NextCheck = $NextCheck+4
				}
			# Recheck for test file at random interval
			Start-Sleep -Milliseconds $RandomInterval
			$DoCount++
			# Wait your turn until lock files are gone
			} Until (!(Test-Path $Script:TestLockFile))
		}
	# Take control by creating a lock file
	$null = New-Item $Script:LockFile
	If (Test-Path $Script:LockFile) {
		Write-Output "**Control received at $(Get-Date)"
		Write-Output "**Lock file is $Script:LockFile"
		}
	}

$Download = 1
# List all files in SaveDir to see if it's been downloaded
$Files = Get-ChildItem $SaveDir -ErrorAction SilentlyContinue
ForEach ($File in $Files) {
	# If a file with the same ProgramID exists don't redownload it
	If ($File.Name -match $ProgramID) {$Download = 0}
	}

If (($Download -eq 1) -OR ($NoDL) -OR ($Force)) {
	# Check for yt-dlp updates and download
	If ((!$NoDL) -AND ($ytdlpUpdate -eq $true)) {& $ytdlpExe -U}

	# Load the Sounds page to grab the tag information
	$SoundsShowPage = (Invoke-WebRequest –Uri $SoundsPlayLink -Method Get -UseBasicParsing -ContentType "text/plain; charset=utf-8").Content

	# Parse the metadata section from the Sounds page and read it as JSON
	$Getjson = "(?<=<script> window.__PRELOADED_STATE__ = )(.*?)(?=; </script>)"
	$jsonResult = [regex]::match($SoundsShowPage, $Getjson)
	# Clean up stupid smart quotes
	$jsonResult = "$jsonResult" -replace '[\u201C\u201D\u201E\u201F\u2033\u2036]', "$([char]92)$([char]34)" -replace "[\u2018\u2019\u201A\u201B\u2032\u2035]", "$([char]39)"
	$jsonData = $jsonResult | ConvertFrom-Json

	# Put the titles into a table
	$TitleTable = $($jsonData.modules.data[0].data.titles)

	If (!$TitleFormat) {
		$TitleFormat = $DefaultTitleFormat
		}

	# Set the name of the program
	$ShowTitle = $TitleTable.'primary'

	# Parse the synopses to set the comment
	$SynopsesTable = $($jsonData.modules.data[0].data.synopses)

	# Default the comment to the short description
	$Comment = $SynopsesTable.'short'
	# Use the medium description if it's available
	If ($SynopsesTable.'medium') {
		$Comment = $SynopsesTable.'medium'
		}
	# Use the long description if it's available
	If ($SynopsesTable.'long') {
		$Comment = $SynopsesTable.'long'
		}

	# Set the station
	$Station = $($jsonData.modules.data[0].data.network.short_title)

	# Grab the release date
	If (!$UseOrigRelease) {$ReleaseDate = [datetime]$($jsonData.modules.data[0].data.availability.from)}
	If ($UseOrigRelease) {$ReleaseDate = [datetime]$($jsonData.modules.data[0].data.release.date)}

	# Grab the original release date
	$OriginalReleaseDate = [datetime]$($jsonData.modules.data[0].data.release.date)

	# Put all of the tracks in an array
	$TrackTable = $($jsonData.tracklist.tracks)
	If ($TrackTable) {
		$trackno = 0
		# Run through each track to build the track list
		ForEach ($item in $TrackTable) {
			# Build the track list line by line
			$TrackList = $TrackList + "$([string]$($trackno+1)). $($item.titles.primary)-$($item.titles.secondary)`n"
			$trackno++
			}
		# Add the track list to the comments
		$Comment = $Comment + "`n`nTracklist:`n" + $TrackList
		}

	# Get the cover art
	$CoverResult = $($jsonData.modules.data[0].data.image_url).replace("{recipe}","1024x1024")

	# Format the episode title (after pulling all other metadata)
	$TitleFormatArray = $TitleTable.'primary', $TitleTable.'secondary', $TitleTable.'tertiary', $ReleaseDate.ToUniversalTime(), [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($ReleaseDate, 'GMT Standard Time')
	$EpisodeTitle = $TitleFormat -f $TitleFormatArray

	# Put each variable in the title format into an array
	$TitleCheckVarArray=[Regex]::Matches($TitleFormat, '(?={)(.*?})') | ForEach-Object {$_.Groups[1].value}
 	# Run through the array and look for blank variables
	:TitleCheck ForEach ($var in $TitleCheckVarArray) {
		$TitleCheck = $var -f $TitleFormatArray
		If ($TitleCheck -eq '') {
			Write-Output "**Correcting null title: $EpisodeTitle"
			# Set the title to the primary (usually the show name)
			$EpisodeTitle = $TitleTable.'primary'
			# Use the secondary title if it's available
			If ($TitleTable.'secondary') {
				$EpisodeTitle = $TitleTable.'secondary'
				}
			# Use the tertiary title if it's available
			If ($TitleTable.'tertiary') {
				$EpisodeTitle = $TitleTable.'tertiary'
				}
			Break TitleCheck
			}
		}

	Write-Output "**Episode Title: $EpisodeTitle"
	Write-Output "  {0} $($TitleTable.'primary')"
	Write-Output "  {1} $($TitleTable.'secondary')"
	Write-Output "  {2} $($TitleTable.'tertiary')"
	Write-Output "**Show: $ShowTitle"
	Write-Output "**Description: $Comment"
	Write-Output "**Station: $Station"
	Write-Output "**Released On: $ReleaseDate"
	Write-Output "**Released On: $($ReleaseDate.ToUniversalTime())"
	
	If ($Printjson) {
		Write-Output "**Beginning of json output (line below):"
		Write-Output $jsonResult
		Write-Output "**End of json output (line above)"
		}

	If ($NoDL) {Exit-Script}

	# Build the DumpFile path
	$NakedName = "$ProgramID-media"
	$DumpFile = "$DumpDirectory\$NakedName"

	If ($VPNConfig) {
		# Put the VPN config paths into an array for looping
		$VPNArray = $VPNConfig.Split(",")
		# Build an array to keep track of PIDs for VPN processes you start for closing later
		$VPNPIDArray = @()
		# Loop through each VPN config so if yt-dlp doesn't download move on to the next one
		:VPNLoop ForEach ($VPNServer in $VPNArray) {
			# Check to see whether the VPN adapter is free
			If ($(Get-NetAdapter -Name $VPNAdapter).Status -ne "Disconnected") {
				Write-Output "**Waiting because $VPNAdapter is in use"
				# If VPN adapter is already connected wait until it's disconnected
				Do { #Wait
					} While ($(Get-NetAdapter -Name $VPNAdapter).Status -ne "Disconnected")
				}

			# Call OpenVPN in a new process and connect using the config file
			$VPNApp = Start-Process $vpnExe -ArgumentList "$vpnLoggingArgs --config `"$VPNServer`"" -passthru
			# Add the VPN PID to the array for closing later
			$VPNPIDArray += $VPNApp.Id
			# Start a timer
			$VPNConnectionTimer = [System.Diagnostics.Stopwatch]::StartNew()
			Write-Output "**Connecting to the VPN using $VPNServer"
			# Wait until the VPN connects - Check link is up has IP and DNS
			Do { #Wait
				} Until ((($(Get-NetAdapter -Name $VPNAdapter).Status -eq "Up") -AND ($(Get-NetIPConfiguration -InterfaceAlias $VPNAdapter).IPv4Address) -AND ($(Get-NetIPConfiguration -InterfaceAlias $VPNAdapter).DNSServer)) -OR ($VPNConnectionTimer.Elapsed.TotalSeconds -gt $VPNTimeout))
			If ($VPNConnectionTimer.Elapsed.TotalSeconds -gt $VPNTimeout) {
				Write-Output "**Could not connect to the VPN"
				Stop-Process -Id $VPNApp.Id
				Continue
				}
			If ($(Get-NetAdapter -Name $VPNAdapter).Status -eq "Up") {
				Write-Output "**Connected to the VPN"

				# Call yt-dlp to download the file
				Start-ytdlp
				}

			ForEach ($VPNPID in $VPNPIDArray) {
				Stop-Process -Id $VPNPID -ErrorAction SilentlyContinue
				}

			# Search for the DumpFile to see if yt-dlp finished downloading
			$FinishedFile = Get-ChildItem -Path $DumpDirectory\$NakedName.* -Exclude *.part, *.ytdl | Select-Object -Last 1
			If ($FinishedFile) {Break VPNLoop}
			}

		Write-Output "**Disconnecting from the VPN"
		# Close OpenVPN to disconnect once the download is done
		ForEach ($VPNPID in $VPNPIDArray) {
			Stop-Process -Id $VPNPID -ErrorAction SilentlyContinue
			}
		If ($(Get-NetAdapter -Name $VPNAdapter).Status -ne "Up") {
			Write-Output "**Disconnected from the VPN"
			}
		}

	# Call yt-dlp to download the file if the VPN isn't used
	If (!$VPNConfig) {
		Start-ytdlp
		}

	# No more downloading after this - release the control for other scripts
	If ($ScriptInstanceControl) {Unlock-Control}

	# Determine the extention of the DumpFile - Used later for kid3
	$ext = [System.IO.Path]::GetExtension((Get-ChildItem -Path $DumpDirectory -Recurse -Filter "*$NakedName.*"))

	# If it didn't download the file - you're done
	If (!(Test-Path $DumpFile$ext)) {
		Write-Output "**DumpFile was not downloaded or no longer exists"
		Exit-Script
		}

	# Test that the metadata is valid by making sure EpisodeTitle and Station have characters
	If (($EpisodeTitle -notmatch '\S+') -AND ($Station -notmatch '\S+')) {
		Write-Output "**Could not validate metadata"
		# Exit script if metadata is not valid
		Exit-Script
		}

	# Check if the audio file needs to transcoded to mp3
	If (($mp3) -AND ($ext -ne ".mp3")) {
		# Run ffprobe to get the bitrate of the m4a file
		$ffprobeData = & $ffprobeExe -v quiet -hide_banner -of default=noprint_wrappers=0 -print_format xml -select_streams v:0 -show_format $DumpFile$ext | Out-String
		[xml]$ffprobeXMLData = $ffprobeData
		# Transcode the audio file to mp3 format
		& $ffmpegExe -i "$DumpFile$ext" -c:v copy -c:a libmp3lame -b:a $($ffprobeXMLData.ffprobe.format.bit_rate) "$DumpFile.mp3"
		# Delete the original audio file with the old extention
		Remove-Item $DumpFile$ext
		# Change the extension to .mp3 so the rest of the script finds the correct file
		$ext = ".mp3"
		}

	# Parse the image name and file extension from the url
	$ImageName = "$CoverResult".Substring("$CoverResult".lastIndexOf('/')+1)
	# Download the image to the dump directory
	$WClient = New-Object System.Net.WebClient
	$WClient.DownloadFile("$CoverResult", "$DumpDirectory\$ImageName")

	# If TrackNoFormat is not set in the command line, then use the DefaultTrackNoFormat
	If (!$TrackNoFormat) {$TrackNoFormat = $DefaultTrackNoFormat}

	Function Get-TrackNumberCount([Switch]$Recurse) {
		# Build the array to store the track numbers from kid3
		$TrackNumbers = @(0)
		# Search the save dir for files matching the short title - sort by creation time
		Get-ChildItem $SaveDir -Recurse:$Recurse -Force | Where-Object { $_.Name -match $("$ShortTitle-([0-9]*)-([A-Za-z0-9]*|[A-Za-z0-9]*_[0-9]*)\.") } | Sort-Object CreationTime -Descending | Foreach-Object {
			# Run kid3 on all files to pull the track number
			$GetTrackNo = & $kid3Exe -c 'get track' $_.FullName
			# Put the track number in the array
			$TrackNumbers += $GetTrackNo
			}
		# Find the highest number in the array
		$TrackNoCount = (($TrackNumbers | Measure -Max).Maximum)

		Return $TrackNoCount
		}

	# Store the track number format in a temporary variable to work with
	$TrackNoFormatWk = $TrackNoFormat
	# If format contains cr - then run the function to recursively figure out the track number and add 1
	$TrackNoFormatWk = $TrackNoFormatWk -creplace "cr", ((Get-TrackNumberCount -Recurse)+1)
	# If format contains c - then run the function to nonrecursively figure out the track number and add 1
	$TrackNoFormatWk = $TrackNoFormatWk -creplace "c", ((Get-TrackNumberCount)+1)
	# Determine the day of the year (Julian date)
	$TrackNoFormatWk = $TrackNoFormatWk -creplace "jjj", ("{0:D3}" -f $ReleaseDate.DayofYear)
	# Break down the two digit year to a single digit
	$TrackNoFormatWk = $TrackNoFormatWk -creplace "o", $ReleaseDate.ToString("yy").substring(1,1)
	# Format the AvailabilityDate to the TrackNoFormat - add a leading 0 to make it at least two digits or it fails
	$TrackNumber = $ReleaseDate.ToString(($TrackNoFormatWk).PadLeft(2, '0'))

	# Set the episode program page - more permanent than the Sounds page (also used by genRSS to set the guid)
	$EpisodePage  = "https://www.bbc.co.uk/programmes/$ProgramID"

	If ($GenreTag -eq $true) {
		# Still need to get the program page if a Sounds link was given as $ProgramURL
		If (!$ProgramPageHTML) {$ProgramPageHTML = (Invoke-WebRequest –Uri $EpisodePage -UseBasicParsing)}
		# Pull the genre links from the program page and put into array
		$GetGenres = @(($ProgramPageHTML.Links | Where-Object {$_.href -like "/programmes/genres/*"}).outerHTML | % {[regex]::matches( $_ , '(?<=>)(.*)*(?=<\/a>)')} | Select -ExpandProperty value)
		$GetGenres = $GetGenres | Select -Unique
		}

	# Get the yt-dlp version info
	$ytdlpName = (Get-Item -Path $ytdlpExe).VersionInfo.ProductName
	$ytdlpVer = (Get-Item -Path $ytdlpExe).VersionInfo.ProductVersion

	# Function to escape quotes in tags before passing them to kid3
	Function Format-kid3CommandString ($StringToFormat) {
		Return $StringToFormat.replace("'","\'").replace("\`"","`"").replace("`"","\`"").replace("|","\|")
		}

	$kid3Commands = @( )
	# Build MP4 or ID3v2.4 metadata commands to pass to kid3 - See kid3 handbook
	If ($Ext -eq ".m4a") {
		# Note: ©nam is required for genRSS.ps1 - sets <title> and <itunes:title>
		$kid3Commands += "-c", "set ©nam '$(Format-kid3CommandString($EpisodeTitle))'"
		$kid3Commands += "-c", "set sonm '$(Format-kid3CommandString($EpisodeTitle -replace $SortArticles))'"
		$kid3Commands += "-c", "set ©ART '$(Format-kid3CommandString($Station))'"
		$kid3Commands += "-c", "set soaa '$(Format-kid3CommandString($Station -replace $SortArticles))'"
		$kid3Commands += "-c", "set soar '$(Format-kid3CommandString($Station -replace $SortArticles))'"
		$kid3Commands += "-c", "set aART '$(Format-kid3CommandString($Station))'"
		$kid3Commands += "-c", "set ©alb '$(Format-kid3CommandString($ShowTitle))'"
		$kid3Commands += "-c", "set soal '$(Format-kid3CommandString($ShowTitle -replace $SortArticles))'"
		$kid3Commands += "-c", "set ©day '$($OriginalReleaseDate.ToString(`"yyyy`"))'"
		# Note: RELEASEDATE is required for genRSS.ps1 - sets <pubDate>
		$kid3Commands += "-c", "set RELEASEDATE '$($ReleaseDate.ToUniversalTime())'"
		$kid3Commands += "-c", "set ORIGINALDATE '$($OriginalReleaseDate.ToString(`"yyyy-MM-dd`"))'"
		$kid3Commands += "-c", "set trkn '$TrackNumber'"
		$kid3Commands += "-c", "set PUBLISHER '$(Format-kid3CommandString($Station))'"
		# Note: WEBSITE is required for genRSS.ps1 - sets <guid> and <link>
		$kid3Commands += "-c", "set WEBSITE '$EpisodePage'"
		$kid3Commands += "-c", "set AudioSourceURL '$SoundsPlayLink'"
		# Note: ©cmt is required for genRSS.ps1 - sets <description> and <itunes:summary>
		$kid3Commands += "-c", "set ©cmt '$(Format-kid3CommandString($Comment))'"
		$kid3Commands += "-c", "set ©too '$ytdlpName $ytdlpVer'"
		} Else {
			# Note: TIT2 is required for genRSS.ps1 - sets <title> and <itunes:title>
			$kid3Commands += "-c", "set TIT2 '$(Format-kid3CommandString($EpisodeTitle))'"
			$kid3Commands += "-c", "set TSOT '$(Format-kid3CommandString($EpisodeTitle -replace $SortArticles))'"
			$kid3Commands += "-c", "set TPE1 '$(Format-kid3CommandString($Station))'"
			$kid3Commands += "-c", "set TSO2 '$(Format-kid3CommandString($Station -replace $SortArticles))'"
			$kid3Commands += "-c", "set TSOP '$(Format-kid3CommandString($Station -replace $SortArticles))'"
			$kid3Commands += "-c", "set TPE2 '$(Format-kid3CommandString($Station))'"
			$kid3Commands += "-c", "set TALB '$(Format-kid3CommandString($ShowTitle))'"
			$kid3Commands += "-c", "set TSOA '$(Format-kid3CommandString($ShowTitle -replace $SortArticles))'"
			$kid3Commands += "-c", "set TDRC '$($OriginalReleaseDate.ToString(`"yyyy`"))'"
			# Note: TDRL is required for genRSS.ps1 - sets <pubDate>
			$kid3Commands += "-c", "set TDRL '$($ReleaseDate.ToUniversalTime())'"
			$kid3Commands += "-c", "set TDOR '$($OriginalReleaseDate.ToString(`"yyyy-MM-dd`"))'"
			$kid3Commands += "-c", "set TRCK '$TrackNumber'"
			$kid3Commands += "-c", "set TPUB '$(Format-kid3CommandString($Station))'"
			# Note: WOAR is required for genRSS.ps1 - sets <guid> and <link>
			$kid3Commands += "-c", "set WOAR '$EpisodePage'"
			$kid3Commands += "-c", "set WOAS '$SoundsPlayLink'"
			# Note: COMM is required for genRSS.ps1 - sets <description> and <itunes:summary>
			$kid3Commands += "-c", "set COMM '$(Format-kid3CommandString($Comment))'"
			$kid3Commands += "-c", "set TSSE '$ytdlpName $ytdlpVer'"
			}
	If ($GetGenres -ne $null) {
			Add-Type -AssemblyName System.Web
			$kid3Commands += "-c", "set genre '$([System.Web.HttpUtility]::HTMLDecode($GetGenres -Join '''|'''))'"
			}
	$kid3Commands += "-c", "set Picture:'$DumpDirectory\$ImageName' ''"
	# Note: AlbumArt is required for genRSS.ps1 - sets cover image as <media:content> and <itunes:image>
	$kid3Commands += "-c", "set AlbumArt '$CoverResult'"

	# Run kid3-cli to set the tags
	& $kid3Exe $kid3Commands $DumpFile$Ext

	# Create the save directory if it doesn't exist
	New-Item -ItemType Directory -Force -Path $SaveDir

	# Build the new filename
	[System.IO.Path]::GetExtension($DumpFile)
	$MoveLoc = $SaveDir + "\" + $ShortTitle + "-" + $ReleaseDate.ToString("yyyyMMdd") + "-" + $ProgramID + $Ext

	# Make sure the filename doesn't already exist
	If (Test-Path $MoveLoc) {
		$i = 0
		# Keep trying with a different instance until the filename doesn't exist
		While (Test-Path $MoveLoc) {
			# Increase the instance on each loop
			$i += 1
			# Rebuild the filename and append the loop instance
			$MoveLoc = $SaveDir + "\" + $ShortTitle + "-" + $ReleaseDate.ToString("yyyyMMdd") + "-" + $ProgramID + "_" + $i + $ext
			}
		}

	# Run ffprobe to check that kid3 set the tags before moving the file
	$ffprobeData = & $ffprobeExe -v quiet -hide_banner -of default=noprint_wrappers=0 -print_format xml -select_streams v:0 -show_format $DumpFile$ext | Out-String
	[xml]$ffprobeXMLData = $ffprobeData
	$CheckTitle = $($ffprobeXMLData.ffprobe.format.tag | Where {$_.key -eq 'title'}).value
	$CheckArtist = $($ffprobeXMLData.ffprobe.format.tag | Where {$_.key -eq 'artist'}).value
	$CheckAlbum = $($ffprobeXMLData.ffprobe.format.tag | Where {$_.key -eq 'album'}).value
	If (($CheckTitle) -AND ($CheckArtist) -AND ($CheckAlbum)) {
		# Move the file
		Move-Item $DumpFile$ext -Destination $MoveLoc
		} Else {
			Write-Output "**Metadata not set correctly"
			Exit-Script
			}

	# Don't clean up unless the file was sucessfully moved (for troubleshooting purposes)
	If ([System.IO.File]::Exists($MoveLoc)) {
		# Check if $Archive value is set
		If ($Archive -ge 1) {
			# RegEx pattern looks for the number pattern after the dash to account for dashes in the $ShortTitle
			$TitleMatchPattern = "$ShortTitle-([0-9]*)-([A-Za-z0-9]*|[A-Za-z0-9]*_[0-9]*)\."
			If (!$Days) {
				# Remove all audio files except the most recent ones
				Get-ChildItem $SaveDir -Recurse -Force | Where-Object { $_.Name -match $($TitleMatchPattern) } | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Archive | Remove-Item -Force -Verbose
				}
			If ($Days) {
				# Run through all items in the SaveDir
				Get-ChildItem $SaveDir -Recurse -Force | Where-Object {$_.Name -match $($TitleMatchPattern)} | ForEach {
					# Parse the release date from the title of each episode
					$ParseReleaseDate = [regex]::match($_.Name, "(\d\d\d\d\d\d\d\d+)")
					# Convert the release date to a DateTime object
					$TitleReleaseDate = [Datetime]::ParseExact($ParseReleaseDate, 'yyyyMMdd', (New-Object System.Globalization.CultureInfo "en-US"))
					# Check if the release date of the ep is older than the specified archive date
					If ($TitleReleaseDate -lt (Get-Date).Date.AddDays(-$Archive)) {
						# Remove it if it is
						Remove-Item $_.FullName -Force -Verbose
						}
					}
				}
			}
		}

	If (($rcloneConfig) -AND ($rcloneSyncDir)) {
		# Function to escape double quotes in parameters before passing them to rclone
		Function Format-rcloneCommandString ($StringToFormat) {
			Return $StringToFormat.replace("`"","\`"")
			}

		# thumbs.db is not necessary - save an upload by deleting it first
		If (Test-Path "$SaveDir\thumbs.db") {Remove-Item "$SaveDir\thumbs.db" -Force -Verbose}
		# Check for rclone updates and download
		If ($rcloneUpdate -eq $true) {& $rcloneExe selfupdate --stable}

		# Parse the rclone config ini file
		$RemoteConfig = Get-IniContent $rcloneConfig
		# Put the rclone sync dirs into an array
		$rcloneSyncDirArray = $rcloneSyncDir.Split(",")
		# Loop through each rclone sync dir
		ForEach ($rcloneSyncDir in $rcloneSyncDirArray) {
			# Parse the rclone remote from the sync directory
			$Remote = $rcloneSyncDir.Substring(0, $rcloneSyncDir.IndexOf(":"))
			# Run through all script blocks that start with 'remote_'
			ForEach ($RemoteItem in $(Get-Variable remote_*)) {
				# Execute each script block (each script block determines whether it matches the remote type to run rclone)
				& (Get-Variable -Name $RemoteItem.Name).Value
				}
			}
		}

	} Else {
		Write-Output "**Program ID $ProgramID already downloaded $($File.CreationTime)"
		If ($ScriptInstanceControl) {Unlock-Control}
		}

Exit-Script
