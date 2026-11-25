<#
.SYNOPSIS
  Rellena itunesId en canciones.json buscando cada canción en la iTunes Search API.

.DESCRIPTION
  - Reanudable: salta las canciones que ya tienen itunesId (o que ya se marcaron como no encontradas).
  - Respeta el límite de ~20 llamadas/minuto de Apple: 3 s entre el INICIO de una llamada y la siguiente
    (el tiempo que tarda la respuesta ya cuenta como espera). Si Apple devuelve 403/429 espera 60 s.
  - Pide explícitamente las versiones 'explicit' (si no, la tienda española parece ocultarlas).
  - Penaliza versiones en directo/acústicas.
  - Deja de buscar en cuanto encuentra una coincidencia fiable (título y artista correctos).
  - Guarda el progreso cada 10 canciones.
  - Genera revision_itunes.csv con las coincidencias dudosas y las no encontradas.

.EXAMPLE
  .\Resolve-ItunesIds.ps1 -Path .\canciones.json
  .\Resolve-ItunesIds.ps1 -Path .\canciones.json -Reintentar   # vuelve a probar las no encontradas
#>
[CmdletBinding()]
param(
    [string]$Path = ".\canciones.json",
    [string]$Country = "es",
    [int]$PausaMs = 3000,
    [switch]$Reintentar
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 puede usar TLS antiguos por defecto; iTunes exige TLS 1.2
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
# Rutas relativas respecto a la carpeta del script si no existen desde la ubicación actual
if (-not (Test-Path $Path)) { $alt = Join-Path $PSScriptRoot (Split-Path $Path -Leaf); if (Test-Path $alt) { $Path = $alt } }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-Norm([string]$s) {
    if (-not $s) { return "" }
    $s = $s.ToLowerInvariant()
    $s = $s -replace '\(.*?\)|\[.*?\]', ' '                 # quita (Remix), [feat. X]...
    $s = $s -replace '\s(feat\.?|ft\.?|featuring)\s.*$', ' '
    $d = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($c in $d.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
    }
    $s = $sb.ToString() -replace '[^a-z0-9 ]', ' ' -replace '\s+', ' '
    return $s.Trim()
}

function Get-MainArtist([string]$a) {
    # "Shakira feat. Maluma" -> "shakira"; "Bad Bunny & Drake" -> "bad bunny"
    $main = ($a -split '\s+(feat\.?|ft\.?|&|x|y|and|con)\s+|,')[0]
    return Get-Norm $main
}

function Get-Score($song, $res) {
    $tSong = Get-Norm $song.titulo
    $tRes  = Get-Norm $res.trackName
    $aSong = Get-MainArtist $song.artista
    $aRes  = Get-Norm $res.artistName
    $score = 0
    if ($tSong -eq $tRes) { $score += 60 }
    elseif ($tSong -and $tRes -and ($tRes.Contains($tSong) -or $tSong.Contains($tRes))) { $score += 35 }
    if ($aSong -and $aRes.Contains($aSong)) { $score += 40 }
    if ($res.previewUrl) { $score += 5 }
    # penaliza versiones que no son la original
    if ($res.trackName -match '(?i)karaoke|cover|tribute') { $score -= 30 }
    if ($res.trackName -match '(?i)instrumental' -and $song.idioma -ne 'inst') { $score -= 30 }
    if ($res.collectionName -match '(?i)karaoke|tribute|made famous|in the style of|lullaby|piano cover|covers') { $score -= 40 }
    if ($res.trackName -match '(?i)remix|version|versión|arr\.' -and $song.titulo -notmatch '(?i)remix') { $score -= 20 }
    if ("$($res.trackName) $($res.collectionName)" -match '(?i)\blive\b|en vivo|en directo|\bdirecto\b|unplugged|acústico|acoustic' -and $song.titulo -notmatch '(?i)live|vivo|directo|unplugged|ac[úu]stic') { $score -= 30 }
    return $score
}

$script:ultimaLlamada = [datetime]::MinValue
function Wait-Turno {
    # espera solo lo que falte para que pasen $PausaMs desde el inicio de la llamada anterior
    $falta = $PausaMs - ((Get-Date) - $script:ultimaLlamada).TotalMilliseconds
    if ($falta -gt 0) { Start-Sleep -Milliseconds ([int]$falta) }
    $script:ultimaLlamada = Get-Date
}
function Invoke-Itunes([string]$term, [string]$extra = '&limit=25', [string]$pais = $Country) {
    $url = "https://itunes.apple.com/search?term=$([uri]::EscapeDataString($term))&entity=song&explicit=Yes&country=$pais$extra"
    for ($i = 1; $i -le 3; $i++) {
        Wait-Turno
        try { return Invoke-RestMethod -Uri $url -TimeoutSec 20 }
        catch {
            $code = $_.Exception.Response.StatusCode.value__
            Write-Warning "HTTP $code en intento $i para '$term'. Espero 60 s..."
            Start-Sleep -Seconds 60
        }
    }
    return $null
}

function Save-Json($songs) {
    $json = $songs | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText((Resolve-Path $Path), $json, $utf8NoBom)
}

# --- main ---
$songs = [IO.File]::ReadAllText((Resolve-Path $Path), [Text.Encoding]::UTF8) | ConvertFrom-Json
foreach ($s in $songs) {
    foreach ($p in 'itunesMatch','itunesScore','itunesEstado','itunesPais') {
        if (-not ($s.PSObject.Properties.Name -contains $p)) { $s | Add-Member -NotePropertyName $p -NotePropertyValue $null }
    }
}

$pendientes = $songs | Where-Object { -not $_.itunesId -and ($Reintentar -or $_.itunesEstado -ne 'no_encontrada') }
Write-Host "Pendientes: $($pendientes.Count) de $($songs.Count). Tiempo estimado: entre $([math]::Ceiling($pendientes.Count * $PausaMs / 60000)) y $([math]::Ceiling($pendientes.Count * 3 * $PausaMs / 60000)) min (según cuántas encuentre a la primera)"
$inicio = Get-Date

$n = 0
foreach ($song in $pendientes) {
    $n++
    $mainArtist = ($song.artista -split '\s+(feat\.?|ft\.?)\s+')[0]
    $tituloLimpio = $song.titulo -replace '\(.*?\)', ''
    # Hasta 3 búsquedas: artista+título, solo título (más resultados) y todo el catálogo del artista
    $intentos = @(
        @{ term = "$mainArtist $tituloLimpio"; extra = '&limit=25' },
        @{ term = "$tituloLimpio"; extra = '&limit=100' },
        @{ term = "$mainArtist"; extra = '&attribute=artistTerm&limit=200' }
        # (otras tiendas: añadir aquí @{ ...; pais = 'us' } si algún día se quiere; ahora solo España)
    )
    $best = $null; $bestScore = -999; $bestPais = $Country
    foreach ($it in $intentos) {
        $pais = if ($it.pais) { $it.pais } else { $Country }
        $resp = Invoke-Itunes $it.term $it.extra $pais
        if ($resp -and $resp.resultCount -gt 0) {
            foreach ($r in $resp.results) {
                $sc = Get-Score $song $r
                if ($sc -gt $bestScore) { $best = $r; $bestScore = $sc; $bestPais = $pais }
            }
        }
        # coincidencia fiable: título exacto o casi y artista correcto -> no hace falta seguir buscando
        if ($best -and $bestScore -ge 85 -and (Get-Norm $best.artistName).Contains((Get-MainArtist $song.artista))) { break }
    }

    $artistaOk = $best -and (Get-Norm $best.artistName).Contains((Get-MainArtist $song.artista))
    if ($best -and $bestScore -ge 75 -and $artistaOk) {
        $song.itunesId    = [long]$best.trackId
        $song.itunesMatch = "$($best.artistName) - $($best.trackName) [$($best.collectionName)]"
        $song.itunesScore = $bestScore
        $song.itunesPais  = if ($bestPais -ne $Country) { $bestPais } else { $null }
        $song.itunesEstado = if (-not $best.previewUrl) { 'sin_preview' } elseif ($bestScore -ge 95) { 'ok' } else { 'dudosa' }
    } else {
        $song.itunesEstado = 'no_encontrada'
        $song.itunesScore  = $bestScore
        if ($best) { $song.itunesMatch = "$($best.artistName) - $($best.trackName)" }
    }

    $min = ((Get-Date) - $inicio).TotalMinutes
    $restan = [math]::Ceiling($min / $n * ($pendientes.Count - $n))
    Write-Host ("[{0}/{1}] {2,-13} {3} - {4}   (quedan ~{5} min)" -f $n, $pendientes.Count, $song.itunesEstado, $song.artista, $song.titulo, $restan)
    if ($n % 10 -eq 0) { Save-Json $songs }
}
Save-Json $songs

# --- informe de revisión ---
$revisar = $songs | Where-Object { $_.itunesEstado -ne 'ok' } |
    Select-Object id, artista, titulo, anio, itunesEstado, itunesScore, itunesMatch, itunesId
$revisar | Export-Csv -Path (Join-Path (Split-Path (Resolve-Path $Path)) 'revision_itunes.csv') -NoTypeInformation -Delimiter ';' -Encoding UTF8

$songs | Group-Object itunesEstado | Select-Object Name, Count | Format-Table -AutoSize
Write-Host "Revisa revision_itunes.csv: 'dudosa' = comprueba que es la versión buena; 'no_encontrada'/'sin_preview' = corrige o quita."
