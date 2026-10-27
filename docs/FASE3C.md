# Fase 3C — políticas, tarefas e interação entre ações

Base preservada: `8ae45bd`, branch `dev/phase2-execution-power-safety`, inicialmente limpa. Apenas SkyOptimizer; sem push, sem VM/hardware e sem aplicar otimizações ao Windows de desenvolvimento.

## 1. Identidade, ownership e Undo parcial

A identidade do recurso já não depende da ordem dos campos JSON ou de maiúsculas no caminho/nome de registo. A baseline original é única por recurso ativo. Comparações de conteúdo continuam sensíveis ao tipo/conteúdo; normalizar identidade não altera dados do utilizador. Recursos de driver/tarefa também mantêm metadados de contrato, cuja substituição não é adotada silenciosamente.

O diário suporta os formatos 1 e 2. Escritas tradicionais conservam o formato 1. O formato 2 acrescenta referências opcionais de ações (`OwnerIds`). Duas ações que exigem o mesmo estado partilham a primeira baseline; estados opostos de proprietários diferentes são recusados antes de qualquer escrita. A ação já conforme antes de qualquer alteração não adquire baseline nem direito a desfazer uma preferência alheia.

`Restore-SkyTrackedChanges -OwnerActionId <ID>` é um mecanismo interno de reversão parcial. Liberta a referência de uma ação; só restaura o recurso quando não há outro proprietário. O Undo normal continua a restaurar o ciclo completo. Falhas e conflitos de um recurso não impedem a tentativa de restaurar recursos independentes.

Ao reutilizar uma entrada antiga sem ownership, o proprietário 0 representa origem desconhecida. Não se inventa a ação histórica: libertar a nova ação preserva essa referência; o Undo completo continua disponível. Não existe downgrade automático do diário. Leitores antigos aceitam apenas formato 1 e recusam formato 2; usar programa e painel da mesma versão, regenerando os scripts do painel antes de recuperar um diário novo. A recusa preserva os ficheiros e não importa defaults.

Esta proteção refere-se aos recursos realmente geridos. Não impõe intenções de ações que nunca alteraram o recurso, nem deteta toda a equivalência física entre APIs diferentes. Operações externas continuam a poder ocorrer entre leitura e escrita; não há transação global do Windows.

Validação inicial: testes de interação verificam ordens A/B e B/A, repetição, conflito de objetivos, caminhos equivalentes, ausência original, dados antigos, falhas de persistência, falha depois da mutação, Undo parcial e recursos independentes. Apenas mocks e TestDrive.
