# Fase 5F — MAX Performance e Deep Debloat

> Entrega histórica. A [Fase 5G](FASE5G.md) acrescentou contratos e substituiu relatórios planos por pastas exclusivas RunId.

Base `6a951fb`, branch `dev/phase2-execution-power-safety`. Desenvolvimento incremental; a missão MAX continua parcial. Não foram aplicadas otimizações ao Windows, executados jogos, benchmarks ou VM, nem efetuado push. SkyOS e Packs não foram alterados.

## Blocos efetivamente entregues

1. Inventário de debloat local por categorias, com leitores independentes, isolamento de falhas e distinção entre ausência observada e leitura desconhecida/parcial.
2. Avaliação individual das 26 ações elegíveis, consumida pelo plano MAX e registada no catálogo. Elegibilidade não promove automaticamente experiências.
3. Diagnóstico de hardware e recursos: CPU/família, GPU/driver, commit de memória, modelos de disco e contadores de I/O. Leituras pontuais não provam gargalo, necessidade de tweaks ou BIOS.
4. Contrato seletivo de background por PFN para News/Weather, reversível e restrito ao laboratório. CLI usa elevação, lock, confirmação, diário e Undo existentes. A aplicação automática permanece bloqueada até consumo funcional validado.

## Inventário e decisões de debloat

`-DebloatPreview` passa a devolver schema 2 com `Sections`; já não devolve apenas o objeto AppX do schema anterior. O leitor `Get-SkyAppxPreview` permanece disponível internamente sem alterar o seu contrato. `-Diagnose` inclui plano MAX, hardware e inventário; `-DryRun` conserva o plano leve. Comandos de leitura não inicializam diários nem pedem elevação automática; algumas categorias podem exigir administrador e devem comunicar Unknown quando indisponíveis. Não existe monitorização residente.

| Categoria | Identidade/dependências observadas | Custo possível e decisão | Recuperação / integração |
|---|---|---|---|
| AppX atual | PackageFullName, publisher, arquitetura, flags e dependências pelo leitor anterior | Instalação não prova CPU/I/O; dependências/protegidas excluídas | Remoção 49 bloqueada; reinstalação não restaura dados/versão |
| Provisionamento | PackageName da imagem, versão e arquitetura; dependências Unknown | Efeito sobretudo em futuras contas e disco | Desprovisionamento bloqueado até payload/licença/dependências e recuperação comprovados |
| Software/OEM | Chave de uninstall HKLM/HKCU, x64/x86, publisher/versão | Role OEM desconhecido; utilitário pode controlar refrigeração/MUX/periféricos | Não executar uninstall strings; exigir contrato por produto/versão/dados |
| Arranque | Nome, comando, conta e localização WMI | Entrada não prova estar ativa ou consumir recursos no jogo | Só contratos Run exatos Spotify/Steam da 5E aplicam; outras fontes apenas inventário |
| Serviços | Nome, estado, startup e edges Required/Dependent do SCM | Edges SCM não cobrem dependências das aplicações | 48/71 continuam bloqueadas; contratos individuais e recuperação funcional antes de promover |
| Tarefas | TaskPath+Name, autor, executável e classe de trigger | Presença não prova execução concorrente; histórico não recolhido | Sem allowlist produtiva; não modificar Windows/OEM/terceiros por nome |
| Features | FeatureName e estado da imagem online | Ativada não prova carga durante jogo | Desativação bloqueada até grafo, payload e recuperação após reinício |
| Processos | PID, parent, criação, working set, private pages e contadores CPU/I/O cumulativos | Comparação temporal necessária; working set não prova pressão nem desperdício | Sem kill por nome; não há controlo de sessão sem pause/resume suportado |
| Background seletivo | PFN exato e política AppPrivacy | Pode evitar background das duas apps; notificações/atualizações deixam de funcionar | Laboratório, sem desinstalar/dados; registo restaurado por recurso |

Os inventários são locais e podem conter paths, comandos, nomes de contas e identificadores. Não exportar sem revisão. Software OEM não é identificado como dispensável só por publisher. O leitor evita `Win32_Product`, cuja enumeração pode acionar verificações MSI. Se um root de software falhar, a cobertura não é declarada completa. Nenhum método de desinstalação é executado a partir do registo.

## Avaliação das 26 ações

A [matriz máquina](FASE5F-MAX-26.json) fornece ID, Disposition, motivo individual e ausência de benefício medido. O plano usa estes motivos para as 19 ações elegíveis fora das sete candidatas automáticas. O catálogo conserva os 90 IDs e acrescenta `AvaliacaoMAX5F` às 26 implementadas.

- Automáticas condicionais existentes: 9/16/41/58/70/79/84, segundo build/edição/browser/gestão. Não foram acrescentadas ações automaticamente sem fundamento.
- Dependência: 1 é cópia inicialmente idêntica, sem mecanismo de ganho isolado.
- Atividade observada necessária: 6 SysMain e 20 DO P2P. Não inferir de SSD, serviço em execução ou tráfego histórico. Modo DO 0 preserva HTTP; não garante menor ping/FPS.
- Validação física: 3/8/38/60/74/75/76; energia, USB e NIC dependem de hardware/driver e compromissos CPU/energia/ligação.
- Contrato insuficiente: 42 usa armazenamento gráfico interno.
- Risco funcional: 25 afeta globalmente Windows apps; 86 agrupa localização/sensores/serviço. Não automatizar indiscriminadamente.
- Preferência/compatibilidade/operação: 13/17/19/59/88/90. Exemplo 13: escrever 1 sobre um original 0 pode aumentar telemetria. 88 pode deixar o disco encher. Não são melhorias de gaming demonstradas.

## Contrato de background seletivo

Allowlist: `Microsoft.BingNews_8wekyb3d8bbwe` e `Microsoft.BingWeather_8wekyb3d8bbwe`. Exige Windows cliente Pro/Enterprise/Education na matriz >=15063, gestão conhecida sem indicadores, PFN/publisher exatos e metadados completos sem flags de proteção. A descoberta cobre a conta atual; a política tem escopo de máquina e pode afetar outras contas. Não se declara atividade efetiva de background.

Escreve somente `LetAppsRunInBackground_ForceDenyTheseApps` como REG_MULTI_SZ. Conserva ordem, duplicados e entradas externas, default global e listas ForceAllow/UserInControl. Colisão nos PFNs ou tipo desconhecido bloqueia o contrato. Revalida pacotes, política e plano antes da alteração; um plano fornecido pelo caller não autoriza path/estado arbitrário. A lista partilha uma baseline por recurso, não uma operação de remoção por pacote; nunca agrupa desinstalações. Undo restaura o valor original inteiro somente se o estado gerido ainda coincide; alterações externas produzem conflito.

```powershell
# Somente em futuro Windows descartável autorizado; não executar no host de desenvolvimento.
.\SkyOptimizer.ps1 -DebloatPreview
.\SkyOptimizer.ps1 -BackgroundLab -Profile Laboratory
.\SkyOptimizer.ps1 -Undo
```

Sem a autorização explícita do mutador, o resultado é Deferred. O CLI exige Laboratory sem IDs extra, confirmação do impacto e revalidação pelo contrato. Guarda `background_lab_plan.json` e, quando alcançado, `background_lab_result.json` na pasta protegida. Um resultado anterior pode persistir após cancelamento: conferir timestamps e diário. Uma escrita bem verificada continua código 2: consumo funcional pendente, não aprovação de produção. Requer reinício/apps e teste da recuperação de notificações/background. O operador não deve tratar este comando como MAX comercial.

Fonte primária: [Privacy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy#letappsruninbackground_forcedenytheseapps). O ADMX local `AppPrivacy.admx` confirma a representação multiText do registo; o formato de transporte CSP não deve ser escrito como String na lista. Não se implementou política alternativa de captura Win11 sem contrato público suficiente.

## Topologia CPU Sets

`GetSystemCpuSetInformation` recolhe os CPU Sets reportados pelo Windows. O parser mantém separados ID, Group, LogicalProcessorIndex, CoreIndex, LastLevelCacheIndex, NumaNodeIndex e EfficiencyClass. Classes de eficiência diferentes são observação do SO; uma classe única não prova silício homogéneo. Cache/NUMA não identificam CCD nem X3D. O plano MAX continua sem receitas por nome/fabricante.

A API só é invocada pelo diagnóstico explícito. Declarações P/Invoke não são compiladas/executadas ao importar funções para testes. A leitura tem buffer limitado, duas chamadas, tamanhos variáveis e falha fechada perante erro, crescimento, truncagem ou duplicados. A implementação não altera CPU Sets, afinidade, core parking ou scheduling. APIs indisponíveis produzem Unknown. Os 10 testes usam buffers ABI sintéticos e uma fronteira nativa mockada, sem consulta real ao hardware.

Fontes: [API Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getsystemcpusetinformation), [estrutura Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-system_cpu_set_information). O próximo gate é comparar os campos com a topologia efetiva em hardware/virtualização; depois formular ensaios individuais de energia, sem promover ajustes universais.

## Validação e continuação

Os testes finais, commits e hashes são registados na prova desta fase. Todos os mutadores foram simulados ou limitaram-se a diários temporários. Num teste intermédio do contrato, antes da correção do mock, ocorreu uma enumeração AppX real somente de leitura; nenhuma política/pacote foi alterado. A execução final usa mocks de leitores Windows. Esta diferença deve ser preservada na descrição da validação.

VM: UAC/conta correta, permissões dos leitores, AppPrivacy efetivamente consumida, outras contas, login/reboot, falhas intermédias e conflitos externos; restaurar configuração e comportamento pelo Undo antes de snapshot restore. Para BackgroundLab, usar `integration/evidence-background-lab.json`: quatro valores (default e três listas), capturados antes/depois pelo coletor independente existente; apenas ForceDeny pode mudar. Conservar os snapshots e o diário para comprovar ausência/tipo/conteúdo original. Os 16 valores MAX anteriores não cobrem este contrato.

Hardware: overhead do diagnóstico/captura, CPU Sets e virtualização, clocks/temperatura/autonomia, drivers e anticheats. A/A e depois A/B por intervenção, com login e condições de abertura das apps controlados, seguindo o protocolo 5D. Comparar FPS médio, 1% lows e p99/picos; latência física só com instrumentação apropriada.

Trabalho offline ainda possível: ampliar contratos por aplicação com identidade/dependências documentadas; recuperação de AppX/payload sem prometer dados; controlo suportado de concorrência por componente; relatório por sessão sem ambiguidades; telemetria com atribuição segura e análise temporal de DO. Não faltam apenas benchmarks. Não se declara missão MAX concluída nem prontidão comercial.

## Resultado offline e commits

- Suite completa: **290/290 Pester**, Windows PowerShell 5.1.26100.9711 / Pester 3.4.0, zero failed/skipped/pending. São 36 testes adicionais: 11 de inventário/decisões, 15 de background/CLI e 10 de CPU Sets. [Prova por teste e hashes](FASE5F-TESTES.json).
- Os testes de diários precisaram de execução fora da restrição de renomeação temporária do sandbox; os mutadores Windows continuaram simulados. As falhas de acesso a temporários do sandbox não foram tratadas como aprovação.
- Python: **34 aprovados na Fase 5D**, árvore benchmarks inalterada; nenhuma repetição sem mudança nesta fase. Não foram executados benchmarks reais.
- Revisão independente do diff não encontrou P0/P1 demonstráveis no âmbito revisto. Duas lacunas de testes de leitores/CLI foram corrigidas com cobertura adicional. CPU ABI/PInvoke foi revisto offline; não é certificação de hardware.
- `ae595c4`: inventário abrangente, diagnóstico e motivos individuais das 26 ações.
- `1a5a3bd`: contrato seletivo de background, comando técnico e regressões.
- `6007aed`: CPU Sets, parser limitado e testes de buffers sintéticos.
- Catálogo, escopo independente e documentação/prova ficam no commit documental posterior; consultar `git log`.

**Estado:** 26 elegíveis, 58 bloqueadas, cinco retiradas e uma manutenção. Sete IDs continuam candidatos MAX automáticos; nenhum foi acrescentado por ausência de prova de adequação universal. O contrato de background é nomeado e de laboratório, fora dos 90 IDs e fora do MAX automático. Nenhum ganho de FPS, lows, frametime ou input lag foi demonstrado. A missão continua parcial e ainda existe trabalho offline descrito acima.
