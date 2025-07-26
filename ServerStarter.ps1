# 请直接运行，不要随意修改本脚本
# Requires -Version 7

# Server Starter Version 0.4

<# ChangeLog
    v1.2.2 17/07/2025
    检测端口可能出错，不再阻止启动
    v1.2.1 18/06/2025
    修正自动服务器配置
    v1.2 07/07/2025
    添加服务端配置检查
    v1.1 07/06/2025
    添加选项为 Forge 提前使用国内镜像下载 Vanilla 服务端
    v1.0.1 15/03/2025
    typo
    v1.0 01/03/2025
    支援 NeoForge，bug 修复
    v0.4 06/08/2024
    支援 Linux
    v0.3 05/06/2024
    增加自定义启动命令
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
$ConfigFileName = 'config.txt' # 配置文件名
$ModLoaders = @('Vanilla', 'Forge', 'Fabric', 'NeoForge', 'Custom') # 支持的模组加载器
$MinecraftVersionAPI = 'https://launchermeta.mojang.com/mc/game/version_manifest.json' # 获取 Minecraft 版本
$ForgeSupportMinecraftAPI = 'https://bmclapi2.bangbang93.com/forge/minecraft' # 获取 Forge 支持的 Minecraft 版本
$ForgeVersionAPI = 'https://bmclapi2.bangbang93.com/forge/minecraft/' # 根据 Minecraft 版本获取 Forge 版本
$FabricInstallerVersionAPI = 'https://meta.fabricmc.net/v2/versions/installer' # 获取 Fabric 安装器版本
$FabricSupportMinecraftAPI = 'https://meta.fabricmc.net/v2/versions/game' # 获取 Fabric 支持的 Minecraft 版本
$FabricVersionAPI = 'https://meta.fabricmc.net/v2/versions/loader/' # 根据 Minecraft 版本获取 Fabric 版本
$NeoForgeSupportMinecraftVersions = @("1.20.2", "1.20.3", "1.20.4", "1.20.5", "1.20.6", 
    "1.21.0", "1.21.1", "1.21.2", "1.21.3", "1.21.4", "1.21.5") # NeoForge 支持的 Minecraft 版本
$NeoForgeVersionAPI = 'https://bmclapi2.bangbang93.com/neoforge/list/' # 根据 Minecraft 版本获取 NeoForge 列表
$VanillaMirrorAPI = 'https://bmclapi2.bangbang93.com/version/{0}/server' # 获取 Vanilla 镜像 https://bmclapi2.bangbang93.com/version/:version/:category

################################################################################

Import-Module ./ReadInput.psm1
Set-Location $PSScriptRoot


# 暂停脚本
function Suspend-Script {
    Write-Host '按任意键继续' -ForegroundColor Yellow
    $host.ui.RawUI.ReadKey('NoEcho,IncludeKeyDown') > $null
}

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

    # 定义每行要显示多少个元素
    $elementsPerRow = 5
    $columns = New-Object System.Collections.ArrayList
    $MaxNoLength = $Array.Count.ToString().Length
    $MaxElementLength = - ($Array | Measure-Object -Maximum -Property Length).Maximum

    # 将数组按 Z 形顺序分组
    for ($i = 0; $i -lt $Array.Count; $i++) {
        $rowIndex = [math]::Floor($i / $elementsPerRow)

        # 确保行数组已经存在，如果没有则扩展
        if ($columns.Count -le $rowIndex) {
            $columns.Add(@()) | Out-Null # 新建一个空数组添加到 columns 中
        }

        # 将数据添加到指定的行中
        $columns[$rowIndex] += $Array[$i]
    }

    # 输出每行
    for ($row = 0; $row -lt $columns.Count; $row++) {
        $line = ""
        for ($col = 0; $col -lt $columns[$row].Count; $col++) {
            # 确保每列之间有至少 4 个空格，第 1 列除外
            if ($col -eq 0) {
                $NoLength = $MaxNoLength
            }
            else {
                $NoLength = $MaxNoLength + 4
            }
            $line += "{0,$NoLength}. {1,$MaxElementLength}" -f (($row * $elementsPerRow) + $col + 1), $columns[$row][$col]
        }
        Write-Host $line
    }

    return $Array[(Read-InputNumber -Message $Message -MinValue 1 -MaxValue $Array.Count) - 1]
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
                Write-Host $_ -ForegroundColor Red
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
                Write-Host $_ -ForegroundColor Red
                Exit-Script "获取 $Script:Modloader 支持的游戏版本失败"
            }
            (($Content | ConvertFrom-Json).versions | Where-Object { $_.type -eq 'release' }).id
        }
        'Forge' {
            try {
                $Content = (Invoke-WebRequest $Script:ForgeSupportMinecraftAPI).Content
            }
            catch {
                Write-Host $_ -ForegroundColor Red
                Exit-Script "获取 $Script:Modloader 支持的游戏版本失败"
            }
            $Content | ConvertFrom-Json | Where-Object { -not ($_.Contains('pre')) } | Sort-Object { [version]$_ } -Descending
        }
        'Fabric' {
            try {
                $Content = (Invoke-WebRequest $Script:FabricSupportMinecraftAPI).Content
            }
            catch {
                Write-Host $_ -ForegroundColor Red
                Exit-Script "获取 $Script:Modloader 支持的游戏版本失败"
            }
            ($Content | ConvertFrom-Json | Where-Object stable).version
        }
        'NeoForge' {
            $NeoForgeSupportMinecraftVersions | Sort-Object { [version]$_ } -Descending
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
                Write-Host $_ -ForegroundColor Red
                Exit-Script "获取模组加载器 $Script:Modloader 版本失败"
            }
            ($Content | ConvertFrom-Json).version | Sort-Object { [version]$_ } -Descending
        }
        'Fabric' {
            try {
                $Content = (Invoke-WebRequest ($Script:FabricVersionAPI + $Script:MinecraftVersion)).Content
            }
            catch {
                Write-Host $_ -ForegroundColor Red
                Exit-Script "获取模组加载器 $Script:Modloader 版本失败"
            }
            ($Content | ConvertFrom-Json).loader.version
        }
        'NeoForge' {
            try {
                $Content = (Invoke-WebRequest ($Script:NeoForgeVersionAPI + $Script:MinecraftVersion)).Content
            }
            catch {
                Write-Host $_ -ForegroundColor Red
                Exit-Script "获取模组加载器 $Script:Modloader 版本失败"
            }
            $tmp = ($Content | ConvertFrom-Json).version
            [array]::Reverse($tmp)
            $tmp
        }
        Default {}
    }
    return (Select-Array -Array $ModLoaderVersions -Message '请选择想要安装的模组加载器版本')
}

# 导入配置文件
function Import-Config {
    # 导入配置文件
    $ConfigFile = Join-Path $PSScriptRoot $Script:ConfigFileName
    if (Test-Path $ConfigFile) {
        Invoke-Expression (Get-Content -Raw $ConfigFile)
    }

    # 配置文件检查
    $ConfigParams = @(
        'ServerName', 'ModLoader', 'VanillaMirror', 'ModLoaderInstallerVersion', 'MinecraftVersion',
        'ModLoaderVersion', 'Java', 'SkipJavaCompatibilityCheck', 'MinMemory',
        'MaxMemory', 'JVMParameters', 'AutoRestart', 'MinRestartTime', 'CustomLaunchCommand', 'ServerPort',
        'ServerAllowFlight', 'ServerEnableCommandBlock', 'ServerEnforceSecureProfile'
    )

    $MissingParams = $ConfigParams | Where-Object { $null -eq (Invoke-Expression "`$Script:$_") }
    if ($MissingParams.Count -gt 0) {
        Write-Host '缺失部分配置，将为您重新生成配置文件'
        Suspend-Script

        foreach ($Param in $MissingParams) {
            switch ($Param) {
                'ServerName' {
                    $Script:ServerName = Read-InputString '请输入服务器（或模组包）名称（将在标题栏显示），缺省值：A Minecraft Server' -DefaultValue 'A Minecraft Server'
                }
                'ModLoader' {
                    $Script:ModLoader = Select-Array -Array $Script:ModLoaders -Message '请选择要安装的模组加载器'
                }
                'VanillaMirror' {
                    $Script:VanillaMirror = ($Script:ModLoader -eq 'Custom') ? '' : (Read-InputBool -Message '是否使用国内镜像下载 Vanilla 客户端（即使是模组端也得下载），缺省值：是' -DefaultValue $true)
                }
                'ModLoaderInstallerVersion' {
                    $Script:ModLoaderInstallerVersion = ($Script:ModLoader -eq 'Fabric') ? (Get-ModLoaderInstallerVersion) : ([version]'0.0.1')
                }
                'MinecraftVersion' {
                    $Script:MinecraftVersion = ($Script:ModLoader -ne 'Custom') ? (Get-MinecraftVersion) : ([version]'0.0.1')
                }
                'ModLoaderVersion' {
                    $Script:ModLoaderVersion = ($Script:ModLoader -ne 'Custom') ? (Get-ModLoaderVersion) : ([version]'0.0.1')
                }
                'Java' {
                    $Script:Java = Read-InputString -Message '请输入 “java.exe” 的路径，使用环境变量中 Java 的可输入 “java”，缺省值：java' -DefaultValue 'java'
                }
                'SkipJavaCompatibilityCheck' {
                    $Script:SkipJavaCompatibilityCheck = ($Script:ModLoader -ne 'Custom') ? (Read-InputBool -Message '是否跳过 Java 兼容性检查，缺省值：否'  -DefaultValue $false) : $true
                }
                'MinMemory' {
                    $Script:MinMemory = Read-InputNumber -Message '请输入最小内存，以字节为单位，可输入 “2000MB”，“4GB” 等，缺省值：2GB' -DefaultValue 2147483648 -MinValue 0
                }
                'MaxMemory' {
                    $Script:MaxMemory = Read-InputNumber -Message '请输入最大内存，以字节为单位，可输入 “2000MB”，“4GB” 等，缺省值：4GB' -DefaultValue 4294967296 -MinValue $Script:MinMemory
                }
                'JVMParameters' {
                    $Script:JVMParameters = Read-InputString -Message '请输入 JVM 参数，不要包含内存设置（-Xmx -Xms），不知道可留空' -DefaultValue ''
                }
                'AutoRestart' {
                    $Script:AutoRestart = Read-InputBool -Message '是否使能自动重启，缺省值：是' -DefaultValue $true
                }
                'MinRestartTime' {
                    $Script:MinRestartTime = Read-InputNumber -Message '请输入最短重启时间，以秒为单位，短于这个时间将不会自动重启，缺省值：120' -DefaultValue 120
                }
                'CustomLaunchCommand' {
                    $Script:CustomLaunchCommand = ($Script:ModLoader -eq 'Custom') ? (Read-InputString -Message '请输入自定义启动命令，如 -jar "xxx.jar"') : ''
                }
                'ServerPort' {
                    $Script:ServerPort = Read-InputNumber -Message '请输入服务器端口，缺省值：25565' -DefaultValue 25565
                }
                'ServerAllowFlight' {
                    $Script:ServerAllowFlight = Read-InputBool -Message '是否允许飞行，缺省值：是' -DefaultValue $true
                }
                'ServerEnableCommandBlock' {
                    $Script:ServerEnableCommandBlock = Read-InputBool -Message '是否启用命令方块，缺省值：是' -DefaultValue $true
                }
                'ServerEnforceSecureProfile' {
                    $Script:ServerEnforceSecureProfile = Read-InputBool -Message '是否强制使用安全配置文件（聊天签名），缺省值：否' -DefaultValue $false
                }
            }
        }

        $Config = @"
# 配置文件，可修改以下等号后的内容

# 服务器（或模组包）名称（将在标题栏显示），可略过
`$Script:ServerName = '$Script:ServerName'

# 模组加载器 'Vanilla', 'Forge', 'Custom'
`$Script:ModLoader = '$Script:ModLoader'

# 是否使用国内镜像下载 Vanilla 客户端（即使是模组端也得下载）
`$Script:VanillaMirror = `[bool`]$($Script:VanillaMirror ? '$true': '$false')

# 模组加载器安装器版本（Fabric 需要此项）
`$Script:ModLoaderInstallerVersion = `[version`]'$Script:ModLoaderInstallerVersion'

# MineCraft 版本 '1.20.1', '1.19.2', 等
`$Script:MinecraftVersion = `[version`]'$Script:MinecraftVersion'

# 模组加载器版本，原版可忽略此设置
`$Script:ModLoaderVersion = `[string`]'$Script:ModLoaderVersion'

# Java 命令行，可填写 `“java.exe`” 的路径
`$Script:Java = '$Script:Java'

# 是否跳过 Java 兼容性检查
`$Script:SkipJavaCompatibilityCheck = `[bool`]$($Script:SkipJavaCompatibilityCheck ? '$true': '$false')

# 最小内存，以字节为单位，可输入 `“2000MB`”，`“4GB`” 等
`$Script:MinMemory = $Script:MinMemory

# 最大内存，以字节为单位，可输入 `“2000MB`”，`“4GB`” 等
`$Script:MaxMemory = $Script:MaxMemory

# JVM 参数，不要包含内存设置（-Xmx -Xms），不知道可留空
`$Script:JVMParameters = '$Script:JVMParameters'

# 使能自动重启
`$Script:AutoRestart = `[bool`]$($Script:AutoRestart ? '$true': '$false')

# 最短重启时间，以秒为单位，短于这个时间将不会自动重启
`$Script:MinRestartTime = '$Script:MinRestartTime'

# 自定义启动命令（Custom 需要）
`$Script:CustomLaunchCommand = '$Script:CustomLaunchCommand'

# 服务器端口，默认为 25565
`$Script:ServerPort = $Script:ServerPort

# 是否允许飞行
`$Script:ServerAllowFlight = `[bool`]$($Script:ServerAllowFlight ? '$true': '$false')

# 是否启用命令方块
`$Script:ServerEnableCommandBlock = `[bool`]$($Script:ServerEnableCommandBlock ? '$true': '$false')

# 是否强制使用安全配置文件（聊天签名）
`$Script:ServerEnforceSecureProfile = `[bool`]$($Script:ServerEnforceSecureProfile ? '$true': '$false')
"@
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
        # $JavaVersion = if ($IsWindows) {
        #     (Get-Command $Script:Java).Version
        # }
        # else {
        #     [version][regex]::Match($Bit.Replace('_', '.'), '[0-9\.]+').Groups[1].Value
        # }
        $JavaVersion = [version][regex]::Match($Bit.Replace('_', '.'), '[0-9\.]+').Groups[0].Value
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
                # 如果使用国内镜像下载 Vanilla 服务端
                if ($Script:VanillaMirror ) {
                    $DownloadUri = $VanillaMirrorAPI -f $Script:MinecraftVersion
                }
                else {
                    $DownloadUri = ($Content | ConvertFrom-Json).downloads.server.url
                }
                # hash 值
                $SHA1 = ($Content | ConvertFrom-Json).downloads.server.sha1
            }
            catch {
                Write-Host $_ -ForegroundColor Red
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
                Write-Host $_ -ForegroundColor Red
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
                    Write-Host $_ -ForegroundColor Red
                    Exit-Script "下载 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 安装器失败"
                }
            }
            # 下载 Vanilla 服务端
            if ($Script:MinecraftVersion.Minor -ge 17) {
                $VanillaServerPath = Join-Path $PSScriptRoot "libraries/net/minecraft/server/$Script:MinecraftVersion/server-$Script:MinecraftVersion.jar"
                # 如果使用国内镜像下载 Vanilla 服务端
                if ($Script:VanillaMirror) {
                    if (Test-Path $VanillaServerPath -PathType Leaf) {
                        Write-Host 'Vanilla 服务端已存在，跳过下载'
                    }
                    else {
                        Write-Host '使用国内镜像提前下载 Vanilla 服务端'
                        try {
                            $VanillaServerUrl = $VanillaMirrorAPI -f $Script:MinecraftVersion
                            $DownloadUri = $VanillaServerUrl
                            # \libraries\net\minecraft\server\1.20.1\server-1.20.1.jar
                            Invoke-WebRequest -Uri $DownloadUri -OutFile $VanillaServerPath
                        }
                        catch {
                            Write-Host $_ -ForegroundColor Red
                            Exit-Script "下载 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 服务端失败"
                        }
                    }
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
                Write-Host $_ -ForegroundColor Red
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
                Write-Host $_ -ForegroundColor Red
                Exit-Script "下载 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 失败"
            }
        }
        "NeoForge" {
            # 已安装 NeoForge 则返回
            $NeoForgeJarLocation = Join-Path $PSScriptRoot "libraries/net/neoforged/neoforge/$Script:ModLoaderVersion/neoforge-$Script:ModLoaderVersion-server.jar"
            if (Test-Path $NeoForgeJarLocation -PathType Leaf) {
                return
            }
            # 如果使用国内镜像下载 Vanilla 服务端
            $VanillaServerPath = Join-Path $PSScriptRoot "libraries/net/minecraft/server/$Script:MinecraftVersion/server-$Script:MinecraftVersion.jar"
            if ($Script:VanillaMirror) {
                if (Test-Path $VanillaServerPath -PathType Leaf) {
                    Write-Host 'Vanilla 服务端已存在，跳过下载'
                }
                else {
                    Write-Host '使用国内镜像提前下载 Vanilla 服务端'
                    try {
                        $VanillaServerUrl = $VanillaMirrorAPI -f $Script:MinecraftVersion
                        $DownloadUri = $VanillaServerUrl
                        # \libraries\net\minecraft\server\1.20.1\server-1.20.1.jar
                        Invoke-WebRequest -Uri $DownloadUri -OutFile $VanillaServerPath
                    }
                    catch {
                        Write-Host $_ -ForegroundColor Red
                        Exit-Script "下载 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 服务端失败"
                    }
                }
            }
            # 下载安装器
            $Destination = Join-Path $PSScriptRoot "neoforge-$Script:MinecraftVersion-$Script:ModLoaderVersion.jar"
            if (-not (Test-Path $Destination -PathType Leaf)) {
                Write-Host '开始下载 NeoForge 安装器'
                $ForgeInstallerUrl = "https://bmclapi2.bangbang93.com/neoforge/version/$Script:ModLoaderVersion/download/installer.jar"
                try {
                    Invoke-WebRequest -Uri $ForgeInstallerUrl -OutFile $Destination
                }
                catch {
                    Write-Host $_ -ForegroundColor Red
                    Exit-Script "下载 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 安装器失败"
                }
            }
            
            # 安装 NeoForge
            try {
                Write-Host '开始安装 NeoForge'
                if ($IsWindows) {
                    cmd /c "`"$Script:Java`" -jar `"$Destination`" --installServer"
                }
                else {
                    "`"$Script:Java`" -jar `"$Destination`" --installServer" | bash
                }
                if (-not (Test-Path $NeoForgeJarLocation -PathType Leaf)) {
                    throw
                }
                Remove-FileIfExist 'run.bat'
                Remove-FileIfExist 'run.sh'
                Remove-FileIfExist 'user_jvm_args.txt'
            }
            catch {
                Write-Host $_ -ForegroundColor Red
                Exit-Script "安装 $Script:ModLoader-$Script:MinecraftVersion-$Script:ModLoaderVersion 失败"
            }
        }
        Default {}
    }    
}

# 需求最终用户许可协议
function Request-Eula {
    # 检查是否存在 eula.txt
    if (Test-Path -Path 'eula.txt' -PathType Leaf) {
        # 检查 eula.txt 内的 eula 是否为 true
        if ('eula=true' -in (Get-Content -Path 'eula.txt')) {
            return
        }
    }

    Write-Host 'Mojang 的 EULA 尚未被接受。为了运行 Minecraft 服务器，您必须接受 Mojang 的 EULA。' -ForegroundColor Yellow
    Write-Host 'Mojang 的 EULA 可在 https://aka.ms/MinecraftEULA 上阅读' -ForegroundColor Yellow
    Write-Host '如果您同意 Mojang 的 EULA，请输入 “我同意” 或 “I agree”' -ForegroundColor Yellow
    $Answer = Read-InputString -Message '您的回答'

    if ($Answer -eq "我同意" -or $Answer -eq "I agree") {
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

# 构造启动命令
function Get-LaunchCommand {
    $RunCommand = switch ($Script:ModLoader) {
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
        'NeoForge' {
            if ($IsWindows) {
                ('@"{0}"' -f (Join-Path $PSScriptRoot "libraries/net/neoforged/neoforge/$Script:ModLoaderVersion/win_args.txt"))
            }
            else {
                ('@"{0}"' -f (Join-Path $PSScriptRoot "libraries/net/neoforged/neoforge/$Script:ModLoaderVersion/unix_args.txt"))
            }
        }
        'Custom' {
            $Script:CustomLaunchCommand
        }
        Default {}
    }
    # "`"$Script:Java`" -Xmx$MaxMemory -Xms$MinMemory $JVMParameters $ServerRunCommand nogui"
    $Script:ServerRunCommand = "`"$Script:Java`" -Xmx$MaxMemory -Xms$MinMemory $JVMParameters $RunCommand nogui"
}

# 检查服务器配置
function Test-Properties {
    # 检查服务器端口是否被占用
    if ($IsWindows) {
        $PortInUse = $null -ne (netstat -ano | Select-String ":$Script:ServerPort\s")
    }
    else {
        $PortInUse = $null -ne (lsof -i :$Script:ServerPort)
    }
    if ($PortInUse) {
        Write-Host "端口 $Script:ServerPort 可能已被占用，请修改配置文件中的 ServerPort" -ForegroundColor Red
        Exit-Script
    }
    # 检查是否存在 server.properties 文件
    if (-not (Test-Path -Path 'server.properties' -PathType Leaf)) {
        Write-Host '未检测到 server.properties 文件，将为您生成'
        $ServerProperties = @"
# Minecraft server properties
server-port=$Script:ServerPort
allow-flight=$($Script:ServerAllowFlight.ToString().ToLower())
enable-command-block=$($Script:ServerEnableCommandBlock.ToString().ToLower())
enforce-secure-profile=$($Script:ServerEnforceSecureProfile.ToString().ToLower())
"@
    }
    else {
        # 如果存在，检查配置项是不是正确的
        $ServerPropertiesPath = Join-Path $PSScriptRoot 'server.properties'
        $ServerProperties = Get-Content -Path $ServerPropertiesPath
        $IsWrongConfig = $false
        if ($null -eq (Select-String $ServerPropertiesPath -Pattern "^server-port\s*=\s*$Script:ServerPort\s*$")) {
            Write-Host "server-port 配置项不正确，将为您修正" -ForegroundColor Yellow
            $ServerProperties = $ServerProperties -replace "^server-port\s*=\s*\d+", "server-port=$($Script:ServerPort)"
            $IsWrongConfig = $true
        }
        if ($null -eq (Select-String $ServerPropertiesPath -Pattern "^allow-flight\s*=\s*$($Script:ServerAllowFlight.ToString().ToLower())\s*$")) {
            Write-Host "allow-flight 配置项不正确，将为您修正" -ForegroundColor Yellow
            $ServerProperties = $ServerProperties -replace "^allow-flight\s*=\s*(true|false)", "allow-flight=$($Script:ServerAllowFlight.ToString().ToLower())"
            $IsWrongConfig = $true
        }
        if ($null -eq (Select-String $ServerPropertiesPath -Pattern "^enable-command-block\s*=\s*$($Script:ServerEnableCommandBlock.ToString().ToLower())\s*$")) {
            Write-Host "enable-command-block 配置项不正确，将为您修正" -ForegroundColor Yellow
            $ServerProperties = $ServerProperties -replace "^enable-command-block\s*=\s*(true|false)", "enable-command-block=$($Script:ServerEnableCommandBlock.ToString().ToLower())"
            $IsWrongConfig = $true
        }
        if ($null -eq (Select-String $ServerPropertiesPath -Pattern "^enforce-secure-profile\s*=\s*$($Script:ServerEnforceSecureProfile.ToString().ToLower())\s*$")) {
            Write-Host "enforce-secure-profile 配置项不正确，将为您修正" -ForegroundColor Yellow
            $ServerProperties = $ServerProperties -replace "^enforce-secure-profile\s*=\s*(true|false)", "enforce-secure-profile=$($Script:ServerEnforceSecureProfile.ToString().ToLower())"
            $IsWrongConfig = $true
        }
        if (-not $IsWrongConfig) {
            Write-Host 'server.properties 配置项正确' -ForegroundColor Green
        }
        else {
            Set-Content -Path $ServerPropertiesPath -Value $ServerProperties
        }
        Suspend-Script
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
# 检查服务器配置
Test-Properties


# 启动服务器
$RestartTime = 0
do {
    Clear-Host
    Write-Host '服务器启动中……'
    Write-Host "重启次数：$RestartTime"
    $host.ui.RawUI.WindowTitle = "$ServerName | 重启次数：$RestartTime"
    $StartTime = Get-Date -UFormat '%s'
    if ($IsWindows) {
        cmd /c $ServerRunCommand
    }
    else {
        "rm `$0`n$ServerRunCommand" | Out-File do_not_run_me
        bash do_not_run_me
    }
    if ($Script:AutoRestart -and ((Get-Date -UFormat '%s') - $StartTime -ge $MinRestartTime)) {
        Write-Host '服务器将在 3 秒后重启，按 q 键以阻止' -ForegroundColor Yellow
        $count = 0
        $key = $null
        $QuitKey = 81 #Character code for 'q' key.
        while ($count -le 12) {
            if ($host.UI.RawUI.KeyAvailable) {
                $key = $host.ui.RawUI.ReadKey("NoEcho, IncludeKeyUp")
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

