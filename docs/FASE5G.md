# Fase 5G — Deep Debloat orientado para desempenho

Base `1ed8f59`, branch `dev/skyoptimizer-max`. Entrega offline incremental; missão MAX continua parcial. Sem otimizações no Windows de desenvolvimento, benchmarks, VM, agentes residentes ou alterações a SkyOS/Packs. Publicação limitada à branch de desenvolvimento do repositório privado.

## Código entregue

- Relatórios MAX, Apply técnico, BackgroundLab, DebloatLab e Undo usam diretório exclusivo `Backups/Runs/<RunId>`. `run.json` guarda tipo, início/fim, exit code, estado e artefactos efetivamente escritos. `latest_run.json` aponta exclusivamente para esse run. Cancelamento não adota resultados de uma tentativa anterior. Crash não tratado pode deixar Started; não considerar sucesso.
- Baselines `mutation_state.json`/`power_state.json` continuam centrais, fora de Runs: Apply repetido não cria uma nova baseline por sessão. Artefactos antigos na raiz são históricos, não o resultado atual; não são apagados. A escrita/índice falhada comunica erro, não prova de conclusão.
- EpicGamesLauncher: contrato de arranque HKCU Run, comando/path/argumentos exatos e assinatura/produto/hash/versão. Remove somente essa entrada no próximo login, não termina processos nem desinstala. Conta, binário e valor são revalidados antes da escrita e baseline preservada pelo motor existente.
- Phone Link e Feedback Hub: novos alvos explícitos da política por PFN. `NewsWeather` mantém o alvo anterior por omissão. Não se aplicam os quatro produtos em conjunto sem seleção. Guardam lista ForceDeny inteira, preservam entradas externas, default global e ForceAllow/UserInControl. Alterar um alvo numa baseline ainda gerida pode gerar conflito: executar Undo/verificar antes de outro ensaio; não forçar composição.
- DiagTrack e TrkWks: contratos individuais Laboratory, separados do grupo 48. Validam cliente conhecido >=19041, gestão, conta, svchost/group/ServiceDll canónicos, assinatura Microsoft/company e hashes; recusam templates per-user, dependências desconhecidas/ativas e estados transitórios. DiagTrack é recusado quando existe estado de onboarding Defender for Endpoint.
- Serviço: runtime e startup continuam recursos separados no mesmo diário. Falha na primeira alteração impede a segunda. Falha intermédia preserva intenção para Undo. Fingerprint adicional é verificado nos leitores/escritores comuns e no Undo autónomo exportado. Baselines anteriores sem binding não são adotadas silenciosamente; IDs canónicos existentes não foram divididos em baselines contraditórias.
- Inventário inclui os planos individuais de laboratório e três tarefas exatas com motivos de bloqueio. Nenhuma tarefa produtiva foi desativada.
- P1 encontrado na revisão e corrigido: `-Component`/`-BackgroundTarget` sem o switch respetivo verdadeiro podia cair no MAX por omissão. Preflight agora recusa antes de UAC/armazenamento, incluindo switches explicitamente falsos, perfil errado ou IDs adicionais.

## Contratos e potencial de concorrência

| Componente | Mecanismo/cenário | Custo funcional e situação |
|---|---|---|
| EpicGamesLauncher | Evitar autoarranque por Run e respetivo background após login | Downloads/atualizações/jogos podem exigir abertura manual. Binário oficial e layout provisório têm de ser validados em VM |
| Phone Link | Negar background por PFN Microsoft.YourPhone | Pode interromper chamadas/mensagens/sync; alvo explícito, nunca presumir dispensável |
| Feedback Hub | Negar background por PFN Microsoft.WindowsFeedbackHub | Pode impedir diagnóstico/gravação durante suporte; política deve ser testada na versão instalada |
| DiagTrack | Impedir execução/arranque de experiências/diagnósticos ligados | Perda de diagnóstico/telemetria; ausência do indicador MDE não certifica ausência de todas as dependências empresariais |
| TrkWks | Impedir tracking de links distribuídos | Ligações/atalhos/workflows NTFS locais ou rede podem perder acompanhamento de movimentos |
| Discord | Cadeia Update.exe/Discord versionado não implementada | Deferred: validar toda a cadeia, argumentos e recuperação antes de remover Run |
| MapsBroker | Papel de mapas offline identificado | Deferred: falta contrato binário/dependências/recuperação para as variantes |
| MapsUpdateTask / MapsToastTask | Tarefas identificadas pelo path exato | Deferred: falta matriz de XML/hash/versão/dependências; engine só autoriza fixtures |
| Microsoft Compatibility Appraiser | Possível trabalho de compatibilidade/diagnóstico | Deferred: papel em compatibilidade/upgrades e recuperação não validado; não alargar allowlist por nome |

Assinatura comprova identidade dentro do contrato; não comprova dispensabilidade ou FPS. Serviço parado e app sem trabalho não passam a beneficiar um jogo por serem removidos. Medir CPU/I/O e frametimes temporalmente; testar controlo negativo sem atividade concorrente. Não há novos ganhos medidos.

## Grupos 48/71 e ação 49

48 continua bloqueada como grupo: DiagTrack e TrkWks têm contratos separados de ensaio; PcaSvc permanece preservado por compatibilidade. 71 continua bloqueada: `diagnosticshub.standardcollector.service` depende de uso de ferramentas, `wercplsupport` preserva evidência de falhas e `OneSyncSvc` combina template/instâncias e dados sincronizados. Ainda não há contratos que permitam desativá-los indiscriminadamente.

49 continua bloqueada. Background por PFN não remove AppX nem provisionamento. Reinstalação não garante versão/dados, e desprovisionamento afeta contas futuras. O gate exige payload/licença, dependências, conta exata, teste de reinstalação e recuperação de dados; nenhum mock de registo substitui essa demonstração.

## Comandos técnicos — apenas futuro laboratório autorizado

```powershell
.\SkyOptimizer.ps1 -DebloatPreview
.\SkyOptimizer.ps1 -BackgroundLab -BackgroundTarget PhoneLink -Profile Laboratory
.\SkyOptimizer.ps1 -BackgroundLab -BackgroundTarget FeedbackHub -Profile Laboratory
.\SkyOptimizer.ps1 -DebloatLab -Component EpicGamesLauncher -Profile Laboratory
.\SkyOptimizer.ps1 -DebloatLab -Component TrkWks -Profile Laboratory
.\SkyOptimizer.ps1 -DebloatLab -Component DiagTrack -Profile Laboratory
.\SkyOptimizer.ps1 -Undo
```

Cada comando lab seleciona um contrato; pede confirmação do impacto e revalida o plano. Aplicação verificada continua exit code 2 por validação funcional pendente. Nenhum destes contratos foi promovido automaticamente ao MAX. O dry-run MAX conserva os sete candidatos anteriores. Tarefas, MapsBroker e Discord aparecem bloqueados no inventário, sem modo de bypass.

Usar exclusivamente programa/Undo/painel atuais. Regenerar o painel antes do ensaio: versões antigas não contêm o novo guarda de identidade. Atualização Windows ou substituição de binário pode bloquear Undo por mudança de hash; isto preserva a baseline e exige revisão, não restauração por nome. Parar o serviço não recupera dados/diagnósticos que deixaram de ser produzidos.

## Relatórios e recuperação

`Runs/<RunId>/run.json` é o manifesto autoritativo da tentativa; somente os ficheiros listados pertencem a essa execução. `latest_run.json` é um índice, não histórico agregado. Verificar RunId, State, ExitCode e artefactos. Pastas não são reutilizadas. Falha na escrita inicial impede o corpo de Apply. Falha após mutação pode deixar evidência incompleta, mas o diário central permanece a fonte de Undo.

Não usar ficheiros antigos da raiz como resultados atuais. Leitores externos dos antigos `max_run.json`/caminhos planos têm de migrar para latest_run e o diretório indicado; não se copiam resultados antigos para manter uma aparência de compatibilidade. Logs tradicionais podem conter várias sessões e não substituem o manifesto. O painel legado continua um comando técnico separado; os seus logs não são um run MAX.

## Testes reais obrigatórios

1. VM recuperável: UAC/argumentos/conta, ACL, leitura de contratos reais, assinatura/metadados de Epic e serviços, ausência de processos/tarefas Sky residentes.
2. Apply, Apply repetido, cancelamento, falta de espaço, encerramento forçado, reinício/login, Undo e novo reinício. Comparar configuração e funcionalidade antes de restaurar snapshot.
3. Serviços: dependentes, permissões, triggers e delayed start preservados; binário atualizado/trocado deve impedir restauração automática. Verificar painel regenerado e conflitos com baselines antigas.
4. Background: alvo e impacto em outras contas; confirmar consumo AppPrivacy por versão e recuperação de chamadas/sync/diagnóstico. Registar os quatro valores com `integration/evidence-background-lab.json` antes da mudança.
5. Hardware: medir overhead, sessões com/sem atividade concorrente, A/A e A/B por contrato antes do conjunto MAX. CPU, I/O e processos menores não provam FPS/lows/latência. Protocolo 5D continua aplicável.

## Continuação offline ainda possível

Contratos adicionais por produto/versão; modelo de definição e dependências para tarefas produtivas; recuperação real de AppX/payload; associação da atividade temporal a componentes; retenção/exportação privada de runs; binding por dispositivo para novas experiências. Não falta apenas benchmarking. Esta entrega não declara missão completa, prontidão comercial nem ganhos de FPS.

## Fontes de mecanismo

- [Microsoft — serviços Windows IoT](https://learn.microsoft.com/windows/iot/iot-enterprise/optimize/services): funções dos serviços, não certificação de gaming desktop.
- [Serviços por utilizador](https://learn.microsoft.com/en-us/windows/application-management/per-user-services-in-windows): diferenças entre template e instâncias.
- [Privacy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy#letappsruninbackground_forcedenytheseapps): overrides por PFN; representação REG_MULTI_SZ confirmada no ADMX.
- [Epic — arranque](https://www.epicgames.com/help/en-US/c-Category_EpicGamesStore/c-EpicGamesStore_LauncherSupport/epic-games-launcherpc-a000090995): opção funcional; não garante todos os layouts de Run.
- [Phone Link](https://support.microsoft.com/en-us/windows/apps/phonelink/phone-link-requirements-and-setup): capacidades e compromissos. PFN Feedback Hub aparece em [documentação Microsoft](https://learn.microsoft.com/en-us/hololens/windows-defender-application-control-wdac); isso não certifica AppPrivacy no desktop.

## Prova e commits

- **331/331 Pester**, PS5.1.26100.9711 / Pester3.4.0, zero failed/skipped/pending. [Prova por teste e hashes](FASE5G-TESTES.json). A suite final correu sobre fonte fixa; a prova verifica o hash antes/depois. Tests adicionais cobrem consentimento, argumentos, identidade no getter/setter real, Undo exportado, falha entre recursos, baseline antiga e isolamento entre runs.
- **34 Python aprovados anteriormente na 5D**; árvore benchmarks inalterada e não retestada sem mudança. Nenhum benchmark físico executado. Uma execução intermédia de testes do inventário antecedeu o mock do novo agregador de planos; eventuais leituras foram apenas diagnósticas. Suite final tem mocks dos leitores Windows e nenhum mutador real.
- P1 de argumentos encontrado em revisão independente foi corrigido com regressão. Não foram demonstrados outros P0/P1 no âmbito revisto; isto não certifica integração real.
- `d29d2a6`: diretórios de relatórios por RunId.
- `a6b39a2`: contratos de laboratório, fingerprint de serviços e preflight.
- `cd4e744`: relatório Undo separado, preservando baselines centrais.
- Documentação, catálogo e provas ficam no commit documental posterior; consultar git log da branch publicada.

Contagens conservadas: **26 elegíveis, 58 bloqueadas, cinco retiradas e uma manutenção**. As sete candidatas automáticas MAX não aumentaram. Os contratos novos são nomeados/de laboratório; não aumentam artificialmente o catálogo nem demonstram melhor FPS. Não houve reescrita de histórico nem merge para main.
