# Perfis de desenvolvimento

Os perfis já são executáveis no programa existente, pela opção 8 ou por parâmetros. São deliberadamente limitados às ações cuja escrita/reversão foi migrada. Não representam certificação de desempenho, hardware ou compatibilidade com anti-cheat.

| Perfil | Seleção atual | Justificação e compromisso |
|---|---|---|
| Gaming — Balanced | 79 | Configurar Game Mode. Preserva gravação, browsers, serviços, energia, segurança e drivers. Pode já estar conforme. |
| Gaming — Performance | 9, 41, 79 | Acrescenta captura no contrato Windows 10 conhecido e políticas dos browsers em fundo. Pode reduzir concorrência quando existe atividade relevante; ganhos não medidos. Em Windows 11, 9 comunica Incompatible e preserva captura. Políticas dos browsers podem perder funções background e tornar o primeiro arranque mais lento. |
| Gaming — Extreme | Performance + IDs explicitamente escolhidos | Conserva a herança de Performance; não isola por si uma intervenção contra Windows original. Não acrescenta todos os tweaks. 3/8 acrescentam a cópia de energia 1. Ações bloqueadas continuam bloqueadas. |
| Laboratory | Apenas IDs explícitos e dependências | Seleção não vazia, sem 9/41/79 implícitas. Resolve somente dependências necessárias, atualmente 1 para 3/8. Usa o mesmo dispatcher, diário e Undo. |

Exemplos para laboratório — **não foram executados no Windows de desenvolvimento**:

```powershell
.\SkyOptimizer.ps1 -Apply -Profile Balanced
.\SkyOptimizer.ps1 -Apply -Profile Performance
.\SkyOptimizer.ps1 -Apply -Profile Extreme -ExperimentalActions "74"
.\SkyOptimizer.ps1 -Apply -Profile Extreme -ExperimentalActions "3,42"
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "41,79"
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "8"
```

Estes comandos usam o fluxo atual de Apply, incluindo o ponto de restauro e o relatório. Para isolar uma experiência, usar Laboratory e registar as dependências; o exemplo 8 seleciona 1/8. Alternativamente, comparar Performance com Extreme + experiência. Não atribuir a um ID toda a diferença entre Windows original e Extreme. Laboratory 41/79 permite estudar browsers/Game Mode sem pedir alterações de captura.

Mudar de perfil não desfaz configurações previamente aplicadas. Executar Undo, verificar resultados e reiniciar quando indicado antes de começar outra comparação. `NotSelected` significa fora da seleção; `Deferred` significa selecionada mas bloqueada por migração/compatibilidade pendente. Nenhuma é contabilizada como execução bem-sucedida. Códigos CLI: 0 sem falhas comunicadas, 1 falha de ação/painel, 2 execução/reversão incompleta, incluindo seleção incompatível. Aplicação de apenas parte das propriedades comunica Unverified. Um código 0 não certifica ganhos de desempenho.

Undo de energia conserva cópias Sky cujo conteúdo externo não pode excluir, reativa o original e comunica Unverified/código 2. Não elimina cópias para fazer coincidir a lista de planos com a baseline. Confirmar plano ativo/índices e arquivar cópias conservadas antes de comparar resultados. Programa e painel autónomo não podem manter sessões concorrentes; fechar o menu principal primeiro.

A [auditoria da Fase 4](FASE4.md) registava 28 elegíveis. A [Fase 5C](FASE5C.md) suspendeu 48/71: **26 elegíveis, 58 bloqueadas, cinco retiradas e uma manutenção**, com maturidades diferentes e nenhuma validação real.

## Condições reais

- IDs elegíveis nesta entrega: **1, 3, 6, 8, 9, 13, 16, 17, 19, 20, 25, 38, 41, 42, 58, 59, 60, 70, 74, 75, 76, 79, 84, 86, 88, 90**. Preferências e compatibilidade não se transformam em otimizações de FPS pela seleção explícita. Ações antes descritas como escolha explícita em Extreme também podem ser selecionadas em Laboratory.
- 9 exige Windows cliente conhecido, build 15063–21999 e SKU admitido pela matriz conservadora Pro/Enterprise/Education. Home, Server, build desconhecida e Windows 11 são recusados antes das cinco escritas. Performance/Extreme continuam a solicitar 9; em Windows 11 a execução comunica Incompatible/código 2, embora outras ações possam aplicar. Nenhuma flag interna substituta foi inventada.
- 48/71 não entram em Apply: os grupos juntavam finalidades diferentes e 71 não distinguia o template OneSyncSvc das instâncias por conta. Chamadas diretas também devolvem Deferred. O Undo de diários anteriores continua disponível. 49 continua bloqueada; o menu 9 oferece preview AppX sem remoção.
- 58/70/84 só entram por escolha explícita em Extreme. 58 é HKLM consumer experiences, Enterprise/Education conhecidas >=17134; 84 é HKCU Spotlight, mesmas edições >=15063; 70 é HKLM OnlineTips, também Pro conhecida >=16299. Pro não recebe 58/84, Home não recebe nenhuma das três. Guardam/restauram apenas o valor gerido com ownership explícito. Não escrevem CDM ou DisableSoftLanding. A conta HKCU pertence ao processo elevado; consumo real das políticas continua por testar. Ver [contratos e consolidação 3C](FASE3C.md).
- 16/59/88/90 foram migradas offline na Fase 3B e só entram por escolha explícita. 16 requer Windows 11 >=22000; 59 cliente >=14393 e apps longPathAware; 88 >=18362; 90 >=17763. A matriz de políticas conserva os SKUs conhecidos Pro/N, Enterprise/N/LTSC e Education/N. Apenas 59 admite Home conhecida. Não há integração real destas ações ainda. Ver [limites e matriz](FASE3B.md).
- 8 é uma experiência de diagnóstico AC no plano isolado, com dependência 1. Não escreve em hubs/dispositivos. A Microsoft recomenda conservar a suspensão seletiva; só comparar para um problema identificado de idle/retoma. DC fica preservado; consumo e temperatura podem aumentar. Alimentação Unknown/DC bloqueia escritas AC, incluindo core parking. Verificação repetida antes de cada escrita; alterações parciais conservam a baseline para Undo.
- 25 usa a política AppPrivacy de background das Windows apps, mantendo exceções por pacote e notificando o risco de perder notificações/sincronização. Não controla todos os processos Win32. Reutiliza a matriz conservadora de edições/build de 19/20; é escolha explícita em Extreme.
- 19/20 são escolhas explícitas de laboratório. Exigem build ≥ 15063, cliente Windows 10/11 e SKU conhecido Pro/N, Enterprise/N/LTSC ou Education/N. Home, Server e outras variantes ficam fora desta matriz conservadora. 19 exclui drivers das atualizações de qualidade, sem bloquear todos os métodos de instalação. 20 impede peering, sem impedir downloads HTTP ou garantir ping inferior. Não modificam serviços, SearchOrderConfig nem limites de cache.
- 41 verifica instalação e versão nos caminhos habituais: Edge ≥ 88; Chrome ≥ 19. Instalações noutros caminhos ficam por detetar. Políticas são escritas apenas uma vez em HKLM. Não se afirma que foram aplicadas por browsers ainda em execução nem se estima RAM libertada.
- 42 exige build ≥ 22621 e mantém as flags gráficas alheias. É experimental: o armazenamento interno `DirectXUserGlobalSettings` não constitui um contrato público de compatibilidade. Validar no Windows e no jogo. Foram retirados os overrides FSE concorrentes dessa ação.
- NIC: exatamente um candidato físico e ativo após os filtros, identidade e driver confirmados; valor `0` suportado pela propriedade existente. Flow Control/EEE/DMA são limitados a Ethernet. Só a configuração persistida foi verificada; reinício e teste do hardware continuam necessários.
- SysMain já não é desativado automaticamente por uma inferência SSD/HDD ou pelo nome do disco. Só entra por escolha explícita para comparação.
- Não existem receitas automáticas por marca de CPU/GPU. Topologias híbridas, X3D, portáteis e drivers ainda precisam de ensaios físicos. HAGS/MSI continuam bloqueados, sem inferir capacidade por VRAM ou fabricante. A implementação indiscriminada de hubs USB (39) foi retirada; o ID histórico não executa alterações. Ver [investigação](HARDWARE-3A.md).
- VBS/HVCI e requisitos de anti-cheat não são alterados por estes perfis.
- IDs 12/14/30/39/54 estão retirados. Selecioná-los devolve Deferred com motivo específico, sem alterar QoS, flags internas CDM, timeouts, hubs ou avisos de disco. 14 foi consolidada em 58 com alcance mais limitado e documentado. Os IDs históricos permitem rastreabilidade; não são experiências a reativar por conveniência.
- 26/56/68 continuam bloqueadas. O mecanismo ScheduledTaskEnabled aceita apenas fixtures explícitas num namespace de laboratório; não existe allowlist de tarefas reais. Não foi adicionado um perfil de desativação automática de manutenção/telemetria.
- A escrita de configurações de Game DVR/Game Mode é verificável no registo; consumo efetivo pelo Windows e benefícios exigem validação. AllowGameDVR não é usado como contrato funcional no Windows 11. O diagnóstico offline informa revisão humana; não muda automaticamente estes perfis por carga, fabricante ou quantidade de RAM.

Fontes: [Game Mode nas definições](https://support.microsoft.com/en-us/accessibility/windows/understand-and-explore-windows-settings), [AllowGameDVR](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement#allowgamedvr), [Edge StartupBoostEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled), [Edge BackgroundModeEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled), [definição Chromium de BackgroundModeEnabled](https://raw.githubusercontent.com/chromium/chromium/main/components/policy/resources/templates/policy_definitions/Miscellaneous/BackgroundModeEnabled.yaml), [otimizações para jogos em janela](https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11).

## Preparação para VM — Fase 5A

A seleção automática de Balanced/Performance/Extreme, a seleção exata Laboratory e as dependências são verificadas por regressão. Um ID bloqueado explicitamente pedido continua a produzir Deferred; não passa a ser elegível por aparecer na seleção. O template independente cobre os dez valores pedidos por Performance (e Balanced como superset); no Windows 11 os cinco valores de 9 devem permanecer iguais. Extreme/Laboratory requerem conferir e alargar o escopo observado antes de Apply. Ver [procedimento e aceitação](FASE5A.md). Nenhum ganho foi medido.
