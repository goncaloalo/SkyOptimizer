# SkyOptimizer — plano de debloat avançado

**Proposta, não implementação.** O objetivo é retirar software não desejado e reduzir trabalho concorrente demonstrado, conservando as capacidades que o cliente usa. Menos aplicações instaladas, espaço libertado e menos processos são resultados diferentes de melhor desempenho em jogos.

## 1. Quatro operações, quatro contratos

1. **Gerir uma sessão:** pausar uma tarefa concorrente através de controlo suportado, com duração e recuperação definidas. Não terminar processos com trabalho por guardar.
2. **Desativar arranque/background:** conservar instalação e dados; guardar a configuração anterior e o escopo exato.
3. **Desinstalar para uma conta:** retirar a aplicação escolhida dessa conta. Reinstalação não implica reposição de dados ou versão.
4. **Remover provisionamento:** impedir instalação para contas novas; operação separada e avançada. Não confundir com desinstalação nas contas existentes.

A Microsoft distingue explicitamente o provisionamento da instalação por utilizador. O produto deve mostrar estes dois estados e duas escolhas. [Remove-AppxProvisionedPackage](https://learn.microsoft.com/en-us/powershell/module/dism/remove-appxprovisionedpackage); [Remove-AppxPackage](https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage).

## 2. Porque a ação 49 precisa de substituição

No código inspecionado, `Remove-BloatwareAppX` começa na linha 2311. Contém uma lista histórica de 17 padrões, incluindo `*TikTok*` e `*SpotifyMusic*`, enumera todas as contas, remove pacotes e provisionamento e silencia erros. O contador incrementa por padrão encontrado, não por remoção individual verificada. A mensagem de sucesso não comprova recuperação nem proteção por dependências.

O dispatcher bloqueia a ação: não é um defeito que esteja a ser executado no perfil atual. **Manter o bloqueio.** Numa implementação futura, retirar o corpo legado do caminho de produção e substituí-lo por inventário e plano explícito. Não basta adaptar esta função ao diário de registo: desinstalação tem um modelo de recuperação diferente.

## 3. Catálogo de oportunidades e condições

Em todas as linhas, “benefício não medido” significa ausência de medição SkyOptimizer. A classe refere-se a gaming. Perfil Performance é futuro e condicional; “Manual” é uma escolha funcional, sem promessa de FPS. Nenhuma ausência de utilização observada substitui a confirmação do cliente.

| Categoria / função | Recursos e condição de impacto | Evidência e uso pelo cliente | Aplicação e pós-verificação | Recuperação, perdas e perfil |
|---|---|---|---|---|
| Apps promocionais/AppX: Clipchamp, notícias, jogos casuais, apps sociais | Disco sempre que instaladas; CPU/RAM/rede apenas quando executam trabalho | D para FPS de app inativa; B se background concorre. Inventariar pacote, conta, tarefas e uso observado; pedir escolha | Identidade exata, editor e dependências; desinstalar só conta escolhida; reenumerar e testar app protegida relacionada | Reinstalação assistida, não Undo exato de dados. Manual; fora de Balanced |
| Provisionamento de apps opcionais | Espaço e experiência de contas futuras; não elimina carga das atuais | D para gaming atual. Mostrar quais contas existentes têm o pacote | Remoção separada por PackageName exato; verificar imagem e criar conta de teste no laboratório | Reprovisionar exige payload/licença/dependências. Manual avançado; bloquear se recuperação declarada exigir fonte ausente |
| Arranque de launchers, updaters e utilitários não essenciais | CPU/I/O no login e background; pode prolongar contenção ao entrar no jogo | B quando medido. Confirmar necessidade de login, biblioteca e atualização; launcher do jogo pode ser obrigatório | Usar preferência suportada ou adapter específico; guardar entrada original, scope e identidade; verificar após login | Restaurar configuração; não prometer restaurar uma execução já perdida. Performance opcional, após escolha |
| Edge/Chrome background e Startup Boost (41) | RAM, extensões, rede e CPU após fechar janelas; benefício depende de atividade | B; configuração não prova processo consumidor. Perguntar sobre apps/extensões/notificações | Separar opções/âmbitos; verificar políticas efetivas no browser e comportamento após fecho/reabertura | Baseline por valor e respeito GPO/MDM; primeiro arranque pode ficar mais lento. Performance condicional |
| Captura histórica/Instant Replay/Game DVR (9) | Encoder, memória, disco, composição e CPU enquanto captura | B com captura ativa; D quando já desligada. Confirmar streaming/clips e processos reais | Controlos suportados por produto; testar gravação efetivamente desligada e reativada, por build | Preferências originais; captura omitida não é recuperável. Performance só para quem prescinde dela; manter Game Bar instalada |
| Overlays Discord/Steam/GPU/monitorização | Hooks, composição, CPU/GPU; impacto variável por jogo | C até A/B. Detetar overlay ativo, não apenas aplicação instalada | Desligar um overlay por vez na interface suportada; confirmar no jogo e preservar chat | Restaurar preferência; podem perder-se atalhos/estatísticas. Manual por jogo; manter overlay necessário |
| OneDrive/cloud/backup | CPU de sincronização, disco, rede; impacto sob alterações/download/upload | B quando concorrência observada. Confirmar saves, documentos e backups pendentes | Pausa temporária suportada, prazo e lembrete de retoma; verificar tráfego/fila. Não apagar pastas, links ou dados | Retomar sincronização; não desfaz atraso nem conflitos na cloud. Performance por sessão mediante escolha |
| Windows Search (51/82 como temas) | I/O/CPU durante indexação, especialmente muitos ficheiros ou HDD | B para reduzir escopo excessivo; C para receita de registo atual. Ver uso de pesquisa/Outlook e índice | Excluir pastas selecionadas através de controlo suportado; observar escopo e I/O. Não reconstruir índice antes de benchmark | Repor escopo; reconstrução pode demorar e gerar carga. Manual; Performance só por sintoma |
| Delivery Optimization (20) | Rede e disco durante transferências/peering | B para gestão de contenção; desligar peering isoladamente é C para latência. Observar origem/volume de tráfego | Controlos de banda/modo suportados e compatíveis; verificar transferência efetiva e política dominante | Restaurar valores originais, não “reset” genérico. Atualizações continuam; Performance condicional |
| Windows Update/Store/Defender | Carga durante atualização/verificação, essencial para segurança/manutenção | B para coordenar horários; E para desativar segurança permanentemente. Ver trabalho pendente | Recomendar concluir manutenção fora do jogo e horários suportados; não cancelar servicing a meio | Não existe Undo de atualização/scan como sessão; testes de compatibilidade separados. Preservar em todos os perfis |
| Widgets, sugestões, Spotlight, dicas (16/58/70/84) | UI, rede e background quando ativo; conteúdo estático pode ter custo desprezável | D para FPS sem atividade; B para preferência funcional. Mostrar política/edição e utilização | Política suportada, escopo correto, verificação de UI e background após login | Baseline tipada; esconder botão não equivale a terminar WebView. Manual de personalização |
| Copilot e componentes de consumo (33) | Depende de aplicação atual, autoarranque e pedidos; política antiga pode não controlar versão nova | D/C. Descobrir pacote atual e startup; não inferir a partir de build apenas | Adapter versionado para app real ou desinstalação suportada; nunca aplicar política obsoleta como universal | Reinstalação pode não restaurar dados/configuração. Manual |
| Telemetria/diagnóstico (13/48/57/69/71) | CPU/rede/I/O em sessões concretas; serviços ociosos podem não competir | D sem trace; C para reduzir carga demonstrada. Privacidade é objetivo distinto | Separar DiagTrack, compatibilidade, tracking e sincronização; preferir política documentada. Ver serviço funcional, não só Start | Configuração restaurável; relatórios não recolhidos não são recuperáveis. Manual, fora de perfis gaming |
| SysMain (6) | Pré-carregamento/atividade de memória e I/O; efeitos frios/quentes | C. Diagnosticar atividade correlacionada antes de testar | Experiência individual com arranque/execução capturados e posterior observação | Restaurar startup/runtime, sem reconstruir o histórico da cache. Extreme/laboratório |
| Serviços opcionais: impressão, Bluetooth, localização (86/painel) | Custo só se houver atividade relevante | D para FPS em repouso. Perguntar sobre comandos, headset, impressora, sensores e apps | Serviço individual, dependências, triggers e sessão; impedir alteração se funcionalidade em uso ou estado desconhecido | Restaurar configuração/runtime possível; ligações/trabalhos interrompidos não são Undo exato. Manual |
| Tarefas de terceiros/OEM (26/56/68 como temas) | Picos de CPU/disco/rede quando executam, não por existirem | C/B se trace associa execução ao problema | Preferência da app antes de Scheduler. Allowlist exata por XML/editor/versão; só Enabled, tarefa não running/queued | Restaurar Enabled se definição não mudou; não recriar XML nem repetir execução omitida. Manual/Performance condicional |
| Utilitários OEM/RGB/periféricos | Polling, overlays, atualizações; alguns controlam ventoinhas, MUX, potência e teclas | C/B quando medido; identidade OEM não significa dispensável | Inventário de serviço/driver e testes das funções; desligar apenas módulo dispensável através do fabricante | Reinstalação/perfis podem ser incompletos. Proteger gestão térmica/energia; Manual |
| Features opcionais Windows, WSL/Hyper-V/Sandbox | Disco; carga depende de VMs/serviços ativos; segurança pode partilhar virtualização | D para desligar feature inativa; E para sacrificar segurança; C para caso de contenção | Recomendar parar workload/VM voluntariamente; separar feature, dependências e segurança. Sem remoção automática | Restart/payload/estado externo limitam recuperação. Manual avançado, fora de perfis |
| Storage Sense/limpeza (88/24) | I/O durante manutenção, espaço recuperado; caches podem ser úteis | D para desligar limpeza permanentemente; E para limpar shaders rotineiramente | Ajustar horário/escopo; manutenção separada, preview de ficheiros e consequências | Ficheiros apagados não têm Undo garantido. Manual, nunca para aumentar artificialmente RAM/FPS |

Fontes de comportamento: [políticas Edge background](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled), [Startup Boost](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled), [Windows Search](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/windows-search-performance-issues), [serviços por utilizador](https://learn.microsoft.com/en-us/windows/application-management/per-user-services-in-windows), [Delivery Optimization](https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/delivery-optimization-in-windows). Os contratos de política específicos devem ser revalidados antes da implementação; a tabela não constitui uma allowlist pronta.

## 4. Componentes protegidos

Proteger por regra inicial Windows servicing/Update, Defender e segurança, Store e mecanismos de instalação/licenciamento, runtimes partilhados, frameworks AppX, WebView2, componentes Xbox/Gaming Services necessários, shell/login, rede, áudio, input, drivers, anti-cheats e gestão OEM de energia/refrigeração. Uma lista de nomes nunca basta: resolver dependências e componentes partilhados.

Não remover Gaming Services, Game Bar ou bibliotecas por corresponderem ao texto “Xbox”. Não remover WebView2 por ser utilizado por Widgets: outras aplicações podem depender dele. Não desativar serviços de fabricante por um padrão `Nv*`, `AMD*` ou equivalente. Assinatura válida identifica editor; não prova que algo é dispensável.

48 agrupa `DiagTrack`, `PcaSvc` e `TrkWks`; 71 agrupa diagnóstico e `OneSyncSvc`. São finalidades diferentes. OneSyncSvc sincroniza dados de utilizador e a Microsoft documenta falhas funcionais quando parado. Separar ações e remover linguagem de “diagnóstico silencioso” aplicada ao conjunto. Alterar o template não demonstra o estado das instâncias por utilizador. [Microsoft, serviços por utilizador](https://learn.microsoft.com/en-us/windows/application-management/per-user-services-in-windows).

## 5. Modelo de catálogo proposto

Cada entrada deve conter: ID estável; versão da regra; nome e finalidade; identidade exata/publisher; arquitetura; famílias de build/edição testadas; âmbito máquina/conta/provisionamento; dependências e capacidades protegidas; consumo observado e janela de observação; classe A–E; fontes e datas; pré-condições; método suportado; resultados de pós-verificação; reinício/logoff; riscos; recuperação e prova disponível; estado de validação.

Separar `ConfigurationVerified`, `FunctionVerified`, `RecoveryVerified` e `PerformanceEvidence`. Não criar um booleano único “seguro”. Para apps, registar PFN, PackageFullName, versão, arquitectura, utilizadores, provisionamento, dependências, origem de reinstalação e disponibilidade comprovada. Não guardar dados pessoais dentro do catálogo distribuído.

Pipeline: inventário somente leitura → grafo de dependências → observação opcional durante jogos → proposta explicada → seleção do cliente → plano imutável com hash → revalidação imediata → execução por recurso → pós-verificação independente → relatório e recuperação.

Plano expira quando muda a identidade, versão, política ou instalação. Mudanças externas não são automaticamente adotadas. Não executar comandos derivados de nomes livres ou wildcards apresentados pela UI. Ausente/incompatível/desconhecido têm resultados separados; erro de enumeração nunca significa “não instalado”.

## 6. Reversibilidade por nível

| Nível | O que se pode prometer | Exemplos |
|---|---|---|
| R1 — configuração recuperável | Repor valores originais verificados, salvo conflito externo | Registo tipado, flag Enabled de tarefa com fingerprint, preferência suportada |
| R2 — recuperação funcional condicionada | Reativar serviço/app ou reinstalar componente se fontes/dependências continuarem disponíveis | Arranque de serviço, reinstalação AppX, feature opcional |
| R3 — sem reversão exata | Efeito omitido ou dados apagados não são reconstruídos | Clips não gravados, tarefa não executada, cache/dados eliminados |

R1 não significa restaurar o estado temporal completo do Windows. Mesmo serviços com baseline correta não recuperam ligações, notificações ou tarefas perdidas. AppX deve mostrar separadamente recuperação do pacote, dados e provisionamento. Nunca prometer “100% reversível” por haver ponto de restauro. Para remoção avançada sem payload validado, permitir apenas fluxo que explique reinstalação incerta e peça escolha informada no produto; não vender como Undo.

## 7. Validação de produto

Testar numa VM descartável: múltiplas contas; conta elevada diferente; pacote ausente; framework partilhado; app em uso; dependência protegida; instalação interrompida; Store indisponível; licença indisponível; atualização de app entre preview e Apply; falta de espaço; remoção parcial; reversão com conflito. Confirmar Store, Xbox/Game Pass quando presentes, notificações, pesquisa, Bluetooth/áudio, impressão e Windows Update após cada lote.

Em hardware, medir um cenário sem carga concorrente e outro com carga plausível e reproduzível. Se só o segundo melhora, o produto deve recomendar apenas quando identifica aquela carga. Publicar espaço recuperado separadamente de CPU/RAM reduzidos e das métricas de jogo.

Primeira versão do novo debloat: inventário/preview, preferências de background e arranque em poucos adapters testados. Segunda: desinstalação por conta de pacotes explicitamente escolhidos. Terceira: provisionamento e tarefas versionadas. Serviços agressivos não são condição de sucesso de um “debloat profundo”.
