Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$publicDir = Join-Path $root "public"
$sourcePath = Join-Path $publicDir "logo-karryt-oficial.png"
$tmpDir = Join-Path $publicDir ".tmp-favicon"
$icoPath = Join-Path $publicDir "favicon.ico"

if (-not (Test-Path $sourcePath)) {
  throw "No se encontro el logo fuente en: $sourcePath"
}

if (Test-Path $tmpDir) {
  Remove-Item -Path $tmpDir -Recurse -Force
}
New-Item -Path $tmpDir -ItemType Directory | Out-Null

function New-PaddedSquarePng {
  param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [int]$Size,

    [double]$PaddingRatio = 0.1
  )

  $src = [System.Drawing.Image]::FromFile($InputPath)
  try {
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        $innerSize = [int][Math]::Round($Size * (1.0 - (2.0 * $PaddingRatio)))
        if ($innerSize -lt 1) { $innerSize = 1 }

        $scale = [Math]::Min($innerSize / $src.Width, $innerSize / $src.Height)
        $drawW = [int][Math]::Round($src.Width * $scale)
        $drawH = [int][Math]::Round($src.Height * $scale)
        if ($drawW -lt 1) { $drawW = 1 }
        if ($drawH -lt 1) { $drawH = 1 }

        $x = [int][Math]::Floor(($Size - $drawW) / 2)
        $y = [int][Math]::Floor(($Size - $drawH) / 2)

        $rect = New-Object System.Drawing.Rectangle($x, $y, $drawW, $drawH)
        $g.DrawImage($src, $rect)

        $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
      }
      finally {
        $g.Dispose()
      }
    }
    finally {
      $bmp.Dispose()
    }
  }
  finally {
    $src.Dispose()
  }
}

$sizes = @(16, 32, 48, 64)
$pngPaths = @()

foreach ($size in $sizes) {
  $pngPath = Join-Path $tmpDir ("icon-{0}.png" -f $size)
  New-PaddedSquarePng -InputPath $sourcePath -OutputPath $pngPath -Size $size -PaddingRatio 0.1
  $pngPaths += $pngPath
}

$pngBytes = @()
foreach ($path in $pngPaths) {
  $pngBytes += ,([System.IO.File]::ReadAllBytes($path))
}

$stream = [System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
try {
  $writer = New-Object System.IO.BinaryWriter($stream)
  try {
    $count = $sizes.Count

    # ICONDIR
    $writer.Write([UInt16]0) # reserved
    $writer.Write([UInt16]1) # type icon
    $writer.Write([UInt16]$count)

    $dataOffset = 6 + (16 * $count)

    for ($i = 0; $i -lt $count; $i++) {
      $size = $sizes[$i]
      $bytes = $pngBytes[$i]

      $dimByte = if ($size -ge 256) { 0 } else { [byte]$size }

      # ICONDIRENTRY (16 bytes)
      $writer.Write([byte]$dimByte)         # width
      $writer.Write([byte]$dimByte)         # height
      $writer.Write([byte]0)                # color count
      $writer.Write([byte]0)                # reserved
      $writer.Write([UInt16]1)              # planes
      $writer.Write([UInt16]32)             # bit count
      $writer.Write([UInt32]$bytes.Length)  # bytes in resource
      $writer.Write([UInt32]$dataOffset)    # image offset

      $dataOffset += $bytes.Length
    }

    for ($i = 0; $i -lt $count; $i++) {
      $writer.Write($pngBytes[$i])
    }
  }
  finally {
    $writer.Dispose()
  }
}
finally {
  $stream.Dispose()
}

# Verify ICO entries
$fs = [System.IO.File]::OpenRead($icoPath)
try {
  $br = New-Object System.IO.BinaryReader($fs)
  try {
    $reserved = $br.ReadUInt16()
    $type = $br.ReadUInt16()
    $entryCount = $br.ReadUInt16()

    if ($reserved -ne 0 -or $type -ne 1) {
      throw "favicon.ico no tiene una cabecera ICONDIR valida"
    }

    $embeddedSizes = @()
    for ($i = 0; $i -lt $entryCount; $i++) {
      $w = $br.ReadByte()
      $h = $br.ReadByte()
      [void]$br.ReadByte()
      [void]$br.ReadByte()
      [void]$br.ReadUInt16()
      [void]$br.ReadUInt16()
      [void]$br.ReadUInt32()
      [void]$br.ReadUInt32()

      $rw = if ($w -eq 0) { 256 } else { [int]$w }
      $rh = if ($h -eq 0) { 256 } else { [int]$h }
      $embeddedSizes += ("{0}x{1}" -f $rw, $rh)
    }

    $info = Get-Item -Path $icoPath
    Write-Output ("ICO generado: {0}" -f $icoPath)
    Write-Output ("Tamano bytes: {0}" -f $info.Length)
    Write-Output ("Entradas: {0}" -f ($embeddedSizes -join ", "))
  }
  finally {
    $br.Dispose()
  }
}
finally {
  $fs.Dispose()
}

Remove-Item -Path $tmpDir -Recurse -Force

$pngTargets = @(
  @{ Path = (Join-Path $publicDir "favicon-16x16.png"); Size = 16; Padding = 0.02 },
  @{ Path = (Join-Path $publicDir "favicon-32x32.png"); Size = 32; Padding = 0.02 },
  @{ Path = (Join-Path $publicDir "favicon-48x48.png"); Size = 48; Padding = 0.03 },
  @{ Path = (Join-Path $publicDir "apple-touch-icon.png"); Size = 180; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "apple-touch-icon-152x152.png"); Size = 152; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "apple-touch-icon-167x167.png"); Size = 167; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "android-chrome-192x192.png"); Size = 192; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "android-chrome-512x512.png"); Size = 512; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "icon-72.png"); Size = 72; Padding = 0.04 },
  @{ Path = (Join-Path $publicDir "icon-96.png"); Size = 96; Padding = 0.04 },
  @{ Path = (Join-Path $publicDir "icon-128.png"); Size = 128; Padding = 0.04 },
  @{ Path = (Join-Path $publicDir "icon-144.png"); Size = 144; Padding = 0.04 },
  @{ Path = (Join-Path $publicDir "icon-150.png"); Size = 150; Padding = 0.04 },
  @{ Path = (Join-Path $publicDir "icon-192.png"); Size = 192; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "icon-256.png"); Size = 256; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "icon-384.png"); Size = 384; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "icon-512.png"); Size = 512; Padding = 0.05 },
  @{ Path = (Join-Path $publicDir "mstile-150x150.png"); Size = 150; Padding = 0.04 }
)

foreach ($target in $pngTargets) {
  New-PaddedSquarePng -InputPath $sourcePath -OutputPath $target.Path -Size $target.Size -PaddingRatio $target.Padding
}

Write-Output "PNG generados para favicon, iOS, Android, PWA y Windows"
