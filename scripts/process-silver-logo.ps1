Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root "logo\BCO.f93f9b13-2cd3-4507-a89b-db3f375bd371.png"
$outputPath = Join-Path $root "public\logo-karryt-silver-clean.png"

if (-not (Test-Path $sourcePath)) {
  throw "No se encontro el archivo fuente: $sourcePath"
}

$src = [System.Drawing.Bitmap]::new($sourcePath)
try {
  # El archivo fuente es un collage 2-paneles; usamos el panel izquierdo.
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

    $mask = New-Object "bool[,]" $roiW, $roiH

    for ($y = 0; $y -lt $roiH; $y++) {
      for ($x = 0; $x -lt $roiW; $x++) {
        $c = $roi.GetPixel($x, $y)
        $maxRGB = [Math]::Max([int]$c.R, [Math]::Max([int]$c.G, [int]$c.B))
        $minRGB = [Math]::Min([int]$c.R, [Math]::Min([int]$c.G, [int]$c.B))
        $sat = $maxRGB - $minRGB

        # Plata/blanco del texto
        $isSilver = ($maxRGB -ge 120) -and ($sat -le 95)

        # Azul del trazo inferior
        $isBlue = ($c.B -ge 85) -and ($c.B -ge ($c.R + 20)) -and ($c.B -ge ($c.G + 10))

        # Blanco intenso (reflejos y linea punteada)
        $isBrightWhite = ($c.R -ge 170) -and ($c.G -ge 170) -and ($c.B -ge 170)

        if ($isSilver -or $isBlue -or $isBrightWhite) {
          $mask[$x, $y] = $true
        }
      }
    }

    $labels = New-Object "int[,]" $roiW, $roiH
    $componentId = 0
    $componentStats = @{}

    for ($y = 0; $y -lt $roiH; $y++) {
      for ($x = 0; $x -lt $roiW; $x++) {
        if (-not $mask[$x, $y]) { continue }
        if ($labels[$x, $y] -ne 0) { continue }

        $componentId++
        $count = 0
        $touchesBorder = $false
        $q = New-Object "System.Collections.Generic.Queue[System.Drawing.Point]"
        $q.Enqueue([System.Drawing.Point]::new($x, $y))

        while ($q.Count -gt 0) {
          $p = $q.Dequeue()
          $px = $p.X
          $py = $p.Y

          if ($px -lt 0 -or $px -ge $roiW -or $py -lt 0 -or $py -ge $roiH) { continue }
          if ($labels[$px, $py] -ne 0) { continue }
          if (-not $mask[$px, $py]) { continue }

          $labels[$px, $py] = $componentId
          $count++

          if ($px -eq 0 -or $py -eq 0 -or $px -eq ($roiW - 1) -or $py -eq ($roiH - 1)) {
            $touchesBorder = $true
          }

          $q.Enqueue([System.Drawing.Point]::new($px + 1, $py))
          $q.Enqueue([System.Drawing.Point]::new($px - 1, $py))
          $q.Enqueue([System.Drawing.Point]::new($px, $py + 1))
          $q.Enqueue([System.Drawing.Point]::new($px, $py - 1))
        }

        $componentStats[$componentId] = @{
          Count = $count
          TouchesBorder = $touchesBorder
        }
      }
    }

    $keepIds = @{}
    foreach ($key in $componentStats.Keys) {
      $stats = $componentStats[$key]
      if (-not $stats.TouchesBorder -and $stats.Count -ge 400) {
        $keepIds[[int]$key] = $true
      }
    }

    if ($keepIds.Count -eq 0) {
      $bestId = 0
      $bestCount = 0
      foreach ($key in $componentStats.Keys) {
        $stats = $componentStats[$key]
        if ($stats.Count -gt $bestCount) {
          $bestCount = $stats.Count
          $bestId = [int]$key
        }
      }
      if ($bestId -eq 0) {
        throw "No se detecto un componente de logo valido"
      }
      $keepIds[$bestId] = $true
    }

    $minX = $roiW
    $minY = $roiH
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $roiH; $y++) {
      for ($x = 0; $x -lt $roiW; $x++) {
        $c = $roi.GetPixel($x, $y)
        $labelValue = [int]$labels[$x, $y]
        if ($keepIds.ContainsKey($labelValue)) {
          $roi.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B))
          if ($x -lt $minX) { $minX = $x }
          if ($y -lt $minY) { $minY = $y }
          if ($x -gt $maxX) { $maxX = $x }
          if ($y -gt $maxY) { $maxY = $y }
        } else {
          $roi.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        }
      }
    }

    if ($maxX -lt 0 -or $maxY -lt 0) {
      throw "No se pudo detectar el logo util para recortar"
    }

    $pad = 3
    $cropX = [Math]::Max(0, $minX - $pad)
    $cropY = [Math]::Max(0, $minY - $pad)
    $cropW = [Math]::Min($roiW - $cropX, ($maxX - $minX + 1) + (2 * $pad))
    $cropH = [Math]::Min($roiH - $cropY, ($maxY - $minY + 1) + (2 * $pad))

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

Write-Output ("Logo procesado: {0}" -f $outputPath)