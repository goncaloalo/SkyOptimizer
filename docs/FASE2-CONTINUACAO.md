# Fase 2 — continuação de 21 a 26 de outubro de 2026

Preservados os quatro commits anteriores na branch `dev/phase2-execution-power-safety`. Apenas SkyOptimizer foi modificado. Sem push e sem aplicar otimizações ao Windows de desenvolvimento.

**Estado final desta continuação:** 19/90 ações elegíveis para Apply, manutenção de shaders separada, perfis limitados e analisador offline implementados. **109 testes Pester e 11 testes Python aprovados.** Os números menores ao longo do documento registam os blocos anteriores. Não existe validação física de desempenho ou release pronta para clientes.

## Bloco 2: baseline por valor e Undo sem defaults

O diário `mutation_state.json` guarda máquina, utilizador, vista do registo, existência, tipo e conteúdo original. Guarda intenção antes da escrita; verifica estado após escrita e reversão. Um lock exclusivo protege operações simultâneas. Valores já conformes não passam a pertencer ao programa. Apply repetido conserva a baseline. Valores com alterações externas são preservados e comunicados como conflito. As chaves vazias ficam no registo: não existe remoção recursiva de árvores potencialmente partilhadas.

O Undo principal e o painel utilizam a mesma implementação. Foram retiradas as importações automáticas de chaves inteiras, remoções recursivas de chaves e reposições arbitrárias de registo, serviços, rede, BCD, armazenamento e tarefas. Backups legados ficam intactos; a informação disponível não prova quais os valores efetivamente modificados. Uma nova execução Apply é bloqueada quando existem esses backups. Não existe migração automática que invente informação ausente.

Primeira integração: ações 9, 13, 17 e 79. As restantes ações conservam as funções e os lugares no menu, mas o dispatcher impede ações cuja reversão ainda não foi migrada. Esta barreira evita novas alterações sem reversão. Energia mantém a implementação anterior.

Validação: 63 testes passaram (44 anteriores e 19 novos). Apenas funções carregadas por AST, registo simulado e ficheiros de teste. Cobertura: Apply repetido, Undo repetido, ausência, tipos, strings expansíveis literais, binários, multi-strings, QWORD, falhas antes/depois da escrita, backup falhado, conflitos externos, diário corrupto, máquina/utilizador errados, concorrência e integração Game DVR.

Referências: [tipos de valores do registo](https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registrykey.getvaluekind), [implementação Microsoft de RegistryKey](https://source.dot.net/Microsoft.Win32.Registry/Microsoft/Win32/RegistryKey.cs.html).

## Bloco 3: serviços, propriedades NIC e painel

Serviços usam entradas distintas para estado Running/Stopped e tipo de arranque. O arranque é reposto antes de reiniciar um serviço originalmente ativo. Serviços originalmente parados continuam parados. O API ChangeServiceConfig altera apenas o tipo de arranque: não redefine delayed start, triggers, conta, dependências ou recovery actions. O valor DelayedAutoStart é também observado para detetar conflitos. Não existe Stop-Service -Force nem arranque automático de dependências paradas. Estados transitórios, pausados ou dependentes ativos impedem a aplicação.

Integradas ações 6, 48, 71 e 86. O template OneSyncSvc guarda Start como valor de registo; não se confundem templates com instâncias de serviços por utilizador. Os controlos de impressora e Bluetooth usam o mesmo diário. O segundo clique restaura a baseline desse serviço, sem tocar em rede ou noutros recursos. Não se inventa um modo de arranque para serviços que já estavam desativados.

As ações 38, 60, 74, 75 e 76 deixaram de percorrer e alterar indiscriminadamente a classe de rede ou usar wildcard para desativar offloads. Exigem adaptador físico ativo, GUID, PnPDeviceID, versão do driver, vínculo da chave NetCfgInstanceId e valores publicados pelo driver. Apenas propriedades já existentes são alteradas. A baseline preserva tipo e conteúdo. Renomear o adaptador não impede Undo; mudança de dispositivo/driver impede uma reversão insegura. Ethernet é identificado pelo tipo físico, não pelo nome comercial.

Estas alterações de NIC são persistidas no registo e verificadas, sem reiniciar interfaces. Exigem reinício; ainda não provam o estado efetivo do hardware. TCP global (78) fica isolado sem executar netsh: a captura textual anterior não sustentava uma reversão exata. O Undo não executa resets globais de TCP, RSC, LSO ou RSS.

Os atalhos VBS e localização conservam os seus lugares, mas não executam as antigas alternâncias sem baseline. VBS depende ainda de validação de arranque e anti-cheat; localização pode ser restaurada pelo Undo geral. A preparação do ponto de restauro já não ativa a proteção do sistema nem modifica silenciosamente a política de frequência.

Validação deste bloco: **76 testes passaram**, incluindo 13 novos testes de serviços/NIC, compilação das declarações C# sem invocar o API nativo e parsing do painel gerado. Falta integração numa instalação Windows descartável e num NIC real de laboratório.

Fontes: [serviços e dependências](https://learn.microsoft.com/en-us/powershell/scripting/samples/managing-services), [delayed auto-start](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-scmr/805b8296-863d-4d1e-8ae8-f639adf8c6cb), [metadados de propriedades NIC](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapteradvancedproperty).

## Bloco 4: perfis, apresentação e manutenção

Foram implementados os perfis no menu existente e na CLI, com argumentos preservados após elevação. Balanced seleciona 79; Performance seleciona 9, 41 e 79; Extreme acrescenta apenas experiências indicadas por ID. A ação 3 acrescenta automaticamente a dependência 1. Não existe seleção automática por fabricante, CPU híbrido/X3D ou anti-cheat. Os perfis não desfazem alterações anteriores: usar Undo e verificar a baseline antes de comparar.

A ação 41 passa a usar políticas únicas em HKLM, com deteção de versões de Edge/Chrome, eliminando duplicação HKCU. A ação 42 preserva outras flags gráficas, recusa configurações ambíguas e alterações concorrentes, e elimina overrides FSE sobrepostos. Continua experimental: escrever uma flag interna não prova que o Windows a consumiu. A ação 6 perde a inferência incorreta de SSD/HDD e fica exclusivamente experimental.

A ação 24 torna-se manutenção explícita de diagnóstico. Preserva caches por omissão, confirma a intenção, limita os ficheiros aos diretórios conhecidos e verifica cada remoção. Não limpa temporários nem executa SilentCleanup. O atalho antigo do painel explica a suspensão da limpeza automática. Apagar caches não tem Undo e pode provocar recompilação/stuttering.

O painel usa a mesma pasta central de backups. Não copia a baseline sobre si própria, não substitui baselines divergentes nem elimina scripts mestre existentes. O script de Undo é publicado por escrita atómica. A remoção de atalhos obsoletos usa caminhos literais, evitando interpretar os parênteses retos como wildcards.

O diário distingue uma restauração efetiva de um recurso já no estado original. Novos testes cobrem falha na persistência final depois de Apply/Undo, sem perder a capacidade de recuperação. A CLI comunica falhas ou execução incompleta, em vez de terminar sempre com sucesso.

## Bloco 5: análise offline de benchmarks

`benchmarks/analyze.py` e `benchmarks/manifest.example.json` implementam análise de capturas já recolhidas, sem executar jogos ou alterar Windows. O manifesto identifica ambiente, versão da captura, tipo de intervalo e frame generation. O analisador exige intervalos válidos em milissegundos, separa processos/swap chains por filtros e calcula hash dos dados analisados.

O resultado contém FPS médio, 1% low com definição explícita, percentis, histograma, picos e dispersão entre runs. Não mistura frames de diferentes runs como ensaios independentes. Assinala amostras curtas, poucas repetições e capturas reutilizadas; não conclui causalidade ou significância. O ficheiro de saída não substitui resultados existentes.

`benchmarks/tests/test_analyze.py`: **11 testes sintéticos aprovados**, Python 3.14.5. Não existem resultados físicos antes/depois. Telemetria CPU/GPU, sensores, captura ETW e latência de entrada não são inferidos a partir dos frametimes. Procedimento completo e limitações em [BENCHMARKS.md](BENCHMARKS.md).

## Catálogo de execução

O catálogo [ACOES-ESTADO.json](ACOES-ESTADO.json) conserva **90 IDs únicos**, finalidade, decisão da auditoria, requisitos, estado de implementação e elegibilidade de execução. Nesta etapa, **17 ações estão migradas para Apply**: 1, 3, 6, 9, 13, 17, 38, 41, 42, 48, 60, 71, 74, 75, 76, 79 e 86. A ação 24 foi revista como manutenção separada. As restantes ações mantêm o código para revisão, mas o dispatcher impede execução sem migração. Isto não significa que todas as 90 ações tenham sido corrigidas ou certificadas.

### Bloco 6: políticas de drivers e Delivery Optimization

As ações **19 e 20** passam a usar o diário por valor, elevando para **19** o número de ações elegíveis. Continuam fora de Balanced/Performance, disponíveis apenas por seleção explícita em Extreme. Teste integrado confirma Apply repetido, Undo, ausência original e preservação das configurações alheias.

19 altera apenas `ExcludeWUDriversInQualityUpdate`; deixa `SearchOrderConfig` intacto. É uma política de exclusão de drivers das atualizações de qualidade, não um bloqueio de toda a instalação de drivers. Pode ajudar a manter uma versão já ensaiada, mas também adiar correções: gerir atualizações de drivers continua necessário. [Microsoft: política de drivers](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update#excludewudriversinqualityupdate).

20 altera apenas `DODownloadMode=0`. Retira a escrita redundante de `DOMinDiskSizeAllowedToPeer`, sem apagar um valor já existente. O modo HTTP-only exclui peers; permite downloads HTTP e Connected Cache. Pode reduzir partilha P2P concorrente, mas não limita downloads nem garante menor ping. Pode aumentar tráfego WAN onde peers locais seriam úteis. [Microsoft: modos de transferência](https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference), [política DODownloadMode](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-deliveryoptimization#dodownloadmode).

Ambas verificam versão 10.0 (Windows 10/11), build mínima 15063, ProductType cliente e SKUs explicitamente enumerados: Pro/N, Enterprise/N/LTSC e Education/N. Home, Server, edições desconhecidas e falha na deteção não originam escritas. Esta matriz conservadora não cobre todas as variantes que a Microsoft documenta, incluindo IoT e Pro for Workstations. [Identificadores de produto](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getproductinfo).

A pós-verificação confirma o registo; consumo pelo serviço, precedência GPO/MDM e efeitos em jogos continuam dependentes de integração. Medir versão do driver, tráfego de atualização/P2P, CPU/I/O e frametimes sob carga concorrente. Não foi executado Windows Update nem Delivery Optimization neste computador.

Validação do bloco 6: **30 testes focados aprovados** (`Journal.Tests.ps1` e `UpdatePolicies.Tests.ps1`), incluindo seis casos novos. Nenhuma operação real de Windows.

## Testes e ficheiros

Validação final: **109 testes Pester aprovados**, sem falhas, ignorados ou pendentes; parsing do programa e dos scripts gerados incluído. Os perfis/painel tinham sido validados com 93 testes; os blocos seguintes acrescentaram seis casos de políticas e dez de reparação/VBS. **11 testes Python aprovados** para o analisador offline, usando dados sintéticos. `git diff --check` sem erros de whitespace; os avisos LF/CRLF referem-se à configuração do Git. Não foram aplicadas otimizações reais ao Windows, executados serviços nativos ou realizados benchmarks de jogos.

Ficheiros funcionais/testes desta continuação: `SkyOptimizer.ps1`, `tests/Journal.Tests.ps1`, `tests/ServiceNetwork.Tests.ps1`, `tests/ProfileMaintenance.Tests.ps1`, `tests/UpdatePolicies.Tests.ps1` e `tests/MaintenanceReporting.Tests.ps1`. Benchmarks: `benchmarks/analyze.py`, `benchmarks/manifest.example.json` e `benchmarks/tests/test_analyze.py`. Documentação: `README.md`, `docs/FASE2-CONTINUACAO.md`, `docs/FASE2-IMPLEMENTACAO.md`, `docs/ACOES-ESTADO.json`, `docs/PERFIS.md`, `docs/OPORTUNIDADES.md`, `docs/BENCHMARKS.md` e `docs/TESTES-RESULTADO.json`.

## Bloco 7: reparação e diagnóstico sem falso sucesso

DISM/SFC passam pelo invocador de processos com exit code observado. DISM falhado ou sem código impede SFC. Código 3010 comunica reinício necessário e adia a segunda etapa; `/NoRestart` impede reinício automático pelo DISM. Falhas de lançamento e códigos SFC não confirmados devolvem `Failed`. Mesmo dois códigos zero produzem `Unverified`: a saída localizada e os logs ainda precisam de interpretação para certificar a integridade. CLI devolve 1 em falha, 2 em verificação incompleta; cancelamento não lança comandos. Não existe Undo de reparações DISM/SFC.

A observação VBS usa o estado efetivo publicado por Win32_DeviceGuard: distingue desativado, configurado sem execução e em execução. Falha, ausência ou valor desconhecido devolvem `Desconhecido`, sem inferir desativação ou usar uma preferência HVCI como prova de execução. A inspeção deixa de anunciar +5–15% de FPS, RAM libertada ou compatibilidade universal com anti-cheat. Não altera VBS/HVCI.

Fontes: [procedimento DISM/SFC](https://support.microsoft.com/en-us/windows/experience/backup-recovery/use-the-system-file-checker-tool-to-repair-missing-or-corrupted-system-files), [código 3010](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--1700-3999-), [estados Win32_DeviceGuard](https://learn.microsoft.com/en-us/windows/security/threat-protection/device-guard/enable-virtualization-based-protection-of-code-integrity). Testes usam processos e CIM simulados; nenhum comando de reparação real foi executado.

## Limitações e próxima etapa

- O Undo novo restaura apenas recursos cuja baseline foi registada. Não reconstrói informação inexistente em backups legados. Estes ficam preservados para revisão manual, sem defaults arbitrários.
- A journalização cobre os percursos migrados; funções legadas bloqueadas ainda contêm escritas antigas. Não executar funções internas isoladamente para contornar o dispatcher.
- HKCU refere-se ao utilizador do processo elevado. O diário verifica SID/máquina, mas elevação com credenciais de outro utilizador ainda não implementa seleção do perfil original.
- Verificações de conflito não constituem uma transação global contra alterações simultâneas de outro software. Chaves vazias são conservadas para evitar remoção de conteúdo alheio.
- Serviços/NIC precisam de integração em Windows descartável. Alterações NIC precisam de reinício e confirmação no hardware; mudança de driver/dispositivo bloqueia reversão automática.
- USB por dispositivo, HAGS, MSI, AppX, tarefas, BCD e TCP global continuam pendentes. A revisão deve avançar em grupos pequenos, com identidade/capacidade e Undo antes da elegibilidade.
- Todos os potenciais ganhos exigem benchmarks físicos. Menos processos/RAM, persistência de registo e testes automatizados não demonstram FPS, 1% lows ou input lag.

Prioridades seguintes: (1) ensaiar Apply repetido, falha intermédia, Undo e reinício numa instalação descartável; (2) rever 8/39 para enumeração e identidade USB por dispositivo, mantendo AC/DC separados; (3) determinar capacidade real de HAGS/MSI nas ações 37/40, sem heurísticas de VRAM/fabricante; (4) migrar os restantes grupos e comparar alterações individuais em hardware físico. As oportunidades de desempenho, mecanismos, riscos e métodos de medição estão em [OPORTUNIDADES.md](OPORTUNIDADES.md). Não foram acrescentadas receitas de afinidade, temporizadores ou segurança sem fundamentação.

Não foram medidos FPS nem latência. Ainda não é uma versão validada para clientes. Branch preservada, sem push; SkyOS e SkyOptimizer-Packs não foram modificados.
