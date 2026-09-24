# SkyOptimizer 🚀

> **Toolkit Autónomo, Não-Destrutivo e 100% Reversível de Otimização para Windows 10 e 11.**

O **SkyOptimizer** é um utilitário consolidado num **único ficheiro PowerShell autocontido** (`SkyOptimizer.ps1`), sem qualquer dependência externa ou pastas adicionais de módulos. Foi concebido especificamente para máquinas de uso diário (máquinas pessoais com jogos, aplicações de trabalho e dados instalados), ao contrário de playbooks agressivos de instalação limpa que removem ficheiros protegidos ou componentes essenciais do Windows.

---

## 🛡️ Pilares de Segurança e Confiabilidade

1. **Ponto de Restauro Automático (`System Restore`):** Cria um ponto de restauro (`SkyOptimizer Pre-Tweak`) antes de efetuar qualquer alteração. Caso a proteção do sistema esteja inativa ou sujeita ao limite de 24h do Windows, o utilizador é avisado com opção de confirmação.
2. **Backups de Registo Individuais (`.reg`):** Antes de cada modificação, a chave original é exportada via `reg export` para a pasta `.\Backups\`.
3. **Registo de Chaves Criadas (`created_keys.txt`):** Se uma chave ou valor não existia previamente, é registada para que a reversão a elimine de raiz em vez de tentar restaurar ficheiros inexistentes.
4. **Manifesto de Estado (`state_backup.json`):** Armazena o plano de energia original, estado da hibernação, modo de inicialização do SysMain e histórico de execução.
5. **Reversão Completa Integrada (UNDO):** Restaura todo o registo, serviços e parâmetros de hardware ao estado original através da opção `[2]` do menu ou com o parâmetro `.\SkyOptimizer.ps1 -Undo`.
6. **Não-Destrutivo:** Zero remoção de ficheiros do sistema (`System32`, `WinSxS`), zero desativação do Windows Update, Windows Defender ou Microsoft Store.

---

## ⚡ As 18 Otimizações Incluídas

### 1. Sistema & Desempenho
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **1** | **Plano de Energia 'Desempenho Máximo'** | Duplica e ativa o esquema *Ultimate Performance* (ou *High Performance*), garantindo frequência estável de CPU e latência mínima sem oscilações agressivas de clock. |
| **2** | **Resolução Global de Temporizador & Dynamic Tick** | Configura `GlobalTimerResolutionRequests=1` no kernel e `disabledynamictick=yes` no BCD. Reduz o jitter de frametimes de forma nativa e persistente, sem necessidade de ferramentas de terceiros em segundo plano. |
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

### 4. Privacidade & Limpeza Leve
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **13** | **Telemetria Básica/Necessária** | Define a política de telemetria para nível Básico (`AllowTelemetry=1`). Mantém o Windows Update e a Microsoft Store 100% funcionais, reduzindo o envio de relatórios de diagnóstico. |
| **14** | **Desativação de Sugestões e Anúncios** | Remove recomendações automáticas de apps, sugestões patrocinadas e dicas de boas-vindas no Menu Iniciar. |
| **15** | **Desativação de Pesquisa Web Bing no Iniciar** | Limita as pesquisas no Menu Iniciar a ficheiros e programas locais, tornando a pesquisa instantânea e sem tráfego de rede para o Bing. |
| **16** | **Desativação de Widgets e Feeds de Notícias** | Desativa os widgets do Windows 11 e o 'Notícias e Interesses' do Windows 10, poupando processos de WebView em segundo plano. |

### 5. Explorador de Ficheiros & Qualidade de Vida
| # | Tweak | Descrição Técnica & Segurança |
|---|-------|--------------------------------|
| **17** | **Exibição de Extensões de Ficheiros** | Ativa a visualização de extensões de todos os ficheiros conhecidos (`.exe`, `.ps1`, `.bat`, etc.) para maior segurança e transparência. |
| **18** | **Desativação de Arquivamento Automático de Apps** | Impede o Windows de comprimir ou desinstalar componentes de aplicações raramente abertas, garantindo arranque imediato quando necessárias. |

---

## 📁 Estrutura do Repositório

```text
SkyOptimizer/
├── Backups/                # Backups de registo (.reg), estado original e chaves criadas (gerados em runtime)
│   └── .gitkeep
├── Logs/                   # Registos timestamped de execução detalhada (gerados em runtime)
│   └── .gitkeep
├── .gitignore
├── README.md
└── SkyOptimizer.ps1        # Ficheiro Único Autocontido (Menu + 18 Tweaks + Reversão / UNDO)
```

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
4. Será exibido o menu interativo:
   ```text
   ========================================
              SkyOptimizer v1.0            
   ========================================
   [1] Aplicar Otimizações
   [2] Reverter Alterações (Desfazer)
   [3] Sair
   ========================================
   Escolha uma opção:
   ```

---

### 2. Automação via Linha de Comando (Sem Menu)
Pode automatizar a execução passando parâmetros diretamente:

* **Aplicar todas as 18 otimizações diretamente:**
  ```powershell
  .\SkyOptimizer.ps1 -Apply
  ```

* **Reverter todas as alterações para o estado original:**
  ```powershell
  .\SkyOptimizer.ps1 -Undo
  ```

---

## 🔒 Licença & Isenção de Responsabilidade
Este projeto foi desenvolvido para fins educacionais e de otimização de latência em sistemas operacionais Windows. Todas as modificações respeitam a integridade do sistema operativo e são 100% revertíveis.
