# Load declarations only. Never dot-source the application entry point in tests.
param([string]$SourcePath = (Join-Path $PSScriptRoot '..\SkyOptimizer.ps1'))
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path -LiteralPath $SourcePath).Path, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$definitions = $ast.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
}, $false)
. ([scriptblock]::Create(($definitions | ForEach-Object { $_.Extent.Text }) -join "`r`n"))
