# Fase 3B — auditoria e desenvolvimento offline

Data: 27 de outubro de 2026. Base preservada: `22def57`, branch `dev/phase2-execution-power-safety`, working tree inicialmente limpa. Apenas SkyOptimizer. Não existe VM ou máquina física disponível para testes; esta fase não executa Apply/Undo no Windows de desenvolvimento.

## 1. Auditoria das 67 ações inicialmente bloqueadas

[AUDITORIA-3B.json](AUDITORIA-3B.json) contém uma entrada individual para cada uma das 67 ações, com mecanismo observado no código, fundamento, impacto esperado, riscos, dependências, requisitos de reversão, decisão offline e referências primárias. A linha/comandos pertencem ao source da base `22def57`; não são referências às linhas após migração. Uma referência geral de mecanismo não valida flags marcadas como internas ou sem contrato confirmado.

Triagem inicial:

| Decisão | Quantidade | Tratamento |
|---|---:|---|
| Laboratório necessário | 21 | Não desbloquear scheduling, memória, rede/driver, energia por hardware ou hipóteses que dependam de medições. |
| Integração de software / investigação adicional | 39 | Podem admitir desenvolvimento offline futuro; ainda faltam contratos, estado runtime, ownership ou teste funcional. Não ficam automaticamente elegíveis. |
| Candidatas a migração offline neste lote | 4 | 16 Widgets, 59 long paths, 88 Storage Sense e 90 clipboard. Limitar a políticas documentadas e guardar só valores geridos. |
| Retirar implementação genérica | 3 | 12 reserva QoS, 30 encerramento forçado e 54 ocultação de disco cheio. Sem impor configurações inversas a instalações antigas. |

### Achados transversais

- 14/58/84 repetem ContentDeliveryManager e SubscribedContent. Consolidar por finalidade e recurso; não migrar três conjuntos iguais de flags internas. 70 também mistura políticas de UI e CloudContent com suporte diferente por edição.
- 16 mistura Widgets de Windows 11 com Feeds de Windows 10 e preferências HKCU. Migrar apenas a política de Widgets aplicável, sem alegar que esconder o botão termina todo o WebView.
- 36 escreve GPU Priority e SFIO Priority documentados como não utilizados e usa Clock Rate como se a garantia antiga ainda existisse. Remover esses campos sem desbloquear o resto do perfil MMCSS. Threads precisam de se inscrever em MMCSS; o registo não afeta todos os threads do jogo.
- 87 confunde controlo MMAgent de ApplicationPreLaunch com AllowDeploymentInSpecialProfiles, que controla deployment AppX em perfis especiais. Eliminar a associação; não desativar deployment para tentar reduzir pré-arranque.
- 90 força AllowClipboardHistory=1 enquanto pretende apenas impedir sincronização entre dispositivos. A preferência de histórico pertence ao utilizador/política e deve ficar intacta.
- 34/7/28/62/64/73/83 alteram preferências inteiras ou estado persistido sem garantir estado da sessão/API. Exigem integração de software e preservação de acessibilidade; não são automaticamente migráveis por serem valores de registo.
- 43 escolhe o primeiro disco e executa ReTrim em C:; cinco segundos e output silenciado não demonstram sucesso. Continua bloqueada, sem transformar TRIM numa ação reversível.
- 49 remove pacotes de todos os utilizadores e provisionamento. Sem fonte/estado de reinstalação, um diário de registo não fornece Undo.

Fontes centrais: [Widgets](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests), [MMCSS](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service), [perfis especiais AppX](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-appxpackagemanager), [reservas QoS](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-qos), [long paths](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation), [Storage Sense](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-storage#allowstoragesenseglobal), [clipboard](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy#allowcrossdeviceclipboard).

## 2. Separação das provas

Aprovar um teste automatizado significa que o percurso de código satisfez os cenários simulados. Não confirma política consumida, compatibilidade funcional com apps, estabilidade de driver ou ganhos de FPS/latência. Toda a validação real permanece `Não executada`.

As candidatas só podem entrar por seleção explícita em Extreme, com compatibilidade e tradeoffs comunicados. Balanced e Performance não recebem mais ações por conveniência. As restantes hipóteses conservam o bloqueio; não há promoção de HAGS/MSI ou tweaks de kernel por falta de laboratório.

## 3. Alimentação: ausência de informação nunca equivale a AC

A Fase 3A já tinha corrigido o fallback antigo que devolvia AC em falha de CIM. Nesta fase, o estado é explícito: AC, DC ou Unknown. GetSystemPowerStatus só autoriza AC quando devolve o código numérico 1; 255, exceção, null ou resultado malformado ficam Unknown. Não se utiliza a ausência de Win32_Battery nem o tipo de chassis como prova de desktop.

O writer comum `Set-SkyAcPowerSettings` passa a recusar alimentação não confirmada antes de abrir backups e a verificar de novo antes de cada escrita e reativação. Assim, core parking também fica abrangido. Se a alimentação mudar a meio de um grupo, comunica falha e conserva a cópia/baseline para Undo; nunca escreve DC nem o plano original. Não existe atomicidade física entre observar AC e enviar o comando, pelo que transições reais continuam por testar.

`Test-IsOnBattery` distingue DC de Unknown e não é usado como prova inversa de AC. Os percursos ativos consultam a condição afirmativa de AC. Validação focada: **39 testes aprovados**, incluindo resultado desconhecido/malformado, core parking sem AC e perda de AC após a primeira escrita com Undo posterior. Nenhum API de leitura de alimentação real foi chamado pelos testes.

## 4. Retiradas e correções de fundamento

12, 30 e 54 deixam de ter implementações que alteram Windows; o dispatcher e as funções diretas comunicam a decisão por ID. Somando 39, existem quatro ações retiradas. Não se apagam valores ou backups legados: a retirada do código não prova o estado anterior de uma máquina.

12 retirava uma suposta reserva fixa de 20% sem demonstrar carga QoS. A política controla o limite das reservas agregadas; não certifica banda perdida nem autoriza prometer recuperação genérica. 30 forçava AutoEndTasks e timeouts de dois segundos, além de inventar baseline 5000 quando ausente. Isto não melhora um jogo em execução e pode interromper encerramento de apps/serviços. 54 escondia disco cheio, sem libertar espaço nem resolver pressão de armazenamento.

As escritas MMCSS 36 foram isoladas numa função sem mutações: não se deixam campos documentados como não utilizados nem se afirma prioridade de todo o jogo. A hipótese de medir threads inscritas permanece na auditoria. A ação 87 também permanece bloqueada sem mutações, retirando a falsa ligação entre deployment AppX em perfis especiais e pré-arranque MMAgent. Não se perdeu a proposta de investigar prelaunch com estado próprio.

Validação focada: **sete testes aprovados** de retirada, consistência do catálogo e cobertura da auditoria. Os testes impedem chamadas a registo, processos externos e Disable-MMAgent. Nenhuma alteração real aplicada.

## 5. Quatro migrações de software

| ID | Implementação mínima | Compatibilidade conservadora | Limites/tradeoffs |
|---:|---|---|---|
| 16 | AllowNewsAndInterests=0 | Windows 11 cliente >=22000, Pro/N, Enterprise/N/LTSC e Education/N | Preserva TaskbarDa e Feeds Win10. Perde Widgets; não garante terminar processos WebView nem reduzir FPS/frametimes. |
| 59 | LongPathsEnabled=1 | Cliente Windows 10/11 >=14393, mesmas edições e Home/N/Single Language/China conhecidas | Apenas APIs/apps longPathAware. Reiniciar Windows para validar processos com cache. Não ultrapassa limites de shell/cloud ou todas as aplicações. |
| 88 | AllowStorageSenseGlobal=0 | Cliente >=18362 e edições de política conhecidas; Home recusada | Preserva 01/cadências/preferências. Não apaga ficheiros. Limpeza manual necessária para evitar disco cheio. |
| 90 | AllowCrossDeviceClipboard=0 | Cliente >=17763 e edições de política conhecidas; Home recusada | Preserva AllowClipboardHistory e conteúdo do histórico. Perde sincronização entre dispositivos; sem alegação de FPS. |

Reutilizam o diário existente: intenção antes da escrita, pós-verificação por valor, baseline estável, Undo de existência/tipo/conteúdo e deteção de conflito externo. A matriz de cliente é parametrizada por build mínima; a função antiga de compatibilidade de Update permanece como wrapper para preservar os percursos anteriores. Edições desconhecidas, Server, versão desconhecida e falha de deteção não originam escritas.

São opções explícitas em Extreme; Balanced/Performance conservam 79 e 9/41/79. A elegibilidade confirma a implementação da configuração, não consumo pelo Windows, integração funcional ou ganho medido. Não houve promoção de ações dependentes de drivers/hardware. O catálogo distingue validação automatizada e validação real.

Os testes verificam ausência original, tipos inesperados, Apply repetido, Undo, preferência de histórico/Feeds/Storage Sense intacta, falha após escrita e falha ao persistir intenção. Validação de migrações/compatibilidade/diário: **42 testes focados aprovados**. Nova prova estrutural e de resultados: **27 testes focados aprovados**; estas suites sobrepõem testes, não se somam como contagem final.

### Correção adicional de resultados

Reproduzido: `Invoke-SkyAction` convertia um resultado Deferred em AlreadyCompliant e descartava o reinício necessário quando havia um child Unverified/Failed. Corrigido para preservar estados de não execução, detalhes de falhas e requisitos de reinício. Aplicação parcial com child Deferred/NotSelected fica Unverified. A suite acrescenta três regressões; não apresenta uma operação bloqueada como sucesso.

## 6. Harness e futura integração

O harness acrescenta BackupWriteFailure: um handle real bloqueia a substituição atómica do diário num ficheiro de laboratório. Exige IOException, bytes da baseline intactos e zero alteração de recursos. Os testes offline usam exclusivamente ficheiros TestDrive e registo simulado, sem executar um cenário real em guest.

ExternalConflict passa a confirmar a restauração dos restantes recursos apesar do conflito no primeiro. Falhas depois de abrir o run produzem JSON `Passed=false` quando possível. A falha de guardar a própria evidência não substitui a exceção original nem avança o cenário. Estão preparados procedimentos específicos de Widgets, long paths, Storage Sense e clipboard em [INTEGRACAO-VM.md](INTEGRACAO-VM.md).

A falta de VM não bloqueou estes desenvolvimentos. Continuam pendentes execução do harness em Windows descartável, reinícios reais, verificação das políticas na shell/apps e ensaios de hardware. O harness não contém reboot nem aprovação automática de desempenho.
