Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root "logo\BCO.f93f9b13-2cd3-4507-a89b-db3f375bd371.png"
$outputPath = Join-Path $root "public\logo-karryt-silver-banner.png"

if (-not (Test-Path $sourcePath)) {
  throw "No se encontro el archivo fuente: $sourcePath"
}

$src = [System.Drawing.Bitmap]::new($sourcePath)
try {
  $roiW = [int][Math]::Floor($src.Width / 2)
  $roiH = $src.Height

  $roi = [System.Drawing.Bitmap]::new($roiW, $roiH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $g = [System.Drawing.Graphics]::FromImage($roi)
    try {
      $g.DrawImage(
        $src,
        [System.Drawing.Rectangle]::new(0, 0, $roiW, $roiH),
        [System.Drawing.Rectangle]::new(0, 0, $roiW, $roiH),
        [System.Drawing.GraphicsUnit]::Pixel
      )
    }
    finally {
      $g.Dispose()
    }

    $minX = $roiW
    $minY = $roiH
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $roiH; $y++) {
      for ($x = 0; $x -lt $roiW; $x++) {
        $c = $roi.GetPixel($x, $y)
        $maxRgb = [Math]::Max([int]$c.R, [Math]::Max([int]$c.G, [int]$c.B))
        $isBlueAccent = ($c.B -ge 80) -and ($c.B -ge ($c.R + 20))
        $isLogoPixel = ($maxRgb -ge 95) -or $isBlueAccent

        if ($isLogoPixel) {
          if ($x -lt $minX) { $minX = $x }
          if ($y -lt $minY) { $minY = $y }
          if ($x -gt $maxX) { $maxX = $x }
          if ($y -gt $maxY) { $maxY = $y }
        }
      }
    }

    if ($maxX -lt 0 -or $maxY -lt 0) {
      throw "No se detecto zona de logo en la imagen fuente"
    }

    $padX = 28
    $padY = 26

    $cropX = [Math]::Max(0, $minX - $padX)
    $cropY = [Math]::Max(0, $minY - $padY)
    $cropW = [Math]::Min($roiW - $cropX, ($maxX - $minX + 1) + (2 * $padX))
    $cropH = [Math]::Min($roiH - $cropY, ($maxY - $minY + 1) + (2 * $padY))

    $final = [System.Drawing.Bitmap]::new($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $gf = [System.Drawing.Graphics]::FromImage($final)
      try {
        $gf.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gf.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $gf.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $gf.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        $gf.DrawImage(
          $roi,
          [System.Drawing.Rectangle]::new(0, 0, $cropW, $cropH),
          [System.Drawing.Rectangle]::new($cropX, $cropY, $cropW, $cropH),
          [System.Drawing.GraphicsUnit]::Pixel
        )
      }
      finally {
        $gf.Dispose()
      }

      $final.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
      $final.Dispose()
    }
  }
  finally {
    $roi.Dispose()
  }
}
finally {
  $src.Dispose()
}

Write-Output ("Banner logo generado: {0}" -f $outputPath)