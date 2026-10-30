# Fase 5E — SkyOptimizer MAX

Base `66b6c76`, branch `dev/phase2-execution-power-safety`. Transição incremental, sem alterar formatos dos diários nem aplicar configurações ao host de desenvolvimento.

## Plano e critérios de saída

1. Introduzir deteção e planeamento MAX somente de leitura, com motivos por ação e incerteza explícita. Reutilizar compatibilidade e elegibilidade existentes. Inventário pontual não identifica gargalos em jogos.
2. Usar MAX por omissão, com comandos técnicos DryRun, Diagnose, Undo e Laboratory. Conservar aliases antigos para scripts existentes. Retirar seleção comercial de perfis e terminar após cada execução; painel apenas por comando explícito.
3. Acrescentar controlo de arranque por contrato estrito, com confirmação do impacto funcional, identidade revalidada e remoção de um valor Run através do diário existente. Não usar StartupApproved não documentado nem eliminar aplicações/dados.
4. Testar plano, falhas, repetição, alterações externas, Undo e integração com a execução existente. Atualizar catálogo e prova.

Rollback: aliases e Laboratory continuam a ler os mesmos diários; Undo não depende da seleção atual. Não existe migração destrutiva de backups. O novo adapter utiliza Registry, já suportado pelos leitores anteriores, sem novo tipo ou esquema. Restaurar Git não desfaz configurações aplicadas: o comando Undo continua obrigatório em laboratório.

Limites: 48/71 continuam grupos suspensos; 49 não tem recuperação de pacote/dados comprovada. Hardware, drivers e ganho de desempenho exigem validação real. A implementação offline não promove experiências de energia/NIC/HAGS/MSI a decisões automáticas.

## Implementação entregue

`SkyOptimizer.ps1` sem parâmetros e `-Apply` executam MAX. O menu com nove opções foi substituído pelo fluxo único. O operador vê as alterações propostas, confirma os impactos funcionais quando existem e a execução termina. O BAT existente conserva exit codes e deixa de pausar após falha. Não foram criados serviços, tarefas de otimização, processos residentes, GUI ou outro launcher.

MAX usa `Invoke-SkyOptimize` e o dispatcher atuais com a seleção preparada. O modo de operador guarda o relatório junto dos backups, não instala painel e não pede ENTER no fim. `-DeployPanel` continua como comando técnico de compatibilidade; não faz parte de MAX. Laboratory conserva seleção exata. Os aliases Balanced/Performance/Extreme continuam disponíveis a scripts antigos; não são propostas comerciais. A escolha anterior de perfil não altera nem migra os diários.

O plano deteta Windows/edição, CPU/núcleos, GPU/driver, capacidade de RAM, chassis, alimentação, browsers e indicadores de gestão. CPU/GPU são observações de inventário; fabricante e nome não determinam afinidades, CCD, core parking, HAGS ou MSI. Topologia híbrida/X3D, margem térmica e gargalo em jogos continuam Unknown. Capacidade até 8 GiB gera recomendação de medir commit/faults, não de limpar memória. DC/Unknown nunca se transforma em AC.

Só os campos estáveis necessários do Windows entram no plano: RAM livre, utilizador registado e outros campos voláteis do objeto CIM não são copiados. O plano é refeito após confirmação; uma diferença impede Apply. Cada ação conserva ainda a própria verificação de compatibilidade e pós-verificação. Deteção de domínio ou indicador OMADM, ou dados desconhecidos nessas leituras, exclui políticas de background/arranque automáticas. Ausência destes indicadores **não certifica** ausência de MDM/GPO/local policy; o operador confirma essa condição e deve validar políticas efetivas no componente.

## Seleção MAX e mecanismo

| Contrato | Condição | Trabalho potencialmente evitado / custo funcional | Prova exigida |
|---|---|---|---|
| 79, Game Mode | Windows cliente conhecido na matriz, incluindo Home | Configuração de gaming nativa; não há ganho universal garantido | Confirmar consumo pelo Windows e comparar jogos CPU/GPU-bound |
| 41, browsers | Edge >=88 ou Chrome >=19 localizado; sem gestão observada | Evitar background após fecho e Startup Boost; perde funções de background e pode aumentar arranque do browser | Ver política efetiva, processos após fecho, carga controlada e A/B |
| 9, captura | Apenas Win10 conhecido e edições previstas | Evitar gravação quando produz carga; perde clips futuros | Gravação antes/depois/Undo e frametimes com controlo negativo sem captura |
| 16, Widgets | Win11 Pro/Enterprise/Education conhecidos | Desativar experiência Widgets por política, preservando WebView/pacotes | Reboot/login, função, processos e consumo; não basta desaparecer botão |
| 58/84, consumidor/Spotlight | Edições Enterprise/Education e builds já contratados | Reduzir experiências promocionais/conteúdo; perde funcionalidades associadas | Consumo efetivo de política e tráfego; debloat, sem FPS comprovado |
| 70, dicas online | Edições/builds já contratados | Evitar obtenção de dicas nas Definições | Política e comportamento; prioridade baixa para gaming |
| Arranque Spotify/Steam | Entrada HKCU Run exata e binário reconhecido; confirmação funcional | Evitar iniciar automaticamente estes programas por essa entrada no próximo login | Login real, abertura manual, jogos/VR/controlador e Undo; carga durante jogo e A/B |

Exemplos verificados com mocks: Win11 Pro com Edge seleciona **16/41/70/79**; Win10 Enterprise com Edge seleciona **9/41/58/70/79/84**; Home com browser suportado seleciona **41/79**. Estado já conforme é devolvido pelo motor sem tomar posse de recursos intocados. O dry-run propõe contratos compatíveis; não é um snapshot de todas as pós-condições nem declara todos os recursos ainda divergentes.

As outras ações elegíveis continuam disponíveis tecnicamente, mas não ganham justificação automática por terem Undo. Exemplos: 1/3/8 são experiências de energia/USB; 6 depende de diagnóstico de SysMain; 13/17/59/86/88/90 têm objetivos de privacidade/preferência/compatibilidade; 19 altera instalação de drivers; 20 requer contexto de tráfego; 25 afeta globalmente apps; 38/60/74/75/76 exigem ensaios NIC; 42 usa armazenamento gráfico interno. Nenhuma destas passa para MAX por nome de CPU, quantidade de RAM ou número de processos.

## Debloat de arranque, exatamente o que muda

Os novos adapters só reconhecem dois contratos de registo: HKCU Run `Spotify` com caminho canónico AppData/Spotify e argumentos `--autostart --minimized`, e `Steam` em Program Files (x86)/Steam com `-silent`. Exigem linha de comando exata, tipo String/ExpandString, caminho sem reparse points, assinatura Authenticode válida, editor e ProductName previstos. Registam hash, versão e thumbprint para revalidar depois da confirmação. Qualquer variação fica Deferred/Unknown; não existe descoberta por substring nem execução do comando encontrado. Instalações Store, outras localizações, argumentos e mecanismos de arranque ficam por suportar.

O mecanismo é retirar **um valor Run**, não desinstalar nem parar processos. O Windows documenta este recurso de [arranque por login](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys). Não se manipula o formato interno de StartupApproved, RunOnce, tarefas de terceiros ou pastas de arranque. Uma entrada Run existente não prova que o Gestor de Tarefas a tenha deixado ativa; esse estado e o efeito real após login exigem validação. Por isso não se promete um processo a menos, nem encerramento imediato, nem eliminação de todas as fontes de arranque.

Assinatura/publisher demonstram identidade dentro do contrato, não dispensabilidade. O operador confirma a perda do arranque automático. Steam pode ser necessário para atualizações, Remote Play, VR e controladores; o cliente terá de o abrir quando precisar. Spotify continua disponível manualmente. OneDrive/backup, drivers, OEM, anticheats e outros programas não são considerados dispensáveis nem removidos por este adapter. Não existe promessa de reconstruir a atividade que deixou de acontecer no login.

O diário Registry existente conserva ausência/tipo/conteúdo literal antes da remoção. `ExpectedBefore` e nova leitura protegem contra alteração entre preview e escrita. Apply repetido não substitui a baseline; a entrada ausente deixa de ser candidata. Undo restaura exclusivamente o valor gerido. Uma app que recrie ou altere a entrada gera conflito, preservado para revisão. Backup falhado impede escrita; falha após remoção deixa intenção recuperável. O Undo não precisa de conhecer Spotify/Steam: utiliza o mesmo recurso Registry, incluindo no painel antigo compatível com esse formato.

Esta é uma extensão concreta de debloat persistente, com alcance limitado. Não equivale à remoção profunda de todos os componentes descritos na missão. Os contratos 48/71 e a remoção AppX/provisionamento 49 continuam bloqueados; não se desbloqueia recuperação de dados através de mocks de registo.

## Comandos e relatórios

```powershell
# Comandos para futuro laboratório autorizado; nenhum foi aplicado neste host.
.\SkyOptimizer.ps1 -DryRun
.\SkyOptimizer.ps1 -Diagnose
.\SkyOptimizer.ps1 -DebloatPreview
.\SkyOptimizer.ps1 -Apply
.\SkyOptimizer.ps1 -Undo
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "41"
```

DryRun/Diagnose devolvem o plano JSON sem criar diretórios, diários, locks ou pontos de restauro e sem exigir elevação automática. Podem ter cobertura reduzida como utilizador normal; Apply refaz tudo na conta elevada. `-DebloatPreview` mantém o inventário AppX de leitura. Não consumir estes comandos como se autorizassem posteriormente mutações: MAX prepara e confirma o próprio plano atual.

Os relatórios contêm identidade/paths locais e devem ser revistos antes de partilha. Dentro da pasta de backups protegida:

- `max_run.json`: início/fim, RunId e exit code da última tentativa; Started sem fim sinaliza interrupção. ConfigurationVerified não certifica consumo funcional nem FPS.
- `max_plan.json`: decisões dos 90 IDs, inventário, candidatos e incertezas. É proposta, não prova de Apply.
- `execution_results.json` e `operator_report.txt`: resultados do motor comum e snapshots, sem inferência de ganhos.
- `max_startup_results.json`: resultados dos adapters de arranque. Não se confundem com os 90 IDs históricos.
- `mutation_state.json` e `power_state.json`: baselines autoritativas, formatos preservados.

Os ficheiros auxiliares são da última execução que os alcançou; após cancelamento/erro precoce podem pertencer à execução anterior. Conferir sempre `max_run.json`, timestamps e diário. Arquivo por sessão completo continua pendente. Códigos: 0 configuração comunicada sem falhas; 1 falha; 2 incompleto, cancelado, incompatível ou com informação necessária desconhecida. Os desconhecidos de topologia/telemetria explicitamente fora da seleção não são transformados em falhas de ações inexistentes.

## Oportunidades fundamentadas e limites da automatização

O [PPM da Microsoft](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configure-processor-power-management-options) distingue core parking, estados de desempenho e classes heterogéneas. Não há fundamento para aplicar uma percentagem universal a Intel/AMD, híbridos ou X3D só pelo nome. Oportunidade seguinte: reader de topologia e observação de ready time/clocks/temperatura, seguido de hipótese individual em Laboratory. Conservar Game Bar/Gaming Services, componentes de chipset e gestão OEM evita destruir dependências antes dessa investigação.

Para GPU/input, [NVIDIA documenta Reflex nos jogos compatíveis](https://www.nvidia.com/en-gb/geforce/guides/system-latency-optimization-guide/) e [AMD oferece perfis por jogo](https://www.amd.com/en/resources/support-articles/faqs/DH3-012.html). São recomendações no jogo/driver, não flags universais aplicadas pelo PowerShell. Confirmar versão/API/jogo e medir latência com instrumentação apropriada. Atualizações de drivers, BIOS, refrigeração, RAM e configurações gráficas podem ter mais impacto que políticas Windows, mas exigem operação e validação próprias.

As políticas [Edge background](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled) e [Widgets](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests#allownewsandinterests) suportam os contratos usados. Outras políticas mantêm as fontes e limites das fases 3C/5C. Configuração persistida não prova que a funcionalidade foi consumida, que a carga desapareceu ou que melhorou o jogo.

## Validação real obrigatória

1. VM com snapshot: DryRun não altera o sistema; UAC preserva comando/conta; MAX termina; painel não é instalado; alias/Laboratory/Undo continuam funcionais. Verificar que nenhum serviço, tarefa ou processo Sky permanece.
2. Windows 10/11 e edições previstas: testar políticas consumidas e recuperação funcional. Domain/MDM e leituras falhadas devem reduzir seleção, sem alternativas especulativas.
3. Instalar versões oficiais dos dois programas de arranque em VM: validar editor/metadata/comandos reais, login, abertura manual, dados, dependências, reinstalação/update e recriação do Run. Identidade não reconhecida deve manter-se bloqueada; não alargar padrões para passar o teste.
4. Before/AfterApply/AfterReboot/AfterUndo/AfterUndoReboot, Apply repetido, Undo parcial, falta de espaço, falha após escrita, intervenção externa e conta elevada diferente. Conservar os originais e não usar snapshot restore como prova de Undo.
5. Hardware: A/A para overhead e A/B por intervenção, controlo negativo sem carga concorrente, cenas/temperatura/cache constantes e critérios da Fase 5D. Só depois comparar MAX completo contra baseline. Reportar FPS médio, lows, p99/picos e latência física apenas quando medida.

Não foram realizados estes ensaios. O produto ainda não está validado para distribuição ou utilização comercial generalizada.

## Recolha independente em VM

O novo `integration/evidence-max.json` é um superset com 16 valores de registo para Windows x64: 10 de Game Mode/captura/browsers, Widgets, três políticas CloudContent/Explorer e duas entradas Run. Não pressupõe que todos serão alterados. No Windows 11, por exemplo, os cinco valores de captura devem permanecer iguais. O escopo é testado contra as chamadas das sete ações e os recursos de arranque, usando mocks sem acesso ao registo.

Usar o coletor independente e as instruções de privacidade/chave HMAC da Fase 5A, substituindo a especificação antes de capturar Before:

```powershell
# Apenas no futuro guest descartável autorizado; não executar Apply no host de desenvolvimento.
$scope = Get-Content .\integration\evidence-max.json -Raw -Encoding UTF8 | ConvertFrom-Json
.\SkyOptimizer.ps1 -DryRun
# Capturar Before com $scope e a chave privada, como descrito na Fase 5A.
.\SkyOptimizer.ps1 -Apply
# Guardar saída, exit code, max_run e cópia dos diários. Capturar AfterApply.
# Repetir Apply para verificar baseline; reiniciar/login manualmente; capturar AfterReboot.
.\SkyOptimizer.ps1 -Undo
# Capturar AfterUndo; reiniciar/login; capturar AfterUndoReboot; comparar com Before.
```

Não abrir o BAT/PS1 sem parâmetros para “ver o menu”: agora inicia MAX. Criar uma pasta privada por tentativa e guardar relatórios antes de outro run. Manter mesma conta, chave, escopo e hash do produto nas cinco capturas. Equality apenas cobre os recursos observados; falhas de leitura são inconclusivas. Acrescentar inspeção funcional de políticas, login, contas, processos e ficheiros/tarefas/serviços criados fora do escopo. Falha de compatibilidade, baseline substituída, recurso externo sobrescrito ou diferença inexplicada após Undo reprova o caso.

Para benchmarking, conservar as ferramentas e o protocolo 5D. Primeiro testar A/A e intervenções isoladas com Laboratory. O controlo de arranque exige login e a mesma condição de abertura manual nas repetições. Depois comparar o conjunto MAX com baseline, com pares/blocos e carga concorrente controlada. Medir redução de concorrência é evidência do mecanismo; FPS/lows/frametimes precisam de dados do jogo. PresentMon não passa a componente residente de MAX.

## Testes, commits e estado final

- Suite completa: **254/254 Pester**, Windows PowerShell 5.1.26100.9711 e Pester 3.4.0, zero falhas, skipped ou pending. [Prova por teste](FASE5E-TESTES.json) com commit e hashes. Leitores/escritas Windows são mocks; ficheiros temporários exercitam os diários.
- Novas regressões: inventário estável/incerto; seleção Win10/11/edições/gestão; cancelamento/revalidação; execução única sem painel/pausa; identidade/comando de arranque; Apply repetido; tipo/conteúdo literal no Undo; falhas antes/depois da escrita; conflito externo; catálogo e escopo de 16 recursos.
- Os **34 testes Python** aprovados na Fase 5D permanecem evidência anterior: a árvore `benchmarks` está byte a byte igual ao commit base 66b6c76. Não foi repetida a suite sem alterações. A [síntese de testes](TESTES-RESULTADO.json) distingue ambas as datas/commits.
- Commit `75875af`: MAX, contratos de arranque e regressões de execução/Undo. Commit `1a17ce7`: catálogo MAX, template de evidência e testes de cobertura. A documentação e as provas ficam num commit próprio posterior; consultar `git log`.
- Continuam **26 ações elegíveis, 58 bloqueadas, cinco retiradas e uma manutenção**. Sete IDs têm seleção MAX condicional; os dois contratos de arranque não alteram a contagem histórica. Não foram desbloqueadas HAGS/MSI, AppX 49, serviços 48/71 ou tarefas de terceiros.
- Ficheiros de produto alterados: `SkyOptimizer.ps1` e o BAT existente `Executar-SkyOptimizer.bat`. Testes: `Max.Tests.ps1`, `StartupDebloat.Tests.ps1`, `ApplyFlow.Tests.ps1`, `Catalogue.Tests.ps1`, `EvidenceScope.Tests.ps1`. Acrescentado `integration/evidence-max.json`; README, catálogo, perfis e documentos/provas atualizados.

A prioridade seguinte é validar UAC/conta, políticas efetivas e os contratos oficiais de arranque numa VM recuperável. Depois medir benefícios e regressões em hardware. O debloat de AppX/OEM/serviços requer contratos por componente, prova de dependências e recuperação; não foi completado por esta entrega. Deteção real de topologia/termal e associação segura da telemetria ao componente continuam oportunidades. Não há evidência para prometer máximo FPS, menor input lag ou preparação comercial.
