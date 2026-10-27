# Perfis de desenvolvimento

Os perfis já são executáveis no programa existente, pela opção 8 ou por parâmetros. São deliberadamente limitados às ações cuja escrita/reversão foi migrada. Não representam certificação de desempenho, hardware ou compatibilidade com anti-cheat.

| Perfil | Seleção atual | Justificação e compromisso |
|---|---|---|
| Gaming — Balanced | 79 | Configurar Game Mode. Preserva gravação, browsers, serviços, energia, segurança e drivers. Pode já estar conforme. |
| Gaming — Performance | 9, 41, 79 | Acrescenta desativação de capturas/Game DVR e políticas de execução dos browsers em fundo. Visa concorrência de CPU/GPU/memória quando essas funcionalidades estavam ativas. Perde gravação/background e pode tornar o primeiro arranque do browser mais lento. |
| Gaming — Extreme | Performance + IDs explicitamente escolhidos | Ambiente de laboratório: isola experiências mensuráveis. Não acrescenta automaticamente todos os tweaks. Selecionar core parking acrescenta a cópia de energia necessária. Ações sem migração continuam bloqueadas. |

Exemplos para laboratório — **não foram executados no Windows de desenvolvimento**:

```powershell
.\SkyOptimizer.ps1 -Apply -Profile Balanced
.\SkyOptimizer.ps1 -Apply -Profile Performance
.\SkyOptimizer.ps1 -Apply -Profile Extreme -ExperimentalActions "74"
.\SkyOptimizer.ps1 -Apply -Profile Extreme -ExperimentalActions "3,42"
```

Estes comandos usam o fluxo atual de Apply, incluindo o ponto de restauro e o relatório. Para uma comparação A/B de uma única experiência sem os efeitos do perfil Performance, comparar Performance com Extreme + essa experiência; não comparar com um Windows original e atribuir toda a diferença a um único ID.

Mudar de perfil não desfaz configurações previamente aplicadas. Executar Undo, verificar resultados e reiniciar quando indicado antes de começar outra comparação. `NotSelected` significa fora da seleção; `Deferred` significa selecionada mas bloqueada por migração/compatibilidade pendente. Nenhuma é contabilizada como execução bem-sucedida. Códigos CLI: 0 sem falhas comunicadas, 1 falha, 2 execução/reversão incompleta. Um código 0 não certifica ganhos de desempenho.

## Condições reais

- IDs migrados nesta entrega: **1, 3, 6, 8, 9, 13, 16, 17, 19, 20, 25, 38, 41, 42, 48, 58, 59, 60, 70, 71, 74, 75, 76, 79, 84, 86, 88, 90**. Preferências e compatibilidade não se transformam em otimizações de FPS pela seleção explícita.
- 58/70/84 só entram por escolha explícita em Extreme. 58 é HKLM consumer experiences, Enterprise/Education conhecidas >=17134; 84 é HKCU Spotlight, mesmas edições >=15063; 70 é HKLM OnlineTips, também Pro conhecida >=16299. Pro não recebe 58/84, Home não recebe nenhuma das três. Guardam/restauram apenas o valor gerido com ownership explícito. Não escrevem CDM ou DisableSoftLanding. A conta HKCU pertence ao processo elevado; consumo real das políticas continua por testar. Ver [contratos e consolidação 3C](FASE3C.md).
- 16/59/88/90 foram migradas offline na Fase 3B e só entram por escolha explícita. 16 requer Windows 11 >=22000; 59 cliente >=14393 e apps longPathAware; 88 >=18362; 90 >=17763. A matriz de políticas conserva os SKUs conhecidos Pro/N, Enterprise/N/LTSC e Education/N. Apenas 59 admite Home conhecida. Não há integração real destas ações ainda. Ver [limites e matriz](FASE3B.md).
- 8 é uma experiência de diagnóstico AC no plano isolado, com dependência 1. Não escreve em hubs/dispositivos. A Microsoft recomenda conservar a suspensão seletiva; só comparar para um problema identificado de idle/retoma. DC fica preservado; consumo e temperatura podem aumentar. Alimentação Unknown/DC bloqueia escritas AC, incluindo core parking. Verificação repetida antes de cada escrita; alterações parciais conservam a baseline para Undo.
- 25 usa a política AppPrivacy de background das Windows apps, mantendo exceções por pacote e notificando o risco de perder notificações/sincronização. Não controla todos os processos Win32. Reutiliza a matriz conservadora de edições/build de 19/20; é escolha explícita em Extreme.
- 19/20 são escolhas explícitas de laboratório. Exigem build ≥ 15063, cliente Windows 10/11 e SKU conhecido Pro/N, Enterprise/N/LTSC ou Education/N. Home, Server e outras variantes ficam fora desta matriz conservadora. 19 exclui drivers das atualizações de qualidade, sem bloquear todos os métodos de instalação. 20 impede peering, sem impedir downloads HTTP ou garantir ping inferior. Não modificam serviços, SearchOrderConfig nem limites de cache.
- 41 verifica instalação e versão nos caminhos habituais: Edge ≥ 88; Chrome ≥ 19. Instalações noutros caminhos ficam por detetar. Políticas são escritas apenas uma vez em HKLM. Não se afirma que foram aplicadas por browsers ainda em execução nem se estima RAM libertada.
- 42 exige build ≥ 22621 e mantém as flags gráficas alheias. É experimental: o armazenamento interno `DirectXUserGlobalSettings` não constitui um contrato público de compatibilidade. Validar no Windows e no jogo. Foram retirados os overrides FSE concorrentes dessa ação.
- NIC: físico, ativo, identidade e driver confirmados; valor `0` suportado pela propriedade existente. Flow Control/EEE/DMA são limitados a Ethernet. Só a configuração persistida foi verificada; reinício e teste do hardware continuam necessários.
- SysMain já não é desativado automaticamente por uma inferência SSD/HDD ou pelo nome do disco. Só entra por escolha explícita para comparação.
- Não existem receitas automáticas por marca de CPU/GPU. Topologias híbridas, X3D, portáteis e drivers ainda precisam de ensaios físicos. HAGS/MSI continuam bloqueados, sem inferir capacidade por VRAM ou fabricante. A implementação indiscriminada de hubs USB (39) foi retirada; o ID histórico não executa alterações. Ver [investigação](HARDWARE-3A.md).
- VBS/HVCI e requisitos de anti-cheat não são alterados por estes perfis.
- IDs 12/14/30/39/54 estão retirados. Selecioná-los devolve Deferred com motivo específico, sem alterar QoS, flags internas CDM, timeouts, hubs ou avisos de disco. 14 foi consolidada em 58 com alcance mais limitado e documentado. Os IDs históricos permitem rastreabilidade; não são experiências a reativar por conveniência.
- 26/56/68 continuam bloqueadas. O mecanismo ScheduledTaskEnabled aceita apenas fixtures explícitas num namespace de laboratório; não existe allowlist de tarefas reais. Não foi adicionado um perfil de desativação automática de manutenção/telemetria.
- A escrita de configurações de Game DVR/Game Mode é verificável no registo; consumo efetivo pelo Windows e benefícios exigem validação. A documentação de AllowGameDVR contém limitações de edição/versão; não se assume que a política é imposta universalmente em Windows 11.

Fontes: [Game Mode nas definições](https://support.microsoft.com/en-us/accessibility/windows/understand-and-explore-windows-settings), [AllowGameDVR](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement#allowgamedvr), [Edge StartupBoostEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled), [Edge BackgroundModeEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled), [definição Chromium de BackgroundModeEnabled](https://raw.githubusercontent.com/chromium/chromium/main/components/policy/resources/templates/policy_definitions/Miscellaneous/BackgroundModeEnabled.yaml), [otimizações para jogos em janela](https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11).
