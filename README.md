## ABOUT
SoundsDownloadScript.ps1 and genRSS.ps1 can work together to download episodes from the BBC Sounds website and then publish a podcast feed. SoundsDownloadScript.ps1 can work without genRSS.ps1 if you just want to download the audio files, but genRSS.ps1 won't really work with audio files tagged with other tools because they won't be tagged properly to build a podcast feed.

## GETTING STARTED
__Package:__
* SoundsDownloadScript.ps1
* genRSS.ps1
* SampleProfile (for use with genRSS.ps1)
* README.htm (includes installation instructions and how to run)
  
__Prerequisites:__
* [ffmpeg](https://www.gyan.dev/ffmpeg/builds/) (I use the full build. I don't know if it matters. Make sure the package you choose comes with ffprobe.)
* [kid3](https://kid3.kde.org/#download)
* [Powershell](https://github.com/PowerShell/PowerShell) (I use v7.0.3 on Windows)
* [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases)
  
__Optional:__
* [OpenVPN Connect](https://openvpn.net/client/client-connect-vpn-for-windows/) (If you want to download higher quality audio from outside the UK. You must have a VPN provider with UK servers.)
* [rclone](https://rclone.org/downloads/) (If you want to upload files somewhere like S3 buckets, FTP, or archive.org)

I believe there are Linux versions for all of these packages, but I've only ever used this on Windows. The script may work on Powershell for Linux, but it will likely take a lot of tweaking. There's probably another language that's more appropriate. If you're up for the challenge, feel free to use my logic as a guide and go for it!

## INSTALLATION & HOW TO RUN
Step by step instructions are in the README.htm file in the package. If anyone would like to translate the html instructons to markdown for this document, be my guest!
