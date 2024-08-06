# 请直接运行，不要随意修改本脚本
# Requires -Version 7

# Server Starter Version 0.2

<# ChangeLog
    v0.4 06/08/2024
    支援 Linux
    v0.3 05/06/2024
    增加自定义核心
    v0.2.1 25/04/2024
    增加自动重启开关
    v0.2 08/02/2024
    支援 Fabric
    v0.1 07/02/2024
    初始版本，支援 Vanilla，Forge
#>

################################################################################

# 除非您知道您正在做什么，否则请不要修改此处配置
# 修改配置请去修改配置文件，运行脚本可自动生成配置文件
$ConfigFileName = 'config.txt'
$ModLoaders = @('Vanilla', 'Forge', 'Fabric', 'Custom')
$MinecraftVersionAPI = 'https://launchermeta.mojang.com/mc/game/version_manifest.json'
$ForgeSupportMinecraftAPI = 'https://bmclapi2.bangbang93.com/forge/minecraft'
$ForgeVersionAPI = 'https://bmclapi2.bangbang93.com/forge/minecraft/'
$FabricInstallerVersionAPI = 'https://meta.fabricmc.net/v2/versions/installer'
$FabricSupportMinecraftAPI = 'https://meta.fabricmc.net/v2/versions/game'
$FabricVersionAPI = 'https://meta.fabricmc.net/v2/versions/loader/'


################################################################################

Import-Module ./ReadInput.psm1
Set-Location $PSScriptRoot

# 检测是否为管理员身份运行
if ($IsWindows) {
    if ( (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host '警告！不建议以管理员权限运行。' -ForegroundColor Yellow
        Suspend-Script
    }
}
else {
    if ((id -u 2>&1) -eq 0) {
        Write-Host '警告！不建议以 root 权限运行。' -ForegroundColor Yellow
        Suspend-Script
    }
}


# 暂停脚本
function Suspend-Script {
    Write-Host '按任意键继续' -ForegroundColor Yellow
    $host.ui.RawUI.ReadKey('NoEcho,IncludeKeyDown') > $null
}

# 退出脚本
function Exit-Script {
    param (
        [string]
        $Message = '脚本退出'
    )
    Write-Host $Message -ForegroundColor Red
    Suspend-Script
    exit 1
}

# 选择列表元素
function Select-Array {
    param (
        [array]
        $Array,
        [string]
        $Message = '请选择'
    )
    if ($Array.Count -eq 1) {
        return $Array[0]
    }
    for ($i = 0; $i -lt $Array.Count; $i++) {
        Write-Host ("{0}.`t{1}" -f ($i + 1), $Array[$i])
    }
    return $array[(Read-InputNumber -Message $Message -MinValue 1 -MaxValue $Array.Count) - 1]
}

# 删除文件如果存在
function Remove-FileIfExist {
    param (
        [System.IO.FileInfo]
        $Path
    )
    if (Test-Path $Path) {
        $null = Remove-Item $Path
    }
}

# 获取模组加载器安装器版本
function Get-ModLoaderInstallerVersion {
    $ModLoaderInstallerVersions = switch ($Script:ModLoader) {
        'Fabric' {
            try {
                $Content = (Invoke-WebRequest $Script:FabricInstallerVersionAPI).Content
            }
            catch {
                Exit-Script "获取 $Script:Modloader 安装器版本失败"
            }
            ($Content | ConvertFrom-Json).version
        }
        Default {}
    }
    return [version](Select-Array -Array $ModLoaderInstallerVersions -Message '请选择想要的模组加载器安装器版本')
}

# 获取模组加载器支持的游戏版本
function Get-MinecraftVersion {
    $MinecraftVersions = switch ($Script:Modloader) {
        'Vanilla' {
            try {
                $Content = (Invoke-WebRequest $Script:MinecraftVersionAPI).Content
            }
            catch {
                Exit-Script "获取 $Script:Modloader 支持的游戏版本失败"
            }
            (($Content | ConvertFrom-Json).versions | Where-Object { $_.type -eq 'release' }).id
        }
        'Forge' {
            try {
                $Content = (Invoke-WebRequest $Script:ForgeSupportMinecraftAPI).Content
            }
            catch {
                Exit-Script "获取 $Script:Modloader 支持的游戏版本失败"
            }
            $Content | ConvertFrom-Json | Where-Object { -not ($_.Contains('pre')) } | Sort-Object { [version]$_ } -Descending
        }
        'Fabric' {
            try {
                $Content = (Invoke-WebRequest $Script:FabricSupportMinecraftAPI).Content
            }
            catch {
                Exit-Script "获取 $Script:Modloader 支持的游戏版本失败"
            }
            ($Content | ConvertFrom-Json | Where-Object stable).version
        }
        Default {}
    }
    return [version](Select-Array -Array $MinecraftVersions -Message '请选择想要安装的游戏版本')
}

# 获取模组加载器版本
function Get-ModLoaderVersion {
    $ModLoaderVersions = switch ($Script:Modloader) {
        'Vanilla' {
            $Script:MinecraftVersion
        }
        'Forge' {
            try {
                $Content = (Invoke-WebRequest ($Script:ForgeVersionAPI + $Script:MinecraftVersion)).Content
            }
            catch {
                Exit-Script "获取模组加载器 $Script:Modloader 版本失败"
            }
            ($Content | ConvertFrom-Json).version | Sort-Object { [version]$_ } -Descending
        }
        'Fabric' {
            try {
                $Content = (Invoke-WebRequest ($Script:FabricVersionAPI + $Script:MinecraftVersion)).Content
            }
            catch {
                Exit-Script "获取模组加载器 $Script:Modloader 版本失败"
            }
            ($Content | ConvertFrom-Json).loader.version
        }
        Default {}
    }
    return [version](Select-Array -Array $ModLoaderVersions -Message '请选择想要安装的模组加载器版本')
}

# 导入配置文件
function Import-Config {
    # 导入配置文件
    $ConfigFile = Join-Path $PSScriptRoot $Script:ConfigFileName
    if (Test-Path $ConfigFile) {
        Invoke-Expression (Get-Content -Raw $ConfigFile)
    }

    # 配置文件检查
    if ($null -eq $Script:ServerName`
            -or $null -eq $Script:ModLoader`
            -or $null -eq $Script:ModLoaderInstallerVersion`
            -or $null -eq $Script:MinecraftVersion`
            -or $null -eq $Script:ModLoaderVersion`
            -or $null -eq $Script:Java`
            -or $null -eq $Script:SkipJavaCompatibilityCheck`
            -or $null -eq $Script:MinMemory`
            -or $null -eq $Script:MaxMemory`
            -or $null -eq $Script:JVMParameters`
            -or $null -eq $Script:AutoRestart`
            -or $null -eq $Script:MinRestartTime`
            -or $null -eq $Script:CustomLaunchCommand) {
        Write-Host '缺失部分配置，将为您重新生成配置文件'
        Suspend-Script
        if ($null -eq $Script:ServerName) {
            $Script:ServerName = Read-InputString '请输入服务器（或模组包）名称（将在标题栏显示），可略过' -DefaultValue ''
        }
        if ($null -eq $Script:ModLoader) {
            $Script:ModLoader = Select-Array -Array $Script:ModLoaders -Message '请选择要安装的模组加载器'
        }
        if ($null -eq $Script:ModLoaderInstallerVersion) {
            $Script:ModLoaderInstallerVersion = ($Script:ModLoader -eq 'Fabric') ? (Get-ModLoaderInstallerVersion) : ([version]'0.0.1')
        }
        if ($null -eq $Script:MinecraftVersion) {
            $Script:MinecraftVersion = ($Script:ModLoader -ne 'Custom') ? (Get-MinecraftVersion) : ([version]'0.0.1')
        }
        if ($null -eq $Script:ModLoaderVersion) {
            $Script:ModLoaderVersion = ($Script:ModLoader -ne 'Custom') ? (Get-ModLoaderVersion) : ([version]'0.0.1')
        }
        if ($null -eq $Script:Java) {
            $Script:Java = Read-InputString -Message '请输入 “java.exe” 的路径，使用环境变量中 Java 的可输入 “java”' -DefaultValue 'java'
        }
        if ($null -eq $Script:SkipJavaCompatibilityCheck) {
            $Script:SkipJavaCompatibilityCheck = ($Script:ModLoader -ne 'Custom') ? (Read-InputBool -Message '是否跳过 Java 兼容性检查'  -DefaultValue $false) : $true
        }
        if ($null -eq $Script:MinMemory) {
            $Script:MinMemory = Read-InputNumber -Message '请输入最小内存，以字节为单位，可输入 “2000MB”，“4GB” 等'
        }
        if ($null -eq $Script:MaxMemory) {
            $Script:MaxMemory = Read-InputNumber -Message '请输入最大内存，以字节为单位，可输入 “2000MB”，“4GB” 等' -MinValue $Script:MinMemory
        }
        if ($null -eq $Script:JVMParameters) {
            $Script:JVMParameters = Read-InputString -Message '请输入 JVM 参数，不要包含内存设置（-Xmx -Xms），不知道可留空' -DefaultValue ''
        }
        if ($null -eq $Script:AutoRestart) {
            $Script:AutoRestart = Read-InputBool -Message '是否使能自动重启' -DefaultValue $true
        }
        if ($null -eq $Script:MinRestartTime) {
            $Script:MinRestartTime = Read-InputNumber -Message '请输入最短重启时间，以秒为单位，短于这个时间将不会自动重启' -DefaultValue 120
        }
        if ($null -eq $Script:CustomLaunchCommand) {
            $Script:CustomLaunchCommand = ($Script:ModLoader -eq 'Custom') ? (Read-InputString -Message '请输入自定义启动命令，如 -jar "xxx.jar"') : ''
        }
        $Config = `
            "# 配置文件，可修改以下等号后的内容`n`n" + `
            "# 服务器（或模组包）名称（将在标题栏显示），可略过`n" + `
            "`$Script:ServerName = '$Script:ServerName'`n`n" + `
            "# 模组加载器 'Vanilla', 'Forge', 'Custom'`n" + `
            "`$Script:ModLoader = '$Script:ModLoader'`n`n" + `
            "# 模组加载器安装器版本（Fabric 需要此项）`n" + `
            "`$Script:ModLoaderInstallerVersion = `[version`]'$Script:ModLoaderInstallerVersion'`n`n" + `
            "# MineCraft 版本 '1.20.1', '1.19.2', 等`n" + `
            "`$Script:MinecraftVersion = `[version`]'$Script:MinecraftVersion'`n`n" + `
            "# 模组加载器版本，原版可忽略此设置`n" + `
            "`$Script:ModLoaderVersion = `[version`]'$Script:ModLoaderVersion'`n`n" + `
            "# Java 命令行，可填写 `“java.exe`” 的路径`n" + `
            "`$Script:Java = '$Script:Java'`n`n" + `
            "# 是否跳过 Java 兼容性检查`n" + `
            "`$Script:SkipJavaCompatibilityCheck = `[bool`]$($Script:SkipJavaCompatibilityCheck ? '$true': '$false')`n`n" + `
            "# 最小内存，以字节为单位，可输入 `“2000MB`”，`“4GB`” 等`n" + `
            "`$Script:MinMemory = $Script:MinMemory`n`n" + `
            "# 最大内存，以字节为单位，可输入 `“2000MB`”，`“4GB`” 等`n" + `
            "`$Script:MaxMemory = $Script:MaxMemory`n`n" + `
            "# JVM 参数，不要包含内存设置（-Xmx -Xms），不知道可留空`n" + `
            "`$Script:JVMParameters = '$Script:JVMParameters'`n`n" + `
            "# 使能自动重启`n" + `
            "`$Script:AutoRestart = `[bool`]$($Script:AutoRestart ? '$true': '$false')`n`n" + `
            "# 最短重启时间，以秒为单位，短于这个时间将不会自动重启`n" + `
            "`$Script:MinRestartTime = '$Script:MinRestartTime'`n`n" + `
            "# 自定义启动命令（Custom 需要）`n" + `
            "`$Script:CustomLaunchCommand = '$Script:CustomLaunchCommand'`n`n"
        $Config | Out-File $ConfigFile -NoNewline
    }
    if ([string]::IsNullOrWhiteSpace($Script:ServerName)) {
        $Script:ServerName = "$Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion"
    }
}

# 检查 Java 兼容性
function Test-Java {
    if (-not $Script:SkipJavaCompatibilityCheck) {

        $Bit = if ($IsWindows) {
            cmd /c "`"$Script:Java`" -version 2>&1"
        }
        else {
            "`"$Script:Java`" -version 2>&1" | bash
        }

        # 32 位检测
        if ( $Bit -contains '32-Bit') {
            Write-Host "警告！ 检测到 32 位 Java！ 强烈建议使用 64 位版本的 Java！" -ForegroundColor Yellow
            Suspend-Script
        }

        # 版本检测       
        $JavaVersion = if ($IsWindows) {
            (Get-Command $Script:Java).Version
        }
        else {
            [version][regex]::Match($Bit, 'version "([0-9\._]+)"').Groups[1].Value.Replace('_', '.')
        }
        if ($Script:MinecraftVersion.Minor -ge 17) {
            if ($JavaVersion.Major -lt 17) {
                Exit-Script "Minecraft $Script:MinecraftVersion 需要 Java 17 以上，请修改 Java 命令行配置`n如没有 Java 17 可前往 https://learn.microsoft.com/zh-cn/java/openjdk/download 获取"
            }
        }
        else {
            if ($JavaVersion.Minor -ne 1 -or $JavaVersion.Major -ne 8) {
                Exit-Script "Minecraft $Script:MinecraftVersion 需要 Java 8，请修改 Java 命令行配置`n如没有 Java 8 可前往 https://learn.microsoft.com/zh-cn/java/openjdk/download 获取"
            }
        }
    }
    else {
        Write-Host 'Java 兼容性检查通过'
    }
}

# 安装服务端
function Install-Server {
    switch ($Script:ModLoader) {
        'Vanilla' {
            try {
                $Content = (Invoke-WebRequest $Script:MinecraftVersionAPI).Content
                $url = (($Content | ConvertFrom-Json).versions |`
                        Where-Object { $_.id -eq $Script:MinecraftVersion -and $_.type -eq 'release' })[0].url
                $Content = (Invoke-WebRequest $url).Content
                $DownloadUri = ($Content | ConvertFrom-Json).downloads.server.url
                $SHA1 = ($Content | ConvertFrom-Json).downloads.server.sha1
            }
            catch {
                Exit-Script "获取 $Script:ModLoader $Script:MinecraftVersion 服务端下载地址失败"
            }
            try {
                $Destination = (Join-Path $PSScriptRoot 'server.jar')
                if (-not (Test-Path $Destination -PathType Leaf)) {
                    Write-Host '开始下载 Vanilla'
                    Invoke-WebRequest -Uri $DownloadUri -OutFile $Destination
                    if ($SHA1 -ne (Get-FileHash $Destination -Algorithm SHA1).Hash) {
                        throw
                    }
                }
            }
            catch {
                Exit-Script "下载 $Script:ModLoader $Script:MinecraftVersion 服务端失败"
            }
        }
        'Forge' {
            if ($Script:MinecraftVersion.Minor -ge 17) {
                $ForgeJarLocation = Join-Path $PSScriptRoot "libraries/net/minecraftforge/forge/$Script:MinecraftVersion-$Script:ModLoaderVersion/forge-$Script:MinecraftVersion-$Script:ModLoaderVersion-server.jar"
            }
            else {
                $ForgeJarLocation = Join-Path $PSScriptRoot "forge-$Script:MinecraftVersion-$Script:ModLoaderVersion.jar"
            }
            # 已安装 Forge 则返回
            if (Test-Path $ForgeJarLocation -PathType Leaf) {
                return
            }
            # 下载安装器
            $Destination = (Join-Path $PSScriptRoot "forge-$Script:MinecraftVersion-$Script:ModLoaderVersion-installer.jar")
            if (-not (Test-Path $Destination -PathType Leaf)) {
                Write-Host '开始下载 Forge 安装器'
                $ForgeInstallerUrl = "https://files.minecraftforge.net/maven/net/minecraftforge/forge/$Script:MinecraftVersion-$Script:ModLoaderVersion/forge-$Script:MinecraftVersion-$Script:ModLoaderVersion-installer.jar"
                try {
                    Invoke-WebRequest -Uri $ForgeInstallerUrl -OutFile $Destination
                }
                catch {
                    Exit-Script "下载 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 安装器失败"
                }
            }
        
            # 安装 Forge
            try {
                Write-Host '开始安装 Forge'
                if ($IsWindows) {
                    cmd /c "`"$Script:Java`" -jar `"$Destination`" --installServer"
                }
                else {
                    "`"$Script:Java`" -jar `"$Destination`" --installServer" | bash
                }
                if (-not (Test-Path $ForgeJarLocation -PathType Leaf)) {
                    throw
                }
                if ($Script:MinecraftVersion.Minor -ge 17) {
                    Remove-FileIfExist 'run.bat'
                    Remove-FileIfExist 'run.sh'
                    Remove-FileIfExist 'user_jvm_args.txt'
                }
            }
            catch {
                Exit-Script "安装 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 失败"
            }
        }
        'Fabric' {
            $Destination = "fabric-server-mc.$Script:MinecraftVersion-loader.$Script:ModLoaderVersion-launcher.$Script:ModLoaderInstallerVersion.jar"
            if (Test-Path $Destination -PathType Leaf) {
                return
            }
            $FabricServerUri = "https://meta.fabricmc.net//v2/versions/loader/$Script:MinecraftVersion/$Script:ModLoaderVersion/$Script:ModLoaderInstallerVersion/server/jar"
            try {
                Write-Host '开始下载 Fabric'
                Invoke-WebRequest -Uri $FabricServerUri -OutFile $Destination
            }
            catch {
                Exit-Script "下载 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 失败"
            }
        }
        Default {}
    }    
}

# 需求最终用户许可协议
function Request-Eula {
    if (-not (Test-Path -Path 'eula.txt' -PathType Leaf)) {
        Write-Host 'Mojang 的 EULA 尚未被接受。为了运行 Minecraft 服务器，您必须接受 Mojang 的 EULA。' -ForegroundColor Yellow
        Write-Host 'Mojang 的 EULA 可在 https://aka.ms/MinecraftEULA 上阅读' -ForegroundColor Yellow
        Write-Host '如果您同意 Mojang 的 EULA，请输入 “我同意”' -ForegroundColor Yellow
        $Answer = Read-InputString -Message '您的回答'

        if ($Answer -eq "我同意") {
            Write-Host '用户同意 Mojang 的 EULA。'
            Suspend-Script
            "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://aka.ms/MinecraftEULA).`n" + `
                "eula=true" | Out-File eula.txt -Encoding utf8
        }
        else {
            Write-Host '用户不同意 Mojang 的 EULA。'
            "您输入了：$Answer"
            '除非您同意 Mojang 的 EULA，否则您无法运行 Minecraft 服务器。'
            Exit-Script
        }
    }
}

# 构造启动命令
function Get-LaunchCommand {
    $Script:ServerRunCommand = switch ($Script:ModLoader) {
        'Vanilla' {
            ('-jar "{0}"' -f (Join-Path $PSScriptRoot "server.jar"))
        }
        'Forge' {
            if ($Script:MinecraftVersion.Minor -ge 17) {
                if ($IsWindows) {
                    ('@"{0}"' -f (Join-Path $PSScriptRoot "libraries/net/minecraftforge/forge/$Script:MinecraftVersion-$Script:ModLoaderVersion/win_args.txt"))
                }
                else {
                    ('@"{0}"' -f (Join-Path $PSScriptRoot "libraries/net/minecraftforge/forge/$Script:MinecraftVersion-$Script:ModLoaderVersion/unix_args.txt"))
                }
            }
            else {
                ('-jar "{0}"' -f (Join-Path $PSScriptRoot "forge-$Script:MinecraftVersion-$Script:ModLoaderVersion.jar"))
            }
        }
        'Fabric' {
            ('-jar "{0}"' -f (Join-Path $PSScriptRoot "fabric-server-mc.$Script:MinecraftVersion-loader.$Script:ModLoaderVersion-launcher.$Script:ModLoaderInstallerVersion.jar"))
        }
        'Custom' {
            $Script:CustomLaunchCommand
        }
        Default {}
    }
}


# Main

# 导入配置文件
Import-Config
# 检查 Java 兼容性
Test-Java
# 安装服务端
Install-Server
# 最终用户许可协议
Request-Eula
# 构造启动命令
Get-LaunchCommand

# 启动服务器
$RestartTime = 0
do {
    Clear-Host
    Write-Host '服务器启动中……'
    Write-Host "重启次数：$RestartTime"
    $host.ui.RawUI.WindowTitle = "$ServerName | 重启次数：$RestartTime"
    $StartTime = Get-Date -UFormat '%s'
    if ($IsWindows) {
        cmd /c "`"$Script:Java`" -Xmx$MaxMemory -Xms$MinMemory $JVMParameters $ServerRunCommand nogui"
    }
    else {
        "rm `$0`n`"$Script:Java`" -Xmx$MaxMemory -Xms$MinMemory $JVMParameters $ServerRunCommand nogui" | Out-File do_not_run_me
        bash do_not_run_me
    }
    if ($Script:AutoRestart -and ((Get-Date -UFormat '%s') - $StartTime -ge $MinRestartTime)) {
        Write-Host '服务器将在 3 秒后重启，按 q 键以阻止' -ForegroundColor Yellow
        $count = 0
        $key = $null
        $QuitKey = 81 #Character code for 'q' key.
        while ($count -le 12) {
            if ($host.UI.RawUI.KeyAvailable) {
                $key = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp")
                if ($key.VirtualKeyCode -eq $QuitKey) {
                    Exit-Script
                }
            }
            $count++
            Start-Sleep -m 250
        }
    }
    else {
        Exit-Script -Message '未使能自动重启或重启时间过短'
    }
    $RestartTime++
} while (
    $true
)

Exit-Script
