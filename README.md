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
Step by step instructions and other notes are in the [README.htm](https://html-preview.github.io/?url=https://github.com/endkb/SoundsDownloadScript/blob/main/README.htm) file in the package. If anyone would like to translate the html instructons to markdown for this document, be my guest!

## SUPPORT
For help with SoundsDownloadScript.ps1 or genRSS.ps1:
* To report an bug or request a feature: [Open an issue on github](https://github.com/endkb/SoundsDownloadScript/issues)
* To ask a question: Drop an e-mail to [&#x65;&#x6e;&#x64;&#x6b;&#x62;<!--- -->&#x40;<!--- -->&#x70;&#x72;&#x6f;&#x74;&#x6f;&#x6e;&#x2e;&#x6d;&#x65;](&#x6d;&#x61;&#x69;&#x6c;&#x74;&#x6f;&#x3a;&#x65;&#x6e;&#x64;&#x6b;&#x62;&#x40;&#x70;&#x72;&#x6f;&#x74;&#x6f;&#x6e;&#x2e;&#x6d;&#x65;)

## LICENSE
Copyright &copy; 2024 endkb &lt;https://github.com/endkb&gt;  
MIT License (see [README.htm](https://html-preview.github.io/?url=https://github.com/endkb/SoundsDownloadScript/blob/main/README.htm#MITLicense) for details)
