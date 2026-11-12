> Atualização: foram acrescentadas três ações de CPU/Wi-Fi; consultar [POWER-PERFORMANCE](POWER-PERFORMANCE.md). As contagens 13/26/90 abaixo descrevem a primeira entrega.

# Recuperação funcional e perfil de desempenho

Branch `dev/performance-rebuild`, iniciada em main e avançada para o histórico completo de `dev/skyoptimizer-max` antes das correções. Main e a branch anterior permanecem preservadas.

## Comportamento atual

- Sem parâmetros: menu com otimização, painel, Undo, temporários, shaders, reparação, auditoria e plano completo dos 90 IDs.
- `-Apply`: perfil Performance contextual, confirmação dos custos e criação automática do painel com relatório. `-Profile MAX` mantém o modo restrito anterior para comparação.
- Performance reutiliza as sete candidatas condicionais MAX e acrescenta os IDs 1/3/20/25/38/60/74/75/76 em Windows cliente reconhecido e sem indicadores de gestão. Home admite energia/NIC, mas não as políticas Pro/Enterprise/Education de 20/25. Energia e experiências de rede adicionais exigem AC confirmado. Cada setter continua a verificar os requisitos reais antes de escrever.
- Windows 11 Pro, Edge, AC, sem gestão: 13 candidatos (`1,3,16,20,25,38,41,60,70,74,75,76,79`). Uma VM sem NIC física suportada pode recusar vários; não se falsifica suporte para aumentar a contagem.
- O perfil aceita maior consumo/temperatura, perda de notificações UWP e possíveis regressões de rede em troca da experiência agressiva. Não há garantia de ganho. Uma NIC sem offloads pode consumir mais CPU; comparar contra Undo.
- `-Clean`: ficheiros de topo em TEMP e Windows Temp, com mais de sete dias, até 300 por raiz, confirmação, revalidação de idade e contagem de erros. Não percorre subpastas, não chama SilentCleanup em background e não elimina shaders.
- `-CleanShaders`: limpeza separada NVIDIA/DirectX, com confirmação. Recompilação pode causar stuttering.
- Painel conserva aplicação de manutenção no armazenamento protegido para funcionar depois de apagar a pasta inicial. Impressora/Bluetooth e Undo mantêm o motor com baseline. Segurança e localização abrem as Definições do Windows com nomes claros; não simulam alternância.
- Relatório guardado no run mesmo quando criar o painel falha. O BAT conserva exit code e pausa para permitir leitura.

O catálogo de elegibilidade continua com 26 ações: esta entrega amplia a seleção e recupera o produto; não converte os 58 bloqueados em implementações validadas. Os documentos Fase 2–5G e os JSON de provas antigos são históricos, não resultados desta versão. `integration/evidence-performance.json` cobre o alias antigo 9/41/79: **não cobre o novo perfil contextual**. Para integração deste perfil é necessário capturar também energia, AppPrivacy, Delivery Optimization e propriedades reais da NIC, além do superset MAX, antes de Apply.

## Próximas melhorias com maior valor

1. **Encontrar o gargalo durante o jogo.** Associar CPU/GPU/frametimes e atividade de processos à sessão. PresentMon fornece durações e latências por CPU/GPU/display; um contador de processos não substitui essa medição. Reutilizar `benchmarks/`, sem acrescentar um serviço residente ao produto. [Projeto oficial](https://github.com/GameTechDev/PresentMon).
2. **Experiências por grupo com controlo.** Comparar energia, background e NIC separadamente antes do conjunto agressivo. Microsoft descreve o compromisso entre menor latência de interrupção e overhead/throughput: não há fundamento para tratar todos os offloads desligados como melhoria universal. A fonte de tuning é de Windows Server; não certifica gaming desktop. [Microsoft: desempenho de adaptadores](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/performance-in-network-adapters), [tuning NIC](https://learn.microsoft.com/en-us/windows-server/networking/technologies/network-subsystem/net-sub-performance-tuning-nics).
3. **Atuar sobre trabalho concorrente observado.** Priorizar launcher, browser, overlays, gravação e downloads quando aparecem ativos durante os piores frames. Expandir os contratos já existentes por produto, com preview e Undo, em vez de substituir assinaturas por wildcards e terminar processos pelo nome.
4. **Reavaliar ações bloqueadas com benefício plausível.** GPU scheduling e apresentação por jogo/driver; energia por topologia/limites térmicos; serviços por atividade/dependências. Preferências de interface podem ser recuperadas como preferências, sem afirmar FPS. AppX exige recuperação de pacotes/dados antes da remoção automatizada.

Critério para promover uma receita: A/A para medir ruído, A/B repetido, jogo/cena e versões constantes, reinício quando necessário, FPS/1% low/frametimes e regressões. VM valida instalação, alterações e Undo; hardware físico valida desempenho. Não foram executadas otimizações no computador de desenvolvimento nem benchmarks físicos nesta entrega.
