# Fase 3C — políticas, tarefas e interação entre ações

Base preservada: `8ae45bd`, branch `dev/phase2-execution-power-safety`, inicialmente limpa. Apenas SkyOptimizer; sem push, sem VM/hardware e sem aplicar otimizações ao Windows de desenvolvimento.

## 1. Identidade, ownership e Undo parcial

A identidade do recurso já não depende da ordem dos campos JSON ou de maiúsculas no caminho/nome de registo. A baseline original é única por recurso ativo. Comparações de conteúdo continuam sensíveis ao tipo/conteúdo; normalizar identidade não altera dados do utilizador. Recursos de driver/tarefa também mantêm metadados de contrato, cuja substituição não é adotada silenciosamente.

O diário suporta os formatos 1 e 2. Escritas tradicionais conservam o formato 1. O formato 2 acrescenta referências opcionais de ações (`OwnerIds`). Duas ações que exigem o mesmo estado partilham a primeira baseline; estados opostos de proprietários diferentes são recusados antes de qualquer escrita. A ação já conforme antes de qualquer alteração não adquire baseline nem direito a desfazer uma preferência alheia.

`Restore-SkyTrackedChanges -OwnerActionId <ID>` é um mecanismo interno de reversão parcial. Liberta a referência de uma ação; só restaura o recurso quando não há outro proprietário. O Undo normal continua a restaurar o ciclo completo. Falhas e conflitos de um recurso não impedem a tentativa de restaurar recursos independentes.

Ao reutilizar uma entrada antiga sem ownership, o proprietário 0 representa origem desconhecida. Não se inventa a ação histórica: libertar a nova ação preserva essa referência; o Undo completo continua disponível. Não existe downgrade automático do diário. Leitores antigos aceitam apenas formato 1 e recusam formato 2; usar programa e painel da mesma versão, regenerando os scripts do painel antes de recuperar um diário novo. A recusa preserva os ficheiros e não importa defaults.

Esta proteção refere-se aos recursos realmente geridos. Não impõe intenções de ações que nunca alteraram o recurso, nem deteta toda a equivalência física entre APIs diferentes. Operações externas continuam a poder ocorrer entre leitura e escrita; não há transação global do Windows.

Validação inicial: testes de interação verificam ordens A/B e B/A, repetição, conflito de objetivos, caminhos equivalentes, ausência original, dados antigos, falhas de persistência, falha depois da mutação, Undo parcial e recursos independentes. Apenas mocks e TestDrive.

A revisão final encontrou uma falha de isolamento entre entradas: se a libertação de ownership falhasse ao gravar, o objeto em memória já estava alterado. Uma gravação posterior de outro recurso podia persistir essa libertação falhada. A regressão reproduziu o problema antes da correção. O Undo repõe agora as referências anteriores em memória quando essa gravação falha; recursos independentes continuam a recuperar e o retry não perde o proprietário.

## 2. Consolidação CloudContent / ContentDeliveryManager

| ID | Decisão | Contrato e alcance |
|---:|---|---|
| 14 | Consolidada em 58, retirada como ação separada | Não repete seis flags internas CDM. A substituição cobre experiências de consumidor documentadas, não promete todas as sugestões removidas. |
| 58 | Migrada | DisableWindowsConsumerFeatures em HKLM. Matriz Enterprise/N/LTSC e Education/N; mínimo conservador 17134 para evitar confundir o antigo escopo User com Device. Pro/Home recusadas. |
| 70 | Migrada | Apenas AllowOnlineTips no caminho Policies\Explorer, cliente conhecido >=16299. Não altera DisableSoftLanding nem outras políticas de CloudContent. |
| 84 | Migrada | DisableWindowsSpotlightFeatures em HKCU, Enterprise/Education conhecidas >=15063. Retira flags CDM sobrepostas e a escrita anterior no escopo HKLM incorreto. |

O mapa `Get-SkyCloudPolicySpec` centraliza valor, escopo, edição e build, mantendo os nomes de funções existentes. Escritas usam ownership 58/70/84. Todas continuam explícitas em Extreme; Balanced e Performance conservam os conjuntos anteriores. Não há terminação de processos, reinstalação de apps ou limpeza de preferências antigas.

As políticas têm sobreposição semântica: desligar Spotlight abrange funcionalidades relacionadas da conta, enquanto a política de consumidor é de máquina. Os escopos não são equivalentes. Não se força o parent Spotlight a permitido para tentar ativar um child; também não se considera a política HKLM redundante para outras contas. A pós-verificação confirma persistência, não consumo pelo componente ou tráfego evitado.

Fontes: [consumer features e Spotlight, edições/escopos](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience), [AllowOnlineTips](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-settings#allowonlinetips). Nenhuma flag SubscribedContent ou FeatureManagementEnabled é agora usada por 14/58/70/84.

Testes específicos: seis ordens de aplicação, repetição, Undo parcial/completo, preferências alheias preservadas, valores inicialmente conformes, builds/edições e falha de persistência numa ação intermédia. Testes de interação e política são simulações, sem integração Windows executada.

## 3. Tarefas: mecanismo preparado, sem tarefas reais elegíveis

O recurso `ScheduledTaskEnabled` usa o mesmo diário, lock, intenção persistida, pós-verificação e Undo. Só altera a propriedade Enabled de uma tarefa já registada. Não regista XML, não altera triggers, ações, principal, condições, privilégios ou segurança; não inicia, termina ou elimina tarefas.

Nesta fase, a única allowlist é de fixtures criadas pelo operador: `\SkyOptimizer-Lab\<GUID de 32 caracteres>\`, com nomes Fixture/Fixture [...]. `Disable-SkyScheduledTask` exige pasta/nome literais, fingerprint esperado e diretório de backup explícito. Não existe allowlist de tarefas de Windows/NVIDIA/terceiros. 26/56/68 mantêm o bloqueio e as funções diretas já não executam as antigas operações amplas.

A identificação inclui pasta/nome e hash SHA-256 da definição XML canonicalizada, excluindo apenas Settings/Enabled, mais owner/group/DACL obtidos por GetSecurityDescriptor(7). DTD/entidades externas, Enabled ausente/ambíguo ou inconsistência com a propriedade COM são recusados. Nome com parênteses retos é literal, nunca wildcard. Definição, principal, triggers, ações ou segurança diferentes impedem Apply/Undo automáticos. Recriação absolutamente idêntica não é distinguível por este fingerprint; SACL não é consultada nem modificada.

Ready/Disabled são os únicos estados aceites para iniciar a desativação; Running/Queued/Unknown são recusados. Não se tenta restaurar um instante de execução passado nem repetir uma execução para simular Undo. O estado restaurado é o Enabled configurado, não LastRunTime/resultado ou XML byte a byte. Mudanças externas depois da verificação continuam possíveis; não há compare-and-swap atómico no API.

O formato 2 é obrigatório para tarefas; o painel novo inclui os mesmos readers/writers e helpers de identidade. O formato 1 de registo/serviços continua legível. Não são abertas tarefas nem criados objetos COM reais nos testes: o adapter COM recebe objetos falsos e a lógica de diário usa um backend simulado.

Provas: Apply→Apply→Undo→Undo, originalmente Disabled sem autoria, recusa de tarefa substituída, estados em execução/fila, falha de backup, falha após escrita, sucesso sem efeito, retry de Undo e parsing do source standalone. Os testes de fingerprint incluem Enabled, comando, principal, segurança e XML inválido. Falta confirmar o comportamento de serialização do Task Scheduler real antes de permitir tarefas de produção.

Referências: [RegisteredTask.Enabled](https://learn.microsoft.com/en-us/windows/win32/taskschd/registeredtask-enabled), [XML](https://learn.microsoft.com/en-us/windows/win32/taskschd/registeredtask-xml), [segurança](https://learn.microsoft.com/en-us/windows/win32/taskschd/registeredtask-getsecuritydescriptor), [lookup literal](https://learn.microsoft.com/en-us/windows/win32/taskschd/taskfolder-gettask), [Enabled no schema](https://learn.microsoft.com/en-us/windows/win32/taskschd/taskschedulerschema-enabled-settingstype-element).

O [procedimento de fixtures](TAREFAS-LAB-3C.md) prepara a integração futura com snapshot, observação independente, reinício e conflitos. Não foi executado. Um snapshot recuperado não conta como prova de Undo.

## 4. Estado das ações e prioridades restantes

O catálogo conserva 90 IDs históricos: **28 elegíveis, 56 bloqueados, cinco retirados e uma manutenção separada**. Elegível significa percurso de Apply migrado e sujeito às guardas próprias; não significa eficácia, integração real ou autorização comercial demonstrada.

- Migradas neste lote: **58, 70 e 84**, apenas por seleção explícita em Extreme. São debloat/preferências documentadas; nenhum ganho de FPS, 1% lows, frametime ou latência foi medido.
- Retirada adicional: **14**, consolidada em 58 com alcance documentado mais limitado. Retiradas totais: **12/14/30/39/54**. Não existe migração que imponha defaults inversos a instalações antigas.
- **26/56/68 permanecem bloqueadas**; os corpos amplos foram suspensos também quando chamados diretamente. O mecanismo de tarefas não desbloqueia uma tarefa de produção.
- **18** ainda contém ArchiveApps no CDM legado, mas continua bloqueada. A consolidação não afirma ter certificado esse valor nem toda a componente CDM. **15/57/69** continuam pendentes: separar finalidade, política documentada e efeitos de shell/tracing antes de migrar. Não sobrepor privacidade a desempenho sem medição.
- Balanced **79** e Performance **9/41/79** não receberam ações adicionais. O número de ações não é critério de seleção.

As próximas decisões com maior relevância potencial para jogos continuam a exigir diagnóstico: apresentação por jogo **42** já é experimental e precisa de integração; HAGS/MSI **37/40** permanecem bloqueadas por ausência de deteção/contrato universal; scheduling/memória **2/5/11/36/81** não devem ser promovidos por plausibilidade. Rede/driver exige carga, DPC e conectividade medidos no hardware. A [auditoria individual 3B](AUDITORIA-3B.json) conserva mecanismo, riscos e evidência históricos; as entradas afetadas receberam Atualizacao3C, sem reescrever a baseline histórica.

O trabalho offline seguinte pode ampliar o inventário de conflitos e a matriz de testes de software. Não deve converter uma escrita verificável em compatibilidade funcional presumida. Evitar novos tweaks de kernel, desativação global de manutenção ou receitas por fabricante enquanto não houver prova adequada. O [protocolo de benchmarks](BENCHMARKS.md) e as [oportunidades de diagnóstico](OPORTUNIDADES.md) continuam aplicáveis.

## 5. Limites de integração e validação futura

1. Executar os protocolos de registo e tarefas num Windows descartável autorizado, com snapshots, reinícios e programa/painel da mesma versão. Testar recuperação dos formatos 1/2, conflitos GPO/MDM e acesso da conta elevada.
2. Confirmar consumo funcional das políticas em cada edição/build suportada, incluindo Pro recusada para consumer/Spotlight. Verificar efeitos nas contas corretas; HKCU não representa automaticamente o utilizador original quando a elevação usa outra conta.
3. Confirmar que o Task Scheduler real não muda campos não geridos ao alterar Enabled. A ausência, substituição ou alteração de segurança conserva o bloqueio; não aceitar um novo hash automaticamente para contornar falha.
4. Só depois avaliar tarefas concretas, sem regras por prefixo/fabricante. Medir se essas tarefas concorrem com jogos antes de propor a desativação.
5. Validar perfis em hardware físico e jogos reproduzíveis: FPS médios, 1% lows, distribuição/picos de frametime, variância, utilização/clocks/temperaturas e DPC/ISR relevante. Latência de entrada requer metodologia instrumentada adequada.

Não houve Apply/Undo real, execução de tarefas, VM, benchmarks físicos, push ou alterações a SkyOS/SkyOptimizer-Packs. O projeto continua em desenvolvimento e não está validado para distribuição comercial.

## 6. Testes, ficheiros e commits

Suite final: **187/187 testes Pester e 11/11 Python aprovados**, zero falhas, skipped ou pending. Comandos: `Invoke-Pester -Script .\tests -PassThru -Quiet` e `python -B -m unittest discover -s benchmarks/tests -v`. PowerShell 5.1.26100.9711, Pester 3.4.0 e Python 3.14.5. `git diff --check` sem erros de whitespace. O aviso de evidência não persistida é um cenário simulado do harness, não uma execução em VM.

Os 32 testes novos são 11 de interação/ownership, seis de políticas e 15 de tarefas. A regressão adicional de libertação falhada apresentou uma falha antes da correção e passou depois. A suite completa inclui as regressões anteriores de registo tipado, serviços, NIC, energia, painel, perfis, dispatcher e harness. Os 11 testes Python validam o analisador com dados sintéticos; não são benchmarks de jogos. [Metadados e hashes dos sources testados](TESTES-RESULTADO.json).

Ficheiros alterados neste lote:

- `SkyOptimizer.ps1`: identidade/ownership, formatos de diário, reversão parcial, mapa de políticas e backend de fixtures; suspensão dos corpos amplos 26/56/68.
- `tests/ActionInteraction.Tests.ps1`, `tests/CloudContent.Tests.ps1`, `tests/ScheduledTask.Tests.ps1`: regressões novas; `tests/RetiredActions.Tests.ps1`: retirada de 14.
- `docs/ACOES-ESTADO.json`, `docs/AUDITORIA-3B.json`: estado atual e adendas históricas.
- `README.md`, `docs/PERFIS.md`, `docs/FASE3B.md`, `docs/FASE3C.md`, `docs/INTEGRACAO-VM.md`, `docs/TAREFAS-LAB-3C.md`, `docs/TESTES-RESULTADO.json`: contratos, procedimentos futuros, limites e prova offline.

Commits incrementais preservados, sem push:

- `728549d` — identidade normalizada, baseline partilhada e Undo parcial.
- `624cb64` — consolidação de políticas por escopo, edição e ownership.
- `cc2cc9b` — diário de Enabled e identificação de fixtures, sem tarefas de produção.
- `6e896fd` — testes de recuperação mista e procedimento de guest.
- `2365e3f` — isolamento da libertação de ownership que falhou perante gravações posteriores.

O commit de fecho regista este relatório, o catálogo e os resultados finais. A branch continua `dev/phase2-execution-power-safety`; `main` não foi alterada.
