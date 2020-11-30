
# load the SCOM module
import-module operationsmanager

# get all resource pools
$rps = Get-SCOMResourcePool

# get all agents for faster processing
$allAgents = Get-SCOMAgent

# show every resource pool and its members
foreach ($rp in $rps) {
    "-"*50
    $rp.displayname

    # Single MS/GW are not redundant.
    if ($rp.members.count -eq 1) {
        Write-Host "There only 1 member (MS/GW) in your pool." -ForegroundColor Red
        Write-Host "The pool is not high available." -ForegroundColor Red
    }
    
    if ((Get-SCOMManagementServer -Name ($rp.Members).displayname[0]).IsGateway -eq $true) {
        # Disable DefaultObserver for all GWs (it will not work)
        $rp.UseDefaultObserver = $false
        $rp.ApplyChanges()

        # 2 GWs are not redundant; add first healthy agent as observer.
        if ($rp.members.count -eq 2) {
            Write-Host "There are 2 members (GW) in your pool." -ForegroundColor Yellow
            Write-Host "Adding the first healthy agent in the list of managed agents as observer." -ForegroundColor Green
            $newObserver = (Get-SCOMGatewayManagementServer -Name ($rp.Members).displayname | Get-SCOMAgent | ?{$_.HealthState -eq "Success"})[0]
            if ($rp.Observers) {
                if (($rp.Observers).Displayname -ne $newObserver.DisplayName) {
                    $oldObserver = $allAgents | ?{$_.displayName -eq ($rp.Observers).Displayname}
                    Write-Host "Removing old observer:" $oldObserver.DisplayName
                    $rp | Set-SCOMResourcePool -Observer $oldObserver -Action "Remove"
                    Write-Host "Adding new observer:" $newObserver.DisplayName
                    $rp | Set-SCOMResourcePool -Observer $newObserver -Action "Add"
                } else {
                    Write-Host "Observer did not change."
                }
            } else {
                Write-Host "Adding observer:" $newObserver.DisplayName
                $rp | Set-SCOMResourcePool -Observer $newObserver -Action "Add"
            }
        }
    } else {
        if ($rp.members.count -ge 5) {
            # Disable DefaultObserver when more than 5 MS are in the pool
            Write-Host "Disable the default observer (more than 5 MS)." -ForegroundColor Green
            $rp.UseDefaultObserver = $false
            $rp.ApplyChanges()
        } else {
            # Enable DefaultObserver when less than 5 MS are in the pool
            Write-Host "Enable the default observer (less than 5 MS)." -ForegroundColor Green
            $rp.UseDefaultObserver = $true
            $rp.ApplyChanges()
        }
    }
 }
