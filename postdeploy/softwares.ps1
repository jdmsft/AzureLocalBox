# Define temp folder
$tempFolder = 'C:\TEMP'
If (!(Test-Path $tempFolder)) { New-Item $tempFolder -ItemType directory }

# Disable progress bar to improve DL speed
$ProgressPreference = 'SilentlyContinue'

ls .\packages\*.json | % {
    $software = Get-Content $_.FullName | ConvertFrom-Json
    $softwareName = [io.path]::GetFileNameWithoutExtension($_.Name)
    $installerLocalPath = "$tempFolder\$softwareName.$($software.installerExtension)"
    
    Write-Host "Donwloading $($software.name) ..."
    Invoke-WebRequest -Uri $software.installerUri -OutFile $installerLocalPath -UseBasicParsing
    Write-Host "Installing $($software.name) ..."
    If ($software.installerExtension -eq 'exe')
    {
        Start-Process $installerLocalPath -ArgumentList $software.installerArguments.Split(' ') -Wait
    }
    ElseIf ($software.installerExtension -eq 'msi')
    {
        Start-Process msiexec.exe -ArgumentList "/I $installerLocalPath /quiet $($software.installerArguments.Split(' '))" -Wait
    }
    
    Write-Host "Removing $($software.name) installer..."
    Remove-Item -Path $installerLocalPath -Force 
}