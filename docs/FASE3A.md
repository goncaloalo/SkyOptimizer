# Fase 3A — validação estrutural e migração progressiva

Branch preservada: `dev/phase2-execution-power-safety`. Base desta fase: `8983f60`, 19 ações elegíveis, 109 testes Pester e 11 Python. Não foram executados Apply, Undo, comandos de reparação ou alterações reais ao Windows de desenvolvimento. Sem push; SkyOS e SkyOptimizer-Packs fora do âmbito.

**Resultado desta entrega:** 21 ações elegíveis, 67 bloqueadas/por migrar, manutenção 24 separada e ação 39 retirada. Catálogo com 90 IDs históricos; isto não significa 90 opções ativas. **135 testes Pester e 11 testes Python aprovados.** Integração real e benchmarks físicos continuam por executar.

## 1. Revisão da integração

| Risco observado | Evidência e decisão |
|---|---|
| Alimentação desconhecida interpretada como AC | A ausência de Win32_Battery ou uma exceção devolvia `true`. Substituído por GetSystemPowerStatus: só ACLineStatus=1 permite experiências AC. 0/255/erro recusam. Não se infere desktop pelo chassis ou ausência de bateria. |
| Undo legado altera um plano sem autoria demonstrada | O GUID textual em `previous_power_plan.txt` provocava `/setactive`, mesmo sem prova da alteração inicial. Agora comunica `Unverified` e preserva o ficheiro/plano. Nenhum comando de energia é executado neste percurso. |
| Diário com recursos ativos duplicados | A leitura validava IDs, mas Undo podia aceitar duas baselines ativas para um recurso. A leitura agora recusa a duplicação antes de escrever. Identidade vazia também impede criação/leitura da baseline. |
| Persistência versus estado efetivo | Registo/powercfg não provam execução de política pelo driver, HAGS, interrupções MSI ou latência física. Continuam necessários reinício e observação independente. |
| Serviços e tarefas do ambiente | Dependências, triggers, políticas GPO/MDM e alterações após boot não são simuladas integralmente. Os testes de integração precisam de incluir esses intervenientes. |
| NIC real e recuperação remota | Mudança de driver bloqueia Undo por identidade; reinício pode interromper acesso remoto. Exige consola local/hipervisor e snapshot. Não testar primeiro num cliente. |
| Elevação com outra conta e sistemas localizados | HKCU pertence ao SID elevado; parsing de scripts não prova elevação/atalhos em todas as contas, idiomas ou caminhos. Necessário cenário de integração específico. |

Validação do primeiro bloco: 27 testes de diário, 28 de energia e três de alimentação aprovados. As declarações C# de leitura de alimentação foram compiladas, sem invocar o API nativo. Uma falha inicial na extração do template pelo teste foi corrigida para ler o AST original, em vez do proxy de mock.

Fontes: [GetSystemPowerStatus](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getsystempowerstatus), [ACLineStatus e estado desconhecido](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-system_power_status).

## 2. Validação pendente

Os resultados desta fase são testes de código, não integração executada nem benchmarks. Procedimentos de VM em [INTEGRACAO-VM.md](INTEGRACAO-VM.md), investigação por dispositivo em [HARDWARE-3A.md](HARDWARE-3A.md). Não se promove qualquer ação por aumentar a contagem do catálogo.

## 3. Migração e retirada por mecanismo

- Migradas **8 e 25**, exclusivamente por seleção explícita em Extreme. Total atual: **21 elegíveis**. USB 8 limita-se ao índice AC do plano próprio; 25 usa uma política documentada, mantendo exceções por app. Balanced e Performance conservam a seleção anterior.
- **37/40 bloqueadas**, incluindo chamada direta das funções. Retiradas as heurísticas de VRAM/fabricante e as escritas não demonstradas. Falta deteção e pós-verificação por adaptador/driver.
- **39 retirada**: o código indiscriminado de WDF foi eliminado. O ID histórico comunica a retirada; não é uma opção de tuning ativa. O catálogo conserva rastreabilidade dos 90 IDs históricos, sem exigir 90 ações executáveis.
- Não foram apagadas configurações antigas do Windows. A retirada de código não permite inferir os valores anteriores de clientes que executaram versões legadas.

Justificação, versões, hardware, riscos, fontes e critérios de desbloqueio em [HARDWARE-3A.md](HARDWARE-3A.md). Validação focada do bloco: **69 testes aprovados**, incluindo os ciclos USB e a política de background. Nenhuma integração real ou benchmark.

## 4. Integração preparada para VM

`integration/SkyVmHarness.ps1` implementa um ensaio faseado da fixture de registo: Prepare, Apply repetido, verificação num novo boot, Undo repetido e verificação após outro boot. Inclui falhas após escrita em Apply/Undo, retentativa e conflito externo preservado. Carrega apenas declarações do produto; não aplica o perfil completo nem gera o painel.

O guard exige opt-in explícito, manifesto com MachineId/SID, hash do source, referência de snapshot e modelo reconhecido de guest. Recusa host físico, origem diferente, diretório já usado ou caminhos reparse. Não cria snapshots nem comprova a sua existência. A fixture e os relatórios ficam em locais exclusivos do RunId; não há reboot ou limpeza automática.

**12 testes do harness aprovados com registo/processos simulados e ficheiros TestDrive**, incluindo chamadas separadas com estado persistido e reposição das variáveis do chamador. Nenhum cenário real do harness foi executado. Os passos manuais cobrem energia, serviços, NIC, políticas, elevação, contas diferentes, painel e concorrência. Serviços/NIC e hardware físico continuam sem integração executada.

## 5. Validação estrutural final

Três testes novos cruzam o AST das declarações do menu com o catálogo: IDs únicos, nomes/funções, funções existentes, elegibilidade/retirada e ausência de ganhos declarados como medidos. Todos os IDs selecionados sem migração ou retirados são testados no dispatcher com um corpo que falharia se fosse executado. Não se fixa a contagem de 90 como requisito para futuras funcionalidades: verifica-se consistência entre fonte e registo histórico.

Foram corrigidos nomes ainda demasiado abrangentes das ações 19/20/24 e mensagens de 9/79/86 que confundiam configurações com GPU encoder libertado, prioridade efetiva ou ausência de scans Wi-Fi. Essas mensagens passam a exigir observação, sem modificar o mecanismo das ações.

Suite final: `Invoke-Pester -Script .\tests -PassThru` — **135 Passed, 0 Failed, 0 Skipped, 0 Pending**. Inclui parsing do produto/painel e compilação das declarações C# sem chamar os APIs de alteração do sistema. `python -B -m unittest discover -s benchmarks/tests -v` — **11 testes aprovados**, com capturas sintéticas. `git diff --check` sem erros. Não há ficheiros temporários de teste no checkout. [Resultado estruturado e hashes do source](TESTES-RESULTADO.json).

Ficheiros desta fase:

- Produto: `SkyOptimizer.ps1`.
- Testes: `tests/Power.Tests.ps1`, `tests/Journal.Tests.ps1`, `tests/HardwareSafety.Tests.ps1`, `tests/UpdatePolicies.Tests.ps1`, `tests/VmHarness.Tests.ps1` e `tests/Catalogue.Tests.ps1`.
- Integração preparada: `integration/SkyVmHarness.ps1`, `integration/guest.example.json` e exclusão de `guest.local.json` em `.gitignore`.
- Documentação: `README.md`, `docs/FASE3A.md`, `docs/HARDWARE-3A.md`, `docs/INTEGRACAO-VM.md`, `docs/PERFIS.md`, `docs/ACOES-ESTADO.json` e `docs/TESTES-RESULTADO.json`; a entrega anterior aponta para esta fase.

## 6. Riscos restantes e prioridade seguinte

1. Executar o percurso de registo numa VM descartável, com snapshot confirmado, consola e autorização explícita. Exigir evidência depois de ambos os reinícios; restore de snapshot não conta como Undo aprovado.
2. Executar os cenários manuais de serviço, plano, painel, NIC e políticas. Os mocks não provam comportamento SCM, triggers, GPO/MDM, fonte de alimentação do firmware ou drivers reais.
3. Conservar 37/40 bloqueadas até existir prova por adaptador/driver e verificação após boot. A retirada 39 não será substituída por flags privadas. Falta também integração física de USB/docks/retoma.
4. Continuar por grupos com mecanismo documentado e estado reversível. Tarefas, AppX, BCD, TCP global, gestão de memória e scheduling continuam pendentes. A retirada de 39 não obriga a criar um substituto para manter a contagem.
5. Comparar 8 e 25 individualmente em hardware físico e cargas identificadas. O índice AC pode não representar o estado de cada porta; a política AppPrivacy tem exceções e pode perder notificações. Nenhum ganho de FPS, 1% lows, frametime ou input lag foi medido.

O SID elevado continua a determinar HKCU. Backups legados não permitem recuperar informação ausente. Locks de energia e diário não constituem transação global; interferência externa continua possível. Nenhuma destas limitações é eliminada por uma suite unitária aprovada.

Commits dos blocos anteriores desta fase: `6a6714f` (guardas de alimentação/Undo), `0894837` (USB, background e retirada das escritas não suportadas), `0a84dde` (harness e protocolo de VM). O commit de fecho regista a consistência do catálogo e os resultados finais. Não há push nem declaração de aplicação pronta para clientes.
