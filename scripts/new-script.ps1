<#
.SYNOPSIS
    Cria um novo repositório de script na org a partir do fivem-script-template.
    Pode ser executado de novo com o mesmo nome: retoma de onde parou.
.EXAMPLE
    .\new-script.ps1 -Name az-zombies -Description "Sistema de zumbis"
#>
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^az-[a-z0-9-]+$')]
    [string]$Name,

    [string]$Description = '',
    [string]$Org = 'Scripts-Zeus',
    [string]$Template = 'fivem-script-template',
    [string]$Destination = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$repo = "$Org/$Name"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# No PowerShell 5.1, qualquer saída em stderr de um executável nativo (ex.: progresso
# do git) vira erro fatal com ErrorActionPreference = 'Stop'. Estas funções isolam isso
# e decidem sucesso/falha apenas pelo exit code.
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments, [switch]$Quiet)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if (-not $Quiet -and $output) { $output | ForEach-Object { Write-Host "  $_" } }
    return @{ Ok = ($code -eq 0); Output = $output; Code = $code }
}

function Assert-Native {
    param([string]$Exe, [string[]]$Arguments)
    $r = Invoke-Native -Exe $Exe -Arguments $Arguments
    if (-not $r.Ok) { throw "$Exe $($Arguments -join ' ') falhou (exit $($r.Code))" }
    return $r
}

if ((Invoke-Native gh @('repo', 'view', $repo, '--json', 'name') -Quiet).Ok) {
    Write-Host "$repo já existe; continuando a partir da configuração."
} else {
    Write-Host "Criando $repo a partir de $Org/$Template..."
    Assert-Native gh @('repo', 'create', $repo, '--private', '--template', "$Org/$Template", '--description', $Description) | Out-Null
}

# A cópia do template é assíncrona no GitHub: aguarda os arquivos existirem.
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    if ((Invoke-Native gh @('api', "repos/$repo/contents/fxmanifest.lua", '--silent') -Quiet).Ok) { $ready = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw "Timeout aguardando o conteúdo do template em $repo" }

Write-Host 'Aplicando labels...'
$labels = Get-Content (Join-Path $PSScriptRoot 'labels.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$wanted = $labels | ForEach-Object { $_.name }
$list = Assert-Native gh @('label', 'list', '-R', $repo, '--limit', '100', '--json', 'name')
$existing = (($list.Output -join "`n") | ConvertFrom-Json) | ForEach-Object { $_.name }
foreach ($old in $existing) {
    if ($wanted -notcontains $old) { Assert-Native gh @('label', 'delete', $old, '-R', $repo, '--yes') | Out-Null }
}
foreach ($l in $labels) {
    Assert-Native gh @('label', 'create', $l.name, '--color', $l.color, '--description', $l.description, '-R', $repo, '--force') | Out-Null
}

$target = Join-Path $Destination $Name
if (Test-Path (Join-Path $target '.git')) {
    Write-Host "Clone já existe em $target."
} else {
    Write-Host 'Clonando...'
    Assert-Native gh @('repo', 'clone', $repo, $target) | Out-Null
}

Write-Host 'Renomeando o resource...'
$renameFiles = 'fxmanifest.lua', 'README.md', 'web/index.html', 'web/package.json', 'web/package-lock.json', 'web/src/lib/nui.ts'
foreach ($file in $renameFiles) {
    $path = Join-Path $target $file
    if (-not (Test-Path $path)) { continue }
    $content = [IO.File]::ReadAllText($path, $utf8).Replace('az-script-template', $Name)
    if ($file -eq 'fxmanifest.lua' -and $Description) {
        $content = $content -replace "(?m)^description '.*'$", "description '$($Description.Replace("'", "\'"))'"
    }
    [IO.File]::WriteAllText($path, $content, $utf8)
}

Assert-Native git @('-C', $target, 'add', '-A') | Out-Null
if ((Invoke-Native git @('-C', $target, 'diff', '--cached', '--quiet') -Quiet).Code -eq 1) {
    Assert-Native git @('-C', $target, 'commit', '-m', "chore: inicializa $Name a partir do template") | Out-Null
    Assert-Native git @('-C', $target, 'push') | Out-Null
}

Write-Host "Pronto: https://github.com/$repo  ->  $target" -ForegroundColor Green
