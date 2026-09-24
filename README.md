# SkyOptimizer 🚀

> **Toolkit Autónomo, Não-Destrutivo e 100% Reversível de Otimização Windows 10 e 11.**  
> Focado em máxima performance, menor latência de input e estabilidade de frametimes no FiveM e jogos competitivos.

O **SkyOptimizer** é um utilitário consolidado num **único ficheiro PowerShell autocontido** (`SkyOptimizer.ps1`), sem qualquer dependência externa ou pastas adicionais de módulos. Foi concebido especificamente para máquinas de uso diário (máquinas pessoais com jogos, aplicações de trabalho e dados instalados), ao contrário de playbooks agressivos de instalação limpa que removem ficheiros protegidos ou componentes essenciais do Windows.

---

## 🛡️ Pilares de Segurança e Confiabilidade

1. **Ponto de Restauro Automático (`System Restore`):** Cria um ponto de restauro (`SkyOptimizer Pre-Tweak`) antes de efetuar qualquer alteração. Remove nativamente a restrição de frequência de 24h do Windows para permitir pontos a qualquer momento.
2. **Backups de Registo Individuais (`.reg`):** Antes de cada modificação, a chave original é exportada via `reg export` para a pasta `.\Backups\`.
3. **Registo de Chaves Criadas (`created_keys.txt`):** Se uma chave ou valor não existia previamente, é registada para que a reversão a elimine de raiz em vez de tentar restaurar ficheiros inexistentes.
4. **Manifesto de Estado (`state_backup.json`):** Armazena o plano de energia original, estado da hibernação, modo do SysMain, estado do Armazenamento Reservado e histórico de execução.
5. **Reversão Completa Integrada (UNDO):** Restaura todo o registo, serviços e parâmetros de hardware ao estado original através da opção `[3]` do menu ou com o parâmetro `.\SkyOptimizer.ps1 -Undo`.
6. **Não-Destrutivo:** Zero remoção de ficheiros protegidos do sistema (`System32`, `WinSxS`), zero desativação total do Windows Update ou Microsoft Store.

---

## ⚡ As 34 Otimizações Incluídas (v2.0)

### 1. Sistema & Desempenho (Kernel & Power)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **1** | **Plano de Energia 'Desempenho Máximo'** | Duplica e ativa o esquema *Ultimate Performance* (ou *High Performance*), garantindo frequência estável de CPU e latência mínima sem oscilações agressivas de clock. |
| **2** | **Resolução Global de Temporizador & Dynamic Tick** | Configura `GlobalTimerResolutionRequests=1` no kernel e `disabledynamictick=yes` no BCD. Reduz o jitter de frametimes de forma nativa e persistente. |
| **3** | **Desativação de Core Parking** | Define o índice de núcleos mínimos para 100% no perfil de energia ativo. Elimina a latência de transição quando núcleos adormecidos são reativados por jogos. |
| **4** | **Desativação de Hibernação** | Executa `powercfg -h off`, libertando imediatamente vários gigabytes de espaço em disco (elimina o ficheiro `hiberfil.sys`). |
| **5** | **Desativação de Fault Tolerant Heap (FTH)** | Desativa a monitorização e injeção do FTH (`HKLM\SOFTWARE\Microsoft\FTH`), eliminando micro-stutters e overhead causados pelo subsistema de análise de crashes. |
| **6** | **SysMain (Superfetch) Inteligente** | Deteta o tipo de disco do sistema. Se for **SSD ou NVMe**, desativa o serviço para poupar ciclos e escritas; se for **HDD mecânico**, mantém o serviço ativo para preservar o desempenho de leitura. |

### 2. Input & Gaming
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **7** | **Desativação de Aceleração do Rato** | Desativa o *Enhanced Pointer Precision* e define thresholds como 0 para garantir resposta linear 1:1 e consistência de mira muscular. |
| **8** | **Desativação de Suspensão Seletiva USB** | Impede o Windows de colocar portas USB e periféricos (rato, teclado, headset, interface de áudio) em modo de poupança de energia, prevenindo micro-atrasos de resposta. |
| **9** | **Desativação de Xbox Game DVR / Game Bar** | Desativa a captura e codificação de vídeo contínua em segundo plano, libertando recursos de GPU/CPU e eliminando stuttering. |

### 3. Rede & Latência
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **10** | **Algoritmo de Nagle (TCPNoDelay & TCPAckFrequency)** | Força a confirmação e envio imediato de pacotes de dados nas interfaces de rede ativas, reduzindo a latência (ping jitter) em jogos online competitivos. |
| **11** | **Network Throttling Index & SystemResponsiveness** | Desativa a limitação imposta pelo Windows a pacotes de rede não multimédia (`NetworkThrottlingIndex=0xFFFFFFFF`) e prioriza jogos (`SystemResponsiveness=0`). |
| **12** | **Remoção de Limite de Banda Reservada QoS** | Define `NonBestEffortLimit=0` no agendador de pacotes QoS, disponibilizando 100% da ligação de rede para aplicações em primeiro plano. |

### 4. Privacidade & Telemetria
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **13** | **Telemetria Básica/Necessária** | Define a política de telemetria para nível Básico (`AllowTelemetry=1`). Mantém o Windows Update e a Microsoft Store 100% funcionais. |
| **14** | **Desativação de Sugestões e Anúncios** | Remove recomendações automáticas de apps, sugestões patrocinadas e dicas de boas-vindas no Menu Iniciar. |
| **15** | **Desativação de Pesquisa Web Bing no Iniciar** | Limita as pesquisas no Menu Iniciar a ficheiros e programas locais, tornando a pesquisa instantânea e sem tráfego de rede para o Bing. |
| **16** | **Desativação de Widgets e Feeds de Notícias** | Desativa os widgets do Windows 11 e o 'Notícias e Interesses' do Windows 10 via Política de Grupo mestre (`AllowNewsAndInterests=0`). |

### 5. Explorador de Ficheiros
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **17** | **Exibição de Extensões de Ficheiros** | Ativa a visualização de extensões de todos os ficheiros conhecidos (`.exe`, `.ps1`, `.bat`, etc.) para maior segurança e transparência. |
| **18** | **Desativação de Arquivamento Automático de Apps** | Impede o Windows de comprimir ou desinstalar componentes de aplicações raramente abertas, garantindo arranque imediato quando necessárias. |

### 6. Controlo Inteligente de Windows Update (Modo Estabilidade)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **19** | **Bloqueio de Substituição de Drivers GPU** | Impede o Windows Update de instalar drivers genéricos antigos por cima de drivers calibrados NVIDIA/AMD (`ExcludeWUDriversInQualityUpdate=1`). |
| **20** | **Desativação de P2P da Otimização de Entrega** | Desativa o upload P2P de atualizações para terceiros (`DODownloadMode=0`), eliminando picos de ping e instabilidade de rede em jogos online. |
| **21** | **Atualização Manual e Sem Reinícios Forçados** | Configura o Windows Update para notificação sem reinícios automáticos intempestivos enquanto o utilizador está em jogo (`NoAutoRebootWithLoggedOnUsers=1`). |

### 7. Armazenamento, I/O & Limpeza de Disco
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **22** | **Desativação de Armazenamento Reservado** | Liberta **7 GB a 10 GB de espaço útil no disco C:** através do DISM (`/Set-ReservedStorageState /State:Disabled`) sem apagar ficheiros do utilizador. |
| **23** | **Otimização de Sistema de Ficheiros NTFS** | Desativa atualizações de carimbo de último acesso (`disablelastaccess=1`) e geração de nomes curtos 8.3 (`disable8dot3=1`), reduzindo drasticamente o overhead de I/O em carregamento de texturas. |
| **24** | **Limpeza Segura de Caches e Shaders** | Limpa caches corrompidos de DirectX (`D3DSCache`), NVIDIA (`DXCache`), ficheiros temporários órfãos e executa o `SilentCleanup` nativo do Windows. |

### 8. Processos em Segundo Plano (Debloat Não-Destrutivo)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **25** | **Desativação de Aplicações UWP em Background** | Impede aplicações da Microsoft Store de acordarem ciclos de CPU/RAM em segundo plano (`GlobalUserDisabled=1`). As apps continuam 100% funcionais quando abertas manualmente. |
| **26** | **Desativação de Diagnóstico SleepStudy** | Desativa o rastreio contínuo de diagnósticos de suspensão e energia (`wevtutil`), poupando escritas desnecessárias em disco. |
| **27** | **Desativação do Windows Error Reporting (WER)** | Desativa relatórios pesados de crashes em segundo plano, eliminando congelamentos e dumps de memória volumosos. |

### 9. Agilidade do Sistema & Qualidade de Vida (QoL)
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **28** | **Eliminação de Delays de Interface e Menus** | Reduz o atraso de abertura de menus de 400ms para 0ms (`MenuShowDelay=0`), tornando a navegação no Windows instantânea. |
| **29** | **Arranque Imediato de Aplicações Pós-Login** | Elimina o atraso artificial de inicialização de programas pós-login (`StartupDelayInMSec=0`). |
| **30** | **Encerramento Rápido do Sistema** | Reduz o tempo limite de espera para processos bloqueados de 20s para 2s (`HungAppTimeout=2000`, `WaitToKillServiceTimeout=2000`). |
| **31** | **Alt-Tab Limpo** | Configura o Alt-Tab para alternar apenas entre janelas abertas reais, sem poluir com separadores individuais do browser Edge (`MultiTaskingAltTabFilter=3`). |
| **32** | **Atalho 'Terminar Tarefa' na Barra de Tarefas** | Ativa a opção nativa no Windows 11 de encerrar jogos ou processos congelados diretamente pelo menu de clique direito da barra de tarefas. |
| **33** | **Desativação do Microsoft Copilot** | Desativa os processos Webview e integrações do Copilot em background para poupar recursos. |
| **34** | **Desativação de Popups de Sticky Keys** | Desativa o popup e atalho de pressionar 5 vezes a tecla Shift, FilterKeys e ToggleKeys (essencial para gaming). |

---

## 🚀 Como Executar

### 1. Modo Interativo (Recomendado)
1. Abra uma janela de **PowerShell como Administrador** (ou clique com o botão direito no `SkyOptimizer.ps1` e selecione **"Executar com o PowerShell"**).
2. Se necessário, permita a execução de scripts temporariamente:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. Execute o script:
   ```powershell
   .\SkyOptimizer.ps1
   ```
4. Será exibido o menu interativo com a ficha técnica de hardware do computador:
   ```text
   ================================================================================
                    Windows 10/11 Performance Toolkit - Versão: 2.0.0
   ================================================================================
     Dispositivo:   MEU-PC
     Sistema:       Windows 11 Pro
     Processador:   AMD Ryzen 7 5800X
     Placa Gráfica: NVIDIA GeForce RTX 3070 (8 GB VRAM)
     Memória RAM:   32 GB
   ================================================================================
   [1] Aplicar Todas as 34 Otimizações
   [2] Limpeza Segura de Caches e Shaders
   [3] Reverter Alterações (Desfazer)
   [4] Sair
   ================================================================================
   Escolha uma opção:
   ```

---

### 2. Automação via Linha de Comando (Sem Menu)
Pode automatizar a execução passando parâmetros diretamente:

* **Aplicar todas as 34 otimizações:**
  ```powershell
  .\SkyOptimizer.ps1 -Apply
  ```

* **Executar apenas a rotina de limpeza de shaders e temporários:**
  ```powershell
  .\SkyOptimizer.ps1 -Clean
  ```

* **Reverter todas as alterações para o estado original:**
  ```powershell
  .\SkyOptimizer.ps1 -Undo
  ```

---

## 🔒 Licença & Isenção de Responsabilidade
Este projeto foi desenvolvido para fins profissionais e de otimização de latência em sistemas operacionais Windows. Todas as modificações respeitam a integridade do sistema operativo e são 100% revertíveis.
