param(
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "${resource_group_name}",

    [Parameter(Mandatory = $false)]
    [string] $StorageAccountName = "${storage_account_name}",

    [Parameter(Mandatory = $true)]
    [bool] $SftpEnabled
)

Connect-AzAccount -Identity | Out-Null

Set-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name              $StorageAccountName `
    -EnableSftp        $SftpEnabled

Write-Output "SFTP $(if ($SftpEnabled) { 'enabled' } else { 'disabled' }) on $StorageAccountName"