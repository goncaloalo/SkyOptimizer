# Fase 3C — políticas, tarefas e interação entre ações

Base preservada: `8ae45bd`, branch `dev/phase2-execution-power-safety`, inicialmente limpa. Apenas SkyOptimizer; sem push, sem VM/hardware e sem aplicar otimizações ao Windows de desenvolvimento.

## 1. Identidade, ownership e Undo parcial

A identidade do recurso já não depende da ordem dos campos JSON ou de maiúsculas no caminho/nome de registo. A baseline original é única por recurso ativo. Comparações de conteúdo continuam sensíveis ao tipo/conteúdo; normalizar identidade não altera dados do utilizador. Recursos de driver/tarefa também mantêm metadados de contrato, cuja substituição não é adotada silenciosamente.

O diário suporta os formatos 1 e 2. Escritas tradicionais conservam o formato 1. O formato 2 acrescenta referências opcionais de ações (`OwnerIds`). Duas ações que exigem o mesmo estado partilham a primeira baseline; estados opostos de proprietários diferentes são recusados antes de qualquer escrita. A ação já conforme antes de qualquer alteração não adquire baseline nem direito a desfazer uma preferência alheia.

`Restore-SkyTrackedChanges -OwnerActionId <ID>` é um mecanismo interno de reversão parcial. Liberta a referência de uma ação; só restaura o recurso quando não há outro proprietário. O Undo normal continua a restaurar o ciclo completo. Falhas e conflitos de um recurso não impedem a tentativa de restaurar recursos independentes.

Ao reutilizar uma entrada antiga sem ownership, o proprietário 0 representa origem desconhecida. Não se inventa a ação histórica: libertar a nova ação preserva essa referência; o Undo completo continua disponível. Não existe downgrade automático do diário. Leitores antigos aceitam apenas formato 1 e recusam formato 2; usar programa e painel da mesma versão, regenerando os scripts do painel antes de recuperar um diário novo. A recusa preserva os ficheiros e não importa defaults.

Esta proteção refere-se aos recursos realmente geridos. Não impõe intenções de ações que nunca alteraram o recurso, nem deteta toda a equivalência física entre APIs diferentes. Operações externas continuam a poder ocorrer entre leitura e escrita; não há transação global do Windows.

Validação inicial: testes de interação verificam ordens A/B e B/A, repetição, conflito de objetivos, caminhos equivalentes, ausência original, dados antigos, falhas de persistência, falha depois da mutação, Undo parcial e recursos independentes. Apenas mocks e TestDrive.

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
