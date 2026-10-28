# SkyOptimizer — protocolo de validação funcional e desempenho

**Estado:** plano para execução futura em laboratório autorizado. Nenhum resultado físico foi produzido nesta investigação. A VM valida integração; não prova desempenho de GPU, USB, NIC, firmware ou latência física.

## 1. Pergunta experimental e pré-registo

Antes de cada experiência, guardar hipótese, mecanismo, ação/versão, contexto, efeito mínimo relevante, métrica primária, tolerâncias de regressão, tamanho planeado, exclusões e critério de paragem. Exemplo: “Desligar gravação histórica reduz p99 de frametime quando a captura está ativa neste jogo/driver, sem piorar 1% low ou causar falhas.”

Não testar “otimização geral” sem definir a carga. Para cada categoria, incluir **controlo negativo** sem o problema presumido. Se debloat só ajuda com sincronização ativa, não anunciar benefício em sistemas já em repouso.

## 2. Gate funcional anterior aos benchmarks

Reutilizar `INTEGRACAO-VM.md`, `VALIDACAO-FASE4.md` e Fase 5A. Confirmar identidade/conta, build/edição, hash do produto, snapshot recuperável e escopo do leitor antes de Apply. Recolher Before, AfterApply, AfterReboot, AfterUndo e AfterUndoReboot. Repetir Apply/Undo e testar falha parcial, conflito externo, concorrência, conta elevada diferente e falta de espaço/acesso.

Resultado por recurso: Pass, Fail, Inconclusive ou NotRun. A igualdade de digest só prova o estado observado no escopo. Confirmar também captura, notificações, pesquisa, Store/jogos, rede, áudio, input e atualização conforme recurso. Restore de snapshot é recuperação de laboratório; não é prova de Undo. Cópias de energia conservadas devem continuar declaradas como limitação.

## 3. Baselines e condições

- **S0:** Windows com drivers suportados, segurança preservada, manutenção concluída, sem SkyOptimizer aplicado. Não chamar “stock” a um Windows previamente depurado.
- **S1:** S0 + uma intervenção e dependências explícitas.
- **S2:** perfil completo, medido depois das intervenções individuais.
- **S3:** retorno a S0 por Undo verificado, para procurar carryover e reversão incompleta.

No produto atual, Extreme inclui 9/41/79. Para atribuir uma experiência adicional, comparar Performance contra Performance + experiência, ou criar futuramente o modo de seleção exata. Não atribuir toda a diferença S0→Extreme a um único ID.

Manter Defender/VBS/Secure Boot e outras proteções constantes. Não desligar segurança para reduzir ruído. Controlar atualizações por um período de ensaio definido, com manutenção retomada depois, sem alterar permanentemente serviços.

## 4. Manifesto de reprodução

Guardar CPU/topologia, placa/BIOS, RAM e configuração conhecida, GPU/driver, chipset, NIC/driver/ligação, volume/disco, Windows build/KB/edição, alimentação/estado de bateria, plano/índices, monitor/Hz/VRR/HDR, periféricos/polling, versões de jogo e anti-cheat, API/present mode, resolução interna/externa, preset, cap/V-Sync, upscaling/FG, overlays/captura, ferramentas e hashes.

Por run: ID, condição, par/bloco/dia, ordem sorteada, boot, hora, duração, cena/replay/seed, processos relevantes, temperatura ambiente quando possível, temperaturas/clocks/potência, estado de cache, logs de falha e hash do CSV. Marcar Unknown quando não observado. Não inventar XMP ou canais por módulos instalados.

Fixar ferramentas e semântica de campos. **GPU busy/render duration não é intervalo entre frames** e não pode ser convertido em FPS com `1000/duração` como se fosse cadência. Adaptar o manifesto existente para impedir esse erro.

## 5. Ordem, repetição e aquecimento

1. Fazer um piloto A/A para medir variabilidade natural e overhead da captura.
2. Pré-aquecer jogo/cache e sistema de forma idêntica; usar patamar térmico estável, sem exigir a mesma temperatura final quando o efeito da intervenção é precisamente térmico.
3. Usar cenas determinísticas de 120–180 segundos como ponto de partida; aumentar duração para eventos raros. Não escolher duração depois de observar resultado favorável.
4. Começar o piloto com 8–10 pares A/B e ordem AB/BA equilibrada e aleatorizada, distribuída por pelo menos dois blocos/dias. Não tratar este número como poder estatístico garantido.
5. Estimar dispersão das diferenças emparelhadas; dimensionar confirmação para o efeito mínimo e poder escolhidos. Para diferenças logarítmicas aproximadamente normais, a aproximação `n ≈ ((1,96 + 0,84) × s_d / δ)^2` dá orientação para 80% de poder, não substitui análise do desenho.
6. Reboot simétrico quando necessário; reaquecer depois. Verificar estado efetivo e Undo antes de trocar condição.
7. Conservar todos os runs válidos. Excluir apenas por regras prévias, como cena errada, captura truncada ou atualização inesperada, guardando motivo e dados.

Medir separadamente cache fria, primeira execução e estado aquecido. Não limpar cache antes de B se A estava aquecido. Para energia, acrescentar sessões de 20–30 minutos ou mais conforme tempo até estabilização. Em bateria, controlar carga inicial e QoS por inatividade; um replay sem input pode não representar jogo real. [Microsoft, QoS](https://learn.microsoft.com/en-us/windows/win32/procthread/quality-of-service).

## 6. Métricas e análise

Manter as definições corretas já existentes no analisador:

- FPS médio = `1000 × N / soma(t_i)`, para intervalos válidos em ms.
- 1% low = `1000 / média(dos ceil(0,01 × N) maiores t_i)`. Não é necessariamente o inverso do percentil 99.
- Frametime: p50/p95/p99/p99,9, método nearest-rank fixado, série temporal e histograma.
- Picos: eventos/minuto acima de limiares pré-definidos, por exemplo 16,667/33,333/50 ms e limiar adequado ao FPS alvo. Agregar frames consecutivos para distinguir um incidente de vários; guardar contagem de frames e incidentes.
- Duração: tempo total dos intervalos acima do limite e tempo excedente sobre o limite são métricas diferentes. Nomear corretamente.
- Recursos: CPU por processo/thread, GPU engines, memória/commit, faults, I/O, rede, clocks, potência e temperaturas quando disponíveis. Ausência de sensor não vira zero.

Unidade experimental é o run/par, não cada frame. Para FPS, analisar razão B/A por par, preferencialmente no domínio logarítmico; para latência/frametime, usar direção de melhoria correta. Estimar CI de 95% por bootstrap dos pares/blocos ou método adequado ao desenho. Preservar agrupamento por dia/máquina. Runs no mesmo boot não são independentes por decreto.

O analisador atual calcula estatística descritiva e dispersão, mas não CI nem significância. Acrescentar estas funções com dados sintéticos de efeito conhecido, nulo e regressão; testar seeds e robustez. Não interpretar aviso “menos de cinco runs” como prova de que cinco chegam.

Escolher uma métrica primária por hipótese e guardrails. Vários jogos/tweaks/métricas geram multiplicidade: aplicar correção apropriada ou confirmação independente pré-registada. Não escolher apenas os melhores jogos. Separar descoberta e confirmação; relatar inconclusivos e regressões.

## 7. Critérios objetivos propostos

Os valores abaixo são **limiares iniciais de engenharia**, não limites universais de perceção nem ganhos previstos. Calibrá-los no piloto e fixá-los antes da confirmação.

| Decisão | Critério |
|---|---|
| Promover num domínio específico | CI de 95% da melhoria primária inteiramente além do efeito mínimo; replicação em novas sessões; função e recuperação aprovadas |
| Exemplo de efeito mínimo | 2% para FPS/1% low, ou 5% para redução de p99. Para latência física, maior entre 1 ms e a incerteza instrumental justificada |
| Guardrail de regressão | Demonstrar não inferioridade com margem previamente fixada, por exemplo 2% para FPS/1% low e 5% para p99; falta de poder mantém inconclusivo |
| Rejeitar promoção | Qualquer falha de segurança, boot, anti-cheat, áudio/input, atualização, dados ou recuperação; maior FPS não compensa |
| Manter experimental | CI cruza ausência de efeito ou limiar relevante; não usar “sem significância” como prova de equivalência |
| Retirar como otimização automática | Ensaio com poder adequado exclui benefício mínimo no domínio, ou regressão/custo supera benefício |
| Conservar como preferência | Utilidade funcional escolhida pelo cliente, rotulada sem benefício FPS demonstrado |

Temperatura, consumo, autonomia e ruído também são guardrails, com limites acordados por classe/OEM. Não há um limite térmico universal para todas as CPUs. Não esconder regressão num jogo através de média geométrica positiva noutros.

## 8. Campanhas por categoria

| Categoria | Carga e controlos | Prova de mecanismo/resultado |
|---|---|---|
| Background/debloat | Jogo sozinho e jogo com browser, sync ou launcher reproduzível | Trabalho concorrente reduzido e melhoria de jogo; custo funcional preservado |
| Captura/overlays | Captura ativa/inativa e overlay individual; mesmas definições | Encoder/composição/I/O e frametimes; confirmar possibilidade de voltar a gravar |
| CPU/energia | CPU-bound, carga mista com OBS e GPU-bound; sessão curta e longa | Ready/placement, clocks efetivos, potência, temperatura, lows |
| Memória | Capacidade baixa e ampla, com workload real controlado | Commit/faults/I/O e stutter; sem stress artificial apresentado como uso normal |
| Armazenamento/cache | Carregamento, traversal e cena residente; frio/quente separados | Latência I/O, compilação quando observável, loading e picos |
| GPU/apresentação | DX11/DX12, fullscreen/borderless, VRR/cap/FG fixados | PresentMode, frames renderizados/mostrados, fluidez e input |
| NIC | Endpoints locais/remotos, idle/upload/download, protocolo definido | RTT p50/p95/p99, perda, throughput, jitter com fórmula, CPU/DPC |
| USB/input | Movimento/clicks repetidos, várias taxas e portas/docks | Frametime sob input e latência física; sleep/resume e desconexões |

WPR/WPA pode alterar overhead: recolher sessão de diagnóstico separada ou igualar instrumentação e quantificar custo. Não inferir causalidade apenas do trace. [Microsoft, CPU Analysis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/cpu-analysis).

## 9. Latência de entrada

Usar equipamento compatível de medição end-to-end ou câmara de alta velocidade com trigger elétrico/LED e resposta de ecrã definidos. Fixar local vertical do alvo, refresh, overdrive, brilho e método de detetar mudança. A câmara de 1.000 fps tem intervalo nominal de 1 ms, mas exposição, sincronização e deteção adicionam incerteza; não anunciar precisão sub-ms automaticamente.

Como piloto, recolher pelo menos 100 eventos por condição distribuídos por blocos; determinar amostra final pela variabilidade. Publicar p50/p95, dispersão, CI e incerteza. Se só houver telemetria software, nomear os pontos de medição e marcar latência física não medida. PresentMon pode disponibilizar campos de input/display conforme versão e instrumentação; o nome do campo não prova medição do periférico à luz emitida. [PresentMon, métricas](https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md).

## 10. Matriz de hardware e publicação

Começar com cinco células: desktop antigo com pouca RAM/HDD ou SATA; desktop moderno convencional; Intel híbrido; portátil híbrido em AC e bateria; Ryzen multi-CCD/X3D. Cobrir NVIDIA/AMD/Intel ao expandir. Uma unidade por classe é piloto, não validação de toda a classe. Confirmar regras automáticas em mais de uma unidade/configuração independente e vários jogos pertinentes.

Selecionar pelo menos um e-sport CPU-bound, um AAA GPU-bound, um DX11 em janela, um jogo com streaming/compilação e uma sessão com captura. Fixar versões; não inferir compatibilidade anti-cheat por um teste em jogo offline.

Publicar por experiência: hipótese, domínio de validade, configuração, alterações exatas, dados por run, resultados negativos, CI, falhas e limitações. Guardar CSV bruto, manifestos, hashes, versões, scripts de análise e relatório funcional. Dados privados/traces completos ficam separados do pacote público. Um relatório comercial só pode dizer “melhorou X nesta configuração e protocolo” quando esse ensaio existir.
