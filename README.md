# SoundsDownloadScript.ps1 + genRSS.ps1

## ABOUT
SoundsDownloadScript.ps1 and genRSS.ps1 can work together to download episodes from the BBC Sounds website and then publish a podcast feed. SoundsDownloadScript.ps1 can work without genRSS.ps1 if you just want to download the files, but genRSS.ps1 won't really work with audio files tagged with other tools because they won't be tagged properly to build a feed.

## GETTING STARTED
### Prerequisites:

*   [ffmpeg](https://www.gyan.dev/ffmpeg/builds/) (I use the full build. I don't know if it matters. Make sure the package you choose comes with ffprobe.)
*   [kid3](https://kid3.kde.org/#download)
*   [Powershell](https://github.com/PowerShell/PowerShell) (I use v7.0.3 on Windows)
*   [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases)

### Optional:

*   [OpenVPN Connect](https://openvpn.net/client/client-connect-vpn-for-windows/) (If you want to download higher quality audio from outside the UK. You must have a VPN provider with UK servers.)
*   [rclone](https://rclone.org/downloads/) (If you want to upload files somewhere like S3 buckets, FTP, or archive.org)

I believe there are Linux versions for all of these packages, but I've only ever used this on Windows. The script may work on Powershell for Linux, but it will likely take a lot of tweaking. There's probably another language that's more appropriate. If you're up for the challenge, feel free to use my logic as a guide and go for it!

## HOW IT WORKS:

When called, SoundsDownloadScript.ps1 checks the program page for the BBC program you are requesting. It gets the name of the most recent episode and checks whether it has downloaded it already. If it hasn't already been downloaded, it calls yt-dlp to download it and then gets the meta data and cover art from the episode's BBC Sounds page. The script calls kid3 to set id3 tags on the audio file. If configured, the script will then clean up old episodes it has downloaded. After that, it can upload the file to a remote location using rclone. If the episode has already been downloaded, the script exits with no action.

genRSS.ps1 uses profile config files to create an RSS file. It scans your download directory of the program and uses kid3 to pull the id3 tags of each episode. It checks the date and time of the most recent file and then checks the date and time of the RSS file to decide whether it needs to update the RSS. If needed, it uses the tags to build an RSS file for a podcast feed. It uses rclone to upload the RSS file to a remote location, if configured. If accessible, the url of the RSS feed can be put into a podcast app to be subscribed to.
