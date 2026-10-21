# Fase 2 — primeiro conjunto de correções

Data: 21 de outubro de 2026. Projeto: **apenas SkyOptimizer**.

## Estado e decisão de âmbito

O trabalho começou em `main`, commit `be4922e`, sem modificações pendentes. Não existiam outras branches locais. Foi criada `dev/phase2-execution-power-safety`; `main` não foi alterada e não houve push.

Foi concluído um conjunto delimitado: resultados de execução, barreira de exportação de backups e ciclo de energia com baseline persistente. Não se tentou migrar as 90 ações simultaneamente. **A aplicação completa ainda não está pronta para distribuição a clientes: permanecem P0 na reversão legada.**

SkyOS, SkyOptimizer-Packs e a pasta de auditoria foram apenas referências; não foram modificados. Não foi desenvolvido motor entre produtos, launcher, licenciamento ou infraestrutura comercial.

## 1. Correções efetivamente implementadas

### Execução e comunicação de resultados

- `Invoke-SkyAction` já não interpreta um retorno booleano, ausência de output ou ausência de exceção como prova de sucesso.
- Existem resultados `Applied`, `AlreadyCompliant`, `Incompatible`, `Failed` e `Unverified`, com motivo e reinício `Yes`, `No` ou `Unknown`.
- Ações antigas sem pós-verificação completa ficam `Unverified`. Um retorno `false` não é transformado arbitrariamente em «hardware incompatível».
- Exceções, erros não terminantes sem supressão explícita e erros comunicados por `Write-SkyLog` são falhas. Mensagens antigas de sucesso dentro da ação são apresentadas como informação ainda por validar.
- `execution_results.json` é atualizado depois de cada ação através de substituição atómica. Não é um diário completo de todas as mutações internas.
- O relatório deixou de inventar valores de resolução de temporizador e estado MSI. Processos/RAM/espaço livre continuam a ser snapshots, sem alegação de ganho em jogos.
- A criação do painel deixa de ser anunciada como concluída quando a função devolve falha.
- `-Repair` e `-Audit` são encaminhados após elevação.
- Falhas de `reg import` deixam de incrementar sucesso nos dois percursos de Undo. As outras operações legadas de Undo continuam por migrar.

### Barreiras de backup

- `Backup-RegistryKey` usa exit code verificado, exportação para ficheiro temporário e publicação apenas quando existe conteúdo.
- A exportação falhada remove apenas o temporário da própria operação e interrompe a ação; não publica um backup parcial como válido.
- Um backup já existente não é substituído por uma nova aplicação. Um backup existente vazio bloqueia a ação.
- Operações de backup e criação de chaves deixam de suprimir falhas relevantes.
- Foram removidas cópias para o mesmo destino na camada de backup e gravação de manifesto.
- `Write-SkyAtomicFile` escreve e descarrega o conteúdo antes de publicar o ficheiro. A versão existente fica preservada se a publicação falhar.

**Limite:** isto não converte backups `.reg` em reversão exata por valor. A ordem Ensure/Backup, valores originalmente ausentes, snapshots de chaves sobrepostas e estados legados continuam pendentes.

### Plano de energia e AC/DC

- A ação 1 passa a criar uma cópia pertencente ao SkyOptimizer a partir do plano original. O nome da função foi mantido para compatibilidade interna; o rótulo da ação foi corrigido.
- Foi abandonada a deteção por nomes localizados e pela variável automática `$matches`. O código usa GUIDs explícitos, incluindo um GUID de destino persistido antes de duplicar.
- Esta cópia preserva inicialmente as políticas OEM, CPU e bateria existentes. O programa não atribui um ganho ao nome «Ultimate Performance».
- `power_state.json` contém versão, identidade da instalação, plano original, plano pertencente ao produto e estado `Prepared`, `Active` ou `Restored`.
- Apply repetido preserva a baseline e reutiliza a cópia. Falhas entre duplicação, ativação e escrita final podem ser retomadas ou revertidas.
- Alterações de energia são serializadas por um ficheiro aberto com exclusividade; o painel usa o mesmo bloqueio.
- Core parking altera apenas índices AC na cópia. DC é lido antes/depois e tem de permanecer igual. Deixam de ser escritos atributos globais para desocultar definições.
- A parte de suspensão USB que altera o plano usa o mesmo mecanismo AC/DC. **A enumeração e as escritas por dispositivo continuam legadas; a ação 8 não é declarada integralmente validada.**
- A leitura dos índices usa `PowerReadACValueIndex`/`PowerReadDCValueIndex`, sem analisar etiquetas localizadas. Definições ausentes/não suportadas detetadas antes da escrita resultam em `Incompatible`; outros erros continuam a ser falhas.
- Undo reativa o plano original sem alterar os respetivos índices. Só remove o GUID de plano criado para esse ciclo e confirma os resultados.
- Sem baseline, não é escolhido um plano «Balanced» arbitrário. Uma escolha externa de outro plano gera conflito explícito, sem a substituir.
- Um plano original eliminado não é reconstruído por adivinhação. A operação falha e conserva o diário.
- O Undo gerado no painel incorpora as mesmas funções de restauro de energia. Continua autocontido, sem dependência de módulos externos.
- Undo sem dados de backup termina sem alterar configurações. Se só houver dados de energia, não entra na reversão legada de serviços/registo.

Documentação técnica: [powercfg](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options), [PowerReadACValueIndex](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powerreadacvalueindex).

### Compatibilidade com dados antigos

Um `previous_power_plan.txt` antigo não é substituído por uma baseline supostamente nova. A nova aplicação de energia recusa essa migração automática. O restauro legado só reativa o GUID registado, após o validar e confirmar a existência do plano; não recupera índices que nunca foram guardados.

O ficheiro antigo permanece disponível. Resolver essa migração exige rever o ciclo anterior e preservar os backups. A presença de um nome de plano ou de um arquivo `.reg` não prova o estado inicial de todos os recursos.

## 2. Ficheiros modificados/adicionados

| Ficheiro | Finalidade |
|---|---|
| `SkyOptimizer.ps1` | Correções de execução, exportação, energia, encaminhamento de parâmetros e integração no painel/Undo |
| `README.md` | Estado real da branch e correção de promessas contrariadas pela auditoria |
| `tests/Import-SkyFunctions.ps1` | Carrega apenas declarações AST, sem executar a inicialização da aplicação |
| `tests/Safety.Tests.ps1` | Resultados, exit codes, persistência atómica e falhas de exportação |
| `tests/Power.Tests.ps1` | Modelo de energia em memória, Apply repetido, Undo, falhas, conflitos e paridade do painel |
| `docs/FASE2-IMPLEMENTACAO.md` | Entrega, limites e próxima etapa |
| `docs/ACOES-ESTADO.json` | Classificação proposta e estado individual dos 90 IDs |
| `docs/BENCHMARKS.md` | Protocolo reproduzível, métricas e critérios de decisão |
| `docs/OPORTUNIDADES.md` | Novas propostas com mecanismo, âmbito, riscos e medição |
| `docs/TESTES-RESULTADO.json` | Contagens e versões da execução final dos testes |

## 3. Testes e resultados

Execução em Windows PowerShell 5.1 com Pester 3.4.0, já instalado:

```powershell
Invoke-Pester -Script .\tests -EnableExit
```

**44 testes passaram; zero falharam, foram ignorados ou ficaram pendentes.** A execução final usou `Invoke-Pester -Script .\tests -PassThru`, com falha do processo se `FailedCount > 0`, para guardar o resumo em `TESTES-RESULTADO.json`.

Os testes de energia usam um modelo de Windows em memória. `Invoke-SkyNativeProcess`, leitura de índices e identidade da máquina são substituídos. O teste de exportação simula ficheiros numa pasta temporária do Pester. Nunca se executa o entry point do otimizador nem se aplica um tweak ao Windows de desenvolvimento.

Casos relevantes cobertos:

- Apply, alteração de índices, Apply novamente, Undo e Undo novamente, com valores originais não padrão.
- GUID reutilizado sem duplicar planos e DC preservado.
- Falha ao guardar a baseline antes de qualquer mutação.
- Falha de ativação após duplicação; falha de persistência depois de ativar.
- Falha no segundo índice, com recuperação do plano original.
- Exit code zero sem efeito real, tanto na ativação como na escrita de índice.
- Baseline inválida/de outra máquina, plano original desaparecido e escolha externa de outro plano.
- Falha ao eliminar o plano criado, preservando informação para tentar novamente.
- Duas operações concorrentes no diário de energia.
- Capacidade ausente sem iniciar alterações; USB incompatível sem entrar em escritas de registo legadas.
- Backup parcial/ausente/vazio, repetição sem sobrescrever e contagem correta de falhas.
- Mesma fonte de funções no restauro principal e no painel gerado.
- Parsing do Undo gerado completo e guarda do entry point sem backups, incluindo pastas que só contêm logs/bloqueios.

Foi também analisada a sintaxe do script principal e do Undo gerado completo. **Não foi feito ensaio de instalação/recuperação num Windows descartável nem benchmark físico.** Os mocks não certificam drivers, firmware, Modern Standby, GPOs ou comportamento térmico.

## 4. Estado das 90 ações

| ID | Finalidade proposta | Trabalho deste conjunto | Pendente |
|---:|---|---|---|
| 1 | Otimização condicional | Plano isolado, baseline durável, deteção por GUID, repetição e Undo | Teste de integração em Windows/firmware reais; seleção de política por hardware |
| 3 | Experimental | AC na cópia, DC preservado, capacidade e pós-verificação | Ganho/regressão por CPU/jogo, temperaturas e isolamento num perfil experimental |
| 8 | Otimização condicional | Parte do plano migrada para AC/DC verificados | Enumeração PnP, suporte e backup por dispositivo; ação completa permanece legada |
| Restantes | Ver `ACOES-ESTADO.json` | Beneficiam da comunicação honesta e da barreira comum de exportação quando a utilizam | Migração individual e verificação do estado efetivo |

O JSON cobre os 90 IDs e reutiliza a análise da Fase 1. A classificação **não é um perfil de execução implementado**, nem significa que se tenha confirmado suporte individual em todas as builds. Neste lote, o catálogo automático continua com as ações legadas; não foi transformado num perfil Balanced validado.

## 5. Eficácia ainda por demonstrar

Não há qualquer percentagem de FPS, 1% low ou latência medida nesta entrega. Isolar um plano e recuperar a baseline melhora fiabilidade; não representa, por si só, uma otimização de FPS.

Core parking em AC permanece uma hipótese de desempenho dependente de CPU, firmware, carga e temperatura. Suspensão USB precisa de um problema reproduzível ou ensaio de input. Nenhum dos dois foi validado como benefício universal.

## 6. Oportunidades e perfis

As propostas estão em `OPORTUNIDADES.md`; o protocolo está em `BENCHMARKS.md`. Nenhum tweak novo de fórum foi acrescentado.

Perfis Balanced/Performance/Extreme são viáveis como seleção simples do catálogo existente, mas ainda não foram ativados. Primeiro são necessários requisitos, rollback e pós-verificação por ação. O perfil experimental não pode ser apenas o atual Apply com um nome diferente. Não foi inventado suporte específico para Intel híbrido, Ryzen X3D, Intel Arc ou anti-cheats.

## 7. Limitações e P0 pendentes

1. **Undo de registo/serviços/rede ainda contém reposições arbitrárias.** Uma execução completa pode entrar nesse percurso legado. O aviso não corrige esse comportamento; é o próximo bloqueio técnico a resolver antes de clientes.
2. `.reg` por chave não representa existência/tipo/conteúdo original de cada valor. Backups sobrepostos e Ensure antes de Backup continuam por migrar.
3. `state_backup.json` não reconstrói toda a baseline entre sessões; vários ficheiros `previous_*` legados ainda podem ser substituídos. O diário novo protege exclusivamente o ciclo de energia.
4. Só os comandos encaminhados para o invocador novo têm essa validação de exit code. Outros comandos nativos e erros explicitamente silenciados continuam legados; as respetivas ações não são contadas como verificadas.
5. A ação USB ainda contém o padrão de enumeração incorreto e escritas por dispositivo sem baseline exata. Não se declara esse defeito resolvido.
6. HAGS, MSI, rede, definições gráficas, AppX, VBS/anti-cheat e a limpeza divergente de shaders continuam pendentes.
7. O processo antigo de limpeza do painel, os restantes botões e a reversão de recursos não energéticos ainda não partilham toda a lógica.
8. O bloqueio de energia só coordena estas rotinas; não impede outro software, uma GPO ou o utilizador de alterar planos. Há verificações de conflito, mas não uma transação global do Windows.
9. `Applied` para energia significa configuração verificada, não efeito físico/ganho de FPS verificado. As políticas de bateria são preservadas no plano; não se certifica a autonomia total perante os outros tweaks legados.

## 8. Próxima etapa recomendada

Migrar o backup/Undo de registo para valores tipados com existência explícita e gravação antes da mutação, **apenas dentro do SkyOptimizer**. Começar por um grupo pequeno de ações que partilham chaves, testar Apply repetido e interrupções, depois alargar.

Eliminar os fallbacks arbitrários de Undo por grupos de recurso. Os backups antigos devem ser reconhecidos como incompletos, sem inventar dados em falta. Só após estes P0 se deve avançar para HAGS/MSI/rede, perfis e seleção de ajustes por benchmark.

Commits funcionais deste conjunto:

- `2a5e7ac` — resultados verificáveis e bloqueio após falhas de backup.
- `08e07cd` — plano isolado, AC/DC, recuperação e paridade de energia no painel.

Os commits seguintes desta branch registam a documentação e qualquer correção encontrada na verificação final. Não houve push.
