Add-Type -AssemblyName System.Drawing
$srcImg = [System.Drawing.Image]::FromFile('C:\Proyectos\Proyecto Karryt\public\logo-karryt-oficial.png')
$targets = @(
    @{ Path = 'public\favicon-32x32.png'; Size = 32 },
    @{ Path = 'public\apple-touch-icon.png'; Size = 180 },
    @{ Path = 'public\icon-192.png'; Size = 192 },
    @{ Path = 'public\icon-512.png'; Size = 512 }
)
foreach ($target in $targets) {
    $bmp = New-Object System.Drawing.Bitmap($target.Size, $target.Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.SmoothingMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    $padding = [Math]::Max(1, [int]($target.Size * 0.09))
    $drawSize = $target.Size - (2 * $padding)
    $ratio = [Math]::Min($drawSize / $srcImg.Width, $drawSize / $srcImg.Height)
    $dw = [int]($srcImg.Width * $ratio); $dh = [int]($srcImg.Height * $ratio)
    $g.DrawImage($srcImg, [int](($target.Size - $dw) / 2), [int](($target.Size - $dh) / 2), $dw, $dh)
    $bmp.Save((Join-Path 'C:\Proyectos\Proyecto Karryt' $target.Path), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}
$srcImg.Dispose()
Get-ChildItem -Path public\favicon-32x32.png, public\apple-touch-icon.png, public\icon-192.png, public\icon-512.png | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    [PSCustomObject]@{ Path = $_.Name; Dimensions = "$($img.Width)x$($img.Height)"; Bytes = $_.Length }
    $img.Dispose()
} | Format-Table

