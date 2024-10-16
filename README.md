## ABOUT
SoundsDownloadScript.ps1 and genRSS.ps1 are Powershell scripts that can work together to download episodes from the BBC Sounds website and then publish them to a podcast feed. SoundsDownloadScript.ps1 can work without genRSS.ps1 if you just want to download the audio files, but genRSS.ps1 won't really work with audio files tagged with other tools because they won't be tagged properly to build a podcast feed.

## GETTING STARTED
__Package:__ ([Latest release](https://github.com/endkb/SoundsDownloadScript/releases/latest))
* genRSS.ps1
* ProfileTemplate (for use with genRSS.ps1)
* README.htm (includes installation instructions and how to run)
* SoundsDownloadScript.ps1
  
__Prerequisites:__
* [ffmpeg](https://www.gyan.dev/ffmpeg/builds/) (Make sure the package you choose comes with ffprobe.)
* [kid3](https://kid3.kde.org/#download)
* [Powershell](https://github.com/PowerShell/PowerShell) (The scripts were developed and tested on v7.0.3 for Windows.)
* [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases)
  
__Optional:__
* [OpenVPN Community](https://community.openvpn.net/openvpn/wiki/Downloads) (If you want to download higher quality audio from outside the UK. You must have a VPN provider with UK servers.)
* [rclone](https://rclone.org/downloads/) (If you want to upload files somewhere like S3 buckets, FTP, or archive.org.)

I believe there are Linux versions for all of these packages, but I've only ever used this on Windows. The script may work on Powershell for Linux, but it will likely take a lot of tweaking. There's probably another language that's more appropriate. If you're up for the challenge, feel free to use the logic as a guide and go for it!

## INSTALLATION & HOW TO RUN
Step by step instructions and other notes are in the [README.htm](https://raw.githack.com/endkb/SoundsDownloadScript/main/README.htm) file in the package. If anyone would like to translate the html instructons to markdown for this document, be my guest!

## SUPPORT
To report an bug or request a feature in either SoundsDownloadService.ps1 or genRSS.ps1, [open an issue on github](https://github.com/endkb/SoundsDownloadScript/issues).

## LICENSE
Copyright &copy; 2024 endkb (https://github.com/endkb)  
MIT License (see [README.htm](https://raw.githack.com/endkb/SoundsDownloadScript/main/README.htm#MITLicense) for details)
