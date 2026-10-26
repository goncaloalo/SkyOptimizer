# Protocolo de benchmarks — SkyOptimizer

Estado: preparado, ainda não executado. Não aplicar otimizações no Windows usado para desenvolver o projeto.

## Analisador offline implementado

`benchmarks/analyze.py` lê capturas CSV já recolhidas. Usa apenas a biblioteca padrão de Python 3.10+; não lança jogos, capturadores nem tweaks. Copiar `benchmarks/manifest.example.json`, preencher a identificação do sistema e acrescentar pelo menos cinco runs por condição. O exemplo não contém medições e é recusado enquanto faltarem os campos obrigatórios.

```powershell
python -B benchmarks/analyze.py caminho/manifest.json --output caminho/resultado.json
python -B -m unittest discover -s benchmarks/tests -v
```

O caminho de cada CSV é relativo ao manifesto. `frametime_column` deve identificar explicitamente intervalos em **milissegundos**. Não escolher durações de trabalho GPU, timestamps absolutos ou latência de renderização como se fossem intervalos entre frames. Declarar `interval_kind` como `present`, `display` ou `render`, conforme a captura e a documentação da versão utilizada. Não existe conversão automática entre estes conceitos.

É possível usar CSV normalizado com coluna `FrameTimeMs` ou indicar a coluna apropriada da versão fixada de PresentMon. Se existirem `ProcessID` ou `SwapChainAddress` com vários valores, selecionar o stream exato em `filters`, por exemplo `{"ProcessID":"1234","SwapChainAddress":"0x123"}`. Todas as condições devem representar a mesma cena/configuração. Guardar também a ordem temporal original e os ficheiros brutos.

O relatório inclui SHA-256 dos bytes analisados, exclusões por filtro, métricas por run, percentis nearest-rank, histograma, picos, mediana, desvio-padrão amostral e coeficiente de variação entre runs. Não mistura todos os frames de A/B numa única amostra independente. Comparações percentuais são descritivas; não são um teste de significância nem uma prova causal. Resultados com menos de cinco runs, menos de 60 segundos ou capturas reutilizadas ficam assinalados. Intervalos inválidos falham a análise; não são descartados silenciosamente.

O analisador não mede temperaturas, clocks, utilização CPU/GPU, DPC/ISR ou input lag. Estes dados devem acompanhar a sessão segundo o protocolo abaixo. Ainda não há integração de sensores, controlo automático de capturas, intervalos de confiança ou gráficos temporais automáticos. O output nunca substitui um ficheiro existente.

## Separar provas

- **Testes de código:** `Invoke-Pester -Script .\tests -EnableExit`. Mocks e ficheiros temporários verificam lógica, falhas e recuperação. Não medem desempenho do Windows.
- **Integração:** Windows descartável para comandos reais, permissões, formatos e reinícios. Snapshot/imagem antes de cada cenário. Uma VM não representa desempenho de CPU/GPU/NIC física.
- **Desempenho:** máquinas físicas de laboratório com configuração controlada e recuperação preparada. Só estes ensaios podem sustentar ganhos do produto.

## Identificação de cada ensaio

Guardar commit/hash do otimizador, IDs das ações, versão do jogo, cena/servidor, versão do capturador e parâmetros. Registar CPU/topologia, GPU, RAM, armazenamento, NIC, BIOS, drivers, build/edição do Windows, estado de segurança/anti-cheat e plano de energia.

Fixar resolução, render scale, API, qualidade gráfica, modo de apresentação, FPS cap, V-Sync/VRR, frame generation, frequência do monitor, polling dos periféricos e AC/DC. Registar temperatura ambiente, clocks, potência e temperaturas observadas. Marcar campos indisponíveis como desconhecidos.

Não limpar caches entre A e B. Aquecer igualmente ambos os cenários. Usar dados locais ou servidor controlado; sessões públicas de FiveM com jogadores/carga diferentes não isolam o tweak.

## Desenho A/B

1. **A:** estado original registado. Reiniciar quando necessário; aguardar estabilização e aquecer a cena.
2. **B:** aplicar apenas a ação ou grupo inseparável em estudo. Confirmar pós-condições e reinício antes de medir.
3. Fazer pelo menos cinco runs válidos por condição, de 60–120 segundos, com ordem alternada/randomizada. Aumentar duração/repetições para eventos raros ou variabilidade elevada.
4. Fixar antes do teste os critérios de exclusão: crash, perda de foco, cena errada ou falha de captura. Não excluir um run por ter FPS baixo.
5. Repetir A após Undo para detetar deriva térmica, de cache ou do ambiente. Comparar configurações, não apenas o contador de FPS.
6. Acrescentar sessão de 20–30 minutos para alterações de energia: um ganho curto não basta se houver regressão térmica sustentada.

### Primeiro ensaio específico deste lote

Comparar original, cópia Sky sem alterações de índices e cópia Sky com ação 3. A cópia simples deve preservar os índices do original; não é apresentada como um ganho de performance.

Testar core parking em desktop Intel/AMD e em portátil AC, separadamente. Incluir topologias híbridas/X3D apenas quando houver máquinas físicas e metodologia adequadas. Verificar também que os índices DC permanecem iguais; não concluir isso a partir de o portátil estar ligado à tomada.

A ação 8 completa ainda não deve ser promovida como validada: o percurso por dispositivo permanece legado. Para ensaiar apenas a política do plano, usar uma execução de laboratório delimitada e documentar essa diferença.

## Métricas e fórmulas

Capturar frame times com ferramenta de versão fixada. [PresentMon](https://github.com/GameTechDev/PresentMon) fornece captura e métricas de apresentação; escolher e documentar o campo utilizado. A disponibilidade/semântica dos campos depende da versão e da instrumentação. Não misturar intervalos de apresentação, renderização e visualização como se fossem equivalentes.

Para uma série de intervalos válidos `t_i`, em milissegundos:

- **FPS médio:** `1000 × N / soma(t_i)`. Não usar a média aritmética dos FPS instantâneos.
- **1% low deste protocolo:** ordenar `t_i` de forma decrescente, selecionar `ceil(0.01 × N)` intervalos e calcular `1000 / média(desses intervalos)`. Declarar esta definição; outras ferramentas podem usar outra.
- **Distribuição:** p50, p95, p99 e p99,9 de frametime, com método de percentil fixado; guardar histograma e série temporal.
- **Picos:** número e duração de intervalos acima de limiares escolhidos antes do ensaio, por exemplo 16,67 ms, 33,33 ms e 50 ms. Interpretar em função do FPS alvo.
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

Esta versão inclui o analisador offline de CSV descrito acima. A recolha automática e a integração de sensores continuam por implementar.
