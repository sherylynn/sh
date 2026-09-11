param(
    [string]$CertificatePath = (Join-Path $PSScriptRoot "novnc-ca.crt")
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $CertificatePath)) {
    throw "CA certificate not found: $CertificatePath. Download https://YOUR-NOVNC-HOST:10086/novnc-ca.crt first."
}

$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::Root,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
try {
    $existing = $store.Certificates | Where-Object Thumbprint -eq $certificate.Thumbprint
    if (-not $existing) {
        $store.Add($certificate)
    }
} finally {
    $store.Close()
}

Write-Host "Installed NewHome noVNC Local CA for the current Windows user. Restart Firefox or the browser before reconnecting."
