<#
    接受各种输入
    Read-InputPath
    Read-InputBool
    Read-InputNumber
    Read-InputUri
    Read-InputString
#>

# Requires -Version 7

<#
    接受路径输入
    -Message: 提示信息
    -ItemType: 项目类型（目录、文件）
    -Filter: 过滤
    -DefaultValue: 预设值
    -CreateIfNotExist: 不存在则创建目录或文件所在目录
    返回值: DirectoryInfo 或者 FileInfo 对象
#>
function Read-InputPath {
    param (
        [string]$Message = '请输入路径',
        [ValidateSet('Directory', 'File')]
        [string]$ItemType = 'Directory',
        [string]$Filter = '*',
        [string]$DefaultValue,
        [switch]$CreateIfNotExist
    )
    #[char[]]$InvalidFileNameChars = @('"', '<', '>', '|', ':', '*', '?', '\', '/' )
    #[char[]]$InvalidFileNameChars = @('"', '<', '>', '|', [char]0, [char]1, [char]2, [char]3, [char]4, [char]5, [char]6, [char]7, [char]8, [char]9, [char]10, [char]11, [char]12, [char]13, [char]14, [char]15, [char]16, [char]17, [char]18, [char]19, [char]20, [char]21, [char]22, [char]23, [char]24, [char]25, [char]26, [char]27, [char]28, [char]29, [char]30, [char]31, ':', '*', '?', '\', '/' )
    [char[]]$InvalidPathChars = ('"', '<', '>', '|', '*', '?')
    #[char[]]$InvalidPathChars = ('"', '<', '>', '|', [char]0, [char]1, [char]2, [char]3, [char]4, [char]5, [char]6, [char]7, [char]8, [char]9, [char]10, [char]11, [char]12, [char]13, [char]14, [char]15, [char]16, [char]17, [char]18, [char]19, [char]20, [char]21, [char]22, [char]23, [char]24, [char]25, [char]26, [char]27, [char]28, [char]29, [char]30, [char]31)
    #[char[]]$InvalidPathCharsWithAdditionalChecks = ( '"', '<', '>', '|', [Char]0, [Char]1, [Char]2, [Char]3, [Char]4, [Char]5, [Char]6, [Char]7, [Char]8, [Char]9, [Char]10, [Char]11, [Char]12, [Char]13, [Char]14, [Char]15, [Char]16, [Char]17, [Char]18, [Char]19, [Char]20, [Char]21, [Char]22, [Char]23, [Char]24, [Char]25, [Char]26, [Char]27, [Char]28, [Char]29, [Char]30, [Char]31, '*', '?' )
    $DefaultMessage = $Message
    while ($true) {
        # 获取输入
        [string]$Read = Read-Host -Prompt $Message
        $Message = $DefaultMessage
        if (-not [string]::IsNullOrWhiteSpace($Read)) {
            $Path = $Read.TrimEnd()
        }
        elseif (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
            $Path = $DefaultValue
        }
        else {
            continue
        }
        # 验证输入
        if (($Path.IndexOfAny($InvalidPathChars) + 1)) {
            $Message = '路径非法，请重新输入'
        }
        else {
            $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            switch ($ItemType) {
                'Directory' {
                    $Path = [System.IO.DirectoryInfo]($Path);
                    $Directory = $Path.FullName 
                }
                'File' {
                    $Path = [System.IO.FileInfo]($Path);
                    $Directory = $Path.DirectoryName 
                }
                Default {}
            }
            # 过滤
            if ($Path.Name -notlike $Filter) {
                Write-Host $Path.Name
                $Message = '没有找到符合过滤的内容，请重新输入'
            }
            else {
                # 不存在就创建
                if ($CreateIfNotExist -and -not $Path.Exists) {
                    New-Item -Path $Directory -ItemType Directory -Force | Out-Null
                }
                return $Path
            }
        }
    }
}

<#
    接受真假输入
    -Message: 提示信息
    -DefaultValue: 预设值
    返回值: 布尔值 $true 或 $false
#>
function Read-InputBool {
    param (
        [string]$Message = '请输入 T/F Y/N 1/0 True/False Yes/No 真/假 是/否（不区分大小写）',
        [string]$DefaultValue
    )
    [string[]]$TrueString = @('T', 'Y', '1', 'True', 'Yes', '真', '是')
    [string[]]$FalseString = @('F', 'N', '0', 'False', 'No', '假', '否')
    $DefaultMessage = $Message
    while ($true) {
        # 获取输入
        [string]$Read = Read-Host -Prompt $Message
        $Message = $DefaultMessage
        if (-not [string]::IsNullOrWhiteSpace($Read)) {
            $Result = $Read
        }
        elseif (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
            $Result = $DefaultValue
        }
        else {
            continue
        }
        # 验证输入
        if ($Result -in $TrueString) {
            return $true
            
        }
        elseif ($Result -in $falseString) {
            return $false
        }
        else {
            $Message = '输入非法，请重新输入'
        }
    }
}

<#
    接受数字输入
    -Message: 提示信息
    -MinValue: 最小值
    -MaxValue: 最大值
    -DefaultValue: 预设值
    返回值: decimal 数
#>
function Read-InputNumber {
    param (
        [string]$Message = '请输入一个数',
        [decimal]$MinValue = [decimal]::MinValue,
        [decimal]$MaxValue = [decimal]::MaxValue,
        [string]$DefaultValue
    )
    $DefaultMessage = $Message
    while ($True) {
        # 获取输入
        [string]$Read = Read-Host -Prompt $Message
        $Message = $DefaultMessage
        if (-not [string]::IsNullOrWhiteSpace($Read)) {
            $Result = $Read
        }
        elseif (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
            $Result = $DefaultValue
        }
        else {
            continue
        }
        # 验证输入
        [decimal]$Number = 0
        if ([decimal]::TryParse($Result, [ref]$Number)) {
            if (($Number -lt $MinValue) -or ($Number -gt $MaxValue)) {
                $Message = "范围必须在 $minValue-$maxValue 之间，请重新输入"
            }
            else {
                return $Number
            }
        }
        else {
            try {
                $Result = Invoke-Expression $Read
                if ([decimal]::TryParse($Result, [ref]$Number)) {
                    if ($Number -lt $MinValue -and $Number -gt $MaxValue) {
                        $Message = "范围必须在 $minValue-$maxValue 之间，请重新输入"
                    }
                    else {
                        return $Number
                    }
                }
                else {
                    throw
                }
            }
            catch {
                $Message = '输入非法，请重新输入'
            }
        }
    }
}

<#
    接受 Uri 输入
    -Message: 提示信息
    -DefaultValue: 预设值
    返回值: Uri 对象
#>
function Read-InputUri {
    param (
        [string]$Message = '请输入 Uri',
        [string]$DefaultValue
    )
    $DefaultMessage = $Message
    while ($True) {
        # 获取输入
        [string]$Read = Read-Host -Prompt $Message
        $Message = $DefaultMessage
        if (-not [string]::IsNullOrWhiteSpace($Read)) {
            $Result = $Read
        }
        elseif (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
            $Result = $DefaultValue
        }
        else {
            continue
        }
        # 验证输入
        $Uri = [uri]($Result)
        if ($Uri.IsAbsoluteUri) {
            return $Uri
        }
        else {
            $Message = '输入非法，请重新输入'
        }
    }
}

<#
    接受字符串输入
    -Message: 提示信息
    -DefaultValue: 预设值
    返回值: 字符串
#>
function Read-InputString {
    param (
        [string]$Message = '请输入字符串（不需要引号）',
        [string]$DefaultValue
    )
    $DefaultMessage = $Message
    while ($True) {
        # 获取输入
        [string]$Read = Read-Host -Prompt $Message
        $Message = $DefaultMessage
        if (-not [string]::IsNullOrWhiteSpace($Read)) {
            $Result = $Read
        }
        elseif ($null -ne $DefaultValue) {
            $Result = $DefaultValue
        }
        else {
            continue
        }
        return $Result
    }
}


<# 接受输入输出模板
function FunctionName {
    param (
        [string]$Message = '提示信息',
        [string]$DefaultValue
    )
    $DefaultMessage = $Message
    while ($True) {
        # 获取输入
        [string]$Read = Read-Host -Prompt $Message
        $Message = $DefaultMessage
        if (-not [string]::IsNullOrWhiteSpace($Read)) {
            $Result = $Read
        }
        elseif ($null -ne $DefaultValue) {
            $Result = $DefaultValue
        }
        else {
            continue
        }
        # 验证输入
        if (condition) {
            return $Result
        }else {
            $Message = '输入非法，请重新输入'
        }
    }
}
#>
Export-ModuleMember -Function *
