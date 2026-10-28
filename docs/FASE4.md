# Fase 4 — Auditoria global e preparação para validação

Data: 2026-10-28. Branch: `dev/phase2-execution-power-safety`. Base auditada: `4dca7e7`. Código final testado: `bb49720744216a7c6d938e8dd4f0ce4a19dbb29d`.

## Veredicto

O projeto continua em desenvolvimento offline. A auditoria encontrou defeitos de integração apesar dos 187 testes anteriores aprovados. As correções desta fase melhoram a comunicação de resultados, a proteção dos dados elevados e a preservação de alterações externas. Não demonstram desempenho superior nem maturidade para clientes.

Foram revistos os percursos das 28 ações elegíveis, as receitas das 56 bloqueadas, a entrada principal, o painel gerado, os diários, os perfis e os testes. A análise partiu do código e procurou contrariar pressupostos anteriores; não constitui certificação por uma entidade externa. Os detalhes individuais incluem função, ficheiro, linha na base auditada, mecanismo, riscos, reversão e evidência automatizada.

**Resultado:** nenhum P0 confirmado; nove P1 corrigidos ou contidos offline; quatro P2, dos quais a apresentação enganadora foi corrigida. Permanecem contratos funcionais incompletos, lacunas de integração e limitações de diagnóstico. Ausência de P0 encontrado não prova ausência de vulnerabilidades.

## Arquitetura e limites

1. O BAT chama o PowerShell do sistema. O script centraliza a elevação, espera pelo processo elevado e propaga o resultado. A passagem real por UAC ainda precisa de ensaio, incluindo recusa e conta administrativa diferente.
2. A inicialização obtém `CommonApplicationData`, verifica proprietário/DACL e recusa reparse points no percurso e na árvore existente. Novos diretórios têm DACL protegida. Conteúdo antigo sem confiança verificável é recusado, não adotado ou reparado automaticamente.
3. Um lock de sessão serializa programa e painel sobre a pasta central, além dos locks dos recursos. O menu aberto mantém o lock: fechar o programa antes de usar o painel autónomo. Um ficheiro `session.lock` existente não significa um processo ativo.
4. A seleção de perfil passa pelo dispatcher. IDs históricos continuam visíveis, mas ações bloqueadas não executam o corpo legado. Os resultados distinguem conformidade, aplicação, incompatibilidade, falha e estado incompleto.
5. O diário de mutações persiste a intenção antes da escrita e conserva a baseline original. A reversão compara identidade e estado esperado. Inicialmente conforme não significa recurso adquirido pelo programa. As políticas 58/70/84 usam ownership explícito; as restantes mantêm autoria legada. A normalização não resolve todos os aliases entre APIs ou tipos de recurso.
6. Energia tem diário separado e plano isolado. O Undo reativa o original, mas conserva cópias cujo conteúdo externo não pode excluir. Comunica `Unverified`/código 2. A lista de planos não regressa integralmente à baseline; limpeza automática fica pendente de um fingerprint completo.
7. O painel incorpora as funções de execução/reversão do produto e usa a mesma inicialização, pasta e lock. É necessário regenerá-lo na mesma versão. Scripts anteriormente instalados não ficam corrigidos retroativamente.
8. Snapshots de processos/RAM/disco são observações. O analisador Python calcula métricas de CSV offline; não captura jogos nem prova que políticas foram consumidas.

`ProgramData\SkyOptimizer\Backups` contém os diários; `ProgramData\SkyOptimizer\Logs` contém logs. A pasta real deriva da known folder do sistema, não de um caminho construído a partir de `%SystemDrive%`. A proteção foi testada com descritores em memória e ficheiros temporários. Não foi aplicada nem ensaiada uma DACL real de instalação. O programa não constitui uma fronteira contra um administrador malicioso nem possui uma cadeia de instalação assinada validada.

As alterações usam mecanismos documentados de [criação de diretório com segurança](https://learn.microsoft.com/en-us/dotnet/api/system.io.directory) e de [elevação/espera com Start-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-5.1). Estas APIs não substituem ensaios de ACL, UAC e recuperação no Windows.

## Descobertas

As localizações completas, anteriores e corrigidas, estão em [FASE4-DESCOBERTAS.json](FASE4-DESCOBERTAS.json). As funções abaixo pertencem a `SkyOptimizer.ps1`, salvo indicação.

| ID | Grau | Localização e evidência | Resultado |
|---|---|---|---|
| F4-01 | P1 | `Get-SkyProfileActionIds`: Apply normal passava experiências null e falhava na seleção | Normalização de null; teste do fluxo completo com efeitos Windows simulados |
| F4-02 | P1 | `Invoke-SkyOptimize`: painel falhado ou seleção incompatível podiam devolver sucesso | Código 1 para falha; 2 para seleção incompleta/incompatível; relatório conservado |
| F4-03 | P1 | `Invoke-SkyAction`: exceção tardia perdia resultados e reinício anteriores; grupo parcial parecia aplicado | Acumulação durante o pipeline; evidência parcial preservada; grupo incompleto `Unverified` |
| F4-04 | P1 | Inicialização/`Deploy-ClientPanel`: leitura e escrita elevadas sobre árvore preexistente sem contrato de confiança | Verificação de owner/DACL/reparse, criação protegida e escrita atómica; ensaio NTFS pendente |
| F4-05 | P1 | Fontes do painel e BAT: processo pai não aguardava UAC nem transmitia o resultado | Host absoluto, elevação única, Wait/PassThru, saída propagada; UAC real pendente |
| F4-06 | P1 | `Restore-SkyPowerPlan`: eliminava cópia mesmo após edição externa | Eliminação suspensa; original reativado, cópias conservadas e incompletude explícita |
| F4-07 | P1 | `Set-SkyNicProperties`: percorria vários adaptadores ativos; propriedades omitidas podiam parecer sucesso | Seleção ambígua recusada; propriedade indisponível comunicada; grupo parcial `Unverified` |
| F4-08 | P1 | Entrada principal/painel: locks locais não serializavam sessão e relatório completo | Lock comum por sessão; teste de exclusão e reabertura após Dispose |
| F4-09 | P1 | Fluxo Apply: terminava Explorer por nome global, ignorava falhas e anunciava reinício | Reinício automático suspenso; instrução manual preserva outras sessões/operações |
| F4-10 | P2 | Inventário/relatório: inferências de dual-channel, XMP, VBS/anti-cheat e ganhos não demonstrados | Linguagem corrigida; dados ausentes permanecem desconhecidos; deltas observados com sinal |
| F4-11 | P2 | Ações elegíveis: estado persistido não prova comportamento dos componentes | Matriz individual identifica contratos incompletos e gates reais; não resolvido por mais mocks |
| F4-12 | P2 | Suite: testes isolados não cobriam todo o fluxo; modelos limitados de serviços/drivers | 24 regressões adicionais; lacunas restantes explicitadas, sem percentagem fictícia de cobertura |
| F4-13 | P2 | Diagnóstico: logs opcionais podem omitir erro de escrita; nomes/versões legados; relatório é último snapshot | Pendente; diário autoritativo tem tratamento distinto e falha de persistência bloqueia mutação |

A proteção de armazenamento é uma mitigação fundamentada, não uma exploração demonstrada no host. A cópia de energia conservada é uma contenção de perda de dados, não um Undo integral da lista de planos. Recusa por ACL exige investigação da instalação anterior; não apagar backups para ultrapassá-la.

## Maturidade das 28 elegíveis

O [exame individual](FASE4-ELEGIVEIS.json) cobre todos os IDs elegíveis e respetivas dependências. Nenhuma ação recebeu validação real nesta fase.

| Maturidade observada | IDs | Próxima prova |
|---|---|---|
| 12 candidatas a integração de políticas | 16, 17, 19, 20, 25, 41, 58, 59, 70, 84, 88, 90 | Edição/build, precedência, componente consumidor, reinício e Undo |
| 8 experiências dependentes de hardware | 3, 8, 38, 42, 60, 74, 75, 76 | Consumo real do estado, driver, estabilidade e benefício no workload |
| 7 com contrato funcional incompleto | 6, 9, 13, 48, 71, 79, 86 | Serviços/instâncias, política efetiva, funcionalidade e compatibilidade |
| 1 com limpeza conservadora pendente | 1 | Reativação original e conservação das cópias; eventual fingerprint antes de eliminar |

Pontos concretos: a ação 13 pode aumentar telemetria de um valor original 0 para 1; o aviso foi corrigido, mas a receita não foi alterada. A ação 71 atua no template OneSyncSvc, não prova controlo de instâncias por utilizador. A ação 48 agrupa serviços com funções diferentes; testes do mecanismo não certificam os três. A ação 42 preserva flags alheias na aplicação, mas uma edição externa do valor completo pode bloquear Undo, intencionalmente. NIC exige um único candidato após filtros; ainda não existe seletor explícito de interface.

Perfis mantidos: Balanced seleciona 79; Performance seleciona 9/41/79; Extreme acrescenta experiências explicitamente escolhidas. Não representam três níveis comprovados de FPS. Ação 8 é apenas política AC no plano Sky; a antiga escrita por dispositivo pertence à ação 39 retirada. Alimentação desconhecida continua a bloquear políticas AC-only.

## Classificação das 56 bloqueadas

O [inventário individual](FASE4-BLOQUEADAS.json) regista fundamento, impacto plausível, riscos, dependências e requisitos de reversão de cada receita.

| Recomendação | Quantidade | IDs |
|---|---|---|
| Desenvolvimento de contrato possível offline, seguido de integração Windows | 24 | 4, 7, 15, 21, 28, 31, 32, 34, 44, 45, 46, 51, 53, 55, 56, 57, 62, 64, 65, 66, 69, 73, 82, 85 |
| Exige também investigação em hardware/workload específico | 17 | 2, 5, 10, 11, 35, 36, 37, 40, 50, 52, 67, 68, 78, 80, 81, 87, 89 |
| Recomenda-se retirar ou substituir a receita atual | 15 | 18, 22, 23, 26, 27, 29, 33, 43, 47, 49, 61, 63, 72, 77, 83 |

Estas categorias são decisões de investigação, não desbloqueios. As 15 recomendações de retirada **continuam bloqueadas no runtime**. A contagem efetiva mantém **28 elegíveis, 56 bloqueadas, cinco retiradas (12/14/30/39/54) e manutenção 24**. Nenhuma nova otimização foi introduzida.

Exemplos de fundamento: a política antiga de Copilot não controla universalmente a aplicação atual; as experiências antigas e a distribuição da aplicação têm [contratos distintos](https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot). Receitas MMCSS incluem campos sem efeito documentado e pressupõem threads inscritas; não governam indiscriminadamente todos os jogos. Ver [MMCSS](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service). Alterar agrupamento de serviços pode trocar isolamento por memória, sem evidência de FPS; ver [refatorização svchost](https://learn.microsoft.com/pl-pl/windows/application-management/svchost-service-refactoring).

Outras receitas confundem preferências de shell, libertação de espaço, TTL, limpeza de cache ou menor número de processos com desempenho. AppX removido de todos os utilizadores não tem reinstalação exata garantida. TRIM assíncrono exige confirmação do job e seleção correta do volume. Preservar IDs históricos serve rastreabilidade, não justifica reativar corpos legados.

## Testes e qualidade da prova

**211/211 Pester e 11/11 Python aprovados; zero testes Pester falhados, ignorados ou pendentes.** Prova detalhada: [FASE4-TESTES.json](FASE4-TESTES.json). Resumo, versões e hashes: [TESTES-RESULTADO.json](TESTES-RESULTADO.json). `git diff --check` sem erros; avisos de conversão LF/CRLF não constituem teste funcional.

As 24 regressões adicionais distribuem-se por ApplyFlow (3), Safety (2), StorageSecurity (13), Power (1), HardwarePresentation (3) e ServiceNetwork (2). Os testes carregam declarações por AST, usam mocks e ficheiros temporários. O ensaio suplementar de leitura de metadados ACL sobre um ficheiro temporário com FileShare.None passou; não alterou permissões. Python usa dados sintéticos para validar fórmulas, não benchmarks reais.

Após atualizar os metadados do catálogo, os três testes Catalogue foram repetidos e aprovados. Estão incluídos nos 211, não são testes adicionais. As matrizes JSON foram verificadas contra os 90 IDs, os links locais foram resolvidos e o hash do produto continuou igual ao da suite completa.

Os testes de fluxo reproduziram falhas que a seleção isolada de perfil não detetava. Regressões também reproduziram perda de evidência parcial, eliminação de plano externamente alterado e seleção múltipla de NIC. UAC, ACL instalada, SCM, drivers, COM de tarefas, políticas consumidas, reboot e durabilidade perante perda de energia continuam sem prova real. Pester 3 permite interferência de mocks entre casos; os novos casos relevantes repõem explicitamente os seus mocks. Uma contagem de testes não é uma percentagem de cobertura ou uma certificação de segurança.

## Alterações e commits

Código: `SkyOptimizer.ps1`, `Executar-SkyOptimizer.bat`. Testes: `ApplyFlow.Tests.ps1`, `HardwarePresentation.Tests.ps1`, `Power.Tests.ps1`, `Safety.Tests.ps1`, `ServiceNetwork.Tests.ps1`, `StorageSecurity.Tests.ps1`, na pasta `tests`.

| Commit | Conteúdo |
|---|---|
| `6e1fe3c` | Fluxo Apply, null, resultados finais e evidência parcial |
| `8161a3b` | Armazenamento elevado, escrita do painel e saída dos launchers |
| `74a50f3` | Conservação de cópias de energia com alterações externas possíveis |
| `fb10349` | NIC ambígua, apresentação fundamentada e suspensão do reinício global do Explorer |
| `9a01420` | Propriedades NIC indisponíveis e resultados parciais |
| `bb49720` | Serialização de sessões do programa e painel |

Documentação desta entrega: este relatório, checklist de validação, três matrizes de auditoria, prova detalhada Pester, catálogo, resumo de testes, README, perfis, protocolo VM, benchmarks e marca histórica da Fase 3C. O commit documental posterior não altera o hash do produto testado.

## Próxima etapa recomendada

Congelar novas receitas até executar a [checklist de validação real](VALIDACAO-FASE4.md). Primeiro, VM descartável para armazenamento/UAC, Apply repetido, reinício, Undo, falhas e integração do painel. Depois, hardware físico para energia, USB, NIC, gráficos, serviços concorrentes e benchmarks reproduzíveis. Uma VM não resolve estas últimas questões.

Enquanto não existir VM, continuar apenas trabalho offline delimitado: completar contratos de edição/serviço, melhorar cenários de falha e retirar alegações não sustentadas. Mais mocks não devem promover ações que dependem de consumo real pelo Windows/driver. Não foram executadas otimizações no Windows de desenvolvimento, testes físicos ou VM; não houve push nem alterações a SkyOS/Packs. O produto não está aprovado para distribuição comercial.
