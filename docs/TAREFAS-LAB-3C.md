# Tarefas de laboratório — preparação offline

**Não executado em Windows real nesta fase.** Este procedimento só é para futura VM descartável, com snapshot confirmado e autorização explícita para registar/alterar uma fixture. Não desativar serviços/tarefas do host ou substituir a fixture por uma tarefa existente de Windows/NVIDIA/terceiros.

## Contrato implementado

- `Disable-SkyScheduledTask` opera apenas em `\SkyOptimizer-Lab\<GUID com 32 caracteres>\`, em tarefas Fixture/Fixture [...]. Exige hash esperado e diretório de backup explícito já existente.
- Só Enabled é gerido. XML de ações/triggers/condições/principal e owner/group/DACL entram no fingerprint; o conteúdo não é re-registado para fazer Undo. SACL não é consultada/modificada.
- Desativação começa apenas em Ready/Disabled. Não há Run, Stop, DeleteTask, RegisterTask ou SetSecurityDescriptor no backend do produto.
- Tarefa ausente, acesso negado, Enabled indisponível, hash diferente ou XML sem Enabled explícito são recusados. Não é inventado um default de tarefa ausente.
- Formato 2 do diário: versões antigas do programa/painel não devem ser usadas para recuperar estes dados. Falham a leitura em vez de assumir uma baseline.

## Futura criação da fixture no guest

1. Restaurar snapshot de Windows de laboratório; abrir consola do hipervisor com a conta elevada que vai executar os testes.
2. No Agendador de Tarefas, criar apenas a pasta SkyOptimizer-Lab e uma subpasta com GUID sem hífen. Guardar esse identificador. A allowlist atual não permite outros diretórios.
3. Criar uma tarefa chamada `Fixture`, sem triggers, executada apenas com a conta de laboratório iniciada. Ação inócua: `%SystemRoot%\System32\cmd.exe`, argumentos `/d /c exit 0`. Não executar a tarefa. Manter Ready e Enabled.
4. Exportar XML e permissões para provas; confirmar que o XML da tarefa tem Settings/Enabled explícito. Se o Scheduler o omitir, a implementação recusa o caso: não remover essa verificação para fazer o teste passar.
5. Criar uma pasta nova de backups só para a fixture, fora de ProgramData\SkyOptimizer\Backups e fora dos runs de registo. Nunca reutilizar a baseline de produção para estes ensaios.

## Futura aplicação e reversão

Depois de carregar as declarações com o harness existente, no guest autorizado:

```powershell
. .\integration\SkyVmHarness.ps1
. (Get-SkyVmDeclarations (Resolve-Path .\SkyOptimizer.ps1).Path)
$taskPath = '\SkyOptimizer-Lab\PREENCHER-GUID-32-CARACTERES\'
$taskName = 'Fixture'
$backups = 'C:\SkyOptimizer-Lab\PREENCHER-GUID-32-CARACTERES\TaskBackups'
# Criar a pasta apenas depois de confirmar que pertence a este novo run.
# A leitura aceita um fingerprint placeholder; a escrita exige o hash observado.
$probe = [pscustomobject]@{
    Type='ScheduledTaskEnabled'; Path=$taskPath; Name=$taskName; DefinitionHash=('0' * 64)
}
$before = Invoke-SkyTaskBackend $probe
Disable-SkyScheduledTask $taskPath $taskName $before.DefinitionHash $backups
Disable-SkyScheduledTask $taskPath $taskName $before.DefinitionHash $backups
Restore-SkyTrackedChanges $backups
Restore-SkyTrackedChanges $backups
```

Os placeholders são inválidos deliberadamente. Estes helpers internos não substituem o guard de isolamento/snapshot do protocolo; só devem ser chamados no guest explicitamente autorizado. A lista de ações do produto não executa estes comandos.

Confirmar de forma independente: Enabled regressa ao original; hash de definição/segurança mantém-se antes, depois de Apply e depois de Undo; XML difere apenas no Enabled enquanto desativada. Nenhum processo da ação deve ter arrancado ou sido terminado. Estado de execução, LastRunTime e LastTaskResult são observações temporais, não dados que o Undo tente reconstituir.

Reiniciar o guest e repetir a observação. Se o Scheduler real reserializar campos adicionais ao mudar Enabled, conservar a falha e os artefactos. Não aceitar um fingerprint novo para contornar automaticamente o conflito. Restaurar snapshot para recuperar o laboratório; isso não é evidência de Undo aprovado.

## Casos de integração ainda pendentes

| Caso | Aprovação exigida |
|---|---|
| Enabled e Disabled originais | Só criar baseline quando há mutação; Undo repõe o booleano original. |
| Ready/Running/Queued | Ready pode ser ensaiado; Running/Queued recusados sem terminar execução. |
| Alterar comando, trigger, principal ou DACL entre Apply/Undo | Reversão recusa a fixture alterada e conserva preferência/evidência. |
| Remover/recriar tarefa | Ausência ou definição diferente não provoca criação de tarefa nem uso de defaults; recriação idêntica é uma limitação do fingerprint. |
| Falha antes/depois de Enabled | Pending/Restoring permitem retry quando contrato/estado continuam verificáveis. |
| Registo partilhado no mesmo diário | Conflito na fixture não bloqueia Undo de um valor independente; Undo de OwnerActionId de política não toca numa fixture sem esse owner. |
| Painel gerado na mesma versão | Parsing não basta: verificar acesso COM e recuperação do formato 2 num guest. |

Só depois destes ensaios se pode avaliar uma allowlist de tarefas de produção, por identidade/finalidade/definição/build. Tarefas críticas e regras amplas por prefixo continuam excluídas. Mesmo uma tarefa seguramente reversível não demonstra melhoria de FPS sem observar contenção e comparar workloads.
