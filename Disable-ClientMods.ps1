# 禁用客户端模组
function Disable-ClientMods {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]
        $ClientMods,
        [Parameter(Mandatory=$true)]
        [System.IO.DirectoryInfo]
        $ModsDirectoryPath
    )
    function IsSameMod {
        param (
            [string]
            $a,
            [string]
            $b
        )
        function min {
            param (
                [int]
                $a,
                [int]
                $b
            )
            return $a -lt $b ? $a : $b
        }
        [string[]]$a = $a.Split('-').Split('_')
        [string[]]$b = $b.Split('-').Split('_')
        $len = min $a.Count $b.Count
        for ($i = 0; $i -lt $len; $i++) {
            if ($a[$i] -ne $b[$i]) {
                return $false
            }
        }
        return $true
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