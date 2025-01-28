# Convert file size from bytes to KB/MB/GB/TB
Function ReadableFileSize {
    Param (
        [int64]$size
    )
    If ($size -gt 1TB) {[string]::Format("{0:0.00} TB", $size / 1TB)}
    ElseIf ($size -gt 1GB) {[string]::Format("{0:0.00} GB", $size / 1GB)}
    ElseIf ($size -gt 1MB) {[string]::Format("{0:0.00} MB", $size / 1MB)}
    ElseIf ($size -gt 1KB) {[string]::Format("{0:0.00} kB", $size / 1KB)}
    Else   {[string]::Format("{0:0} B", $size)}
}
function ConvertRCloneFileSizeInfo {
    [OutputType([hashtable])]
    param(
        [parameter(ParameterSetName='rCloneInfo', Mandatory=$true, Position=0)]
        [string[]]$rCloneInfo
    )
    $numberformat = [System.Globalization.CultureInfo]::CurrentCulture.NumberFormat
    $rCloneInfo=$rCloneInfo -replace '^[^\d]*','' -replace 'iB','B'
    [float[]]$rCloneInfoNumOnly=$rCloneInfo -replace '[^0-9.]', ''
    [string[]]$rCloneInfoUnits=$rCloneInfo -replace '.*?(\bB\b|\bKB\b|\bMB\b|\bGB\b|\bTB\b|\bPB\b).*', '$1'
    [float[]]$RoundedNumbers=$rCloneInfoNumOnly | ForEach-Object {[math]::Round($_, 2)}
    return @{
        "Total Space"=$RoundedNumbers[0].ToString("G",$numberformat)+" "+$rCloneInfoUnits[0]
        "Used Space"=$RoundedNumbers[1].ToString("G",$numberformat)+" "+$rCloneInfoUnits[1]
        "Free Space"=$RoundedNumbers[2].ToString("G",$numberformat)+" "+$rCloneInfoUnits[2]
    }
}