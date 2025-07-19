# 禁用客户端模组
function Disable-ClientMods {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]
        $ClientMods,
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]
        $ModsDirectoryPath
    )
    function IsSameMod {
        param (
            [string]$ModName, [string]$ClientModName
        )
        return $ModName.StartsWith($ClientModName)
    }
    $Mods = Get-ChildItem -Path $ModsDirectoryPath -Filter '*.jar'
    foreach ($Mod in $Mods) {
        foreach ($ClientMod in $ClientMods) {
            if (IsSameMod $Mod.Name $ClientMod) {
                Rename-Item $Mod ($Mod.Name + '.disabled')
                Write-Host "已禁用：" $Mod.Name
                break
            }
        }
    }
}

Disable-ClientMods (Get-Content .\ClientModList.txt) .\mods