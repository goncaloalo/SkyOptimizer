# Fase 2 — continuação em 21 de outubro de 2026

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

Não foram medidos FPS nem latência. Ainda não é uma versão validada para clientes.
