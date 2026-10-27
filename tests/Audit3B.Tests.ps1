Describe 'Phase 3B audit remains a complete baseline record' {
    $audit = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\docs\AUDITORIA-3B.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    It 'contains every originally blocked ID exactly once' {
        $expected = @(2,4,5,7,10,11,12,14,15,16,18,21,22,23,26,27,28,29,30,31,32,33,34,35,36,37,40,43,44,45,46,47,49,50,51,52,53,54,55,56,57,58,59,61,62,63,64,65,66,67,68,69,70,72,73,77,78,80,81,82,83,84,85,87,88,89,90)
        (@($audit.Acoes.Id | Sort-Object) -join ',') | Should Be (($expected | Sort-Object) -join ',')
        @($audit.Acoes.Id | Select-Object -Unique).Count | Should Be $audit.QuantidadeBloqueadasInicial
        $audit.BaseCommit | Should Be '22def57'
    }
    It 'provides individual mechanism, risks, dependencies, rollback and baseline evidence without claiming real validation' {
        foreach ($record in $audit.Acoes) {
            foreach ($field in @('Mecanismo','Fundamento','ImpactoEsperado','Riscos','Dependencias','Reversibilidade','DecisaoOffline','Funcao')) {
                [string]::IsNullOrWhiteSpace($record.$field) | Should Be $false
            }
            ($record.LinhaBase -gt 0) | Should Be $true
            ($record.EvidenciaComandos.Count -gt 0) | Should Be $true
            ($record.Fontes.Count -gt 0) | Should Be $true
            $record.ValidacaoReal | Should Be 'Nao executada'
            $record.GanhoMedido | Should Be $false
        }
    }
}
