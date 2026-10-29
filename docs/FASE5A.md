# Fase 5A — Preparação final para validação

> Registo histórico desta entrega. O estado atual, as restrições adicionais de captura/serviços e os resultados mais recentes estão na [Fase 5C](FASE5C.md). As contagens abaixo descrevem a Fase 5A.

Entrega offline de 2026-10-28, na branch `dev/phase2-execution-power-safety`, a partir de `1d3d10e`. Não foram executadas otimizações, VM ou benchmarks físicos. Mantêm-se 28 ações elegíveis, 56 bloqueadas, cinco retiradas e manutenção 24. Elegibilidade não equivale a compatibilidade funcional validada.

## P2 revistos

| Problema da Fase 4 | Resultado nesta fase | Limite restante |
|---|---|---|
| F4-11: contratos funcionais incompletos | Perfis automáticos e dependências confrontados com IDs elegíveis; escopo de observação dos dez valores de Performance confrontado com chamadas reais aos setters, simuladas | Consumo de políticas 9/13/79/86, instâncias de 71 e funções dos serviços de 48 exigem Windows real. Não foram promovidos nem reescritos |
| F4-12: mocks não provam integração | Coletor independente do motor de Apply/Undo; comparação com recusa de cobertura/identidade divergente e leituras falhadas; leitores e cenários negativos testados | APIs reais, reinício, ACL, UAC, SCM e durabilidade continuam pendentes |
| F4-13: diagnóstico auxiliar silencioso/legado | `Write-SkyLog` passa a emitir aviso limitado por destino quando a escrita falha, incluindo NoConsole; exceção privada não é exportada. Referências 2.6.0 uniformizadas em 2.8.0 | Não existe arquivo imutável de todos os ciclos. O operador deve arquivar cada run; logs e diários locais podem conter informação privada |

F4-11/12 permanecem abertos. F4-13 foi parcialmente corrigido; não se declara resolvido o arquivo histórico ou toda a linguagem legada. O aviso auxiliar não substitui a falha obrigatória do diário autoritativo. A versão é um identificador editorial, não uma certificação.

## Auditoria de instalação e arranque

O produto é um script e BAT, sem instalador, pacote assinado ou atualização automática. O código não instala módulos nem descarrega dependências. Não precisa de Python/Pester em runtime. Python só serve o analisador de benchmarks; Pester só serve os testes de desenvolvimento.

Primeira célula de laboratório: Windows cliente x64, Windows PowerShell **5.1 de 64 bits**, consola interativa, .NET Framework do Windows e conta administrativa conhecida. Os percursos corrigidos usam APIs de ACL do .NET Framework; PowerShell 7 não é o ambiente aprovado. O cabeçalho histórico “5.1+” não certifica outros hosts. Não foi adicionado suporte a Server, ARM64, x86, Server Core ou execução headless.

É necessário ler CIM/WMI e o registo, escrever os recursos escolhidos e criar pastas protegidas na known folder CommonApplicationData e atalhos no Desktop da conta elevada. Em instalações com OneDrive, pasta redirecionada ou outra conta na elevação, confirmar o Desktop real. HKCU é o utilizador do processo elevado. Não existe instalador multiutilizador que redistribua atalhos.

Comandos/dependências condicionais: `Checkpoint-Computer`/System Restore, `powercfg.exe`, NetAdapter, Storage e CIM; `dism.exe`/`sfc.exe` apenas na manutenção explícita; COM Schedule.Service apenas para fixtures de tarefas. System Restore pode estar indisponível, desativado ou limitado: falha não substitui snapshots nem justifica afirmar backup integral. Drivers/edições podem não expor propriedades; incompatibilidade deve ficar explícita. A execução normal do perfil não requer ligação de rede; reparação DISM e funcionamento do Windows podem ter requisitos separados.

O BAT passa `-NoProfile -ExecutionPolicy Bypass` apenas ao processo; não altera a política persistente. Políticas de grupo, WDAC/AppLocker, antivírus ou restrições empresariais podem impedir a execução. Não desativar controlos para fazer um ensaio passar. A [precedência de execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies) deve ser registada, incluindo bloqueios. Primeiro copiar o checkout revisto para uma pasta local do guest e guardar hashes; não executar a partir de um partilhamento gravável do host.

O script eleva antes de inicializar armazenamento. A pasta central antiga é validada antes de ser adotada: owner/DACL inseguros e reparse points provocam recusa. Não apagar backups nem modificar permissões automaticamente. Um arranque com árvore vazia e outro com dados antigos são casos separados. O menu mantém lock durante a sessão; fechar o programa antes dos atalhos autónomos do painel. Scripts gerados devem corresponder ao mesmo checkout.

## Instrumentação independente

`integration/SkyValidationEvidence.ps1` contém apenas declarações. Dot-source não recolhe dados nem importa/executa o produto. `Get-SkyValidationSnapshot` lê exclusivamente uma lista explícita de recursos e devolve um objeto; não grava ficheiros, modifica registo/serviços/planos nem reinicia processos.

Leitores disponíveis:

- Registo: hive e vista explícitas, ausência, tipo e conteúdo, sem expandir ExpandString. Não confunde chave/valor ausente com tipo não suportado; REG_NONE/REG_LINK ficam inconclusivos. A opção de leitura é documentada em [RegistryKey.GetValue](https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registrykey.getvalue).
- Serviço: existência, StartMode, State e existência/tipo/valor de DelayedAutoStart. Não cobre triggers, conta, recovery, ACL ou toda a árvore de dependências; inventariar separadamente.
- Energia: saída de `/getactivescheme`, `/list` e `/qh` do plano ativo, com exit codes verificados. É comparação sensível a idioma/formatação e inclui nomes/GUIDs apenas dentro do digest. Não inventaria índices de todos os planos inativos. Cópias retidas tornam a comparação global diferente, como esperado; investigar sem eliminar automaticamente.

A exportação contém IDs anónimos R001..R999 e HMAC-SHA256 do escopo, estado e identidade máquina/utilizador. Requer uma chave privada aleatória de 32 bytes, igual em todas as capturas do run, conservada no guest. Não exporta chave, nomes/valores, hostname, SID, GUIDs ou exceções. Quem detiver a chave e especificações poderá testar hipóteses de valores: manter ambos separados das evidências partilhadas. Timestamps, hash de código e correlação entre capturas continuam visíveis. Isto reduz exposição, não constitui um sistema de anonimização ou assinatura contra um operador malicioso.

`Compare-SkyValidationSnapshot` recusa hashes de produto, chave, identidade ou cobertura divergentes e entradas malformadas/duplicadas. Duas leituras falhadas produzem Inconclusive, nunca Equal. Diferenças produzem Changed por recurso. Equal significa apenas igualdade observada no escopo e momento escolhidos; não prova ausência de outras alterações, consumo funcional, origem da alteração ou desempenho. Associar observação aos resultados e diário locais para atribuir autoria; não enviar esses ficheiros privados sem revisão.

O template `integration/evidence-performance.json` cobre os dez valores escritos por Game Mode, Game DVR e ambos os browsers. Serve também Balanced como superset; valores não selecionados devem permanecer iguais. Um teste chama as três funções com setters simulados e verifica a cobertura exata. O template **não cobre Extreme**: acrescentar recursos, serviços e inventários externos correspondentes antes da captura Before, mantendo o mesmo escopo nas cinco capturas. Não descobrir o escopo só depois de Apply, pois isso perderia a baseline independente.

## Run reproduzível — somente no futuro guest autorizado

Executar primeiro a preparação de snapshots e isolamento de [INTEGRACAO-VM.md](INTEGRACAO-VM.md). Abaixo são instruções futuras, não comandos executados nesta fase. Guardar artefactos privados numa pasta NTFS do guest acessível só ao operador/admin. Não colocar a chave, specs personalizadas, manifests privados ou diários de clientes no Git.

1. Confirmar hash/commit, snapshot recuperável, identidade e PowerShell x64. Copiar também o coletor e template; registar o hash do coletor. Criar uma pasta exclusiva por run. Verificar espaço e ausência de redirecionamentos. Usar nomes de captura únicos; não sobrescrever evidência anterior.
2. Numa consola PowerShell do guest, carregar o coletor, gerar chave e capturar Before. O exemplo supõe uma pasta privada de run já criada e vazia:

```powershell
. .\integration\SkyValidationEvidence.ps1
$runDirectory = Read-Host 'Caminho absoluto da pasta privada de run, ja criada e vazia'
if (-not [IO.Directory]::Exists($runDirectory) -or @(Get-ChildItem -LiteralPath $runDirectory -Force).Count) { throw 'Pasta de run inexistente ou nao vazia.' }
$scope = Get-Content .\integration\evidence-performance.json -Raw -Encoding UTF8 | ConvertFrom-Json
$key = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($key) } finally { $rng.Dispose() }
[IO.File]::WriteAllBytes((Join-Path $runDirectory 'private-key.bin'), $key)
$sourceHash = (Get-FileHash .\SkyOptimizer.ps1 -Algorithm SHA256).Hash
$before = Get-SkyValidationSnapshot -Resources $scope -Key $key -SourceSha256 $sourceHash -Stage Before
$before | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $runDirectory 'Before.json') -Encoding UTF8
```

3. Guardar a chave no guest privado para a sessão seguinte. Abrir o BAT e confirmar menu/elevação; sair. Executar `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SkyOptimizer.ps1 -Apply -Profile Balanced` no guest, responder às confirmações e guardar saída/código. Repetir Apply e capturar AfterApply. Repetir o run com Performance num snapshot independente, incluindo browsers instalados e ausentes. Usar o host de sistema x64 ao chamar a partir de outro processo.
4. Fechar o programa, terminar transcript e reiniciar manualmente o guest. Recarregar coletor, specs e a chave com `[IO.File]::ReadAllBytes`, confirmar hash do produto e capturar AfterReboot. Registar boot separadamente: o coletor não impõe que um reinício aconteceu.
5. Executar Undo, guardar resultado e capturar AfterUndo. Fechar e reiniciar novamente; capturar AfterUndoReboot com o mesmo escopo/chave/hash. Guardar cada objeto como JSON privado no run, com o respetivo Stage. O coletor não escreve automaticamente sobre um run antigo.
6. Comparar Before com AfterApply/AfterReboot para observação; comparar Before com AfterUndoReboot para reversão. Exemplo de comparação offline, sem leitura do Windows:

```powershell
$before = Get-Content (Join-Path $runDirectory 'Before.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$after = Get-Content (Join-Path $runDirectory 'AfterUndoReboot.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Compare-SkyValidationSnapshot -Before $before -After $after | ConvertTo-Json -Depth 10
```

7. Arquivar snapshots, comparação, commits/hashes, códigos, transcrição privada e cópias dos diários/resultados por run. Partilhar por defeito apenas snapshots HMAC e comparação, revendo conteúdo antes de exportar. Mapear Rxxx para a especificação local para investigar Changed; não publicar valores para “explicar” o digest.
8. Em snapshots independentes executar falhas do painel, logs e journal; injeção after-write; conflito externo; crash de processo e concorrência. O [harness existente](INTEGRACAO-VM.md) já contém os passos de falha intermédia, diário bloqueado, reinício e recuperação da fixture. Usar também a [checklist Fase 4](VALIDACAO-FASE4.md). Não classificar exceção simulada como perda elétrica ou execução real.

## Aceitação objetiva

Cada linha exige baseline, procedimento, esperado/observado, hash e artefactos. O resultado do cenário é Pass, Fail, Inconclusive ou NotRun, com motivo. Incompatible é resultado de uma ação, não aprovação de compatibilidade dessa plataforma.

| Gate | Pass | Fail ou bloqueio |
|---|---|---|
| Instalação/elevação | Arranque x64, conta correta, ACL protegida e argumentos/código preservados | Execução sob conta inesperada, recusa silenciosa, scripts/journal graváveis por identidade indevida |
| Apply e repetição | Todos os recursos esperados verificados; baseline original inalterada no segundo Apply | Sucesso aparente, baseline substituída, alteração fora do escopo |
| Reinício | Boot comprovado e estado esperado confirmado por leitor independente e componente | Reboot não comprovado, ReadFailed, política não consumida quando esperada |
| Undo | Before e AfterUndoReboot iguais nos recursos próprios sem conflito; funcionalidades recuperadas | Default imposto, dados externos substituídos ou divergência sem explicação |
| Energia conservadora | Original ativo/índices intactos; cópias retidas identificadas e Unverified/código 2 | Eliminação de cópia externa ou anúncio de reversão integral. Retenção é aprovação da contenção, não de limpeza integral |
| Conflito/falha | Conflito preservado e comunicado, recursos independentes recuperados; falha antes da intenção não escreve | Erro silencioso, mutação sem baseline, retry destrutivo |
| Evidência/privacidade | Escopo completo, hashes corretos, sem identificadores/valores nos snapshots partilhados | Escopo incompleto, chave exportada ou Inconclusive tratado como Equal |
| Perfis | Só IDs elegíveis automáticos; bloqueados explícitos devolvem Deferred e código incompleto | Corpo bloqueado executado ou ganho de FPS prometido sem medição |

O teste de integração não aprova FPS ou latência. Benchmarks continuam separados em [BENCHMARKS.md](BENCHMARKS.md). Um Pass no caminho conservador de energia não aprova distribuição comercial enquanto a limitação de limpeza e restantes gates não forem aceites de forma explícita.

## Entrega e limitações

**225/225 testes Pester e 11/11 Python aprovados**, zero Pester falhados/ignorados/pendentes. São 14 testes novos sobre os 211 anteriores. `git diff --check` passou. A suite final inclui o template completo de Performance. Testes e hashes finais: [FASE5A-TESTES.json](FASE5A-TESTES.json) e [TESTES-RESULTADO.json](TESTES-RESULTADO.json). Código alterado: logging/version strings do produto; coletor independente; template de escopo. Testes novos cobrem falha de log, digest/cobertura/privacidade/comparação, contrato do leitor de registo e alinhamento do template/perfis. Os leitores reais de serviço/energia e integração NTFS/UAC continuam sem execução.

Commits funcionais: `3b10ecf` (logs), `0c02c6e` (coletor/comparação/perfis), `0878bd9` (escopo Performance). Sem novas dependências de runtime, sem desbloqueio de ações, sem push. A preparação offline está concluída; a próxima prova é a primeira execução controlada em VM, seguida de hardware físico quando necessário. O produto continua fora da distribuição comercial.
