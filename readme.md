# PoC code

## deploy

* dotnet core 2.2
* azure website in 32bit mode
* <code>dotnet publish -r win-x86 -o publish</code>
* copy files to azure website
* Add Account Key to appsettings.json

## Infra as Code

* Folder IaC
* terraform v0.12.7
* set environment variable as seen in provider.tf



## Thanks

* Based on the awesome example '[Sample application for chunked file upload](https://github.com/edsoncunha/chunked-file-upload-csharp/blob/master/LICENSE)'