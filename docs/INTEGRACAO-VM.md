# Integração em Windows descartável — protocolo reproduzível

**Preparado, não executado nesta fase.** Estes comandos são instruções para um operador autorizado numa VM descartável. Não os executar no Windows de desenvolvimento. Não foram criados snapshots nem arrancadas VMs durante o desenvolvimento.

## 1. Ambiente e evidência

1. Criar uma VM sem dados de clientes, sem conta de produção e sem discos/pastas partilhados de escrita com o host. Usar consola do hipervisor; não depender de AnyDesk/RDP para recuperar rede ou login.
2. Instalar uma imagem oficial e fixar build/edição/idioma, versão PowerShell 5.1, drivers virtuais e versão do hipervisor. Registar ativação/atualizações e alimentação exposta pelo guest. Windows 10 e 11 são células separadas; Home serve também para provar recusas de políticas. VM x64 é a primeira célula, sem inferir suporte ARM64 ou x86.
3. Copiar este checkout e guardar commit, `git status`, hashes e resultados dos testes. Criar snapshot com VM desligada após instalação, e outro imediatamente antes de cada cenário destrutivo. Confirmar no hipervisor que é possível restaurá-lo. O nome no manifesto não comprova a existência do snapshot.
4. Restaurar o snapshot para cada cenário independente. Não apagar backups para forçar Apply. Exportar evidência antes de restaurar, para uma pasta dedicada, sem dados pessoais. Usar `Start-Transcript` dentro do guest e terminar a transcrição antes de reiniciar.
5. Os comandos seguintes presumem sessão elevada, mesma conta/SID e diretório do checkout. Não remover o bloqueio de guest para testar num host físico. O guard reconhece pares de fabricante/modelo de Hyper-V, VMware, VirtualBox e QEMU/KVM; recusa ambientes desconhecidos. É uma prevenção operacional, não uma prova de isolamento ou autorização do hipervisor.

## 2. Harness de registo implementado

`integration/SkyVmHarness.ps1` contém apenas declarações. Carrega as funções do produto por AST, sem executar entrada, UAC, criação do painel ou as 90 ações. Não depende de Pester no guest.

O cenário real fica limitado a `HKCU\Software\SkyOptimizerIntegration\<RunId>` e `%SystemDrive%\SkyOptimizer-Lab\<RunId>`. Não modifica políticas de gaming, energia, serviços ou NIC. A preparação semeia valores artificiais; Apply/Undo usam as funções reais de registo e diário. O teste não equivale à integração do Apply completo. A baseline inclui ausência, DWORD, QWORD máximo assinado, ExpandString literal, Binary, MultiString, valor sem nome e um valor já conforme que nunca deve ficar sob autoria do programa.

Preparação **dentro do guest**, depois de criar o snapshot:

```powershell
. .\integration\SkyVmHarness.ps1
$context = Get-SkyVmContext
$manifest = [ordered]@{
    SchemaVersion = 1
    Acknowledgement = 'DISPOSABLE-VM-WITH-SNAPSHOT'
    SnapshotReference = 'PREENCHER-COM-O-SNAPSHOT-CONFIRMADO-NO-HIPERVISOR'
    RunId = [guid]::NewGuid().ToString()
    MachineId = $context.MachineId
    UserSid = $context.UserSid
    SourceSha256 = (Get-FileHash .\SkyOptimizer.ps1 -Algorithm SHA256).Hash
}
$manifest | ConvertTo-Json | Set-Content .\guest.local.json -Encoding UTF8
Invoke-SkyVmScenario -ManifestPath .\guest.local.json -Stage Prepare -AllowSystemChanges
Invoke-SkyVmScenario -ManifestPath .\guest.local.json -Stage Apply -AllowSystemChanges
Invoke-SkyVmScenario -ManifestPath .\guest.local.json -Stage Apply -AllowSystemChanges
```

O template `guest.example.json` é deliberadamente inválido. Preencher a referência de snapshot real; não alterar o source entre fases. Guardar o ficheiro local fora do Git. O harness recusa diretórios de ensaio já existentes em Prepare e paths com junctions/symlinks. Não há limpeza automática nem eliminação de provas.

Terminar a transcrição e reiniciar manualmente o **guest** pelo menu do Windows. Reabrir uma sessão elevada com a mesma conta:

```powershell
. .\integration\SkyVmHarness.ps1
Invoke-SkyVmScenario -ManifestPath .\guest.local.json -Stage VerifyAfterReboot -AllowSystemChanges
Invoke-SkyVmScenario -ManifestPath .\guest.local.json -Stage Undo -AllowSystemChanges
Invoke-SkyVmScenario -ManifestPath .\guest.local.json -Stage Undo -AllowSystemChanges
```

Reiniciar novamente o guest e executar `VerifyAfterUndo`. A verificação exige um LastBootUpTime diferente, confirma tipo/conteúdo/existência e baseline original, e não permite saltar de Prepare para Undo. Cada fase aprovada gera JSON próprio; erros terminam com exceção e conservam estado/diário para inspeção. Não existe reinício automático.

### Falhas após escrita e alterações externas

Em snapshots/runs separados, executar Prepare e depois apenas um destes comandos:

```powershell
Invoke-SkyVmScenario -ManifestPath .\guest.local.json -Stage FailureRecovery -AllowSystemChanges
# Ou, num run independente:
Invoke-SkyVmScenario -ManifestPath .\guest.local.json -Stage ExternalConflict -AllowSystemChanges
```

`FailureRecovery` injeta uma exceção depois do setter real e antes de persistir a conclusão. Exige Pending após Apply interrompido; restaura e repete com uma falha de Undo, exigindo Restoring e recuperação no retry. Termina com a fixture original. Isto valida o limite lógico; não simula falha elétrica, kernel crash ou write cache do disco.

`ExternalConflict` aplica um valor, muda-o como software externo e exige Undo falhado que preserve essa preferência. O cenário passa precisamente quando o conflito esperado é comunicado. Deixa a preferência e o diário para revisão, sem substituir o valor para “limpar” o teste. Exportar provas e restaurar o snapshot.

Para crash de processo real, usar um snapshot separado e debugger/breakpoint no guest depois de Save-SkyMutationState e antes/depois de Set-SkyResourceState. Terminar apenas o processo de teste, reabrir e executar Undo. Registar instrução/commit do breakpoint, journal Pending/Restoring e estado do recurso. Não classificar a injeção de exceção como este teste. Falha de disco/permissões deve ser ensaiada num volume de laboratório, sem encher o disco do host.

## 3. Integração do produto completo — procedimento manual pendente

| Cenário por snapshot | Procedimento | Critério de aprovação |
|---|---|---|
| Baseline inexistente | Iniciar com Backups vazio; Undo pelo programa e painel | Zero alteração de configuração; nenhum default aplicado. |
| Balanced repetido | Exportar valores Game Mode com tipo/existência; Apply Balanced duas vezes; reiniciar; Undo e novo reinício | Baseline original estável; valores conforme; já conformes sem autoria; recuperação exata. |
| Performance | Acrescentar capturas e browsers instalados/ausentes; reiniciar browsers e consultar política efetiva | Valores exatos; diferenças de edição respeitadas; capturas e background regressam após Undo. Registo sozinho não prova política consumida. |
| Energia/USB | Guardar plano ativo, lista e índices AC/DC; Extreme + 8 em snapshot; repetir; reiniciar; Undo | Uma cópia, DC/original intactos, AC verificado; original ativo no fim e cópia retirada. Se definição ausente, ação incompatível. |
| Alimentação desconhecida/DC | Guest/plataforma que reporte 255/0; repetir com 8 e 38 | Sem escrita AC-only nessas ações. A dependência 1 pode criar a cópia antes da recusa; não é ganho de desempenho. Não falsificar estado do host para passar. |
| Mudança externa de plano | Após Apply escolher outro plano no guest; Undo | Falha/conflito preserva escolha externa. Repor snapshot para ensaiar plano original removido. |
| Serviços | Registar startup, delayed start, runtime, triggers, dependências, conta e recovery de serviço de teste; testar automatic delayed/running, manual/stopped e already disabled | Só startup/runtime geridos mudam; Undo reconstitui os originais. Dependentes ativos e paused/pending recusados; nada arranca em cascata. Usar serviço descartável, não substituir binários de serviços do Windows. |
| Falha de serviço | Bloquear a mudança de startup depois da paragem num serviço de teste; Undo | Estado Running original recuperável; startup original conservado. Nunca Stop-Service -Force. |
| NIC virtual | Registar GUID/PnP/driver e todas as propriedades; selecionar 74/75 individualmente; reiniciar; Undo | Só propriedades suportadas alteradas. Sem reset global. Se driver não expõe propriedade: incompatível, não fingir teste passado. VM não valida NIC física. |
| NIC alterado externamente | Renomear, alterar propriedade e, noutro snapshot, mudar driver/remover dispositivo | Renomear mantém identidade; preferência externa fica intacta; driver/dispositivo diferente bloqueia Undo. Recuperar via consola. |
| AppPrivacy 25 | Preparar exceção por pacote e default existente; Extreme + 25; reiniciar apps; Undo | Exceção intacta, default restaurado; comparar política efetiva e comportamento de notificação. Home/edição desconhecida recusada. |
| Backups legados | Introduzir cópia de `.reg`/previous_* artificiais; tentar Apply/Undo | Apply recusa; não importa chaves inteiras nem reativa planos pelo GUID textual. Evidência preservada. |
| Painel/elevação | Caminho com espaços/acentos; gerar e regenerar; testar Undo e Spooler/bthserv em snapshots separados | Mesma pasta central, mesmo diário, scripts completos sem truncamento. Perfil/IDs preservados na elevação. Sem recriar baseline ou copiar backup sobre si mesmo. |
| Conta diferente | Elevar com outra conta e executar com baseline pertencente ao SID anterior | Diário recusa SID diferente. A limitação de seleção de HKCU deve ficar registada; não declarar suporte multiutilizador. |
| Concorrência | Abrir dois Apply/Undo e painel ao mesmo tempo; interromper um processo com lock | Um proprietário por diário; segunda operação falha claramente; terminar processo liberta handle, sem apagar baseline. Energia e diário têm locks separados; não há atomicidade global entre recursos. |

Para o fluxo completo, usar o menu ou parâmetros documentados em [PERFIS.md](PERFIS.md); Extreme inclui Performance. Não atribuir diferenças de várias ações a um único ID. O harness usa pasta própria; o produto completo usa `%SystemDrive%\ProgramData\SkyOptimizer\Backups`. Não misturar as duas baselines.

Guardar antes/depois: exportações por valor com tipo/existência, `mutation_state.json`, `power_state.json`, `execution_results.json`, relatórios do painel, stdout/stderr/exit code, histórico de boots, Event Viewer e inventário de drivers. Marcar cada célula como Passed, Failed, Incompatible ou NotRun. Não usar “passou” para hardware ausente.

## 4. Aprovação de integração e desempenho

Só concluir integração quando a comparação independente depois do segundo boot confirma o estado original de todos os recursos alterados. Qualquer conflito deve continuar explícito. Restaurar snapshots pode recuperar a VM, mas não demonstra que o Undo funcionou.

HAGS/MSI permanecem bloqueados. USB físico, docks, sleep/resume, áudio, GPUs híbridas, NIC físico e anti-cheats precisam de laboratório próprio. A VM valida mecanismos do Windows, não FPS, frametimes, latência de periféricos ou compatibilidade com todos os drivers. Benchmarks físicos seguem [BENCHMARKS.md](BENCHMARKS.md).
