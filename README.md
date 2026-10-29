# SkyOptimizer

**Branch de desenvolvimento — Fase 5C — diagnóstico e contratos orientados pela investigação. Não distribuir como versão validada para clientes.**

O SkyOptimizer mantém o programa PowerShell existente, destinado a instalações Windows já em uso. O objetivo é melhorar desempenho real em jogos; ainda não foram medidos ganhos de FPS, 1% lows ou latência.

## Estado atual

- O catálogo conserva **90 IDs históricos**: 26 elegíveis para Apply, 58 bloqueados, manutenção 24 separada e cinco retirados (12/14/30/39/54). Elegíveis: **1, 3, 6, 8, 9, 13, 16, 17, 19, 20, 25, 38, 41, 42, 58, 59, 60, 70, 74, 75, 76, 79, 84, 86, 88 e 90**.
- As restantes ações ficam bloqueadas no dispatcher enquanto faltam baseline, reversão ou compatibilidade. As escritas indiscriminadas USB/HAGS/MSI foram retiradas; o catálogo regista as decisões.
- A ação 24 é manutenção de diagnóstico separada, com confirmação explícita. Não existe limpeza automática de shaders nos perfis.
- [Entrega da Fase 5C](docs/FASE5C.md): diagnóstico temporal offline, semântica de frametimes, seleção exata Laboratory e preview AppX. Ação 9 limitada ao contrato Windows 10 conhecido; grupos 48/71 suspensos; 49 continua bloqueada. Nenhuma nova ação desbloqueada.
- [Preparação final da Fase 5A](docs/FASE5A.md): instalação, recolha privada de evidências, comparação independente e gates de aceitação.
- [Auditoria global da Fase 4](docs/FASE4.md), [checklist de validação real](docs/VALIDACAO-FASE4.md), [maturidade histórica das 28 elegíveis](docs/FASE4-ELEGIVEIS.json) e [classificação histórica das 56 bloqueadas](docs/FASE4-BLOQUEADAS.json). Para o estado atual, consultar o catálogo e a Fase 5C.
- [Consolidação de políticas e integração 3C](docs/FASE3C.md), [auditoria histórica 3B](docs/FASE3B.md), [estado das ações](docs/ACOES-ESTADO.json), [Fase 3A](docs/FASE3A.md), [perfis](docs/PERFIS.md), [benchmarks](docs/BENCHMARKS.md) e [oportunidades](docs/OPORTUNIDADES.md).
- 14 foi consolidada em 58. 58/70/84 usam apenas políticas documentadas, com escopo, edição e build verificados. Não escrevem flags internas CDM. Tarefas de Windows/NVIDIA continuam bloqueadas; o mecanismo novo aceita apenas fixtures de laboratório.

## Perfis de desenvolvimento

| Perfil | Ações selecionadas | Compromisso |
|---|---|---|
| Gaming — Balanced | 79 | Configura Game Mode; pode já estar conforme. |
| Gaming — Performance | 9, 41, 79 | Acrescenta captura no contrato Windows 10 e políticas de browsers em segundo plano. Em Windows 11, 9 comunica Incompatible sem escrever. |
| Gaming — Extreme | Performance e IDs escolhidos | Experiências explícitas; ações ainda não migradas continuam bloqueadas. |
| Laboratory | Apenas IDs escolhidos e dependências | Sem herdar Performance. Exige seleção não vazia; 3/8 acrescentam 1. |

Não existem receitas automáticas por fabricante, CPU híbrido/X3D ou anti-cheat. Mudar de perfil não desfaz alterações anteriores: executar Undo e confirmar a baseline antes de comparar configurações.

## Backup e Undo

`mutation_state.json`, na pasta central `SkyOptimizer\Backups` sob a known folder `CommonApplicationData` (normalmente `%ProgramData%`), guarda existência, tipo e conteúdo original de cada valor gerido. A intenção é persistida antes da alteração. Apply repetido conserva a baseline; Undo repetido não modifica recursos já restaurados. Valores inicialmente conformes não passam a pertencer ao programa. Conflitos externos são preservados e comunicados.

Energia usa `power_state.json` e uma cópia isolada do plano original. Serviços guardam arranque e execução separadamente. NIC exige identidade e versão do driver; a configuração persistida requer reinício e validação no hardware. Programa e painel partilham a lógica de reversão. Undo de energia reativa o original, mas conserva cópias potencialmente alteradas externamente e comunica `Unverified`/código 2; a limpeza dessas cópias está pendente. NIC exige um único candidato após os filtros e comunica propriedades indisponíveis, incluindo aplicação parcial.

A identidade normalizada evita baselines duplicadas por ordem JSON ou maiúsculas no mesmo tipo de recurso. As novas políticas 58/70/84 usam ownership explícito no diário de formato 2; ações com o mesmo objetivo podem partilhar baseline e libertar referências por Undo parcial interno. Objetivos opostos são recusados. Os leitores atuais aceitam formatos 1/2; versões antigas recusam formato 2. Regenerar o painel e manter programa/painel na mesma versão. Não existe equivalência automática entre todos os tipos de recurso ou APIs.

Backups legados `.reg`/`previous_*` ficam intactos, sem inferir dados ausentes. Apply bloqueia uma nova baseline sobre estes ficheiros. Não existe garantia de reversão histórica integral. Chaves vazias podem permanecer; não são eliminadas árvores de registo. HKCU corresponde ao utilizador do processo elevado.

O programa tenta criar um ponto de restauro, que pode falhar e não substitui as baselines. O relatório distingue `Applied`, `AlreadyCompliant`, `Incompatible`, `Failed`, `Unverified`, `NotSelected` e `Deferred`. Configuração persistida não prova ganho de desempenho nem consumo pelo Windows/driver.

O armazenamento valida proprietário, DACL e ausência de reparse points antes de usar dados elevados. Recusa instalações antigas inseguras sem alterar ACL ou adotar backups automaticamente. Não apagar backups para ultrapassar a recusa. Novos diretórios usam DACL protegida; integração NTFS/UAC real continua pendente. Logs ficam em `SkyOptimizer\Logs` sob a mesma pasta central.

## Interface e painel

O menu existente mantém Apply, painel, inspeção, limpeza, Undo, reparação e saída. A opção 8 seleciona perfil e experiências. A opção 9 mostra o preview AppX da conta do processo elevado: dependências, componentes protegidos e metadados desconhecidos. Nenhum pacote fica autorizado para remoção; não é inventário de todas as contas nem do provisionamento.

Programa e painel usam um lock comum de sessão. Fechar o programa principal antes de abrir o painel autónomo. Regenerar o painel na mesma versão; painéis já instalados não recebem correções retroativas. Launchers aguardam a elevação e propagam o código de saída. O reinício automático global do Explorer está suspenso.

O painel mantém os atalhos:

- **Reverter:** restaura apenas recursos com baseline verificável; preserva backups e conflitos.
- **Impressora/Bluetooth:** desativa o serviço ou restaura a baseline própria. Não inventa um modo de arranque para serviços originalmente desativados.
- **VBS/localização:** os controlos antigos estão suspensos. Localização aplicada pela ação 86 pode ser restaurada pelo Undo geral.
- **Shaders:** explica por que a limpeza automática está suspensa. A manutenção de diagnóstico continua no programa principal.
- **Relatório:** snapshots de configuração, processos, RAM e disco. Não é um benchmark nem uma certificação de compatibilidade com anti-cheat.

## Utilização em laboratório

Requer Windows PowerShell 5.1. Não executar estes comandos no computador de desenvolvimento durante a validação de código.

```powershell
.\SkyOptimizer.ps1
.\SkyOptimizer.ps1 -Apply -Profile Balanced
.\SkyOptimizer.ps1 -Apply -Profile Performance
.\SkyOptimizer.ps1 -Apply -Profile Extreme -ExperimentalActions "3,42"
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "41,79"
.\SkyOptimizer.ps1 -Undo
.\SkyOptimizer.ps1 -DeployPanel
.\SkyOptimizer.ps1 -Audit
.\SkyOptimizer.ps1 -Clean
.\SkyOptimizer.ps1 -Repair
```

Apply e Undo conservam as confirmações do programa. A ação 3 inclui a dependência 1. `-Clean` exige confirmação e apaga caches sem possibilidade de Undo; recompilar shaders pode causar stuttering. `-Repair` é manutenção do Windows, não uma otimização de FPS. Verifica exit codes e devolve código 2 quando os resultados/logs ainda precisam de revisão; não certifica integridade apenas com exit code zero. Reparações DISM/SFC não têm Undo neste programa.

## Validação sem alterar Windows

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command '$r = Invoke-Pester -Script .\tests -PassThru; if ($r.FailedCount -gt 0) { exit 1 }'
python -B -m unittest discover -s benchmarks/tests -v
```

Os testes PowerShell carregam declarações por AST e usam mocks/ficheiros temporários. O comando fixa Windows PowerShell 5.1; a política Bypass aplica-se apenas ao processo. Pester 3.4 não foi validado em PowerShell 7. Os testes Python usam dados sintéticos. O [analisador offline](benchmarks/analyze.py) lê CSV com manifesto de formato 2 e semântica explícita; o [diagnóstico temporal](benchmarks/diagnose.py) importa amostras anónimas de CPU, memória e I/O. Ambos são ferramentas offline: não recolhem jogos nem alteram Windows. Integração em Windows descartável e benchmarks físicos continuam necessários.

Última suite offline: **232 testes Pester e 19 Python aprovados**. O catálogo distingue implementação, cobertura automatizada e validação real. Nenhuma destas contagens demonstra FPS ou latência melhores.

A [prova detalhada Pester](docs/FASE5C-TESTES.json) identifica o código testado. Nenhuma ação foi desbloqueada nesta fase.

O [protocolo de VM](docs/INTEGRACAO-VM.md) inclui o harness de registo com reinícios manuais, falhas intermédias e conflitos externos. O harness está preparado e testado com mocks; ainda não foi executado num guest real. Só o utilizar num Windows descartável com snapshot confirmado e autorização para alterações. A [preparação de tarefas 3C](docs/TAREFAS-LAB-3C.md) acrescenta fixtures isoladas, fingerprint e Enabled, sem allowlist de tarefas reais.

[Comunidade SkyOptimizer](https://discord.gg/cE8ZaDRGV5).
