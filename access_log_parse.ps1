# Pfad zum Logverzeichnis
$logDir = "C:\Logs"
$logFiles = Get-ChildItem -Path $logDir -Filter "access_log*" | Sort-Object Name

# Regex zum Extrahieren von Benutzername und Datum
$pattern = '^\d+\.\d+\.\d+\.\d+\s+-\s+(?<username>[^\s\[\]]+)\s+\[(?<datetime>\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2}\s+[-+]\d{4})\]'

# Hashtable für letzten Login je Benutzer
$userLastLogin = @{}

foreach ($file in $logFiles) {
    Get-Content $file.FullName | ForEach-Object {
        if ($_ -match $pattern) {
            $username = $matches['username']
            $datetimeStr = $matches['datetime']

            try {
                $loginTime = [DateTime]::ParseExact($datetimeStr, "dd/MMM/yyyy:HH:mm:ss zzz", [System.Globalization.CultureInfo]::InvariantCulture)

                if (-not $userLastLogin.ContainsKey($username) -or $loginTime -gt $userLastLogin[$username]) {
                    $userLastLogin[$username] = $loginTime
                }
            }
            catch {
                Write-Warning "Datum konnte nicht geparst werden: $datetimeStr"
            }
        }
    }
}

# CSV-Dateipfad (Ziel für den Export)
$outputFile = "C:\Logs\UserLastLogin.csv"

# Daten in CSV exportieren (deutsches Datumsformat, Semikolon als Trennzeichen)
$userLastLogin.GetEnumerator() |
    Sort-Object Value |
    ForEach-Object {
        [PSCustomObject]@{
            Benutzername = $_.Key
            LetzterLogin = $_.Value.ToString("dd.MM.yyyy HH:mm:ss")
        }
    } |
    Export-Csv -Path $outputFile -Delimiter ';' -Encoding UTF8 -NoTypeInformation

Write-Host "Export abgeschlossen: $outputFile"
