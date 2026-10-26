# Fase 3A — validação estrutural e migração progressiva

Branch preservada: `dev/phase2-execution-power-safety`. Base desta fase: `8983f60`, 19 ações elegíveis, 109 testes Pester e 11 Python. Não foram executados Apply, Undo, comandos de reparação ou alterações reais ao Windows de desenvolvimento. Sem push; SkyOS e SkyOptimizer-Packs fora do âmbito.

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

Os resultados desta fase são testes de código, não integração executada nem benchmarks. Os procedimentos de VM e a investigação por dispositivo acompanham os próximos blocos. Não se promove qualquer ação por aumentar a contagem do catálogo.
