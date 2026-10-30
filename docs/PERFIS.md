# MAX e compatibilidade dos perfis técnicos

A [Fase 5F](FASE5F.md) acrescenta inventário, CPU Sets e avaliação individual das 26 ações. Background seletivo é laboratório separado, não um novo perfil nem seleção automática MAX. `-Diagnose` agora inclui estes leitores; `-DryRun` conserva o plano leve.

A Fase 5E substitui o menu de perfis pelo modo MAX. Sem parâmetros ou com `-Apply`, o programa prepara um plano condicionado ao contexto, confirma impactos, usa o motor existente e termina sem instalar painel. MAX não herda Extreme nem seleciona as 26 ações só por terem implementação de Apply/Undo. Ver [decisões, limites e validação](FASE5E.md).

## Seleção automática

São candidatos os IDs 9/16/41/58/70/79/84. A matriz Windows/edição/build filtra políticas; a deteção de versões filtra browsers. Domínio/indicador MDM ou leitura desconhecida excluem políticas e arranque automáticos, conservando apenas 79 quando o Windows é conhecido. Ausência dos indicadores não prova ausência de gestão; o operador confirma a condição. Energia DC/Unknown não é interpretada como AC. CPU/GPU/RAM são inventário, sem inferência de gargalo de gaming.

Os contratos Spotify/Steam só retiram entradas HKCU Run exatas e reconhecidas após confirmação. Não pertencem aos 90 IDs. AppX/serviços agrupados/tarefas reais continuam bloqueados. Políticas configuradas e menos entradas de arranque não demonstram ganhos de desempenho.

```powershell
# Apenas em laboratório autorizado para Apply/Undo.
.\SkyOptimizer.ps1 -DryRun
.\SkyOptimizer.ps1 -Diagnose
.\SkyOptimizer.ps1 -DebloatPreview
.\SkyOptimizer.ps1 -Apply
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "41,79"
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "8"
.\SkyOptimizer.ps1 -Undo
```

DryRun/Diagnose devolvem JSON sem criar diários ou locks e sem elevação automática. O contexto da conta elevada é refeito para Apply. Laboratory usa apenas IDs explícitos; 3/8 acrescentam a dependência 1. Laboratory 41/79 permite estudar browsers/Game Mode sem captura ou as restantes decisões MAX.

## Aliases de compatibilidade

Balanced continua a selecionar 79; Performance seleciona 9/41/79; Extreme acrescenta IDs explícitos a Performance. Estes nomes preservam scripts e regressões existentes; não são modos comerciais. As chamadas CLI também terminam sem painel/pausa final. Laboratory não herda estas ações. O catálogo conserva os nomes históricos em `PerfisAtuais` e acrescenta `MAX: condicional` aos sete candidatos.

Mudar a seleção não desfaz configurações anteriores. Antes de outra comparação, executar Undo, verificar resultados e reiniciar quando indicado. `NotSelected` significa fora da seleção; `Deferred` significa selecionada mas bloqueada. Códigos: 0 configuração comunicada sem falhas, 1 falha, 2 execução/reversão incompleta. Nenhum certifica FPS ou consumo efetivo pelo componente. MAX conserva `max_run.json` para identificar tentativa/fim e código; outros relatórios podem ser de uma tentativa anterior se houver cancelamento precoce.

Undo de energia conserva cópias cujo conteúdo externo não pode excluir, reativa o original e comunica Unverified/código 2. Confirmar plano/índices e arquivar cópias antes de comparar. Programa e painel autónomo não podem manter sessões concorrentes.

A Fase 5C suspendeu 48/71: **26 elegíveis, 58 bloqueadas, cinco retiradas e uma manutenção**. A Fase 5E mantém estas contagens, com maturidades diferentes e nenhuma validação real.

## Condições reais

- IDs elegíveis nesta entrega: **1, 3, 6, 8, 9, 13, 16, 17, 19, 20, 25, 38, 41, 42, 58, 59, 60, 70, 74, 75, 76, 79, 84, 86, 88, 90**. Preferências e compatibilidade não se transformam em otimizações de FPS pela seleção explícita. Ações antes descritas como escolha explícita em Extreme também podem ser selecionadas em Laboratory.
- 9 exige Windows cliente conhecido, build 15063–21999 e SKU admitido pela matriz conservadora Pro/Enterprise/Education. Home, Server, build desconhecida e Windows 11 são recusados antes das cinco escritas. MAX exclui 9 no Windows 11. Os aliases Performance/Extreme continuam a solicitar 9; em Windows 11 a execução comunica Incompatible/código 2, embora outras ações possam aplicar. Nenhuma flag interna substituta foi inventada.
- 48/71 não entram em Apply: os grupos juntavam finalidades diferentes e 71 não distinguia o template OneSyncSvc das instâncias por conta. Chamadas diretas também devolvem Deferred. O Undo de diários anteriores continua disponível. 49 continua bloqueada; `-DebloatPreview` oferece preview AppX sem remoção.
- 58/70/84 podem entrar em MAX segundo a matriz e os indicadores de gestão, ou por escolha explícita técnica. 58 é HKLM consumer experiences, Enterprise/Education conhecidas >=17134; 84 é HKCU Spotlight, mesmas edições >=15063; 70 é HKLM OnlineTips, também Pro conhecida >=16299. Pro não recebe 58/84, Home não recebe nenhuma das três. Guardam/restauram apenas o valor gerido com ownership explícito. Não escrevem CDM ou DisableSoftLanding. A conta HKCU pertence ao processo elevado; consumo real das políticas continua por testar. Ver [contratos e consolidação 3C](FASE3C.md).
- 16/59/88/90 foram migradas offline na Fase 3B. MAX pode selecionar 16; 59/88/90 continuam escolhas explícitas técnicas. 16 requer Windows 11 >=22000; 59 cliente >=14393 e apps longPathAware; 88 >=18362; 90 >=17763. A matriz de políticas conserva os SKUs conhecidos Pro/N, Enterprise/N/LTSC e Education/N. Apenas 59 admite Home conhecida. Não há integração real destas ações ainda. Ver [limites e matriz](FASE3B.md).
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
- A escrita de configurações de Game DVR/Game Mode é verificável no registo; consumo efetivo pelo Windows e benefícios exigem validação. AllowGameDVR não é usado como contrato funcional no Windows 11. O diagnóstico temporal offline informa revisão humana; MAX não associa IDs anónimos de telemetria a aplicações nem muda a seleção por carga, fabricante ou quantidade de RAM.

Fontes: [Game Mode nas definições](https://support.microsoft.com/en-us/accessibility/windows/understand-and-explore-windows-settings), [AllowGameDVR](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement#allowgamedvr), [Edge StartupBoostEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled), [Edge BackgroundModeEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled), [definição Chromium de BackgroundModeEnabled](https://raw.githubusercontent.com/chromium/chromium/main/components/policy/resources/templates/policy_definitions/Miscellaneous/BackgroundModeEnabled.yaml), [otimizações para jogos em janela](https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11).

## Preparação para VM

Seleção MAX, aliases, Laboratory e dependências têm testes de regressão com mocks. Um ID bloqueado explicitamente pedido continua Deferred. `integration/evidence-max.json` cobre 16 valores: todas as políticas possíveis de MAX e as duas entradas Run. Capturar este superset antes de Apply, mesmo quando alguns recursos não serão selecionados; estes devem permanecer iguais. Um teste compara o escopo com setters simulados e recursos lidos pelos contratos de arranque.

O template histórico Performance cobre dez valores; não cobre MAX nem experiências adicionais de Laboratory. Conservar o procedimento de snapshots privados, leitura independente e comparação da [Fase 5A](FASE5A.md), usando o escopo MAX e a sequência atual da [Fase 5E](FASE5E.md). No Windows 11 os valores de 9 devem permanecer iguais. Antes de ampliar uma experiência, ampliar também a observação Before. Nenhum ganho foi medido.
