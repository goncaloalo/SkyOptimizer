# SkyOptimizer — matriz de decisões e oportunidades

Data: 28/10/2026. A matriz avalia a utilidade para gaming, não apenas se uma escrita é possível. **Não altera o catálogo nem autoriza executar ações.**

Estados atuais: **EL** elegível no dispatcher; **BL** bloqueada; **RT** retirada; **MN** manutenção. Classes: **A** benefício experimental no contexto identificado; **B** benefício condicional; **C** experimental; **D** benefício de gaming não demonstrado; **E** receita desproporcionada/contraproducente. Nenhuma linha representa ganho medido pelo SkyOptimizer.

“Retirar receita” é recomendação para desenvolvimento futuro; não significa que o ID já esteja retirado. “Manter manual” conserva uma utilidade funcional, sem promoção para perfil. As letras classificam a receita indicada; uma versão redesenhada pode ter outra classificação.

Prova local **R**: `ACOES-ESTADO.json`, `AUDITORIA-3B.json`, `FASE4-ELEGIVEIS.json`, `FASE4-BLOQUEADAS.json`, Fase 5A e código inspecionado. São evidência de implementação e auditoria, não de eficácia. Referências externas abreviadas estão no final. A seleção de perfis proposta está detalhada no plano adaptativo e no plano de debloat.

## 1. Decisão para cada ID histórico

| ID | Estado | Técnica | Classe | Decisão, condição e prova necessária | Base |
|---:|---|---|---|---|---|
| 1 | EL | Cópia de plano de energia | D | Manter infraestrutura isolada; cópia idêntica não é ganho. Verificar plano original/AC/DC e cópias conservadas | R |
| 2 | BL | Timer global/dynamic tick | D/E | Retirar receita combinada; só investigação de temporização de aplicação com trace e energia | R,T |
| 3 | EL | Desativar core parking AC | C | Laboratório por topologia; medir clocks, temperatura, lows e carga mista; não automático | R,Q |
| 4 | BL | Desativar hibernação | D | Manual para espaço, não gaming; explicar perda de hibernação/Fast Startup e validar estado completo | R |
| 5 | BL | Desativar FTH global | E | Retirar como otimização; diagnóstico de incompatibilidade por aplicação apenas | R |
| 6 | EL | Desativar SysMain | C | Manter laboratório; I/O concorrente provado, cache fria/quente e arranque de apps | R |
| 7 | BL | Aceleração/curvas de rato | D | Redesenhar como preferência via API; não prometer Raw Input ou latência; preservar acessibilidade | R,I |
| 8 | EL | Suspensão USB AC | C | Apenas problema de idle/retoma reproduzido; custo energético e dispositivos testados | R,U |
| 9 | EL | Game DVR/captura | B | Rever contrato Win10/11; perda de clips escolhida, encoder/I/O efetivos e Undo funcional | R,G |
| 10 | BL | Nagle/ACK global | D | Retirar receita de interfaces; identificar TCP do jogo e controlo suportado por aplicação | R,N |
| 11 | BL | NetworkThrottling/MMCSS | C/D | Manter bloqueada; separar mecanismos e provar threads/carga afetadas | R,M |
| 12 | RT | “Recuperar 20% QoS” | D | Manter retirada; não existe banda permanentemente perdida demonstrada | R |
| 13 | EL | Nível de diagnóstico | D | Manual de privacidade; confirmar edição/política, não vender FPS | R |
| 14 | RT | Sugestões/CDM duplicado | D | Manter consolidada em 58; não reintroduzir flags internas por conveniência | R |
| 15 | BL | Bing/Spotlight/search | D | Separar políticas atuais de flags antigas; preferência manual e teste da pesquisa | R |
| 16 | EL | Widgets | D | Manter manual; verificar função e processo, esconder UI não prova menos trabalho | R |
| 17 | EL | Extensões de ficheiro | D | Manter usabilidade; retirar de qualquer contagem de otimizações FPS | R |
| 18 | BL | Arquivamento automático | D | Não migrar flag sem contrato; possível efeito sobre espaço, sem benefício gaming demonstrado | R |
| 19 | EL | Excluir drivers do WU | D | Gestão manual de versão ensaiada; atualizações não podem ficar abandonadas | R |
| 20 | EL | DO sem peering | C | Rever para gestão de banda sob carga; não bloqueia downloads nem assegura ping | R,DO |
| 21 | BL | Update manual/reinícios | E | Rejeitar bloqueio permanente; redesenhar horários/notificações suportados | R |
| 22 | BL | Reserved Storage off | D/E | Não promover para gaming; mais espaço não prova FPS e pode dificultar servicing | R |
| 23 | BL | NTFS last access/8dot3 | D | Manter bloqueada; sem workload específico, não justificar alteração global | R |
| 24 | MN | Limpeza de shaders | E como rotina | Manter reparação manual para corrupção; sem Undo e com recompilação esperada | R,S |
| 25 | EL | Background Windows apps | B | Preferir escopo por app; testar notificações/sync e exceções; não controla todo Win32 | R |
| 26 | BL | SleepStudy/logs | E | Retirar receita gaming; preservar observabilidade e diagnóstico de energia | R |
| 27 | BL | Desativar WER | D/E | Não promover; perde evidência de crashes. Só política manual justificada | R |
| 28 | BL | Delays de interface | D | Preferência manual; confirmar API/estado runtime, não input lag do jogo | R |
| 29 | BL | StartupDelay zero | D | Retirar receita como ganho gaming; pode concentrar carga no login | R |
| 30 | RT | Encerramento forçado | E | Manter retirada; risco de trabalho perdido sem ganho durante jogo | R |
| 31 | BL | Alt-Tab só janelas | D | Manual após contrato por build; medir usabilidade, não FPS | R |
| 32 | BL | Terminar tarefa na barra | D | Conveniência manual; não é otimização | R |
| 33 | BL | Copilot | D/C | Inventariar app atual e startup; política histórica não basta | R |
| 34 | BL | StickyKeys/FilterKeys | E na receita | Substituir sobrescrita de bitmasks por preferência granular com acessibilidade preservada | R |
| 35 | BL | Win32PrioritySeparation | D | Retirar recomendação global; baseline pode já coincidir e efeito depende de threads | R,M |
| 36 | BL | MMCSS Games high | D | Manter corpo sem mutações; campos não usados não são otimização | R,M |
| 37 | BL | HAGS | C | Manter bloqueio até capacidade/estado efetivo e A/B por driver/jogo | R,H |
| 38 | EL | EEE/Green Ethernet | C | Só NIC/rota identificadas e sintoma local; testar energia, latência e link | R,N |
| 39 | RT | Energia hubs indiscriminada | E | Manter retirada; não substituir por outra flag privada | R,U |
| 40 | BL | Forçar MSI GPU | E na receita | Preservar decisões do driver; só diagnóstico de interrupções com documentação específica | R |
| 41 | EL | Browsers background | B | Separar opções, observar carga real e políticas efetivas; preservar uso intencional | R |
| 42 | EL | Otimizações em janela | B função/C escrita | Priorizar diagnóstico/apresentação; armazenamento interno exige contrato e teste por jogo | R,W |
| 43 | BL | ReTrim C: | D | Manutenção suportada por volume, sem promessa de FPS ou Undo; não primeiro disco | R |
| 44 | BL | LLMNR off | D | Política de rede/segurança separada; testar resolução de nomes, não ping gaming | R |
| 45 | BL | Folder sniffing Explorer | D | Preferência/diagnóstico Explorer; não atribuir melhoria de FiveM sem ensaio | R |
| 46 | BL | Maintenance WakeUp off | D | Opção de energia/sono; não impede toda manutenção e não é FPS | R |
| 47 | BL | Agrupar svchost | E | Retirar receita de gaming; menos processos não prova trabalho reduzido e altera isolamento | R |
| 48 | EL | DiagTrack/PcaSvc/TrkWks | D/E como grupo | Separar finalidades; fora de perfis; requer atividade e consequências individualizadas | R |
| 49 | BL | Remoção AppX global | E atual/B futuro | Substituir por inventário/consentimento/conta/dependências; benefício só com carga real | R,Apx |
| 50 | BL | Kernel residente/page combining | D/E | Retirar receita global; preservar gestão de memória e medir pressão real | R,P |
| 51 | BL | Search respeitar energia | B tema/C receita | Confirmar política atual e I/O; preferir escopo de indexação suportado | R,Se |
| 52 | BL | SMB throttling off | D | Só carga SMB relevante; não transportar tuning de servidor para gaming local | R |
| 53 | BL | Aero Shake | D | Manual/usabilidade; sem alegação de desempenho | R |
| 54 | RT | Ocultar disco cheio | E | Manter retirada; não resolve espaço e oculta diagnóstico útil | R |
| 55 | BL | BSOD sem reinício | D | Diagnóstico manual; preservar dumps e recuperação; não otimização | R |
| 56 | BL | Tarefas de manutenção | E receita/C seleção | Manter fixtures; nenhuma tarefa real até allowlist/fingerprint e custo observado | R |
| 57 | BL | Histórico/tracing | D/E | Separar privacidade de tracing; não remover observabilidade genericamente | R |
| 58 | EL | Consumer experiences | D | Manter manual em edições suportadas; não desinstala apps existentes | R |
| 59 | EL | Long paths | D | Manter compatibilidade opt-in de aplicações, não FPS | R |
| 60 | EL | DMA coalescing | C | Experiência NIC/driver; medir carga CPU, latência e energia | R,N |
| 61 | BL | Cache ícones | D | Retirar alegações de eliminar stutter; só problema Explorer comprovado | R |
| 62 | BL | Audio ducking | D | Preferência de áudio via controlo suportado; testar chamadas e aplicações | R |
| 63 | BL | Menu clássico Win11 | D | Personalização, contrato frágil por build; baixa prioridade | R |
| 64 | BL | Animações janelas | D | Preferência visual; responsividade percebida não prova FPS no jogo | R |
| 65 | BL | Wallpaper JPEG 100% | D | Fora do roadmap de desempenho; preferência estética | R |
| 66 | BL | Edge swipe | D | Manual; preservar touch/acessibilidade e compatibilidade | R |
| 67 | BL | WPBT off | E como global | Não usar debloat para bloquear firmware sem avaliação OEM específica | R |
| 68 | BL | Telemetria NVIDIA/tarefas | D/E atual | Manter bloqueio; identificar pacote/tarefas reais e proteger componentes do driver | R |
| 69 | BL | Feedback SIUF | D | Preferência suportada por build; abandonar flags antigas sem contrato | R |
| 70 | EL | Dicas online Settings | D | Manter manual; benefício funcional, não aceleração de jogo | R |
| 71 | EL | Hub/WER/OneSync | E como grupo | Separar serviços e instâncias; não tratar sincronização como diagnóstico dispensável | R,Usr |
| 72 | BL | PresenceWriter off | E | Retirar receita de ativação WinRT interna; preservar reconhecimento/compatibilidade de jogos | R |
| 73 | BL | Repeat teclado/strafe | D | Retirar alegação de strafe/input lag; oferecer apenas preferência de repetição | R,I |
| 74 | EL | Interrupt moderation off | C | Testar só NIC explícita; pode trocar latência por CPU/DPC e piorar jogo | R,N |
| 75 | EL | RSC/LSO off | C | Separar offloads; comparar throughput, CPU e protocolo do jogo; não desligar em massa | R,N |
| 76 | EL | Flow control off | C | Laboratório Ethernet; medir perdas/backpressure; não é solução universal de bufferbloat | R,N |
| 77 | BL | Portas/TTL/TIME_WAIT | D | Retirar receita gaming; só diagnóstico de exaustão real de sockets | R |
| 78 | BL | TCP global ECN/timestamps | D/E | Manter bloqueio; conservar autotuning/ECN conforme plataforma até problema comprovado | R |
| 79 | EL | Game Mode | B | Manter candidato Balanced, mas provar estado funcional e contexto; conformidade não é ganho | R |
| 80 | BL | FSE flags globais | E como global | Retirar receita; testar apresentação por executável usando controlos suportados | R,W |
| 81 | BL | Power throttling off global | E | Retirar global; pesquisar QoS granular de concorrentes com restauração e medição | R,Q |
| 82 | BL | Indexação ZIP | C/D | Confirmar suporte do mecanismo; preferir exclusão de pasta escolhida e efeito observado | R,Se |
| 83 | BL | “Sombras DWM” | D | Corrigir rótulo: preferências de shell/texto não são tuning geral do compositor | R |
| 84 | EL | Spotlight | D | Manter preferência de conta/edição; preservar políticas externas | R |
| 85 | BL | Quick Access/histórico | D | Privacidade/usabilidade, sem afirmação de reduzir stutter ou desgaste relevante | R |
| 86 | EL | Localização/lfsvc | D | Manual, testar aplicações/sensores; não alegar eliminar scans Wi-Fi | R |
| 87 | BL | Prelaunch + AppX policy | D | Manter sem mutações; política de perfis especiais não controla prelaunch | R |
| 88 | EL | Storage Sense off | D/E como perfil | Retirar de gaming; preservar gestão de espaço, configurar manualmente se houver conflito | R |
| 89 | BL | NetBIOS global | D | Manual por interface/rede quando apropriado; sem promessa de latência gaming | R |
| 90 | EL | Clipboard cloud sync | D | Manter privacidade; histórico local preservado, efeito gaming não demonstrado | R |

## 2. Oportunidades fora do catálogo

As oportunidades de diagnóstico não são novos tweaks. Risco/complexidade são relativos: baixo, médio, alto. A recuperação do diagnóstico é simplesmente terminar recolha e apagar dados conforme política; configurações associadas exigem baseline.

| Oportunidade | Classe / natureza | Quando pode ajudar e como refutar | Risco / complexidade / destino |
|---|---|---|---|
| Diagnóstico por frame e processo | B, método documentado | Correlacionar e testar concorrente; refutar se intervenção não altera resultado | Baixo/médio; núcleo do produto |
| Startup/background de terceiros | B, hipótese condicionada | CPU/I/O ativos no jogo; A/B sem concorrente com função preservada | Médio/médio; Performance seletivo |
| Pausa temporária de sync/download | B, mecanismo | Rede/disco saturados; medir cenário sem carga e com carga | Médio/médio; por sessão, opt-in |
| GPU correta em sistema híbrido | B, configuração | Verificar adaptador usado e apresentação/cópias; comparar energia/FPS | Médio/médio; recomendação antes de escrita |
| VRR/cap/V-Sync por objetivo | B | Medir pacing, tearing e latência; pode baixar FPS e melhorar consistência | Médio/médio; por jogo |
| Reflex/Anti-Lag 2 suportados | B, fabricante | Fila GPU em jogo integrado; input instrumentado e frametimes | Baixo/médio; por jogo, sem injeção |
| Upscaling com qualidade escolhida | B | GPU limitada; comparar imagem e FPS renderizados | Baixo/médio; cliente escolhe compromisso |
| Frame generation | B para fluidez/D para equivalência de input | Separar renderizado/gerado e latência; refutar melhoria de controlo sem medida | Médio/médio; opcional |
| Cache shader suficiente | B, fabricante | Evicção/recompilação; repetir runs quentes sem limpeza e controlar espaço | Baixo/médio; recomendação |
| ReBAR em plataforma suportada | B | Capacidade/estado efetivo e A/B; benefício varia com GPU/jogo | Alto para firmware/médio diagnóstico; manual |
| XMP/EXPO/topologia RAM | B, hardware | Memória mal configurada e workload sensível; estabilidade e A/B | Alto para tuning/médio diagnóstico; manual |
| Térmica/boost/limites OEM | B | Queda sustentada correlacionada; testar sessão longa e refrigeração | Baixo diagnóstico/alto alteração; recomendar |
| Polling adaptado a jogo/CPU | B/C | Comparar 1K/4K/8K com movimento, latência e CPU | Baixo/médio; manual por dispositivo |
| EcoQoS de concorrentes | C, API documentada | Reduzir competição sem atrasar tarefa útil; medir todo o workload | Médio/alto; laboratório |
| CPU Sets/SMT/E-cores por jogo | C | Problema de placement demonstrado; teste misto/streaming e novos runs | Alto/alto; laboratório, nunca automático por marca |
| Diagnóstico de DPC/driver | B para método/C para tuning | Reproduzir pico e alterar driver suportado; correlação isolada insuficiente | Médio/alto; investigação |
| Cap por orçamento térmico | C | Portátil oscila sob carga; comparar pacing/potência em sessão longa | Médio/médio; cliente escolhe menor FPS máximo |
| QoS de inatividade em bateria | B para controlar ensaio | Benchmark sem input pode mudar política; registar/igualar condições | Médio/médio; laboratório, não tweak global |
| Índice/pastas de mods | B | Grande volume de ficheiros e I/O concorrente; excluir escopo com teste de pesquisa | Médio/médio; manual |
| SSD/espaço/DirectStorage | B condicional | Espera de assets/I/O; comparar carregamento e streaming, não só média FPS | Baixo diagnóstico/alto migração; recomendar |
| Gestão de tráfego/router | B diagnóstico/C recomendação concreta | RTT sob carga no caminho local/WAN; teste controlado do gargalo | Médio/médio; fora do motor de tweaks |
| Limpar standby/compressão off | D/E | Não adotar; só nova investigação se trace provar problema específico | Alto/baixo código; rejeitada como rotina |
| Desativar VBS/HVCI/Defender | A custo externo/E política | Benefício externo não compensa violar requisito de segurança do produto | Alto; rejeitada em perfis |
| BCD/HPET/TSC forçados | D/E | Não adotar como universal; mecanismos de debug não são tuning provado | Alto; rejeitada como rotina |
| Diagnóstico que recomenda nenhuma mudança | B, estratégia | Baseline já adequada ou diferença inferior à variabilidade | Baixo/médio; resultado de primeira classe |

## 3. Fontes de mecanismo e limites

- **T:** [timeBeginPeriod](https://learn.microsoft.com/en-us/windows/win32/api/timeapi/nf-timeapi-timebeginperiod) — comportamento mudou em Win10 2004/Win11; não prova ganho de FPS. [BCDEdit](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/bcdedit--set) — `useplatformclock` é opção de debugging.
- **M:** [MMCSS](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service) — confirma âmbito e campos sem uso.
- **Q:** [QoS](https://learn.microsoft.com/en-us/windows/win32/procthread/quality-of-service) — scheduling/energia dependem de estado e plataforma; não valida uma regra de gaming.
- **I:** [Raw Input e ponteiro](https://learn.microsoft.com/en-us/windows/win32/dxtecharts/taking-advantage-of-high-dpi-mouse-movement) — não confundir ballistics com latência física.
- **U:** [USB selective suspend](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend) — recomendação explícita de conservar a funcionalidade.
- **G:** [AllowGameDVR](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement#allowgamedvr) — limitação de imposição em Windows 10 desktop.
- **N:** [NIC performance](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/performance-in-network-adapters) — compromisso interrupções/throughput/latência; não prova FPS de um NIC de consumidor.
- **H:** [HAGS](https://devblogs.microsoft.com/directx/hardware-accelerated-gpu-scheduling/) — capacidade e driver, sem promessa geral de melhoria visível.
- **W:** [Windows 11 windowed games](https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11) — funcionalidade suportada não certifica flags internas.
- **S:** [NVIDIA Shader Cache](https://www.nvidia.com/content/Control-Panel-Help/vLatest/en-us/mergedProjects/3D%20Settings/Manage_3D_Settings_%28reference%29.htm) — recompilação e tamanho de cache.
- **P:** [Pagefile](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/introduction-to-the-page-file) — commit e dumps, não regra de FPS.
- **Se:** [Windows Search](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/windows-search-performance-issues) — ajuste de escopo, backoff e custo de reconstrução.
- **Usr:** [Serviços por utilizador](https://learn.microsoft.com/en-us/windows/application-management/per-user-services-in-windows) — função de OneSyncSvc e perdas de funcionalidade.
- **Apx:** [Remoção de provisionamento](https://learn.microsoft.com/en-us/powershell/module/dism/remove-appxprovisionedpackage) — contas existentes separadas de futuras.
- **DO:** [Delivery Optimization](https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/delivery-optimization-in-windows) — controlar partilha não desativa downloads.

As oportunidades adicionais usam também fontes de fabricantes e ensaios descritos no relatório técnico. Nas linhas com apenas R, a recomendação conservadora deriva da inspeção/auditoria e da falta de contrato/benefício demonstrado; não se apresenta como nova medição externa.
