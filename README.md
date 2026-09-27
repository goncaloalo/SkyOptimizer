# SkyOptimizer 🚀

> **Toolkit Autónomo, Não-Destrutivo e 100% Reversível de Otimização Windows 10 e 11.**  
> Focado em máxima performance, menor latência de input e estabilidade de frametimes no FiveM e jogos competitivos.

O **SkyOptimizer** é um utilitário consolidado num **único ficheiro PowerShell autocontido** (`SkyOptimizer.ps1`), sem qualquer dependência externa ou pastas adicionais de módulos. Foi concebido especificamente para suporte e otimização remota via **AnyDesk** (máquinas de clientes com jogos, aplicações de trabalho e dados instalados), sem quebrar funcionalidades essenciais nem deixar ficheiros bloqueados no computador.

---

## 🛡️ Pilares de Segurança e Confiabilidade

1. **Ponto de Restauro Automático (`System Restore`):** Cria um ponto de restauro (`SkyOptimizer Pre-Tweak`) antes de efetuar qualquer alteração. Remove nativamente a restrição de frequência de 24h do Windows para permitir pontos a qualquer momento.
2. **Backups de Registo Individuais (`.reg`):** Antes de cada modificação, a chave original é exportada via `reg export` para a pasta `.\Backups\`.
3. **Registo de Chaves Criadas (`created_keys.txt`):** Se uma chave ou valor não existia previamente, é registada para que a reversão a elimine de raiz em vez de tentar restaurar ficheiros inexistentes.
4. **Manifesto de Estado (`state_backup.json`):** Armazena o plano de energia original, estado da hibernação, modo do SysMain, estado do Armazenamento Reservado e histórico de execução.
5. **Reversão Completa Integrada (UNDO):** Restaura todo o registo, serviços e parâmetros de hardware ao estado original através da opção `[5]` do menu ou com o parâmetro `.\SkyOptimizer.ps1 -Undo`.
6. **Reversão Total de 1 Clique:** O cliente dispõe de um atalho direto no Ambiente de Trabalho para restaurar 100% dos ficheiros de registo e configurações originais da máquina com segurança absoluta.
7. **Regras Estritas de Hardware & Anti-Cheat:**
   - **VBS / HVCI Seguro & Guia de Jogos:** O script base não força alterações cegas de VBS. O cliente dispõe do utilitário `[4] Alternar Isolamento do Nucleo (VBS e Jogos).cmd` com uma lista abrangente de compatibilidade de jogos para alternar quando quiser.
   - **Modo MSI Exclusivo:** Aplicado estritamente à GPU dedicada (NVIDIA/AMD) com prioridade padrão (`Undefined`). NUNCA em controladores de áudio, USB ou rede.
   - **Deteção de Energia:** Otimizações de rede (EEE) e portas USB operam exclusivamente em Desktop ou quando ligado à tomada (AC Power), preservando a bateria de portáteis.
   - **HAGS Inteligente:** Só é ativado em sistemas com $\ge$ 6 GB de VRAM dedicada real (64-bit) e drivers WDDM 2.7+.

---

## 📊 Relatório de Impacto (Antes vs. Depois)

No final de cada sessão, o SkyOptimizer calcula o delta real do sistema e grava o resumo num ficheiro `Relatorio_Otimizacao.txt` dentro do Painel do Cliente:

```text
================================================================================
                    SkyOptimizer - Relatório de Impacto (Antes vs. Depois)
================================================================================
  Data/Hora:     25/09/2026 16:45:10
  Computador:    DESKTOP-CLIENTE
  Sistema:       Microsoft Windows 11 Pro
  Núcleo VBS:    Ativado (Valorant / CS2 no FACEIT Suportados)
--------------------------------------------------------------------------------
  Métrica                      Antes             Depois            Impacto Real
  ------------------------------------------------------------------------------
  Processos Ativos:            188               124               -64 processos
  Memória RAM em Uso:          5.80 GB           3.40 GB           -2.40 GB libertados
  Espaço Livre Disco C:        42.10 GB          51.70 GB          +9.60 GB recuperados
  Resolução de Temporizador:   15.6 ms (Padrão)  0.5-1.0 ms        Estabilizado (DynamicTick Off)
  Modo de Interrupção GPU:     Partilhado        Modo MSI          Prioridade Exclusiva Ativa
================================================================================
  Comunidade & Suporte SkyOptimizer:
  Dúvidas ou novos setups? Dá um salto no nosso Discord:
  👉 https://discord.gg/cE8ZaDRGV5
================================================================================
```

---

## 🖥️ Painel do Cliente no Ambiente de Trabalho

Ao aplicar a otimização, o SkyOptimizer gera automaticamente a pasta:  
📁 **`SkyOptimizer - Painel de Controlo`**

Contendo 5 utilitários essenciais com **elevação automática de Administrador** (UAC) e execução com **1 clique**:
* **`[1] Reverter Todas as Otimizacoes.cmd`** — Executa o motor leve de reversão (`SkyRevert.ps1`), restaurando 100% das definições originais da máquina com segurança e proteção total de propriedade intelectual (zero exposição de código de tuning).
* **`[2] Alternar Impressora (Ligar-Desligar).cmd`** — Liga ou desliga o serviço de impressão `Spooler` na hora.
* **`[3] Alternar Bluetooth (Ligar-Desligar).cmd`** — Liga ou desliga os serviços Bluetooth (para comandos sem fios Xbox/PS5 ou auscultadores).
* **`[4] Alternar Isolamento do Nucleo (VBS e Jogos).cmd`** — Permite alternar o VBS com o guia abrangente de compatibilidade (desativar para FiveM/CS2/Warzone/Fortnite/Apex/Rust/Tarkov/ARC Raiders; ativar para VALORANT/LoL/CS2 no FACEIT).
* **`[5] Limpar Shaders e Caches de Jogos.cmd`** — Rotina rápida de manutenção mensal para eliminar micro-stutters causados por caches corrompidas de DirectX, NVIDIA e jogos.
* **`Relatorio_Otimizacao.txt`** — Comprovativo detalhado de RAM libertada, processos reduzidos e GBs recuperados.
* **`LÊ-ME (Suporte SkyOptimizer).txt`** — Guia amigável com suporte, instruções dos atalhos e oportunidade exclusiva de agendamento de sessão VIP de BIOS & Hardware Tuning.

---

## ⚡ As 90 Otimizações Incluídas (v2.8)

### 1. Sistema & Desempenho (Kernel & Power)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **1** | **Plano de Energia 'Desempenho Máximo'** | Ativa o esquema *Ultimate Performance*, garantindo clock de CPU sem quedas de frequência. |
| **2** | **Resolução Global de Temporizador & Dynamic Tick** | `GlobalTimerResolutionRequests=1` e `disabledynamictick=yes`. Reduz jitter de frametimes. |
| **3** | **Desativação de Core Parking** | Define índice mínimo para 100%, eliminando latência de acordar núcleos de CPU. |
| **4** | **Desativação de Hibernação** | Remove `hiberfil.sys`, recuperando vários gigabytes de disco imediatamente. |
| **5** | **Desativação de Fault Tolerant Heap (FTH)** | Desativa o FTH (`HKLM\SOFTWARE\Microsoft\FTH`), eliminando micro-stutters. |
| **6** | **SysMain (Superfetch) Inteligente** | Desativa em SSD/NVMe (poupa ciclos e escritas); mantém ativo em HDD mecânico. |

### 2. Input & Gaming
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **7** | **Desativação de Aceleração do Rato & Curva MarkC 1:1** | Desativa o *Enhanced Pointer Precision*, define sensibilidade neutra 6/11 e aplica a curva MarkC 1:1 linear. |
| **8** | **Desativação de Suspensão Seletiva USB & Controladores** | Impede portas USB de entrarem em micro-suspensão e remove poupança de energia nos controladores (estabilidade a 1000Hz-8000Hz). |
| **9** | **Desativação de Xbox Game DVR / Game Bar** | Desativa captura e codificação de vídeo de fundo, libertando recursos da GPU. |

### 3. Rede & Latência
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **10** | **Algoritmo de Nagle (TCPNoDelay & TCPAckFrequency)** | Força envio imediato de pacotes de dados sem acumular buffer, estabilizando o ping. |
| **11** | **Network Throttling Index & SystemResponsiveness** | `NetworkThrottlingIndex=0xFFFFFFFF` e `SystemResponsiveness=10`, priorizando tráfego de jogos. |
| **12** | **Remoção de Limite de Banda Reservada QoS** | `NonBestEffortLimit=0`, disponibilizando 100% da banda para a aplicação em primeiro plano. |

### 4. Privacidade & Telemetria
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **13** | **Telemetria Básica/Necessária** | Nível Básico (`AllowTelemetry=1`). Preserva Windows Update e Microsoft Store 100% funcionais. |
| **14** | **Desativação de Sugestões e Anúncios** | Remove recomendações de apps patrocinadas no Menu Iniciar. |
| **15** | **Desativação de Pesquisa Web Bing no Iniciar** | Limita pesquisas no Iniciar a ficheiros e programas locais (instantâneo e privado). |
| **16** | **Desativação de Widgets e Feeds de Notícias** | Desativa widgets do Win11 e notícias do Win10 (`AllowNewsAndInterests=0`). |

### 5. Explorador de Ficheiros
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **17** | **Exibição de Extensões de Ficheiros** | Torna extensões conhecidas visíveis (`.exe`, `.ps1`, `.bat`, etc.) para transparência. |
| **18** | **Desativação de Arquivamento Automático de Apps** | Impede compressão ou desinstalação de componentes de apps em segundo plano. |

### 6. Controlo Inteligente de Windows Update (Modo Estabilidade)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **19** | **Bloqueio de Substituição de Drivers GPU** | Impede o Windows Update de sobrescrever drivers NVIDIA/AMD (`ExcludeWUDriversInQualityUpdate=1`). |
| **20** | **Desativação de P2P da Otimização de Entrega** | `DODownloadMode=0`, eliminando picos de ping causados por uploads P2P de atualizações. |
| **21** | **Atualização Manual e Sem Reinícios Forçados** | Notificação manual sem reinícios forçados enquanto joga (`NoAutoRebootWithLoggedOnUsers=1`). |

### 7. Armazenamento, I/O & Limpeza de Disco
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **22** | **Desativação de Armazenamento Reservado** | Liberta **7 GB a 10 GB úteis no disco C:** via DISM (`/Set-ReservedStorageState /State:Disabled`). |
| **23** | **Otimização de Sistema de Ficheiros NTFS** | `disablelastaccess=1` e `disable8dot3=1`. Reduz overhead de I/O em carregamento de texturas. |
| **24** | **Limpeza de Caches e Shaders** | Limpa caches DirectX (`D3DSCache`), NVIDIA (`DXCache`), temporários órfãos e corre `SilentCleanup`. |

### 8. Processos em Segundo Plano (Debloat Não-Destrutivo)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **25** | **Desativação de Aplicações UWP em Background** | `GlobalUserDisabled=1`. Poupa RAM/CPU sem quebrar funcionamento manual das apps. |
| **26** | **Desativação de Diagnóstico SleepStudy** | Desativa registo contínuo de diagnósticos de suspensão (`wevtutil`), poupando escritas em disco. |
| **27** | **Desativação do Windows Error Reporting (WER)** | Desativa relatórios pesados de crashes em background, eliminando congelamentos repentinos. |

### 9. Agilidade do Sistema & Qualidade de Vida (QoL)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **28** | **Eliminação de Delays de Interface e Menus** | `MenuShowDelay=0`, tornando a navegação e menus do Windows instantâneos. |
| **29** | **Arranque Imediato de Aplicações Pós-Login** | `StartupDelayInMSec=0`, eliminando o delay imposto pelo Explorer no login. |
| **30** | **Encerramento Rápido do Sistema** | `HungAppTimeout=2000` e `WaitToKillServiceTimeout=2000`, reduzindo timeout para 2 segundos. |
| **31** | **Alt-Tab Limpo** | Configura Alt-Tab para mostrar apenas janelas abertas reais, sem separadores do Edge. |
| **32** | **Atalho 'Terminar Tarefa' na Barra de Tarefas** | Ativa opção nativa de encerrar processos congelados pelo menu de contexto (Win11). |
| **33** | **Desativação do Microsoft Copilot** | Desativa processos WebView e telemetria do Copilot em background. |
| **34** | **Desativação de Popups de Sticky Keys** | Desativa atalhos de 5x Shift, FilterKeys e ToggleKeys para evitar saídas acidentais de jogo. |

### 10. Escalonamento de CPU & Latência Gráfica (Fase 2)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **35** | **Escalonamento de CPU para Jogos (Win32PrioritySeparation)** | `0x26` (38 decimal: quantum curto, variável, 3:1 de foco no jogo ativo sem sufocar o Discord). |
| **36** | **Prioridade Multimédia MMCSS para Jogos** | Configura a tarefa `Games` com prioridade GPU 8, prioridade 6, agendamento High e SFIO High. |
| **37** | **HAGS Condicional (Hardware-Accelerated GPU Scheduling)** | Ativa `HwSchMode=2` **apenas** em GPUs dedicadas NVIDIA/AMD com $\ge$ 6 GB de VRAM real e WDDM 2.7+. |

### 11. Hardware, Rede & Periféricos (Baixa Latência)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **38** | **Desativação de Energy Efficient Ethernet (EEE) na Placa de Rede** | Desativa micro-suspensões (`*EEE`, `*GreenEthernet`, etc.) em adaptadores físicos (Desktop/AC). |
| **39** | **Desativação de Poupança de Energia nos Hubs USB Raiz** | Desativa `IdleInWorkingState` nos controladores USB Root Hub (Desktop/AC) para estabilidade no rato. |
| **40** | **Modo MSI (Message Signaled Interrupts) na GPU Dedicada** | Configura `MSISupported=1` **exclusivamente na GPU dedicada** (NVIDIA/AMD) com prioridade `Undefined`. |

### 12. Navegadores, Jogos em Janela & Armazenamento Avançado
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **41** | **Desativação de Processos em Fundo de Navegadores** | Desativa o *Startup Boost* e apps em background do Edge e Chrome, libertando 300 a 800 MB de RAM. |
| **42** | **DirectFlip / Otimizações para Jogos em Janela** | Ativa modelo DirectFlip moderno (`SwapEffectUpgradeEnable=1;`) no Windows 11 para latência zero em Borderless. |
| **43** | **Re-Trim Otimizado de Memória Flash em SSDs NVMe** | Executa `ReTrim` no disco C: se detetado como SSD, prevenindo engasgos no streaming de texturas no FiveM. |

### 13. Otimizações de Elite (Rede, Explorador & Agendador)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **44** | **Desativação de Protocolo LLMNR na Rede** | `EnableMulticast=0`, eliminando pacotes broadcast desnecessários e ruído na rede local. |
| **45** | **Desativação de Sniffing de Pastas no Explorador** | `FolderType=NotSpecified`, eliminando o atraso/barra verde ao abrir pastas pesadas e FiveM. |
| **46** | **Bloqueio de Acordar por Manutenção Automática** | `WakeUp=0`, impedindo o Windows de acordar o PC da suspensão para tarefas pesadas noturnas. |

### 14. Debloat Profundo & svchost (Atlas Tweaks)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **47** | **Agrupamento de Processos svchost.exe** | `SvcHostSplitThresholdInKB=0x40000000`, agrupando serviços partilhados e cortando 40 a 70 processos e 200-400 MB de RAM. |
| **48** | **Desativação de Serviços de Telemetria Ocultos** | Desativa `DiagTrack`, `PcaSvc` e `TrkWks` (eliminação de popups, I/O inútil e telemetria de diagnóstico). |
| **49** | **Remoção Segura de Bloatware Pré-instalado** | Remove Clipchamp, Disney+, Bing News/Weather, Feedback Hub, etc. Preserva 100% da Microsoft Store, Xbox e Gaming Services. |

### 15. Kernel, Memória & I/O Avançado (Atlas Engine)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **50** | **Kernel em RAM & Desativação de Page Combining** | `DisablePagingExecutive=1` (mantém o kernel NT e drivers em RAM física, eliminando page faults/stutters) e `DisablePageCombining=1` (desativa thread de desduplicação de memória). |
| **51** | **Indexação Windows Search Sensível a Planos de Energia** | `RespectPowerModes=1` (`Gather\Windows\SystemIndex`), forçando o motor de pesquisa a pausar indexação pesada durante jogos ou planos de alto desempenho. |
| **52** | **Remoção de Estrangulamento de Largura de Banda SMB** | `DisableBandwidthThrottling=1` em `LanmanWorkstation\Parameters`, eliminando limitação artificial de taxa de transferência de ficheiros e streaming em rede. |
| **53** | **Desativação de Gesto Aero Shake** | `DisallowShaking=1` em `Explorer\Advanced`, impedindo a minimização acidental de Discord, OBS ou janelas do jogo em movimentos rápidos de rato/mira. |
| **54** | **Desativação de Sondagem de Pouco Espaço em Disco** | `NoLowDiskSpaceChecks=1` em `Policies\Explorer`, eliminando o thread de verificação periódica de partições e popups invasivos em jogos. |
| **55** | **Controlo de Falhas BSOD (Diagnóstico Visível)** | `AutoReboot=0` e `DisplayParameters=1` em `CrashControl`, permitindo ver o código de erro e driver problemático sem reiniciar instantaneamente. |

### 16. Telemetria Silenciosa, Agendador & Caminhos Longos (Atlas Engine)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **56** | **Desativação de Tarefas Agendadas de Telemetria e Disco** | Desativa 5 tarefas pesadas de agendador (`Consolidator`, `UsbCeip`, `PcaPatchDbTask`, `DiskDiagnosticDataCollector`, etc.) e remove telemetria crítica do `Ubpm`. |
| **57** | **Desativação de Histórico de Atividades & Tracing de Diagnóstico** | `UploadUserActivities=0`, `PublishUserActivities=0`, `DisableDiagnosticTracing=1` e `CEIPEnable=0`. |
| **58** | **Bloqueio de Instalação Silenciosa de Apps (ContentDeliveryManager)** | Bloqueia downloads e sugestões automáticas de jogos/apps patrocinadas em segundo plano. |
| **59** | **Ativação de Caminhos Longos de Ficheiro Win32** | `LongPathsEnabled=1` em `FileSystem`, eliminando o limite legado de 260 caracteres para ficheiros de mods e texturas do FiveM. |
| **60** | **Desativação de DMA Coalescing em Placas de Rede** | Define `*DMACoalescing=0` em adaptadores de rede, eliminando atrasos de buffer e micro-latência em pacotes de rede (documentado pela Intel). |

### 17. Interface, Janelas & Multimédia (Atlas Engine)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **61** | **Expansão da Cache de Ícones do Explorador** | `Max Cached Icons="4096"` em `Windows\CurrentVersion\Explorer`. Expande de 500 KB para 4 MB, eliminando recarregamentos contínuos de ícones e travamentos de pastas. |
| **62** | **Desativação de Atenuação de Áudio (Audio Ducking)** | `UserDuckingPreference=3` em `Multimedia\Audio`. Impede que o Windows reduza o som do jogo em 80% quando alguém fala no Discord, FiveM ou TeamSpeak. |
| **63** | **Menu de Contexto Clássico Instantâneo no Windows 11** | Chave CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}`. Devolve o menu clássico instantâneo sem atrasos nem necessidade de clicar em "Mostrar mais opções". |
| **64** | **Desativação de Animações de Janelas e Barra de Tarefas** | `MinAnimate=0` e `TaskbarAnimations=0`. Elimina atrasos gráficos no Alt-Tab e minimização, mantendo a nitidez de tipos de letra 100% intacta. |
| **65** | **Qualidade Máxima de Papel de Parede (100% JPEG)** | `JPEGImportQuality=100` em `Control Panel\Desktop`. Desativa a compressão padrão de 85% do Windows, garantindo imagem nítida sem artefactos de compressão. |
| **66** | **Desativação de Gestos de Extremidade do Ecrã (Edge Swipe)** | `AllowEdgeSwipe=0` em `Policies\Microsoft\Windows\EdgeUI`. Previne a ativação acidental de menus laterais durante movimentos rápidos de mira/rato em jogos. |

### 18. Firmware, Diagnóstico & Serviços Adicionais (Atlas Engine)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **67** | **Bloqueio de Injeção de Bloatware da BIOS/Firmware (WPBT)** | `DisableWpbtExecution=1` em `Session Manager`. Impede que a motherboard/BIOS injete instaladores e bloatware (Armoury Crate, Vantage) na inicialização do Windows. |
| **68** | **Desativação de Telemetria e Relatórios em Fundo da NVIDIA** | `OptInOrOutPreference=0` e desativação das tarefas agendadas `\NvTm*`. Reduz processos de diagnóstico em background preservando o NVIDIA Control Panel e GeForce Experience. |
| **69** | **Desativação de Inquéritos e Pedidos de Feedback (SIUF)** | `DoNotShowFeedbackNotifications=1` e `NumberOfSIUFInPeriod=0`. Bloqueia inquéritos invasivos de satisfação do Windows e sondagens do utilizador. |
| **70** | **Desativação de Dicas Online e Promoções Cloud nas Definições** | `AllowOnlineTips=0` e `DisableSoftLanding=1`. Impede a app Definições de contactar servidores remotos para descarregar conteúdos promocionais e ajuda. |
| **71** | **Desativação de Serviços de Diagnóstico Silencioso** | Desativa com salvaguarda reversível em JSON os serviços `diagnosticshub.standardcollector.service`, `wercplsupport` e o template `OneSyncSvc`. |
| **72** | **Desativação de GameBarPresenceWriter em Fundo** | `ActivationType=0` na classe COM de presença de jogos. Impede que o processo seja instanciado em segundo plano no arranque de cada jogo, eliminando micro-stutters. |

### 19. Rede Competitiva, Hitreg & Resposta de Movimento (Hardware & TCP)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **73** | **Otimização de Taxa e Delay de Repetição do Teclado (Strafe Seguro)** | `KeyboardDelay="0"` e `KeyboardSpeed="31"` em `Control Panel\Keyboard`. Elimina latência no início de repetição de teclas do Windows sem corromper digitação ou backspace no Discord, browser ou chat. |
| **74** | **Desativação de Moderação de Interrupções na Placa de Rede (ITR Off)** | `*InterruptModeration="0"` na interface de rede física. Força o hardware de rede a interromper a CPU no instante milimétrico em que os pacotes UDP chegam, eliminando buffer em fila de espera. |
| **75** | **Desativação de RSC e LSO na Rede (Ticks Puros sem Agregação)** | `Disable-NetAdapterRsc` e `Disable-NetAdapterLso`. Impede que a placa de rede agrupe múltiplos segmentos TCP/UDP em grandes blocos, assegurando que cada tick de jogo é processado em tempo real sem desfasamentos visuais/hitbox. |
| **76** | **Desativação de Controlo de Fluxo na Rede (Flow Control Off / Anti-Bufferbloat)** | `*FlowControl="0"`. Evita o envio e receção de tramas PAUSE em routers/switches domésticos, prevenindo engarrafamentos de pacotes e o efeito de atraso em tiroteios e esquinas. |
| **77** | **Expansão de Portas Efémeras e Reciclagem de Sockets (MaxUserPort & WaitDelay)** | `MaxUserPort=65534` e `TcpTimedWaitDelay=30` em `Tcpip\Parameters`. Expande a capacidade para 65534 portas e reduz o tempo de retenção de sockets obsoletos de 240s para 30s, prevenindo exaustão de conexões. |
| **78** | **Otimização da Pilha TCP Global (Timestamps/ECN Off & Proteção AutoTuning)** | Desativa `timestamps` e `ecncapability` desnecessários via Netsh TCP, garantindo e protegendo `autotuninglevel=normal` para manter velocidades máximas de fibra (500M/1Gbps). |

### 20. Modo de Jogo & Apresentação Gráfica (FSO)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **79** | **Ativação do Modo de Jogo Nativo do Windows (Game Mode)** | `AutoGameModeEnabled=1` em `SOFTWARE\Microsoft\GameBar`. Prioriza alocação de GPU e agendamento de threads de CPU exclusivamente para o jogo ativo, suspendendo tarefas de manutenção de fundo do Windows. |
| **80** | **Otimização de Ecrã Inteiro e Apresentação (FSEBehaviorMode=2)** | `GameDVR_FSEBehaviorMode=2` em `System\GameConfigStore`. Desativa o hooking forçado de Fullscreen Optimizations híbridas, eliminando conflitos de taxa de atualização (Hz) e micro-atrasos de apresentação em jogos DirectX 9/11. |

### 21. Estabilidade de Frametimes & Otimizações Cirúrgicas
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **81** | **Desativação de Power Throttling do Windows (Prioridade Contínua no Discord/OBS)** | `PowerThrottlingOff=1` em `SYSTEM\CurrentControlSet\Control\Power\PowerThrottling`. Impede o Windows de cortar frequências e prioridades de threads auxiliares (Discord, OBS, FiveM subprocessos) enquanto o jogo corre. |
| **82** | **Desativação de Indexação de Ficheiros Comprimidos (.zip/mods no Windows Search)** | `PreventIndexingArchives=1` em `SOFTWARE\Policies\Microsoft\Windows\Windows Search`. Impede o descompactar e indexar em segundo plano de ficheiros `.zip` e pacotes de mods/assets, eliminando picos de CPU e leituras de SSD. |
| **83** | **Otimização de Sombras do DWM e Compositor Gráfico (Sem Sombras / Texto Nítido)** | Desativa sombras decorativas sob janelas e ponteiro do rato no DWM, mantendo o *ClearType / FontSmoothing* ativo a 100% para máxima legibilidade com menos overhead gráfico. |
| **84** | **Bloqueio de Downloads em Background do Windows Spotlight no LockScreen** | Desativa tarefas e transferências de conteúdo patrocinado e wallpapers do Bing via `ContentDeliveryManager` e políticas de CloudContent. |
| **85** | **Acesso Rápido Limpo sem Histórico Contínuo no SSD (Menos Escritas)** | `ShowRecent=0` e `ShowFrequent=0` em `Software\Microsoft\Windows\CurrentVersion\Explorer`. Elimina escritas desnecessárias no journaling do SSD a cada ficheiro acedido e torna a abertura do Explorador instantânea. |

### 22. Latência Extrema & Resposta de Fundo
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **86** | **Desativação de Telemetria de Localização e Sensores (Serviço lfsvc Off)** | Desativa o serviço `lfsvc` e as políticas `LocationAndSensors`. Elimina varreduras em segundo plano de redes Wi-Fi e sondagens por IP para estimativa de localização. |
| **87** | **Desativação de Aplicações Pré-Lançadas Especulativamente (ApplicationPreLaunch Off)** | `Disable-MMAgent -ApplicationPreLaunch`. Impede o Windows de injetar instâncias silenciosas de apps UWP em RAM antes de serem abertas, poupando ciclos de CPU e RAM. |
| **88** | **Desativação de Varreduras em Segundo Plano do Storage Sense (StoragePolicy Off)** | `01=0` em `StorageSense\Parameters\StoragePolicy`. Impede varreduras e limpezas automáticas no disco durante sessões de jogo, eliminando picos de I/O em SSDs. |
| **89** | **Desativação de Broadcasts Legados NetBIOS sobre TCP/IP (NetBT Off)** | `NetbiosOptions=2` em todas as interfaces ativas. Elimina o ruído de pacotes broadcast periódicos UDP (portas 137/138) na rede local, mantendo a navegação e resolução DNS puras. |
| **90** | **Desativação de Sincronização da Área de Transferência na Cloud (Clipboard Local)** | `AllowCrossDeviceClipboard=0` em `Policies\Microsoft\Windows\System`. Mantém o histórico local de copiar/colar (Win+V) a funcionar perfeitamente, mas bloqueia o envio contínuo de dados para a cloud. |

---

## 🚀 Como Executar

### 1. Modo Rápido (1-Clique via AnyDesk)
Dê duplo clique no ficheiro **`Executar-SkyOptimizer.bat`**.  
O iniciador solicita automaticamente privilégios de Administrador (UAC), define a política de execução e abre o menu interativo com codificação UTF-8.

---

### 2. Modo Interativo (PowerShell Manual)
1. Abra uma janela de **PowerShell como Administrador**.
2. Se necessário, permita a execução de scripts temporariamente:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. Execute o script:
   ```powershell
   .\SkyOptimizer.ps1
   ```
4. O menu interativo exibirá a ficha técnica do computador (incluindo tipo de disco, plano de energia e estado de VBS):
   ```text
   ================================================================================
     ____  _            ___        _   _           _              
    / ___|| | _____   _/ _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __ 
    \___ \| |/ / | | | | | | '_ \| __| | '_ ` _ \| |_  / _ \ '__|
     ___) |   <| |_| | |_| | |_) | |_| | | | | | | |/ /  __/ |   
    |____/|_|\_\\__, |\___/| .__/ \__|_|_| |_| |_|_/___\___|_|   
                |___/      |_|                                    
                    Windows 10/11 Performance Toolkit
                             Versão: 2.8.0
   ================================================================================
     Dispositivo:   MEU-PC
     Sistema:       Windows 11 Pro
     Processador:   AMD Ryzen 7 5800X
     Placa Gráfica: NVIDIA GeForce RTX 3070 (8 GB VRAM)
     Memória RAM:   32 GB
     Disco do SO:   SSD (NVMe)
     Plano Energia: Desempenho Máximo
     Núcleo VBS:    Ativado (Valorant / CS2 no FACEIT Suportados)
   ================================================================================
   [1] Aplicar Otimizações Completas (90 Tweaks)
   [2] Gerar 'Painel do Cliente' no Ambiente de Trabalho
   [3] Inspeção do Técnico (Hardware, XMP, Hz do Ecrã & Arranque)
   [4] Limpeza de Caches e Shaders
   [5] Reverter Alterações (100% Desfazer)
   [6] Reparar Integridade do Windows (DISM / SFC)
   [7] Sair
   ================================================================================
   ```

---

### 3. Automação via Linha de Comando
* **Aplicar todas as 90 otimizações e gerar o Painel do Cliente:**
  ```powershell
  .\SkyOptimizer.ps1 -Apply
  ```

* **Instalar exclusivamente o Painel do Cliente no Desktop:**
  ```powershell
  .\SkyOptimizer.ps1 -DeployPanel
  ```

* **Executar Inspeção do Técnico (RAM/XMP, Hz do Monitor, Apps no Arranque):**
  ```powershell
  .\SkyOptimizer.ps1 -Audit
  ```

* **Limpar apenas shaders e temporários:**
  ```powershell
  .\SkyOptimizer.ps1 -Clean
  ```

* **Reverter 100% das alterações efetuadas:**
  ```powershell
  .\SkyOptimizer.ps1 -Undo
  ```

* **Reparar integridade do Windows via DISM e SFC:**
  ```powershell
  .\SkyOptimizer.ps1 -Repair
  ```

---

## 💬 Comunidade & Suporte Oficial SkyOptimizer
Tens dúvidas sobre o teu setup ou queres otimizar outro computador?  
Junta-te à nossa comunidade no Discord:  
👉 **[Discord Oficial SkyOptimizer](https://discord.gg/cE8ZaDRGV5)**

---

## 🔒 Licença & Isenção de Responsabilidade
Este projeto foi desenvolvido para fins profissionais e de otimização de latência em sistemas operativos Windows. Todas as modificações respeitam a integridade do sistema operativo e são 100% reversíveis.
