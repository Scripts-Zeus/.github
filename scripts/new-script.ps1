<#
.SYNOPSIS
    Cria um novo repositório de script na org a partir do fivem-script-template.
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

function Invoke-Gh {
    & gh @args
    if ($LASTEXITCODE -ne 0) { throw "gh $($args -join ' ') falhou (exit $LASTEXITCODE)" }
}

Write-Host "Criando $repo a partir de $Org/$Template..."
Invoke-Gh repo create $repo --private --template "$Org/$Template" --description $Description

# A cópia do template é assíncrona no GitHub: aguarda os arquivos existirem.
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    & gh api "repos/$repo/contents/fxmanifest.lua" --silent 2>$null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw "Timeout aguardando o conteúdo do template em $repo" }

Write-Host 'Aplicando labels...'
$labels = Get-Content (Join-Path $PSScriptRoot 'labels.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$wanted = $labels | ForEach-Object { $_.name }
$existing = ((& gh label list -R $repo --limit 100 --json name) -join "`n" | ConvertFrom-Json) | ForEach-Object { $_.name }
foreach ($old in $existing) {
    if ($wanted -notcontains $old) { Invoke-Gh label delete $old -R $repo --yes }
}
foreach ($l in $labels) {
    Invoke-Gh label create $l.name --color $l.color --description $l.description -R $repo --force
}

Write-Host 'Clonando e renomeando o resource...'
$target = Join-Path $Destination $Name
Invoke-Gh repo clone $repo $target

foreach ($file in 'fxmanifest.lua', 'README.md') {
    $path = Join-Path $target $file
    $content = [IO.File]::ReadAllText($path, $utf8).Replace('az-script-template', $Name)
    if ($file -eq 'fxmanifest.lua' -and $Description) {
        $content = $content -replace "(?m)^description '.*'$", "description '$($Description.Replace("'", "\'"))'"
    }
    [IO.File]::WriteAllText($path, $content, $utf8)
}

git -C $target add -A
git -C $target commit -m "chore: inicializa $Name a partir do template"
git -C $target push
if ($LASTEXITCODE -ne 0) { throw 'git push falhou' }

Write-Host "Pronto: https://github.com/$repo  ->  $target" -ForegroundColor Green
