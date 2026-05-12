Add-Type -AssemblyName System.Drawing
$logoSilver = Join-Path (Get-Location) "public\logo-karryt-silver-clean.png"
$logoBCO = Join-Path (Get-Location) "logo\BCO.f93f9b13-2cd3-4507-a89b-db3f375bd371.png"
if (Test-Path $logoSilver) {
    $bmp = New-Object System.Drawing.Bitmap($logoSilver)
    $alpha = 0; $minX=$bmp.Width; $maxX=0; $minY=$bmp.Height; $maxY=0
    for($y=0;$y -lt $bmp.Height;$y++){for($x=0;$x -lt $bmp.Width;$x++){
        $p=$bmp.GetPixel($x,$y); if($p.A -gt 0){$alpha++; if($x -lt $minX){$minX=$x} if($x -gt $maxX){$maxX=$x} if($y -lt $minY){$minY=$y} if($y -gt $maxY){$maxY=$y}}
    }}
    Write-Output "SILVER: Total=$($bmp.Width*$bmp.Height), Alpha=$alpha, BBox=[$minX,$minY] to [$maxX,$maxY]"
    $bmp.Dispose()
}
if (Test-Path $logoBCO) {
    $bmp = New-Object System.Drawing.Bitmap($logoBCO)
    $c1=$bmp.GetPixel(0,0); $c2=$bmp.GetPixel(0,$bmp.Height-1); $c3=$bmp.GetPixel([int]($bmp.Width/4),[int]($bmp.Height/2))
    Write-Output "BCO: TL=($($c1.A),$($c1.R),$($c1.G),$($c1.B)), BL=($($c2.A),$($c2.R),$($c2.G),$($c2.B)), CL=($($c3.A),$($c3.R),$($c3.G),$($c3.B))"
    $bmp.Dispose()
}
