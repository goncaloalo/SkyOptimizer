# Fase 5D — instrumentação e avaliação de desempenho

Base `7d0a285`, branch `dev/phase2-execution-power-safety`, 29/10/2026. Desenvolvimento offline com a skill lean-build: reutilizar análise/diagnóstico existentes, completar um percurso de captura autorizada até relatório e testar falhas sem executar leitores Windows ou binários externos. Nenhuma expansão das 90 ações: permanecem 26 elegíveis, 58 bloqueadas, cinco retiradas e manutenção 24.

## Blocos entregues

1. `benchmarks/experiment.py`: reutiliza `analyze_manifest`; pares completos A/B dentro de blocos, ordem temporal, bootstrap de clusters e relatório JSON/Markdown.
2. `benchmarks/capture.py`: plano por defeito e execução apenas com switch explícito de laboratório. Adaptador de argumentos para PresentMon Console **2.3.1**, não para GUI/serviço ou versões arbitrárias. Não instala, descarrega, eleva nem lança jogos.
3. `benchmarks/Collect-SkySession.ps1`: amostragem automática de processos por .NET, exportando o formato do diagnóstico existente, com identidade anónima e vida do processo. `normalize.py`: seleção exata do stream CSV e evidência da transformação.
4. `diagnose.py`: hipóteses orientadas pela atividade concorrente e commit observado, acompanhadas da próxima medição. Não escolhe ações com base num ID anónimo e não fecha processos.

## Ferramentas, compatibilidade e confiança

Escolhida a console PresentMon por permitir captura ETW externa ao jogo. O [README 2.3.1](https://github.com/GameTechDev/PresentMon/blob/v2.3.1/README-ConsoleApplication.md) documenta seleção por PID, duração, sessão e CSV. O adaptador usa métricas legadas (`--v1_metrics`), com `MsBetweenPresents` como intervalo de apresentação. Esse modo não fornece o conjunto completo de telemetria moderna. Não estima clocks, potência, temperatura, DPC/ISR ou latência física.

O [projeto 2.3.1](https://github.com/GameTechDev/PresentMon/blob/v2.3.1/README.md) descreve ETW, limitações de instrumentação por API/HAGS e acesso através de Performance Log Users; elevação pode ser necessária conforme contexto. Este código não altera grupos nem requisitos de segurança. Alvo inicial de laboratório: Windows cliente x64. Sistemas/jogos/anti-cheats específicos e permissões continuam sem certificação.

A [licença 2.3.1](https://github.com/GameTechDev/PresentMon/blob/v2.3.1/LICENSE.txt) permite uso comercial sob MIT, preservando o aviso. Nenhum binário foi incorporado. Antes de distribuir uma build, verificar também avisos e dependências dessa distribuição. O operador deve obter uma release oficial, confirmar origem, versão e assinatura quando disponível e aprovar o SHA-256 por canal confiável. Calcular um hash de um ficheiro desconhecido não o torna fiável. O adaptador apenas compara os bytes com o hash aprovado e volta a verificar antes do lançamento; não autentica a origem nem infere versão pelo nome.

Cada execução recebe uma sessão ETW própria e diretório novo. Nunca usa stop_existing_session ou restart_as_admin. Timeout encerra apenas o subprocesso lançado; a limpeza da sessão ETW fica Unverified e deve ser inspecionada pelo nome registado. Não parar sessões alheias. Nonzero, timeout, falta de CSV ou CSV vazio são falhas. Exit zero com CSV é **CapturedUnvalidated**, não benchmark aprovado. Guardam-se código, duração, hashes e logs locais. Os logs/CSV podem conter nomes de aplicações, PID, caminhos ou outros dados privados; rever antes de partilhar.

## Coletor de concorrência

`Process.TotalProcessorTime` fornece CPU acumulada, somando tempo de utilizador e kernel ([API .NET](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.totalprocessortime?view=netframework-4.8.1)). StartTime distingue reutilização de PID; PrivateMemorySize64 observa memória privada. O total lógico vem de [Win32_ComputerSystem](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-computersystem); ausência ou mais de 64 CPUs bloqueiam a normalização ainda sem suporte a processor groups.

Requer x64 Windows PowerShell 5.1 e switch explícito. O PID alvo deve ser legível na primeira amostra. Processos inacessíveis são contados e omitidos, nunca interpretados como consumo zero. IDs P001 e Lnnn não incluem nomes, comandos ou StartTime. Limite de 999 identidades/vidas evita colisões; excedê-lo falha a recolha. Acesso parcial e saída do jogo reduzem cobertura; o diagnóstico não classifica atividade após a saída como concorrência do jogo.

Campos de I/O, memória disponível/commit, GPU e disco permanecem null neste coletor. A hipótese de commit alto só se aplica a importações que efetivamente forneçam commit. O tempo de leitura de cada amostra é registado. Leituras sequenciais não são snapshots atómicos; tempos relativos delimitam a aproximação. O intervalo real inclui o tempo de coleta e pode perder picos. Gravação é exclusiva; uma falha pode deixar um ficheiro incompleto, que não deve ser apresentado como sessão válida. Não se mede overhead real através de mocks.

## Inferência estatística e apresentação

Manifesto de frametimes continua no formato 2. O template `benchmarks/experiment.example.json` acrescenta design pré-registado: métrica primária, benefício mínimo, margem de regressão, seed e número de resamples; cada run declara par, bloco e ordem. Os campos devem ser preenchidos antes de observar resultados. A ferramenta não prova quando o pré-registo foi feito.

Métricas fixas: FPS médio, 1% low e p99 de frametime. Calculam-se razões B/A em log; para p99 usa-se A/B para que maior seja sempre melhor. Este último número é **razão recíproca**, não percentagem de redução do p99. A média dos logs por bloco tem peso igual entre blocos. O bootstrap amostra blocos completos, conservando os pares; não reamostra frames como observações independentes. Reporta dispersão entre pares e entre blocos. Seed fixa torna o cálculo reproduzível.

Intervalos percentis com correção Bonferroni para as três métricas pretendem cobertura familiar aproximada de 95%; não são garantia finita, teste causal ou substituto de dimensionamento. Outros jogos, tweaks e escolhas posteriores acrescentam multiplicidade que esta correção não resolve. Blocos declarados não provam independência; CI com poucos clusters pode ser demasiado estreito. Menos de cinco blocos ou oito pares, ordem AB/BA desequilibrada, runs curtos ou avisos do analisador forçam Inconclusive. Estes mínimos são gates conservadores de engenharia, não poder estatístico garantido.

Estados: BenefitDetected quando o limite inferior supera benefício mínimo e todas as métricas passam a margem de regressão; Regression quando um intervalo inteiro demonstra regressão além da margem; NoMeaningfulBenefit quando o intervalo primário exclui benefício relevante e regressão material; restantes Inconclusive. Um guardrail não aprovado impede benefício global. Ausência de significância não prova equivalência. Resultados continuam exploratórios até replicação, revisão funcional e confirmação independente.

Relatórios guardam métricas por run, hashes dos CSV e manifesto, exclusões e limitações. Dados com `synthetic:true` recebem aviso visível de dados sintéticos. O operador não deve retirar esse marcador de fixtures. Nenhum resultado sintético desta fase representa ganho SkyOptimizer.

## Primeira experiência A/B reproduzível — execução futura autorizada

1. Passar primeiro o gate funcional em Windows descartável: snapshot, identidade, Apply, reinício, Undo, conflito e falha, seguindo `INTEGRACAO-VM.md`. Confirmar a ação pretendida e dependências. Usar Laboratory do produto existente; estes módulos não têm setters nem outro diário.
2. Em hardware físico, registar commit/hash, versões, cena determinística, resolução/cap/VRR/FG, cache, segurança, drivers, alimentação, temperaturas e plano. Começar por A/A para variabilidade e overhead. Comparar captura de frames isolada com frames + coletor de processos, mantendo a captura base igual. Medir também custo de CPU/I/O do capturador. Não assumir overhead desprezável.
3. Pré-registar hipótese, métrica e margens. A é baseline confirmada; B é **uma** ação e dependências via Laboratory. Exemplo possível: 41 apenas num sistema com browser suportado e carga de background reproduzível. Incluir controlo negativo com browser inativo. A escolha não implica benefício esperado universal.
4. Aquecer igualmente a cena. Como piloto, 8–10 pares de 150 segundos, AB/BA equilibrado e aleatorizado, em pelo menos dois blocos/dias. Guardar ordem e estado; o piloto continuará inconclusivo pelo gate conservador de clusters. Dimensionar confirmação e expandir para pelo menos cinco blocos independentes antes de qualquer classificação de benefício, sem tratar esse número como amostra suficiente por definição.
5. Para cada run, fornecer PID atual e diretório novo. Comando sem o switch final apenas mostra plano. Os exemplos seguintes são para laboratório futuro, **não foram executados neste host**:

```powershell
python -B benchmarks/capture.py --tool C:\Lab\PresentMon-2.3.1-x64.exe --approved-sha256 HASH_APROVADO --pid 1234 --seconds 150 --output C:\Lab\A1-raw
# Acrescentar --execute-authorized-lab-capture apenas após validar plano, origem e autorização.

# Em consola separada, somente quando se pretende diagnóstico de concorrência:
.\benchmarks\Collect-SkySession.ps1 -GameProcessId 1234 -Seconds 150 -OutputPath C:\Lab\A1-session.json -ExecuteAuthorizedLabCapture
python -B benchmarks/diagnose.py C:\Lab\A1-session.json --output C:\Lab\A1-diagnosis.json

# Escolher explicitamente a swapchain do jogo após inspecionar os streams brutos:
python -B benchmarks/normalize.py C:\Lab\A1-raw\frames.csv --pid 1234 --swapchain 0x123 --output C:\Lab\A1-normalized
```

6. `normalize.py` mantém só PID/swapchain declarados e regista quantas linhas de outros streams excluiu. Admite apenas um zero inicial do stream como fronteira sem intervalo anterior, registando-o explicitamente. Qualquer zero posterior, NaN, negativo ou linha malformada falha; nunca eliminar outliers de frametime. Guardar o raw intacto. Os CSV normalizados usam FrameTimeMs e fonte/semântica documentadas no manifesto.
7. Preencher `experiment.example.json` com todos os runs/ambiente e caminhos relativos. Mudar de condição exige Undo verificado e reinício quando indicado; não inferir baseline por trocar o nome do perfil. Guardar evidência de Apply/Undo e condições junto dos CSV. Só a duração dos intervalos analisados conta, não o temporizador solicitado ao capturador.

```powershell
python -B benchmarks/experiment.py C:\Lab\manifest.json --output C:\Lab\report-01
```

8. Rever analysis.json, experiment.json e report.md, incluindo runs individuais, qualidade, regressões e retorno a A. Diretórios existentes são recusados. Latência física fica NotMeasured; o adaptador desativa tracking de input e não transforma telemetria de apresentação em click-to-photon. Instrumentos externos calibrados e um contrato de importação específico são trabalho posterior.

## Validação e limites desta entrega

Testes Python cobrem efeito conhecido, nulo, regressão, guardrail, variabilidade, seed, pares inválidos, pilotos, falha/timeout de captura, alteração do binário, normalização e percurso CLI até relatório, sempre com dados sintéticos. Os testes Pester importam só funções por AST e substituem leitores de processos/CIM; nenhum ponto de entrada de captura é executado.

**234/234 testes Pester** e **34/34 Python** aprovados. Prova em `FASE5D-TESTES.json` e resumo em `TESTES-RESULTADO.json`. Não foram executados capturadores externos, APIs de coleta reais, jogos, VM, tweaks ou benchmarks. A compatibilidade real de ETW, CSV, permissões, versão, anti-cheat, durações, cleanup e overhead continua por validar. A amostragem de processos não está sincronizada com frames e não demonstra causalidade. Não existe captura automática de input físico, sensores ou decisão automática de aplicar tweaks.

Commits: `3536010` (estatística e testes) e `c787bf7` (captura, coleta, normalização e diagnóstico). A suite completa foi executada antes do segundo commit, sobre os mesmos bytes do coletor, identificados por SHA-256. `d49f386` acrescenta métricas A/B descritivas ao relatório; os 34 testes Python foram repetidos após essa alteração. O commit documental seguinte conserva prova, instruções e resultados. `SkyOptimizer.ps1` e o catálogo de ações não foram alterados nesta fase.
