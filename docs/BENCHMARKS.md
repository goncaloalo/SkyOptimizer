# Protocolo de benchmarks — SkyOptimizer

Estado: preparado, ainda não executado. Não aplicar otimizações no Windows usado para desenvolver o projeto.

A [Fase 5D](FASE5D.md) acrescenta adaptadores de captura autorizada, normalização e inferência por pares/blocos. Apenas o percurso offline foi testado. O protocolo e as definições abaixo continuam aplicáveis; disponibilidade da API não demonstra compatibilidade real nem overhead aceitável.

## Analisador offline implementado

`benchmarks/analyze.py` lê capturas CSV já recolhidas. Usa apenas a biblioteca padrão de Python 3.10+; não lança jogos, capturadores nem tweaks. Copiar `benchmarks/manifest.example.json`, preencher a identificação do sistema, a semântica da medição e os runs planeados. O exemplo não contém medições e é recusado enquanto faltarem os campos obrigatórios. O [protocolo da investigação](investigacao-2026-10-28/05_Protocolo_benchmarks.md) define o desenho futuro; cinco runs não garantem poder estatístico.

```powershell
python -B benchmarks/analyze.py caminho/manifest.json --output caminho/resultado.json
python -B -m unittest discover -s benchmarks/tests -v
```

O caminho de cada CSV é relativo ao manifesto. `frametime_column` deve identificar explicitamente intervalos em **milissegundos**. Não escolher durações de trabalho GPU, timestamps absolutos ou latência de renderização como se fossem intervalos entre frames. Declarar `interval_kind` como `present`, `display` ou `render`, conforme a captura e a documentação da versão utilizada. Não existe conversão automática entre estes conceitos.

Desde a Fase 5C, o manifesto exige `schema_version: 2` e `measurement` com `unit: "ms"`, `source_reference` não vazia e semântica coerente: `between_present_events`, `between_display_events` ou `between_render_completion_events`, respetivamente. A referência deve identificar a definição do campo na versão fixada da ferramenta, não apenas o nome do fornecedor. Nomes de coluna contendo busy/duration/latency são recusados. Esta barreira não autentica uma declaração nem deteta uma coluna renomeada: a revisão humana da fonte continua obrigatória.

Manifestos de formato 1 são recusados. Preservar o original, criar uma cópia de formato 2 e preencher os campos após consultar a definição da captura. Não alterar CSV nem converter GPU busy em cadência. `render` só admite intervalos entre conclusões de frames, não duração de trabalho GPU.

É possível usar CSV normalizado com coluna `FrameTimeMs` ou indicar a coluna apropriada da versão fixada de PresentMon. Se existirem `ProcessID` ou `SwapChainAddress` com vários valores, selecionar o stream exato em `filters`, por exemplo `{"ProcessID":"1234","SwapChainAddress":"0x123"}`. Todas as condições devem representar a mesma cena/configuração. Guardar também a ordem temporal original e os ficheiros brutos.

O relatório inclui SHA-256 dos bytes analisados, exclusões por filtro, métricas por run, percentis nearest-rank, histograma, picos, mediana, desvio-padrão amostral e coeficiente de variação entre runs. Não mistura todos os frames de A/B numa única amostra independente. Comparações percentuais são descritivas; não são um teste de significância nem uma prova causal. Resultados com menos de cinco runs, menos de 60 segundos ou capturas reutilizadas ficam assinalados. Estes avisos históricos são heurísticas mínimas, não aprovação do desenho. Intervalos inválidos falham a análise; não são descartados silenciosamente.

O analisador não mede temperaturas, clocks, utilização CPU/GPU, DPC/ISR ou input lag. Estes dados devem acompanhar a sessão segundo o protocolo abaixo. Ainda não há integração de sensores, controlo automático de capturas, intervalos de confiança ou gráficos temporais automáticos. O output nunca substitui um ficheiro existente.

## Diagnóstico temporal offline implementado

`benchmarks/diagnose.py` importa JSON de formato 1, separado do manifesto de frametimes. O [exemplo sintético](../benchmarks/session.example.json) documenta o formato; não contém medições reais e não captura o host.

```powershell
python -B benchmarks/diagnose.py benchmarks/session.example.json --output session-synthetic-result.json
```

O relógio é relativo e monotónico, em segundos. Cada amostra declara `logical_processors` ao nível da sessão e processos com ID anónimo `P001`–`P999`, token de vida `L001`–`L999`, CPU acumulada em segundos, bytes acumulados de leitura/escrita e memória privada em bytes. Usar token novo após reinício/reutilização do PID. O operador mapeia o processo do jogo. Contadores ausentes são null, nunca zero presumido. Amostras não crescentes, deltas negativos, CPU impossível por processo e valores não finitos são recusados.

Saída por janela: CPU em equivalentes de core e percentagem da capacidade lógica, taxas de I/O, memória privada, memória disponível/fração de commit e métricas opcionais do volume explicitamente identificado como o do jogo. Não soma working sets. I/O de processo não equivale a I/O físico; CPU total não prova espera da thread crítica. Não há recolha automática, ligação temporal a frames, métricas GPU ou sensores térmicos.

Candidatos a inspeção excedem 0,25 core ou 1 MiB/s de I/O de processo numa janela com a mesma vida do jogo observada nas duas fronteiras. São limiares de engenharia, não diagnóstico causal nem autorização para fechar processos. Picos entre amostras podem escapar; observar fronteiras não prova atividade contínua. O resultado pode não justificar qualquer alteração.

A saída usa apenas IDs e métricas previstas; não copia nomes, comandos ou caminhos adicionais. O JSON bruto continua sob responsabilidade do operador e deve ser revisto antes de partilha. Não existe autenticação da identidade ou anonimização garantida de dados introduzidos pelo utilizador. O destino não substitui ficheiros existentes. O overhead do futuro coletor terá de ser medido por A/A antes de orientar decisões.

## Separar provas

- **Testes de código:** `Invoke-Pester -Script .\tests -EnableExit` dentro de Windows PowerShell 5.1 com Pester 3.4; ver comando explícito no README. Mocks e ficheiros temporários verificam lógica, falhas e recuperação. Não medem desempenho do Windows.
- **Integração:** Windows descartável para comandos reais, permissões, formatos e reinícios. Snapshot/imagem antes de cada cenário. Uma VM não representa desempenho de CPU/GPU/NIC física.
- **Desempenho:** máquinas físicas de laboratório com configuração controlada e recuperação preparada. Só estes ensaios podem sustentar ganhos do produto.

## Identificação de cada ensaio

Guardar commit/hash do otimizador, IDs das ações, versão do jogo, cena/servidor, versão do capturador e parâmetros. Registar CPU/topologia, GPU, RAM, armazenamento, NIC, BIOS, drivers, build/edição do Windows, estado de segurança/anti-cheat e plano de energia.

Fixar resolução, render scale, API, qualidade gráfica, modo de apresentação, FPS cap, V-Sync/VRR, frame generation, frequência do monitor, polling dos periféricos e AC/DC. Registar temperatura ambiente, clocks, potência e temperaturas observadas. Marcar campos indisponíveis como desconhecidos.

Não limpar caches entre A e B. Aquecer igualmente ambos os cenários. Usar dados locais ou servidor controlado; sessões públicas de FiveM com jogadores/carga diferentes não isolam o tweak.

## Desenho A/B

1. **A:** estado original registado. Reiniciar quando necessário; aguardar estabilização e aquecer a cena.
2. **B:** aplicar apenas a ação ou grupo inseparável em estudo. Confirmar pós-condições e reinício antes de medir.
3. Começar por piloto A/A e depois 8–10 pares A/B, com ordem AB/BA equilibrada e aleatorizada, distribuídos por pelo menos dois blocos/dias. Cenas de 120–180 segundos são um ponto de partida; dimensionar a confirmação pela dispersão e efeito mínimo pré-registado. Nenhum destes números garante poder estatístico.
4. Fixar antes do teste os critérios de exclusão: crash, perda de foco, cena errada ou falha de captura. Não excluir um run por ter FPS baixo.
5. Repetir A após Undo para detetar deriva térmica, de cache ou do ambiente. Comparar configurações, não apenas o contador de FPS.
6. Acrescentar sessão de 20–30 minutos para alterações de energia: um ganho curto não basta se houver regressão térmica sustentada.

Usar Laboratory para seleção exata de uma ação e dependências; Extreme continua a herdar 9/41/79. No Windows 11, 9 fica Incompatible, sem mudar captura. Registar ações efetivamente aplicadas e estados incompletos, não apenas o perfil pedido. Incluir controlo negativo sem a carga presumida; manter segurança/anti-cheat constantes. Bootstrap por pares/blocos, dimensionamento e critérios de promoção do protocolo Work continuam por implementar no analisador; guardar par, bloco, ordem e contexto junto dos dados brutos para análise futura.

### Primeiro ensaio específico deste lote

Comparar original, cópia Sky sem alterações de índices e cópia Sky com ação 3. A cópia simples deve preservar os índices do original; não é apresentada como um ganho de performance.

Testar core parking em desktop Intel/AMD e em portátil AC, separadamente. Incluir topologias híbridas/X3D apenas quando houver máquinas físicas e metodologia adequadas. Verificar também que os índices DC permanecem iguais; não concluir isso a partir de o portátil estar ligado à tomada.

A ação 8 atual altera apenas a política AC de suspensão seletiva no plano Sky, com AC confirmado. Não altera hubs/dispositivos; a antiga receita por dispositivo é a ação 39, retirada. Continua experimental e sem validação física.

O Undo reativa o plano original e conserva cópias Sky potencialmente alteradas externamente, com Unverified/código 2. Comparar GUID ativo e índices AC/DC do original; não exigir limpeza automática das cópias nem ocultar este resultado incompleto no manifesto do ensaio.

## Métricas e fórmulas

Capturar frame times com ferramenta de versão fixada. [PresentMon](https://github.com/GameTechDev/PresentMon) fornece captura e métricas de apresentação; escolher e documentar o campo utilizado. A disponibilidade/semântica dos campos depende da versão e da instrumentação. Não misturar intervalos de apresentação, renderização e visualização como se fossem equivalentes.

Para uma série de intervalos válidos `t_i`, em milissegundos:

- **FPS médio:** `1000 × N / soma(t_i)`. Não usar a média aritmética dos FPS instantâneos.
- **1% low deste protocolo:** ordenar `t_i` de forma decrescente, selecionar `ceil(0.01 × N)` intervalos e calcular `1000 / média(desses intervalos)`. Declarar esta definição; outras ferramentas podem usar outra.
- **Distribuição:** p50, p95, p99 e p99,9 de frametime, com método de percentil fixado; guardar histograma e série temporal.
- **Picos:** `count` conta frames acima do limiar; `incidents` agrega frames consecutivos acima desse limiar; `incidents_per_minute` normaliza pela duração total dos intervalos. `total_interval_ms` soma os intervalos acima do limiar; `excess_ms` soma apenas a parte acima do limiar. São métricas distintas. Limiares atuais: 16,667 ms, 33,333 ms e 50 ms; interpretar em função do FPS alvo, sem os ajustar após observar resultados.
- **Consistência:** resultados por run, mediana entre runs, dispersão e intervalos de confiança calculados sobre runs independentes. Não tratar milhões de frames correlacionados como milhões de ensaios independentes.
- **Carga:** CPU/GPU utilization, clocks, temperaturas, potência, RAM/VRAM e atividade de armazenamento. Manter o mesmo intervalo e overhead de amostragem.

Separar FPS renderizados e gerados. Um aumento de frames apresentados por frame generation não prova redução de latência de controlo.

## DPC/ISR e latência de entrada

Para spikes reproduzidos, recolher ETW/WPR em sessão separada ou com overhead igual entre condições. Correlacionar os instantes de stutter com CPU ready time, DPC/ISR, I/O e atividade de drivers no WPA. Não atribuir automaticamente o problema ao módulo com o maior máximo isolado. [Microsoft: CPU Analysis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/cpu-analysis).

Latência física de entrada exige instrumento compatível ou câmara de alta velocidade com procedimento calibrado. Declarar ponto inicial/final, taxa de amostragem e distribuição dos resultados. DPC, timer resolution, polling e latência de renderização não substituem click-to-photon. Não usar captura que injete código num jogo protegido sem confirmar suporte e regras do ambiente de teste.

## Rede

Fixar adaptador, driver, tipo de ligação, endpoints e carga. Medir gateway e destino remoto separadamente: RTT p50/p95/p99, perdas, throughput e jitter com definição explícita. Repetir em repouso e sob upload/download. Guardar alterações de offloads e consumo CPU.

Não deduzir hit registration a partir de um teste de débito TCP ou de ping ICMP. Identificar protocolo do jogo e condições do servidor.

## Aceitação

Promover uma alteração apenas quando a melhoria ultrapassa a variabilidade entre runs e se repete na classe de hardware declarada. Definir a tolerância de regressão antes do ensaio; não escolher a posteriori a métrica que melhorou.

Resultados inconclusivos permanecem experimentais. Falhas de boot, sleep/resume, áudio, USB, rede, anti-cheat ou recuperação bloqueiam a promoção, mesmo com maior FPS médio. Arquivar resultados brutos, manifestos, gráficos e falhas, incluindo resultados negativos.

Esta versão inclui análise descritiva de CSV e diagnóstico de amostras JSON. A Fase 5D implementa recolha autorizada de frames/processos e inferência exploratória por blocos, com validação real pendente. Integração de sensores e latência física continuam por implementar. [Entrega da Fase 5D](FASE5D.md) e [histórico da Fase 5C](FASE5C.md).
