# Server Version and Change Log
See [CHANGE.log](./CHANGE.log)



# How to start server
## Recommend
### Windows or Linux with [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
You can modify `config.txt` to configure the configuration.
``` PowerShell
git clone https://github.com/UraraChiya/GregTech-Leisure-Server
Set-Location GregTech-Leisure-Server
./ServerStarter.ps1
```
## Traditional
Download `forge-1.20.1-47.3.5-installer.jar`.
### Windows with cmd
``` shell
git clone https://github.com/UraraChiya/GregTech-Leisure-Server
cd GregTech-Leisure-Server
java -jar forge-1.20.1-47.3.5-installer.jar --installServer
run.bat
```
### Linux with bash

``` bash
git clone https://github.com/UraraChiya/GregTech-Leisure-Server
cd GregTech-Leisure-Server
java -jar forge-1.20.1-47.3.5-installer.jar --installServer
bash run.sh
```

## How to update server
``` shell
cd GregTech-Leisure-Server
git pull https://github.com/UraraChiya/GregTech-Leisure-Server
```

# Need Client?
See https://github.com/UraraChiya/GregTech-Leisure-Client