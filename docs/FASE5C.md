# Fase 5C — implementação orientada pela investigação

> Registo histórico. A instrumentação e inferência por blocos posteriores estão documentadas na [Fase 5D](FASE5D.md); a ausência de validação real mantém-se.

Base: `ab55736`, branch `dev/phase2-execution-power-safety`. Os cinco documentos de `investigacao-2026-10-28` foram lidos integralmente antes de editar ficheiros. Eram os únicos ficheiros não versionados; ficam preservados sem alterações. Consultadas as entregas 2–5A. Aplicam-se as skills lean-build e surgical-patch já usadas na fase anterior.

## Plano priorizado e dependências

1. **P1 — diagnóstico e medições offline:** impedir conversão de GPU busy/duração de trabalho em FPS; explicitar semântica do campo; contar incidentes consecutivos e tempo excedente. Importar amostras temporais de processos/memória/I/O e produzir observações com dados ausentes explícitos. Não recolher no host, não inferir causalidade nem latência física.
2. **P1 — contratos e debloat:** conter captura sem contrato funcional Win11; impedir execução dos grupos 48/71; substituir corpo destrutivo de 49 por recusa e oferecer inventário/preview da conta atual. Dependências e componentes desconhecidos nunca autorizam remoção. Undo de alterações anteriores continua disponível.
3. **P1 — perfis:** seleção exata Laboratory, com dependências visíveis e sem herdar Performance. Conservar aliases e menus existentes. Recomendações por diagnóstico são hipóteses para escolha do operador, não mutações automáticas.
4. **P1 — entrega:** regressões, catálogo e protocolos atualizados; commits incrementais; distinguir observação, implementação e validação real.

VM, recuperação AppX/dados, leitores funcionais de captura, drivers, sensores e testes físicos continuam gates posteriores. Não serão criados adapters de remoção ou perfis por fabricante sem esse suporte. CI por pares/blocos será posterior à validação do formato de captura; não se apresentará estatística descritiva como significância.

## Decisões sobre a investigação

As categorias A–E são avaliações da investigação, não benchmarks SkyOptimizer. A presença de um processo/AppX não demonstra carga dispensável. A ausência de carga observada também não autoriza removê-lo. GPU busy não mede cadência. AllowGameDVR não é contrato funcional Win11; não será substituído por outra flag interna adivinhada. Não é possível separar 48/71 em novas ações automaticamente aprovadas apenas reutilizando o writer de serviços.

## Implementação entregue — 29/10/2026

### Diagnóstico temporal offline

`benchmarks/diagnose.py` importa amostras JSON de uma sessão, com relógio relativo monotónico e unidades explícitas. Calcula deltas de CPU por processo, equivalentes de um core, percentagem da capacidade lógica, taxas de I/O, memória privada observada, memória disponível e fração de commit. Aceita métricas de latência/fila/I/O do volume do jogo quando fornecidas; não escolhe o primeiro disco nem infere zero para sensores ausentes.

Cada processo usa um ID anónimo e um token de vida distinto do PID. Reutilização de PID, processo recém-observado e contadores ausentes não geram taxas inventadas. Deltas negativos, tempos não crescentes, valores não finitos, CPU impossível e commit acima do limite são recusados. Atividade depois da saída do jogo não é classificada como concorrência durante o jogo. Não soma working sets partilhados.

O relatório ordena atividade e destaca candidatos a inspeção usando limiares de engenharia explícitos: 0,25 core equivalente ou 1 MiB/s de I/O de processo. Esses limiares não diagnosticam bottleneck nem autorizam fechar/remover aplicações. I/O de processo inclui cache e outros destinos; não equivale a throughput físico do disco. CPU total não revela ready/wait da thread crítica. O processo alvo deve ser mapeado pelo operador antes de importar. Não existe captura automática, sensor, serviço residente, injeção ou overlay novo.

O resultado normal pode ser “No change justified by these samples”. Campos adicionais de entrada, como comandos/caminhos, não são copiados para a saída; apenas IDs anónimos e métricas previstas. Rever também IDs e dados brutos antes de partilhar. O parser não transforma um ID escolhido pelo utilizador numa identidade autenticada. Amostragem não comprova execução contínua entre fronteiras e pode perder picos curtos.

Exemplo executável **apenas sintético**, sem aceder a processos/Windows:

```powershell
python -B benchmarks/diagnose.py benchmarks/session.example.json --output session-synthetic-result.json
```

O destino é criado exclusivamente: não substitui entrada nem relatório anterior. Para dados reais, o operador deve produzir o mesmo esquema a partir de uma recolha autorizada e documentada. O exemplo não é captura PresentMon nem benchmark. GPU, DPC/ISR, temperaturas, potência e associação temporal a frames continuam desconhecidos; o relatório não inventa causalidade, ganhos ou latência física.

### Medições de frametime

`benchmarks/analyze.py` passa a exigir manifesto de formato **2**, incluindo `measurement.semantics`, `unit=ms` e `source_reference`. Os significados aceites são intervalos entre eventos de present, display ou conclusão de render, coerentes com `interval_kind`. Nomes com busy/duration/latency são recusados como campos de cadência. Esta proteção elimina ambiguidades comuns, mas não consegue detetar uma coluna renomeada ou uma declaração incorreta: rever sempre a definição da versão da ferramenta.

Manifestos de formato 1 são recusados, não convertidos por adivinhação. Preservar o original, criar cópia e preencher a semântica/fonte; os CSV não mudam. Não foi alterada a definição de FPS médio, 1% low ou percentis. Os picos passam a distinguir frames acima do limiar, incidentes consecutivos, incidentes/minuto, duração total dos intervalos e tempo excedente sobre o limiar.

O analisador continua descritivo. O protocolo Work pede bootstrap por pares/blocos, pré-registo e confirmação independente; esses requisitos estão documentados, mas CI, desenho emparelhado e promoção estatística ainda não foram implementados. A ferramenta não afirma que cinco runs bastam nem declara significância.

### Captura Windows 10/11 — ação 9

A ação 9 consulta a matriz conservadora de Windows cliente/SKU com limite superior de build. Só admite o percurso existente em Windows 10 conhecido (build 15063–21999, edições já previstas na matriz). Home, Server, build desconhecida e Windows 11 ficam incompatíveis antes de qualquer escrita. Os cinco valores, o diário, Apply repetido e Undo permanecem iguais para a célula suportada.

Isto é uma restrição fundamentada, não validação funcional do Windows 10. A [documentação AllowGameDVR](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement#allowgamedvr) limita a imposição a Windows 10 desktop. A investigação não demonstra quais flags alternativas controlam captura no Windows 11 atual; não se implementou uma substituição especulativa. Game Bar permanece instalada. Performance/Extreme continuam a solicitar 9, mas em Win11 recebem Incompatible, preservam captura e devolvem execução incompleta; usar Laboratory para selecionar só as ações pretendidas.

### Serviços 48 e 71

Ambos os grupos saíram dos IDs elegíveis e os corpos devolvem Deferred também quando chamados diretamente. O histórico continua rastreável; Undo de entradas anteriores não foi removido nem filtrado por elegibilidade atual.

| Grupo | Serviço | Contrato funcional necessário antes de voltar a atuar |
|---|---|---|
| 48 | DiagTrack | Diagnóstico/telemetria: observar carga e impacto de privacidade separadamente |
| 48 | PcaSvc | Compatibilidade de aplicações: preservar assistência e verificar regressões |
| 48 | TrkWks | Tracking de ligações: verificar dependências e utilização efetiva |
| 71 | diagnosticshub.standardcollector.service | Recolha de diagnóstico: preservar ferramentas que a utilizam |
| 71 | wercplsupport | Suporte a relatórios: não perder evidência de falhas por predefinição |
| 71 | OneSyncSvc | Sincronização de dados; distinguir template e instâncias por conta |

A [documentação de serviços por utilizador](https://learn.microsoft.com/en-us/windows/application-management/per-user-services-in-windows) confirma o papel de OneSyncSvc e o impacto em aplicações dependentes. Nenhum destes nomes isoladamente justifica desligar um serviço. A separação de finalidades é registada, mas não há seis novas ações aprovadas: leitores funcionais e ensaios ainda faltam.

### AppX — ação 49 e menu 9

O corpo legado que removia padrões de todas as contas/provisionamento e contava sucesso por padrão foi substituído por recusa explícita. O ID 49 mantém-se bloqueado. O menu **9** abre um inventário/preview somente de leitura da conta do processo, incluindo frameworks/resources/bundles. Não enumera outras contas nem provisionamento; `CurrentProcessUser` pode ser a conta administrativa usada na elevação.

O inventário usa identidades exatas, publisher, versão, arquitetura e referências de dependências. Classifica frameworks, recursos, NonRemovable, dependências referenciadas e capacidades reconhecidas de sistema/gaming como Protected. Metadados ausentes ou dependências não resolvidas ficam Unknown. Os restantes ficam ReviewOnly, nunca “seguro para apagar”. `ApplyAllowed=false` e recuperação desconhecida em todos os casos. Listas de nomes são proteção adicional; não são autorização de remoção. A fonte é o [contrato Get-AppxPackage](https://learn.microsoft.com/en-us/powershell/module/appx/get-appxpackage).

Falha da enumeração é Unknown; resultado vazio observado é distinto de falha. Não existem comandos de desinstalação, contadores de removidos ou promessa de recuperar dados. Runtimes de dependência externos ao inventário, app em uso, licenças, Store e fontes de reinstalação requerem contrato posterior. Esta é a primeira etapa do debloat seletivo previsto pelo Work, não a entrega de um desinstalador profundo completo.

### Perfis e estado das ações

Balanced permanece 79. Performance solicita 9/41/79. Extreme conserva compatibilidade e herda Performance; a interface agora explicita essa herança e o caráter experimental. **Laboratory** aceita seleção exata, sem 9/41/79 implícitas. 3/8 acrescentam somente a dependência 1, mostrada na lista antes de Apply. Sem IDs, Laboratory recusa a operação. Dispatcher, diário, conflitos, pós-verificação e Undo existentes são reutilizados.

```powershell
# Instruções para futuro laboratório autorizado; não executar no host de desenvolvimento.
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "41,79"
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "8"
```

O segundo exemplo seleciona 1/8; não é uma recomendação de desligar suspensão USB. O primeiro preserva captura e não herda receitas de serviços. Não existe adaptação automática por marca de CPU/GPU ou diagnóstico; os resultados observados alimentam a revisão do operador. Automatizá-la antes de ensaios confirmatórios contrariaria a própria investigação.

Estado atual: **26 elegíveis, 58 bloqueadas, cinco retiradas e manutenção 24**. 48/71 foram suspensas, não retiradas definitivamente. 9 continua elegível condicionalmente apenas no contrato Win10. 49 continua bloqueada com corpo destrutivo eliminado. Rótulos 9/48/49/71/73/88 foram corrigidos. 88 conserva utilidade manual e não entra automaticamente em Balanced/Performance; não se promete FPS por desligar limpeza. Nenhuma nova ação foi desbloqueada.

## Verificação e limites

**232/232 testes Pester** (Windows PowerShell 5.1.26100.9711, Pester 3.4.0) e **19/19 Python** (3.12.14), sem falhas. Prova final e hashes em [FASE5C-TESTES.json](FASE5C-TESTES.json); resumo em [TESTES-RESULTADO.json](TESTES-RESULTADO.json). Os testes carregam declarações por AST, simulam CIM/AppX/setters e usam ficheiros temporários. A entrada do produto, coleta de processos e leitores AppX reais não foram executados. Python usa somente fixtures sintéticas.

Foi identificada uma diferença do ambiente de execução: o terminal passou a PowerShell 7.6.5, onde o Pester 3.4 fornecido falhou em Should Throw também nos testes antigos. Verificadas exceções diretamente; a execução explícita em Windows PowerShell 5.1 passou o conjunto focado. Não foi alterado o produto para acomodar esse falso diagnóstico. O Python do WindowsApps não abriu na sandbox; usou-se o runtime Python conhecido fornecido pelo ambiente. Testes temporários Python e a suite Pester completa precisaram de execução fora da sandbox devido a acesso negado às fixtures e operações Move. A primeira execução completa ficou em 157/232 por estas recusas e efeitos em cascata; a repetição fora da sandbox passou 232/232, sem alterar código; não houve recolha ou otimização do host.

Hipóteses a comprovar: redução de concorrência observada pode melhorar frametimes; desligar gravação só pode ajudar quando produz carga relevante; separar experiências reduz confundidores; remover uma aplicação inativa pode não melhorar nenhuma métrica gaming. Primeiro ensaiar integração e recuperação; depois A/A e A/B conforme [protocolo Work](investigacao-2026-10-28/05_Protocolo_benchmarks.md), com controlo negativo sem carga, segurança constante, cache/temperatura e efeito mínimo pré-registados.

Próximos blocos: validação funcional 9/41/79 em VM; leitor/captura temporal com overhead medido; plano de background por aplicação com consentimento e revalidação; contratos separados dos serviços; inferência estatística por blocos e manifestos de contexto; só depois remoção AppX por conta com recuperação declarada. Nenhum ganho foi medido. Sem push, SkyOS/Packs intactos e sem aprovação para clientes.

## Aceitação futura específica deste lote

Os procedimentos anteriores de snapshot, identidade, elevação, Apply/reinício/Undo, falhas e conflitos continuam obrigatórios. Acrescentar estas verificações à matriz de VM, sem interpretar snapshot restore como prova de Undo:

1. **Captura 9:** numa célula Windows 10 admitida, observar os cinco valores antes/depois, captura efetiva e recuperação após Undo/reinício. Numa célula Windows 11, confirmar Incompatible e ausência de alteração desses valores. Performance deve comunicar execução incompleta, não sucesso total.
2. **Serviços 48/71:** seleção explícita deve ficar Deferred e não mudar arranque/execução de qualquer serviço. Testar recuperação de um diário anterior válido independentemente da elegibilidade atual, usando fixtures autorizadas de laboratório.
3. **AppX:** confirmar que menu 9 enumera apenas a conta do processo elevado; comparar com a identidade da sessão. Exercitar erro de enumeração e dependências. Nenhum caminho deve remover pacotes, alterar provisionamento ou sugerir recuperação já garantida.
4. **Laboratory:** confirmar que 41/79 não inclui 9 e que 8 inclui somente a dependência 1. A baseline independente deve cobrir os recursos da seleção efetiva. Confirmar passagem de argumentos após UAC e relatório de falhas/parcialidade.
5. **Diagnóstico e medições:** confrontar unidades e deltas importados com a fonte autorizada. Quantificar overhead por A/A antes de usar um coletor em decisões. Campos GPU busy/duração não podem produzir FPS no analisador; a referência declarada deve corresponder à definição da versão fixada.

A prova automatizada não cobre Cmdlets AppX reais, consumo das políticas, UAC, SCM, drivers, restauração após reboot ou jogos/anti-cheats. A instrumentação temporal e a escolha de alterações permanecem separadas; nenhum processo é encerrado pelo diagnóstico. Código e catálogo foram revistos com `git diff --check`; os três testes de catálogo foram repetidos após atualizar os perfis documentados. Exemplo JSON sintético, links locais, hashes e preservação de `main` verificados.

## Commits desta fase

- `49d08fb`: preservação dos cinco documentos e plano priorizado.
- `c308115`: diagnóstico temporal, contrato de intervalos e incidentes de stutter.
- `897a128`: captura, suspensão dos grupos de serviços, preview AppX e Laboratory.
- `65e1d2d`: concorrência limitada à vida observada do jogo, exemplo sintético e clareza da interface.
- O commit de consolidação deste relatório reúne catálogo, perfis, protocolo e provas finais.

A prova Pester identifica `65e1d2d`, último commit que altera código/testes; a consolidação seguinte é documental. O histórico de investigação mantém-se intacto.
