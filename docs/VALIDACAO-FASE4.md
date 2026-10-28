# Fase 4 — Checklist de validação real

**Estado de todos os ensaios abaixo: não executados.** Esta checklist prepara trabalho futuro autorizado num Windows descartável. Não autoriza aplicar alterações ao Windows de desenvolvimento. Registar cada resultado como aprovado, falhado, inconclusivo ou não executado, com artefactos; não converter ausência de erro em aprovação.

## Preparação e recuperação

- [ ] Obter autorização explícita para alterações no guest. Usar imagem oficial, consola do hipervisor, nenhuma credencial de produção e nenhum disco/pasta do host partilhado para escrita.
- [ ] Fixar commit/hash, edição/build/idioma/arquitetura, atualizações, PowerShell, drivers e identidade/SID. Guardar `git status` e hashes dos scripts principal e gerados.
- [ ] Confirmar snapshot desligado e ensaiar recuperação antes dos cenários. Restaurar snapshot entre casos independentes. Guardar evidência antes de restaurar; recuperar snapshot não demonstra que Undo funcionou.
- [ ] Capturar transcrição, planos/índices AC/DC, valores com tipo/existência, serviços e propriedades NIC relevantes. Não guardar dados pessoais desnecessários.
- [ ] Testar Windows 10/11 e SKUs Home/Pro/Enterprise/Education conforme o contrato de cada ação. Não extrapolar suporte ARM64/x86, MDM ou anti-cheat de uma VM x64.

## Armazenamento, elevação e sessões

- [ ] Instalação com raiz ausente: confirmar DACL protegida, owner e pasta real CommonApplicationData; logs e backups centrais. Um utilizador não elevado não consegue escrever scripts/diários, trocar descendentes nem obter delete-child sobre a raiz protegida.
- [ ] Raiz/ficheiro preexistente com owner ou Allow inseguro: recusa antes de mutações, sem alterar ACL nem adotar evidência. Repetir com junction/symlink em ancestral e descendente. Fazer estes ensaios apenas sobre fixtures do guest.
- [ ] Inicialização repetida e regeneração do painel enquanto a sessão detém o lock: nenhum truncamento, recusa falsa ou substituição de baseline.
- [ ] UAC aceite, recusado e elevado com outra conta; argumentos com espaços/acentos, perfil/IDs; códigos do BAT e atalhos preservados depois de pause. HKCU pertence à conta elevada; diário de outro SID é recusado.
- [ ] Duas sessões principais, Apply/Undo concorrentes e painel: segunda sessão recusa acesso ao mesmo estado. Fechar a primeira e repetir com sucesso. Lockfile antigo sem handle não bloqueia para sempre.
- [ ] Regenerar painel e comparar funções/versão com o produto. Testar Undo, Spooler e bthserv em snapshots separados, depois de fechar o menu principal. Não usar painéis antigos como prova do código atual.

## Apply, diário e Undo

- [ ] Balanced sem experiências; Apply → Apply → reboot → Undo → Undo → reboot. Comparar existência, tipos e conteúdo originais; conformidade inicial não ganha autoria.
- [ ] Perfil inválido, ID inválido, ID bloqueado, pré-condição incompatível e aplicação parcialmente suportada: relatório coerente, códigos 1/2 conforme o erro, nenhuma declaração de sucesso integral.
- [ ] Falha do painel após aplicação: relatório e diários das alterações continuam disponíveis; saída falhada; Undo ainda restaura recursos próprios.
- [ ] Executar o [harness de registo](INTEGRACAO-VM.md): ausência, valor sem nome, DWORD, QWORD, Binary, MultiString, ExpandString literal e Unicode. Confirmar estado após os dois reinícios.
- [ ] Injetar falha antes da escrita, depois da escrita/antes de commit e durante Undo. Repetir com diário bloqueado, acesso negado e falta de espaço num volume de laboratório. Nunca encher o disco do host.
- [ ] Terminar só o processo do ensaio nos limites Pending/Restoring, guardar ponto exato/commit e recuperar. Exceção simulada não substitui crash do processo; nenhum destes ensaios prova tolerância a perda elétrica.
- [ ] Duas ações sobre um recurso: A/B e B/A, repetição, objetivo oposto, Undo parcial, falha ao libertar ownership e nova tentativa. Baseline única; recurso só restaurado quando permitido pelos owners.
- [ ] Alteração externa após Apply: preservar conflito e restaurar os outros recursos independentes. Não sobrescrever preferência externa para conseguir um teste verde.
- [ ] Identidade da máquina/SID/driver divergente, diário malformado, schema incompatível e backup legado: recusa fundamentada; sem defaults ou eliminação de provas.
- [ ] Falha do ponto de restauro não elimina baselines nem anuncia backup integral inexistente. Logs opcionais falhados não devem esconder falha do diário autoritativo.

## Energia, serviços, NIC e tarefas

- [ ] Energia: comparar original, cópia ativa e índices AC/DC. Alimentação Unknown/DC recusa políticas AC-only; transição durante Apply conserva evidência parcial. Registar eventual cópia criada pela dependência antes da recusa.
- [ ] Undo de energia reativa original e conserva cópias existentes, incluindo índices alterados externamente; comunica `Unverified`/código 2 e RetainedOwnedGuids. Não exigir eliminação automática. Se cópias já não existem, verificar o resultado específico sem inventar limpeza.
- [ ] Plano ativo escolhido externamente ou original removido: conflito preservado. Novo ciclo não apaga histórico das cópias conservadas. Comparações de benchmark verificam plano ativo e índices, não apenas nome.
- [ ] Serviço descartável: automatic/delayed/manual/disabled, running/stopped, dependentes e estados pending/paused. Capturar triggers, conta e recovery antes/depois; não devem mudar indiretamente. Falha após paragem permite recuperação do runtime original.
- [ ] Separadamente, validar os contratos funcionais de SysMain, grupo da ação 48, localização e template/instâncias OneSyncSvc. Não substituir binários dos serviços do Windows para facilitar testes.
- [ ] NIC: zero, um e vários candidatos; propriedades existentes/ausentes, tipo desconhecido, driver trocado, dispositivo renomeado/removido. Vários candidatos são recusados; nenhuma alteração global ou restart automático de adaptador.
- [ ] Após reinício, comparar configuração e comportamento de rede. Propriedade persistida não prova consumo pelo driver; VM virtual não valida NIC física. Manter consola para recuperar conectividade.
- [ ] Tarefas: usar apenas [fixtures de laboratório](TAREFAS-LAB-3C.md), comparar XML/fingerprint/Enabled e descritor de segurança. Running/Queued, tarefa apagada/recriada e edição externa devem ser tratados sem controlar tarefas reais de Windows/terceiros.

## Políticas e interface

- [ ] Para cada ID elegível, seguir [maturidade e lacunas individuais](FASE4-ELEGIVEIS.json). Testar componente consumidor, versão/edição suportada, precedência MDM/GPO e rollback funcional após reinício.
- [ ] Browsers instalados/ausentes e versões diferentes; política efetiva após relançamento. Capturas, Game Mode, Widgets, background, Spotlight, clipboard e Storage Sense confirmados na função correspondente, não só no registo.
- [ ] Ação 13 com baseline 0/1/ausente: avisar aumento possível de telemetria. Ação 42 com flags externas antes e depois de Apply: conservar conteúdo alheio e recusar Undo conflituoso.
- [ ] UI com inventário incompleto, múltiplas GPUs/discos e frequências incomuns: mostrar limites, sem certificação de XMP, canais de RAM, anti-cheat ou ganhos. Seleção visível, motivos de bloqueio e necessidade de reinício claros.
- [ ] Verificar que Explorer não é terminado globalmente e que instrução de reinício manual é compreensível. Confirmar perda funcional esperada de cada perfil antes de qualquer distribuição.

## Hardware e benchmarks — etapa posterior

- [ ] Selecionar hardware por hipótese: Intel/AMD, híbrido/X3D, portátil/desktop e GPU/driver concretos. Registar energia, temperaturas e estabilidade; não extrapolar de uma máquina.
- [ ] Seguir [BENCHMARKS.md](BENCHMARKS.md): pelo menos cinco runs de 60–120 s por condição, ordem alternada/aleatória, caches aquecidas e A após Undo. Preparar estado térmico comparável; incluir carga sustentada de 20–30 min quando relevante.
- [ ] Fixar cena, jogo, build, drivers, captura, sensores e definição de 1% low. Guardar CSV bruto, manifests, FPS médio, percentis/picos de frametime e variabilidade entre runs.
- [ ] Investigar stuttering com DPC/ISR/ETW quando relevante e overhead equivalente. Medir clocks, utilização, temperaturas e potência. Menos processos/RAM não são métricas substitutas de FPS.
- [ ] Latência de entrada só com instrumentação calibrada e pontos de medição definidos. Não deduzir click-to-photon de FPS, DPC ou timer resolution. Rede exige endpoint/protocolo/carga fixos; ping não prova hit registration.
- [ ] Definir tolerâncias antes da recolha. Promover apenas melhoria repetível superior à variabilidade, sem regressão funcional, térmica, de segurança ou estabilidade. Arquivar também resultados negativos/inconclusivos.

## Gate de saída

Um ensaio aprovado precisa de baseline, estado depois de Apply/reboot/Undo, resultado esperado e observado, versão/hash e evidência. Qualquer conflito ou resultado incompleto mantém a limitação explícita. Completar esta checklist numa plataforma não certifica automaticamente todas as outras. Até existir essa prova, manter o programa fora da distribuição comercial.
