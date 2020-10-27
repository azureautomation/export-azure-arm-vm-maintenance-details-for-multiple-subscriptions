Add-AzureRmAccount
$Subs = Get-AzureRmSubscription | Select-Object Id, Name, TenantId | Out-GridView -Title "Select Subscriptions (use Ctrl/Shift for multiples)" -PassThru
$VMs = @()

$DateFormat = "dd/MM/yyyy HH:mm"
$usCulture = [Globalization.CultureInfo]'en-US'
$KnownUTCDates=((Get-Date -Date "10 January  2018 00:00"),(Get-Date -Date "11 January  2018 00:00"),(Get-Date -Date "12 January  2018 00:00"),(Get-Date -Date "15 January  2018 00:00"))
$TZ = [System.TimeZoneInfo]::Local

foreach ($sub in $Subs) {
    Select-AzureRmSubscription -Subscription $sub.Id
    $SubId = $sub.Id
    $SubName = $sub.Name
    $SubVMs = @()
    $SubVMs = Get-AzureRmVM -Status | Select-Object @{n="SubscriptionGuid";e={$SubId}},@{n="SubscriptionName";e={$SubName}},`
        Name, ResourceGroupName, PowerState, Location, `
        @{n="VMSize";e={$_.HardwareProfile.VmSize}}, 
        @{n="CustomerInitiatedMaintenanceAllowed";e={$_.MaintenanceRedeployStatus.IsCustomerInitiatedMaintenanceAllowed}}, `
        @{n="PreMaintenanceWindowStartTime";e={if($_.MaintenanceRedeployStatus.PreMaintenanceWindowStartTime -ne $null) {[datetime]::Parse($_.MaintenanceRedeployStatus.PreMaintenanceWindowStartTime,$usCulture)} else {$null}}}, `
        @{n="PreMaintenanceWindowEndTime";e={if($_.MaintenanceRedeployStatus.PreMaintenanceWindowEndTime -ne $null) {[datetime]::Parse($_.MaintenanceRedeployStatus.PreMaintenanceWindowEndTime,$usCulture)} else {$null}}}, `
        @{n="MaintenanceWindowStartTime";e={if($_.MaintenanceRedeployStatus.MaintenanceWindowStartTime -ne $null) {[datetime]::Parse($_.MaintenanceRedeployStatus.MaintenanceWindowStartTime,$usCulture)} else {$null}}}, `
        @{n="MaintenanceWindowEndTime";e={if($_.MaintenanceRedeployStatus.MaintenanceWindowEndTime -ne $null) {[datetime]::Parse($_.MaintenanceRedeployStatus.MaintenanceWindowEndTime,$usCulture)} else {$null}}}, `
        @{n="LastOperationResultCode";e={$_.MaintenanceRedeployStatus.LastOperationResultCode}}, `
        @{n="LastOperationMessage";e={$_.MaintenanceRedeployStatus.LastOperationMessage}}, `
        @{n="AvailabilitySetReference";e={$_.AvailabilitySetReference.Id}}

    Write-Output "$($SubName) : $($SubVMs.Count)"

    #Fudge to see if Maintenance information is in UTC or local time using known UTC Maintenance start times
    if (($SubVMs.MaintenanceWindowStartTime |Sort-Object | Select-Object -First 1) -in $KnownUTCDates) {
        $UTCFlag = $true
        foreach ($VM in $SubVMs) {
            if ($VM.PreMaintenanceWindowStartTime -ne $null) {
                $VM.PreMaintenanceWindowStartTime =Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeFromUtc($VM.PreMaintenanceWindowStartTime, $TZ)) -Format $DateFormat 
            }
            if ($VM.PreMaintenanceWindowEndTime -ne $null) {
                $VM.PreMaintenanceWindowEndTime = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeFromUtc($VM.PreMaintenanceWindowEndTime, $TZ)) -Format $DateFormat 
            }
            if ($VM.MaintenanceWindowStartTime -ne $null) {
                $VM.MaintenanceWindowStartTime = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeFromUtc($VM.MaintenanceWindowStartTime, $TZ)) -Format $DateFormat 
            }
            if ($VM.MaintenanceWindowEndTime -ne $null) {
                $VM.MaintenanceWindowEndTime = Get-Date -Date ([System.TimeZoneInfo]::ConvertTimeFromUtc($VM.MaintenanceWindowEndTime, $TZ)) -Format $DateFormat 
            }
        }
    } else {
        $UTCFlag = $false
    }
    $VMs += $SubVMs
}
$VMs | `
    Select-Object SubscriptionGuid, SubscriptionName, `
        Name, ResourceGroupName, PowerState, Location, `
        VMSize, CustomerInitiatedMaintenanceAllowed, `
        PreMaintenanceWindowStartTime, PreMaintenanceWindowEndTime, `
        MaintenanceWindowStartTime, MaintenanceWindowEndTime, `
        LastOperationResultCode, LastOperationMessage, `
        AvailabilitySetReference `
    | Export-Csv -Path "$($Env:Temp)\ARM_Maint_VMs.csv" -NoTypeInformation

Invoke-Item "$($Env:Temp)\ARM_Maint_VMs.csv"
