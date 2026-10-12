# ============================================
# Zstandard vs GZip vs Brotli 計測スクリプト（Windows / PowerShell）
#
# 使い方:
#   1) 別ウィンドウでアプリを起動
#        dotnet run --urls "http://localhost:5000"
#   2) このスクリプトを実行
#        .\measure.ps1
#        .\measure.ps1 -Port 5198 -Target medium
#
# 注意: PowerShell の curl は Invoke-WebRequest のエイリアスなので、
#       必ず curl.exe と拡張子まで指定すること。
# ============================================

param(
    [int]$Port = 5198,
    [ValidateSet("small", "medium", "large")]
    [string]$Target = "large",
    [int]$Trials = 5
)

$Url = "http://localhost:$Port/api/products/$Target"

# --- 前提チェック ---------------------------------------------------------
if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Write-Host "curl.exe が見つかりません。" -ForegroundColor Red
    Write-Host "Windows 10 1803 以降なら C:\Windows\System32\curl.exe にあります。" -ForegroundColor Yellow
    exit 1
}

$probe = & curl.exe -s -o NUL -w "%{http_code}" --max-time 10 $Url 2>$null
if ($probe -ne "200") {
    Write-Host "$Url に接続できません (HTTP $probe)" -ForegroundColor Red
    Write-Host "アプリが起動しているか、ポート番号が合っているか確認してください。" -ForegroundColor Yellow
    Write-Host "  dotnet run --urls `"http://localhost:$Port`"" -ForegroundColor Yellow
    exit 1
}

# --- 表示幅（全角=2, 半角=1）----------------------------------------------
# -f の {0,-12} は全角を1幅と数えるため自前で算出する
function Get-DispWidth([string]$s) {
    $w = 0
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        if (($c -ge 0x1100 -and $c -le 0x115F) -or
            ($c -ge 0x2E80 -and $c -le 0xA4CF) -or
            ($c -ge 0xAC00 -and $c -le 0xD7A3) -or
            ($c -ge 0xF900 -and $c -le 0xFAFF) -or
            ($c -ge 0xFE30 -and $c -le 0xFE6F) -or
            ($c -ge 0xFF00 -and $c -le 0xFF60) -or
            ($c -ge 0xFFE0 -and $c -le 0xFFE6)) { $w += 2 } else { $w += 1 }
    }
    return $w
}
function PadR([string]$s, [int]$n) { $s + (' ' * [Math]::Max(0, $n - (Get-DispWidth $s))) }
function PadL([string]$s, [int]$n) { (' ' * [Math]::Max(0, $n - (Get-DispWidth $s))) + $s }
function Format-Row($a, $b, $c, $d, $e) {
    "{0} {1} {2} {3} {4}" -f (PadR $a 11), (PadL $b 12), (PadL $c 9), (PadL $d 10), (PadL $e 12)
}

# --- 1回の計測 ------------------------------------------------------------
# -D - でレスポンスヘッダーも同時に取る。
# HEAD(-I) だと ASP.NET Core がボディなしのため圧縮せず、
# Content-Encoding が出ないので必ず GET で見ること。
function Invoke-Probe([string]$header) {
    $raw = (& curl.exe -s -o NUL -D - `
                -H "Accept-Encoding: $header" `
                -w "`nMETRICS %{size_download} %{time_total}" `
                $Url) -join "`n"

    $m = [regex]::Match($raw, 'METRICS\s+(\d+)\s+([\d.]+)')
    $e = [regex]::Match($raw, '(?im)^\s*content-encoding:\s*(\S+)\s*$')

    [pscustomobject]@{
        Bytes    = [int]$m.Groups[1].Value
        Ms       = [double]$m.Groups[2].Value * 1000
        Encoding = if ($e.Success) { $e.Groups[1].Value } else { "なし" }
    }
}

# --- 計測 -----------------------------------------------------------------
$encodings = @(
    @{ Name = "圧縮なし";  Header = "identity" },
    @{ Name = "GZip";      Header = "gzip"     },
    @{ Name = "Brotli";    Header = "br"       },
    @{ Name = "Zstandard"; Header = "zstd"     }
)

Write-Host ""
Write-Host "対象: $Url  （${Trials}回の中央値）" -ForegroundColor Cyan
Write-Host ("=" * 64)
Write-Host (Format-Row "方式" "サイズ" "圧縮率" "時間(ms)" "Encoding")
Write-Host ("-" * 64)

$baseline = 0

foreach ($enc in $encodings) {
    # ウォームアップ（JIT の影響を除く）
    Invoke-Probe $enc.Header | Out-Null

    $times = New-Object System.Collections.Generic.List[double]
    $bytes = 0
    $applied = "なし"

    for ($i = 0; $i -lt $Trials; $i++) {
        $r = Invoke-Probe $enc.Header
        $times.Add($r.Ms)
        $bytes   = $r.Bytes
        $applied = $r.Encoding
    }

    $sorted = $times | Sort-Object
    $median = $sorted[[int]($sorted.Count / 2)]

    if ($enc.Header -eq "identity") {
        $baseline = $bytes
        $ratio = "-"
    } elseif ($baseline -gt 0) {
        $ratio = "{0:N1}%" -f ($bytes / $baseline * 100)
    } else {
        $ratio = "-"
    }

    $sizeKb = "{0:N1} KB" -f ($bytes / 1KB)
    $ms     = "{0:N1}" -f $median
    $color  = if ($enc.Header -eq "zstd") { "Green" } else { "White" }

    Write-Host (Format-Row $enc.Name $sizeKb $ratio $ms $applied) -ForegroundColor $color
}

Write-Host ("=" * 64)
Write-Host ""