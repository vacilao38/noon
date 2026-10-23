$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$appRoot = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Path (Join-Path $appRoot 'artifacts') -Force | Out-Null
$bitmap = [System.Drawing.Bitmap]::new(256, 256)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(18, 19, 19))
$pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(233, 197, 135), 14)
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawArc($pen, 54, 58, 148, 148, 180, 180)
$graphics.DrawLine($pen, 38, 156, 218, 156)
$heights = @(8, 24, 42, 24, 8)
for ($index = 0; $index -lt 5; $index++) {
    $x = 72 + 28 * $index
    $graphics.DrawLine($pen, $x, 186, $x, 186 + $heights[$index])
}
$memory = [System.IO.MemoryStream]::new()
$bitmap.Save($memory, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $memory.ToArray()
$stream = [System.IO.File]::Create((Join-Path $appRoot 'windows/runner/resources/app_icon.ico'))
$writer = [System.IO.BinaryWriter]::new($stream)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
$writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
$writer.Write([uint16]1); $writer.Write([uint16]32)
$writer.Write([uint32]$pngBytes.Length); $writer.Write([uint32]22); $writer.Write($pngBytes)
$writer.Dispose()
foreach ($density in @(@('mdpi',48), @('hdpi',72), @('xhdpi',96), @('xxhdpi',144), @('xxxhdpi',192))) {
    $directory = Join-Path $appRoot "android/app/src/main/res/mipmap-$($density[0])"
    $scaled = [System.Drawing.Bitmap]::new($bitmap, [int]$density[1], [int]$density[1])
    $scaled.Save((Join-Path $directory 'ic_launcher.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $scaled.Dispose()
}
$bitmap.Save((Join-Path $appRoot 'artifacts/noon-icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose(); $memory.Dispose()
