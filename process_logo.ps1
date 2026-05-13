Add-Type -AssemblyName System.Drawing
$srcPath = "C:\Proyectos\Proyecto Karryt\logo\BCO.f93f9b13-2cd3-4507-a89b-db3f375bd371.png"
$outPath = "C:\Proyectos\Proyecto Karryt\public\logo-karryt-silver-clean.png"

$src = New-Object System.Drawing.Bitmap($srcPath)
$wFull = $src.Width
$h = $src.Height
$roiW = [int]($wFull / 2)

$roi = New-Object System.Drawing.Bitmap($roiW, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gRoi = [System.Drawing.Graphics]::FromImage($roi)
$gRoi.DrawImage($src, (New-Object System.Drawing.Rectangle(0,0,$roiW,$h)), (New-Object System.Drawing.Rectangle(0,0,$roiW,$h)), [System.Drawing.GraphicsUnit]::Pixel)
$gRoi.Dispose()

# Usar un stack simple con ArrayList para evitar problemas de profundidad de recursión o tipos genéricos pesados en PS
$visited = New-Object "bool[,]" $roiW, $h
$stack = New-Object System.Collections.ArrayList

for ($x = 0; $x -lt $roiW; $x++) { 
    $null = $stack.Add((New-Object System.Drawing.Point($x, 0)))
    $null = $stack.Add((New-Object System.Drawing.Point($x, $h-1))) 
}
for ($y = 0; $y -lt $h; $y++) { 
    $null = $stack.Add((New-Object System.Drawing.Point(0, $y)))
    $null = $stack.Add((New-Object System.Drawing.Point($roiW-1, $y))) 
}

while ($stack.Count -gt 0) {
    $p = $stack[$stack.Count-1]
    $stack.RemoveAt($stack.Count-1)
    
    if ($p.X -lt 0 -or $p.X -ge $roiW -or $p.Y -lt 0 -or $p.Y -ge $h) { continue }
    if ($visited[$p.X, $p.Y]) { continue }
    
    $c = $roi.GetPixel($p.X, $p.Y)
    $maxRGB = [Math]::Max($c.R, [Math]::Max($c.G, $c.B))
    if ($maxRGB -lt 100) {
        $visited[$p.X, $p.Y] = $true
        $roi.SetPixel($p.X, $p.Y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        
        $null = $stack.Add((New-Object System.Drawing.Point($p.X+1, $p.Y)))
        $null = $stack.Add((New-Object System.Drawing.Point($p.X-1, $p.Y)))
        $null = $stack.Add((New-Object System.Drawing.Point($p.X, $p.Y+1)))
        $null = $stack.Add((New-Object System.Drawing.Point($p.X, $p.Y-1)))
    }
}

$minX = $roiW; $minY = $h; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $roiW; $x++) {
        if (-not $visited[$x, $y]) {
            $c = $roi.GetPixel($x, $y)
            $roi.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B))
            if ($x -lt $minX) { $minX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

$pad = 4
$cropX = [Math]::Max(0, $minX - $pad)
$cropY = [Math]::Max(0, $minY - $pad)
$cropW = [Math]::Min($roiW - $cropX, ($maxX - $minX + 1) + 2*$pad)
$cropH = [Math]::Min($h - $cropY, ($maxY - $minY + 1) + 2*$pad)

$final = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gFinal = [System.Drawing.Graphics]::FromImage($final)
$gFinal.DrawImage($roi, (New-Object System.Drawing.Rectangle(0,0,$cropW,$cropH)), (New-Object System.Drawing.Rectangle($cropX,$cropY,$cropW,$cropH)), [System.Drawing.GraphicsUnit]::Pixel)
$gFinal.Dispose()

$final.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

Write-Host "Fuente: $($wFull)x$h"
Write-Host "ROI: $($roiW)x$h"
Write-Host "Final: $($cropW)x$cropH"
Write-Host "Ok: $outPath"

$final.Dispose(); $roi.Dispose(); $src.Dispose()

