. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Catalogue and dispatcher agree without executing action bodies' {
    $catalogue = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\docs\ACOES-ESTADO.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '..\SkyOptimizer.ps1'), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Product source does not parse.' }
    $assignment = $ast.Find({ param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$tweaks'
    }, $true)
    $rows = @($assignment.Right.FindAll({ param($node) $node -is [Management.Automation.Language.HashtableAst] }, $true) | ForEach-Object {
        $row = @{}
        foreach ($pair in $_.KeyValuePairs) {
            $key = $pair.Item1.Value
            if ($key -in @('Id','Name')) { $row[$key] = $pair.Item2.PipelineElements[0].Expression.SafeGetValue() }
            if ($key -eq 'Action') {
                $command = $pair.Item2.Find({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)
                $row.Function = $command.GetCommandName()
            }
        }
        [pscustomobject]$row
    })
    Mock Get-SkyWindowsBuild { 22631 }
    Mock Invoke-SkyNativeProcess { throw 'Structural tests must not execute Windows commands.' }
    It 'keeps historical IDs unique and maps names/functions to the existing menu declarations' {
        $catalogue.Count | Should Be $rows.Count
        @($catalogue.Id | Select-Object -Unique).Count | Should Be $catalogue.Count
        @($rows.Id | Select-Object -Unique).Count | Should Be $rows.Count
        foreach ($row in $rows) {
            $record = @($catalogue | Where-Object Id -eq $row.Id)
            $record.Count | Should Be 1
            $record[0].Nome | Should Be $row.Name
            $record[0].Funcao | Should Be $row.Function
            ($null -ne (Get-Command $row.Function -CommandType Function -ErrorAction Stop)) | Should Be $true
        }
    }
    It 'matches eligible and retired IDs with dispatcher gates and never claims measured gains' {
        (@($catalogue | Where-Object ElegivelApply | ForEach-Object Id | Sort-Object) -join ',') | Should Be ((Get-SkyMigratedActionIds | Sort-Object) -join ',')
        (@($catalogue | Where-Object Retirada | ForEach-Object Id | Sort-Object) -join ',') | Should Be ((Get-SkyRetiredActionIds | Sort-Object) -join ',')
        @($catalogue | Where-Object { $_.Retirada -and $_.ElegivelApply }).Count | Should Be 0
        @($catalogue | Where-Object GanhoMedido).Count | Should Be 0
    }
    It 'quarantines every selected unmigrated or retired action before reaching its body' {
        foreach ($record in $catalogue | Where-Object { -not $_.ElegivelApply }) {
            (Invoke-SkyEligibleAction -Id $record.Id -SelectedIds @($record.Id) -Action { throw 'Blocked body must not execute.' }).Status | Should Be Deferred
        }
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
}
