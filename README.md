# SkyOptimizer MAX

**Branch de desenvolvimento — Fase 5F — inventário profundo, CPU Sets e contratos seletivos de laboratório. Não distribuir como versão validada para clientes.**

O SkyOptimizer mantém o programa PowerShell existente, destinado a instalações Windows já em uso. O objetivo é melhorar desempenho real em jogos; ainda não foram medidos ganhos de FPS, 1% lows ou latência.

## Estado atual

- O catálogo conserva **90 IDs históricos**: 26 elegíveis para Apply, 58 bloqueados, manutenção 24 separada e cinco retirados (12/14/30/39/54). Elegíveis: **1, 3, 6, 8, 9, 13, 16, 17, 19, 20, 25, 38, 41, 42, 58, 59, 60, 70, 74, 75, 76, 79, 84, 86, 88 e 90**.
- As restantes ações ficam bloqueadas no dispatcher enquanto faltam baseline, reversão ou compatibilidade. As escritas indiscriminadas USB/HAGS/MSI foram retiradas; o catálogo regista as decisões.
- A ação 24 é manutenção de diagnóstico separada, com confirmação explícita. Não existe limpeza automática de shaders nos perfis.
- [Entrega da Fase 5F](docs/FASE5F.md): inventário por categorias, motivos individuais das 26 elegíveis, diagnóstico CPU Sets/commit/I/O e contrato de background News/Weather restrito a laboratório. Sem ganhos medidos; missão MAX continua parcial.
- [Entrega da Fase 5E](docs/FASE5E.md): MAX por omissão, plano automático condicionado a Windows/software/gestão, comandos de leitura e contratos reversíveis de arranque Spotify/Steam. Sete IDs podem entrar no plano, conforme compatibilidade; não são todos aplicados universalmente. Nenhum ganho medido.
- [Entrega da Fase 5D](docs/FASE5D.md): adaptador autorizado PresentMon, coletor de processos, normalização rastreável, comparação por pares/blocos e relatórios. Percurso validado com dados sintéticos; captura real e overhead ainda por testar.
- [Entrega da Fase 5C](docs/FASE5C.md): diagnóstico temporal offline, semântica de frametimes, seleção exata Laboratory e preview AppX. Ação 9 limitada ao contrato Windows 10 conhecido; grupos 48/71 suspensos; 49 continua bloqueada. Nenhuma nova ação desbloqueada.
- [Preparação final da Fase 5A](docs/FASE5A.md): instalação, recolha privada de evidências, comparação independente e gates de aceitação.
- [Auditoria global da Fase 4](docs/FASE4.md), [checklist de validação real](docs/VALIDACAO-FASE4.md), [maturidade histórica das 28 elegíveis](docs/FASE4-ELEGIVEIS.json) e [classificação histórica das 56 bloqueadas](docs/FASE4-BLOQUEADAS.json). Para o estado atual, consultar o catálogo e a Fase 5E.
- [Consolidação de políticas e integração 3C](docs/FASE3C.md), [auditoria histórica 3B](docs/FASE3B.md), [estado das ações](docs/ACOES-ESTADO.json), [Fase 3A](docs/FASE3A.md), [perfis](docs/PERFIS.md), [benchmarks](docs/BENCHMARKS.md) e [oportunidades](docs/OPORTUNIDADES.md).
- 14 foi consolidada em 58. 58/70/84 usam apenas políticas documentadas, com escopo, edição e build verificados. Não escrevem flags internas CDM. Tarefas de Windows/NVIDIA continuam bloqueadas; o mecanismo novo aceita apenas fixtures de laboratório.

## Modo MAX e comandos técnicos

Sem parâmetros ou com `-Apply`, o programa prepara MAX: apresenta decisões, confirma impactos funcionais quando necessários, reutiliza Apply/Undo existentes e termina. Não instala painel, serviço, tarefa ou monitor residente. O BAT existente termina com o mesmo código de saída; não foi criado outro launcher.

MAX pode selecionar 9/16/41/58/70/79/84 segundo Windows, edição, browsers e indicadores de gestão. Em Windows 11 Pro com Edge, a seleção é 16/41/70/79; captura Windows 11 e experiências de hardware ficam fora. Em sistemas geridos ou com gestão desconhecida, a seleção automática limita-se a Game Mode quando o Windows é conhecido. Ausência de indicadores não prova ausência de gestão: o operador deve confirmar essa condição.

`-DryRun` devolve o plano JSON. `-Diagnose` acrescenta hardware/CPU Sets, commit/I/O e inventário. Ambos evitam inicializar armazenamento ou elevar automaticamente. A conta elevada pode ter contexto diferente; Apply prepara e revalida o próprio plano. `-DebloatPreview` devolve schema 2 com AppX atual, provisionamento, software/OEM, arranque, serviços, tarefas, features, processos e plano de background seletivo. Não executa desinstalações. O controlo de arranque só remove valores HKCU Run exatos de Spotify/Steam após verificar comando, assinatura e identidade; não termina processos nem desinstala aplicações.

Laboratory conserva IDs explícitos e dependências para experiências isoladas. Balanced/Performance/Extreme permanecem aliases técnicos de compatibilidade, fora da experiência comercial. Não existem receitas automáticas por fabricante, CPU híbrido/X3D ou anti-cheat. Mudar a seleção não desfaz alterações anteriores: executar Undo e confirmar a baseline antes de comparar configurações. Ver [condições e compatibilidade](docs/PERFIS.md).

## Backup e Undo

`mutation_state.json`, na pasta central `SkyOptimizer\Backups` sob a known folder `CommonApplicationData` (normalmente `%ProgramData%`), guarda existência, tipo e conteúdo original de cada valor gerido. A intenção é persistida antes da alteração. Apply repetido conserva a baseline; Undo repetido não modifica recursos já restaurados. Valores inicialmente conformes não passam a pertencer ao programa. Conflitos externos são preservados e comunicados.

Energia usa `power_state.json` e uma cópia isolada do plano original. Serviços guardam arranque e execução separadamente. NIC exige identidade e versão do driver; a configuração persistida requer reinício e validação no hardware. Programa e painel partilham a lógica de reversão. Undo de energia reativa o original, mas conserva cópias potencialmente alteradas externamente e comunica `Unverified`/código 2; a limpeza dessas cópias está pendente. NIC exige um único candidato após os filtros e comunica propriedades indisponíveis, incluindo aplicação parcial.

A identidade normalizada evita baselines duplicadas por ordem JSON ou maiúsculas no mesmo tipo de recurso. As novas políticas 58/70/84 usam ownership explícito no diário de formato 2; ações com o mesmo objetivo podem partilhar baseline e libertar referências por Undo parcial interno. Objetivos opostos são recusados. Os leitores atuais aceitam formatos 1/2; versões antigas recusam formato 2. Regenerar o painel e manter programa/painel na mesma versão. Não existe equivalência automática entre todos os tipos de recurso ou APIs.

Backups legados `.reg`/`previous_*` ficam intactos, sem inferir dados ausentes. Apply bloqueia uma nova baseline sobre estes ficheiros. Não existe garantia de reversão histórica integral. Chaves vazias podem permanecer; não são eliminadas árvores de registo. HKCU corresponde ao utilizador do processo elevado.

O programa tenta criar um ponto de restauro, que pode falhar e não substitui as baselines. O relatório distingue `Applied`, `AlreadyCompliant`, `Incompatible`, `Failed`, `Unverified`, `NotSelected` e `Deferred`. Configuração persistida não prova ganho de desempenho nem consumo pelo Windows/driver.

O armazenamento valida proprietário, DACL e ausência de reparse points antes de usar dados elevados. Recusa instalações antigas inseguras sem alterar ACL ou adotar backups automaticamente. Não apagar backups para ultrapassar a recusa. Novos diretórios usam DACL protegida; integração NTFS/UAC real continua pendente. Logs ficam em `SkyOptimizer\Logs` sob a mesma pasta central.

## Interface e painel

A entrada normal executa MAX uma vez e termina. Os comandos técnicos conservam inspeção, limpeza, Undo, reparação e geração explícita do painel. `-DebloatPreview` mostra AppX da conta atual: dependências, componentes protegidos e metadados desconhecidos. Nenhum pacote fica autorizado para remoção; não é inventário de todas as contas nem do provisionamento.

Programa e painel usam um lock comum de sessão. Fechar o programa principal antes de abrir o painel autónomo. Regenerar o painel na mesma versão; painéis já instalados não recebem correções retroativas. Launchers aguardam a elevação e propagam o código de saída. O reinício automático global do Explorer está suspenso.

O painel mantém os atalhos:

- **Reverter:** restaura apenas recursos com baseline verificável; preserva backups e conflitos.
- **Impressora/Bluetooth:** desativa o serviço ou restaura a baseline própria. Não inventa um modo de arranque para serviços originalmente desativados.
- **VBS/localização:** os controlos antigos estão suspensos. Localização aplicada pela ação 86 pode ser restaurada pelo Undo geral.
- **Shaders:** explica por que a limpeza automática está suspensa. A manutenção de diagnóstico continua no programa principal.
- **Relatório:** snapshots de configuração, processos, RAM e disco. Não é um benchmark nem uma certificação de compatibilidade com anti-cheat.

## Utilização em laboratório

Requer Windows PowerShell 5.1. Não executar estes comandos no computador de desenvolvimento durante a validação de código. O comando sem parâmetros inicia Apply MAX; usar `-DryRun` para inspecionar.

```powershell
.\SkyOptimizer.ps1
.\SkyOptimizer.ps1 -DryRun
.\SkyOptimizer.ps1 -Diagnose
.\SkyOptimizer.ps1 -DebloatPreview
.\SkyOptimizer.ps1 -Apply
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

Última suite Pester offline: **290 testes aprovados**. Os **34 testes Python** foram aprovados na Fase 5D; a pasta benchmarks permanece idêntica e não foi retestada sem alterações nesta fase. O catálogo distingue implementação, cobertura automatizada e validação real. Nenhuma destas contagens demonstra FPS ou latência melhores.

A [prova detalhada Pester](docs/FASE5F-TESTES.json) identifica o código testado. Os 90 IDs mantêm a elegibilidade. Contratos de arranque e background são recursos nomeados separados; background continua restrito a laboratório, com confirmação e código 2 mesmo após escrita verificada. Ver o relatório 5F antes de testar `-BackgroundLab -Profile Laboratory`.

O [procedimento A/B da Fase 5D](docs/FASE5D.md) explica a primeira experiência reproduzível. `benchmarks/capture.py` apenas planeia por defeito e exige binário PresentMon 2.3.1 de origem verificada, hash aprovado e autorização explícita para capturar. `benchmarks/Collect-SkySession.ps1` também exige autorização explícita. `benchmarks/experiment.py` cria análise JSON e relatório Markdown, com bootstrap por blocos e classificação de regressões/inconclusivos. Nenhuma destas ferramentas aplica ações ou lança jogos. Aplicar a intervenção continua a usar Laboratory e o Undo do programa existente.

A [validação MAX](docs/FASE5E.md) acrescenta o escopo independente `integration/evidence-max.json`, com 16 valores, e prepara a verificação de login/Undo dos contratos de arranque. O [protocolo de VM](docs/INTEGRACAO-VM.md) inclui o harness de registo com reinícios manuais, falhas intermédias e conflitos externos. O harness está preparado e testado com mocks; ainda não foi executado num guest real. Só o utilizar num Windows descartável com snapshot confirmado e autorização para alterações. A [preparação de tarefas 3C](docs/TAREFAS-LAB-3C.md) acrescenta fixtures isoladas, fingerprint e Enabled, sem allowlist de tarefas reais.

[Comunidade SkyOptimizer](https://discord.gg/cE8ZaDRGV5).
