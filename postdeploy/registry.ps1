ls .\registry\*.json | % {
    $registryKeys = Get-Content $_.FullName | ConvertFrom-Json 
    $registryKeys | % {

        # Registry key
        If (!(Test-Path $_.registryPath)) { 
            Write-Host "Registry key $($_.registryPath) NOT found. Creating registry key..." 
            New-Item -Path $_.registryPath -Force | Out-Null 
        } Else {Write-Host "Registry key $($_.registryPath) found!" }

        # Registry key property
        If ($_.registryName)
        {
            If (Get-ItemProperty -Path $_.registryPath -Name $_.registryName -ea SilentlyContinue) 
            {
                Write-Host "Registry property $($_.registryName) found! Updating registry property..."
                Set-ItemProperty -Path $_.registryPath -Name $_.registryName -Value $_.registryValue
            }
            Else 
            {
                Write-Host "Registry property $($_.registryName) NOT found. Creating registry property..."
                New-ItemProperty -Path $_.registryPath -Name $_.registryName -Value $_.registryValue -PropertyType $_.registryType -Force | Out-Null
            }
        } 
    
    }
}