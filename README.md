# SkyOptimizer

**Branch de desenvolvimento — Fase 3C offline. Não distribuir como versão validada para clientes.**

O SkyOptimizer mantém o programa PowerShell existente, destinado a instalações Windows já em uso. O objetivo é melhorar desempenho real em jogos; ainda não foram medidos ganhos de FPS, 1% lows ou latência.

## Estado atual

- O catálogo conserva **90 IDs históricos**: 28 elegíveis para Apply, 56 bloqueados, manutenção 24 separada e cinco retirados (12/14/30/39/54). Migradas: **1, 3, 6, 8, 9, 13, 16, 17, 19, 20, 25, 38, 41, 42, 48, 58, 59, 60, 70, 71, 74, 75, 76, 79, 84, 86, 88 e 90**.
- As restantes ações ficam bloqueadas no dispatcher enquanto faltam baseline, reversão ou compatibilidade. As escritas indiscriminadas USB/HAGS/MSI foram retiradas; o catálogo regista as decisões.
- A ação 24 é manutenção de diagnóstico separada, com confirmação explícita. Não existe limpeza automática de shaders nos perfis.
- [Consolidação de políticas e integração 3C](docs/FASE3C.md), [auditoria histórica 3B](docs/FASE3B.md), [estado das ações](docs/ACOES-ESTADO.json), [Fase 3A](docs/FASE3A.md), [perfis](docs/PERFIS.md), [benchmarks](docs/BENCHMARKS.md) e [oportunidades](docs/OPORTUNIDADES.md).
- 14 foi consolidada em 58. 58/70/84 usam apenas políticas documentadas, com escopo, edição e build verificados. Não escrevem flags internas CDM. Tarefas de Windows/NVIDIA continuam bloqueadas; o mecanismo novo aceita apenas fixtures de laboratório.

## Perfis de desenvolvimento

| Perfil | Ações selecionadas | Compromisso |
|---|---|---|
| Gaming — Balanced | 79 | Configura Game Mode; pode já estar conforme. |
| Gaming — Performance | 9, 41, 79 | Acrescenta desativação de capturas e políticas de browsers em segundo plano. Perde essas funcionalidades. |
| Gaming — Extreme | Performance e IDs escolhidos | Experiências explícitas; ações ainda não migradas continuam bloqueadas. |

Não existem receitas automáticas por fabricante, CPU híbrido/X3D ou anti-cheat. Mudar de perfil não desfaz alterações anteriores: executar Undo e confirmar a baseline antes de comparar configurações.

## Backup e Undo

`mutation_state.json`, na pasta central `%SystemDrive%\ProgramData\SkyOptimizer\Backups`, guarda existência, tipo e conteúdo original de cada valor gerido. A intenção é persistida antes da alteração. Apply repetido conserva a baseline; Undo repetido não modifica recursos já restaurados. Valores inicialmente conformes não passam a pertencer ao programa. Conflitos externos são preservados e comunicados.

Energia usa `power_state.json` e uma cópia isolada do plano original. Serviços guardam arranque e execução separadamente. NIC exige identidade e versão do driver; a configuração persistida requer reinício e validação no hardware. Programa e painel partilham a lógica de reversão.

A identidade normalizada evita baselines duplicadas por ordem JSON ou maiúsculas no mesmo tipo de recurso. As novas políticas 58/70/84 usam ownership explícito no diário de formato 2; ações com o mesmo objetivo podem partilhar baseline e libertar referências por Undo parcial interno. Objetivos opostos são recusados. Os leitores atuais aceitam formatos 1/2; versões antigas recusam formato 2. Regenerar o painel e manter programa/painel na mesma versão. Não existe equivalência automática entre todos os tipos de recurso ou APIs.

Backups legados `.reg`/`previous_*` ficam intactos, sem inferir dados ausentes. Apply bloqueia uma nova baseline sobre estes ficheiros. Não existe garantia de reversão histórica integral. Chaves vazias podem permanecer; não são eliminadas árvores de registo. HKCU corresponde ao utilizador do processo elevado.

O programa tenta criar um ponto de restauro, que pode falhar e não substitui as baselines. O relatório distingue `Applied`, `AlreadyCompliant`, `Incompatible`, `Failed`, `Unverified`, `NotSelected` e `Deferred`. Configuração persistida não prova ganho de desempenho nem consumo pelo Windows/driver.

## Interface e painel

O menu existente mantém Apply, painel, inspeção, limpeza, Undo, reparação e saída. A opção 8 seleciona perfil e experiências.

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
.\SkyOptimizer.ps1 -Undo
.\SkyOptimizer.ps1 -DeployPanel
.\SkyOptimizer.ps1 -Audit
.\SkyOptimizer.ps1 -Clean
.\SkyOptimizer.ps1 -Repair
```

Apply e Undo conservam as confirmações do programa. A ação 3 inclui a dependência 1. `-Clean` exige confirmação e apaga caches sem possibilidade de Undo; recompilar shaders pode causar stuttering. `-Repair` é manutenção do Windows, não uma otimização de FPS. Verifica exit codes e devolve código 2 quando os resultados/logs ainda precisam de revisão; não certifica integridade apenas com exit code zero. Reparações DISM/SFC não têm Undo neste programa.

## Validação sem alterar Windows

```powershell
$r = Invoke-Pester -Script .\tests -PassThru
if ($r.FailedCount -gt 0) { exit 1 }
python -B -m unittest discover -s benchmarks/tests -v
```

Os testes PowerShell carregam declarações por AST e usam mocks/ficheiros temporários. Os testes Python usam intervalos sintéticos. O [analisador offline](benchmarks/analyze.py) lê CSV recolhido em laboratório; não executa tweaks nem captura jogos. Integração em Windows descartável e benchmarks físicos continuam necessários.

Última suite offline: **187 testes Pester e 11 Python aprovados**. O catálogo distingue implementação, cobertura automatizada e validação real. Nenhuma destas contagens demonstra FPS ou latência melhores.

O [protocolo de VM](docs/INTEGRACAO-VM.md) inclui o harness de registo com reinícios manuais, falhas intermédias e conflitos externos. O harness está preparado e testado com mocks; ainda não foi executado num guest real. Só o utilizar num Windows descartável com snapshot confirmado e autorização para alterações. A [preparação de tarefas 3C](docs/TAREFAS-LAB-3C.md) acrescenta fixtures isoladas, fingerprint e Enabled, sem allowlist de tarefas reais.

[Comunidade SkyOptimizer](https://discord.gg/cE8ZaDRGV5).
