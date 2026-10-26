# Fase 2 — continuação de 21 a 26 de outubro de 2026

Preservados os quatro commits anteriores na branch `dev/phase2-execution-power-safety`. Apenas SkyOptimizer foi modificado. Sem push e sem aplicar otimizações ao Windows de desenvolvimento.

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

## Estado das 90 ações

O catálogo [ACOES-ESTADO.json](ACOES-ESTADO.json) conserva **90 IDs únicos**, finalidade, decisão da auditoria, requisitos, estado de implementação e elegibilidade de execução. Nesta etapa, **17 ações estão migradas para Apply**: 1, 3, 6, 9, 13, 17, 38, 41, 42, 48, 60, 71, 74, 75, 76, 79 e 86. A ação 24 foi revista como manutenção separada. As restantes ações mantêm o código para revisão, mas o dispatcher impede execução sem migração. Isto não significa que todas as 90 ações tenham sido corrigidas ou certificadas.

## Testes e ficheiros

Validação deste conjunto: **93 testes Pester aprovados**, sem falhas; parsing do programa e dos scripts gerados incluído. **11 testes Python aprovados** para o analisador offline, usando dados sintéticos. `git diff --check` sem erros de whitespace; os avisos LF/CRLF referem-se à configuração do Git. Não foram aplicadas otimizações reais ao Windows, executados serviços nativos ou realizados benchmarks de jogos.

Ficheiros funcionais/testes desta continuação: `SkyOptimizer.ps1`, `tests/Journal.Tests.ps1`, `tests/ServiceNetwork.Tests.ps1` e `tests/ProfileMaintenance.Tests.ps1`. Documentação: `README.md`, `docs/FASE2-CONTINUACAO.md`, `docs/FASE2-IMPLEMENTACAO.md`, `docs/ACOES-ESTADO.json`, `docs/PERFIS.md`, `docs/OPORTUNIDADES.md` e `docs/TESTES-RESULTADO.json`. A ferramenta de benchmarks e o respetivo protocolo são registados num commit separado.

## Limitações e próxima etapa

- O Undo novo restaura apenas recursos cuja baseline foi registada. Não reconstrói informação inexistente em backups legados. Estes ficam preservados para revisão manual, sem defaults arbitrários.
- A journalização cobre os percursos migrados; funções legadas bloqueadas ainda contêm escritas antigas. Não executar funções internas isoladamente para contornar o dispatcher.
- HKCU refere-se ao utilizador do processo elevado. O diário verifica SID/máquina, mas elevação com credenciais de outro utilizador ainda não implementa seleção do perfil original.
- Verificações de conflito não constituem uma transação global contra alterações simultâneas de outro software. Chaves vazias são conservadas para evitar remoção de conteúdo alheio.
- Serviços/NIC precisam de integração em Windows descartável. Alterações NIC precisam de reinício e confirmação no hardware; mudança de driver/dispositivo bloqueia reversão automática.
- USB por dispositivo, HAGS, MSI, AppX, tarefas, BCD e TCP global continuam pendentes. A revisão deve avançar em grupos pequenos, com identidade/capacidade e Undo antes da elegibilidade.
- Todos os potenciais ganhos exigem benchmarks físicos. Menos processos/RAM, persistência de registo e testes automatizados não demonstram FPS, 1% lows ou input lag.

Prioridade seguinte: concluir um grupo de políticas documentadas ainda bloqueadas; depois rever os controlos por dispositivo e testar recuperação/reinício numa instalação descartável. As oportunidades de desempenho, mecanismos, riscos e métodos de medição estão em [OPORTUNIDADES.md](OPORTUNIDADES.md). Não foram acrescentadas receitas de afinidade, temporizadores ou segurança sem fundamentação.

Não foram medidos FPS nem latência. Ainda não é uma versão validada para clientes. Branch preservada, sem push; SkyOS e SkyOptimizer-Packs não foram modificados.
