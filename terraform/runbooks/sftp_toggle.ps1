param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $StorageAccountName,

    [Parameter(Mandatory = $true)]
    [bool] $SftpEnabled
)

Connect-AzAccount -Identity | Out-Null

Set-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name              $StorageAccountName `
    -EnableSftp        $SftpEnabled

Write-Output "SFTP $(if ($SftpEnabled) { 'enabled' } else { 'disabled' }) on $StorageAccountName"