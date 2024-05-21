## ABOUT
SoundsDownloadScript.ps1 and genRSS.ps1 are Powershell scripts that can work together to download episodes from the BBC Sounds website and then publish them to a podcast feed. SoundsDownloadScript.ps1 can work without genRSS.ps1 if you just want to download the audio files, but genRSS.ps1 won't really work with audio files tagged with other tools because they won't be tagged properly to build a podcast feed.

## GETTING STARTED
__Package:__
* genRSS.ps1
* README.htm (includes installation instructions and how to run)
* SampleProfile (for use with genRSS.ps1)
* SoundsDownloadScript.ps1
  
__Prerequisites:__
* [ffmpeg](https://www.gyan.dev/ffmpeg/builds/) (I use the full build. I don't know if it matters. Make sure the package you choose comes with ffprobe.)
* [kid3](https://kid3.kde.org/#download)
* [Powershell](https://github.com/PowerShell/PowerShell) (I use v7.0.3 on Windows)
* [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases)
  
__Optional:__
* [OpenVPN Connect](https://openvpn.net/client/client-connect-vpn-for-windows/) (If you want to download higher quality audio from outside the UK. You must have a VPN provider with UK servers.)
* [rclone](https://rclone.org/downloads/) (If you want to upload files somewhere like S3 buckets, FTP, or archive.org)

I believe there are Linux versions for all of these packages, but I've only ever used this on Windows. The script may work on Powershell for Linux, but it will likely take a lot of tweaking. There's probably another language that's more appropriate. If you're up for the challenge, feel free to use the logic as a guide and go for it!

## INSTALLATION & HOW TO RUN
Step by step instructions and other notes are in the [README.htm](https://html-preview.github.io/?url=https://github.com/endkb/SoundsDownloadScript/blob/main/README.htm) file in the package. If anyone would like to translate the html instructons to markdown for this document, be my guest!

##MIT LICENSE
Copyright © 2024 endkb

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
