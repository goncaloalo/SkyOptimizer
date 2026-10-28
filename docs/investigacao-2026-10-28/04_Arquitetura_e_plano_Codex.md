# SkyOptimizer — arquitetura adaptativa e plano de implementação

**Tudo neste documento é proposta futura.** Não autoriza executar otimizações no computador de desenvolvimento. Reutilizar os mecanismos existentes; não criar um segundo motor de Apply/Undo.

## 1. Arquitetura mínima

Fluxo: **inventariar → observar sessão → formular hipótese → propor mudança → validar → medir → conservar ou restaurar**. A decisão “não alterar” é um resultado normal e útil.

| Componente | Responsabilidade | Reutilização / custo |
|---|---|---|
| Inventário de capacidades | SO/build/edição, conta interativa/elevada, GPU do jogo, CPU/topologia, RAM/commit, volumes, NIC/rota, alimentação e políticas | Expandir diagnóstico atual com valores Unknown; baixa/média complexidade, sem escrita |
| Sessão de captura | Executável/versão, PID e início, swapchain, relógio, cena, PresentMon e sensores opcionais | Primeiro importar CSV; depois coletor separado. Custo medido de CPU/I/O/disco, sem overlay obrigatório |
| Evidência temporal | Frametime, CPU busy/ready, GPU busy, memória/I/O e atividade concorrente | ETW/WPR detalhado apenas quando necessário; custo alto, privacidade sensível |
| Motor de hipóteses | Regras explicáveis e contraditórias, com grau de confiança e dados em falta | Sem machine learning inicial. Não converter correlação em causa |
| Catálogo e planner | Capacidade, dependências, conflitos, risco, recuperação, evidência e objetivo | Reutilizar IDs/ownership; separar ações compostas. Preview não escreve |
| Executor | Só plano escolhido, revalidado, com baseline/intenção e resultados parciais | Reutilizar dispatcher/diário; APIs específicas por recurso |
| Verificador | Estado configurado, consumo funcional e recuperação independentes | Estender `SkyValidationEvidence.ps1`; escopo definido antes da baseline |
| Avaliador | A/B, incerteza, regressões e validade por versão/hardware/jogo | Expandir `benchmarks/analyze.py`; não tornar estatística um botão de promoção automática |

Na primeira versão, limitar a identificação de processos e importação de capturas. Não criar serviço permanente, driver kernel, launcher obrigatório ou sistema de auto-tuning contínuo. Antes de qualquer recolha privilegiada, verificar necessidade e custo.

## 2. Hipóteses de diagnóstico e testes confirmatórios

| Hipótese | Indícios necessários | Explicação alternativa / confirmação | Ação proposta |
|---|---|---|---|
| Limitação GPU | GPU ocupada durante grande parte do frame; fila/tempo de GPU alto | Cap, V-Sync e workload variável confundem. Reduzir resolução/custo gráfico numa sessão controlada | Recomendar settings/upscaling/baixa latência suportada; não debloat genérico |
| Limitação CPU/jogo | Thread crítica ocupada ou ready; GPU espera | FPS cap/espera do jogo pode parecer CPU-bound. Baixar resolução sem mudar resultado não basta isoladamente | Procurar concorrência e comportamento por thread; evitar prioridade/afinidade global |
| Concorrência de processos | Picos coincidem com trabalho de processo identificado em runs repetidos | Ambos podem responder ao mesmo carregamento; coincidência não prova causalidade | Testar pausa suportada do concorrente, sem terminar trabalho útil |
| Pressão de memória | Commit alto, pouca memória disponível, hard faults e I/O correlacionados | Ficheiros mapeados/streaming normal também fazem hard faults | Reduzir apps/qualidade de texturas ou recomendar RAM; conservar pagefile |
| Pressão VRAM | Orçamento/residência e eventos de evicção quando disponíveis | VRAM alocada não é toda ativamente usada | Testar texturas/resolução; não anunciar “limpeza de VRAM” |
| Armazenamento | Espera/I/O no volume correto coincide com stutter | Shader compilation pode coexistir com leitura normal | Comparar cache quente/fria e carga concorrente; recomendar espaço/disco se confirmado |
| Térmico/energia | Limites ativos, clocks efetivos a cair sob carga estável | Clock baixo durante espera é normal | Sessão sustentada, comparação OEM/AC; aconselhar refrigeração sem mexer em proteções |
| Driver/DPC/ISR | Eventos temporalmente ligados ao bloqueio, reproduzíveis | Maior DPC isolado não é causa suficiente | Testar versão suportada/dispositivo identificado e efeitos funcionais |
| Rede local/WAN | RTT/perdas sob carga em endpoints separados | ICMP pode ser despriorizado; servidor muda carga | Medir protocolo representativo e tráfego; não inferir hit registration |

Fontes metodológicas: [CPU/WPA](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/cpu-analysis), [PresentMon](https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md), [pagefile/commit](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/introduction-to-the-page-file).

Cada hipótese deve guardar observações favoráveis, contraditórias e ausentes. Exemplo de saída: “Captura ativa coincide com picos de I/O em três sessões; testar sem gravação, preservando a opção de voltar.” Não produzir “GPU 97% = otimização X obrigatória”. Não estimar canais RAM, XMP, MSI, HAGS ou anti-cheat quando o reader não os conhece.

## 3. Perfis propostos

**Balanced:** diagnóstico e preservação de comportamento; Game Mode apenas se funcionalmente validado e desejado. Não desinstala apps, muda segurança ou força energia. “Já conforme” deve ser apresentado como ausência de trabalho necessário.

**Performance:** não é lista fixa crescente. Acrescenta apenas controlo de concorrência observado e autorizado, apresentação por jogo e recomendações suportadas. Captura, notificações, browsers, sincronização e OBS são escolhas funcionais. Deve haver variantes “jogar e gravar” e “jogar sem captura”, sem assumir que streaming é bloat.

**Extreme:** renomear na interface para “Laboratório”, ou mostrar claramente que não é promessa de maior desempenho. Experiências individuais, baseline, recuperação e métrica definida; nenhuma desativação de segurança. As opções de personalização e privacidade saem do perfil de gaming e tornam-se módulos manuais.

Hoje Extreme herda 9/41/79. Acrescentar futuramente um modo de ensaio com seleção **exata** de ações e dependências, sem herança escondida. Até lá, comparar Performance contra Performance + experiência, como já documentado. Trocar de perfil não equivale a Undo.

Um resultado validado deve ter chave de validade: CPU/topologia, GPU/driver, Windows build, jogo/versão/API, captura/FG, alimentação e parâmetros relevantes. Atualizações materiais invalidam a recomendação para nova observação; não repõem automaticamente preferências do cliente.

## 4. Custo e fiabilidade

Inventário pontual é barato, mas insuficiente para causalidade. Sensores a 1–2 Hz são ponto de partida proposto para tendências; não capturam todos os picos. ETW detalhado oferece granularidade superior com maior overhead e volume. Medir o overhead real com captura ligada/desligada, no mesmo hardware; não publicar um custo estimado como garantia.

Guardar dados localmente por omissão. Traces podem incluir caminhos, nomes de processos e ficheiros. Exportação deve ser explícita e revista. Reutilizar a separação de evidência HMAC da Fase 5A, sem confundir HMAC com anonimização ou prova contra administrador. Registar versões/hashes e preservar dados brutos necessários à investigação com prazo definido.

Não selecionar “a melhor de 50 configurações” com base no melhor run: isso seleciona ruído. Separar descoberta e confirmação com novas sessões; limitar número de hipóteses. Não automatizar alterações enquanto o jogo está em execução. Uma sessão que falha não deve desencadear cascata de tweaks.

## 5. Plano faseado para o Codex

Esforço relativo: baixo = alteração localizada; médio = contrato/adapter com integração; alto = subsistema ou campanha física. Não são estimativas de calendário.

| Fase / prioridade | Entrega concreta e ficheiros de partida | Impacto/evidência | Risco, esforço e recuperação | Gate de saída / dependência |
|---|---|---|---|---|
| 0 / P0 | Congelar baseline, acrescentar estado de prova por ação em catálogo/relatórios; corrigir rótulos 9/48/71/73/88 e receitas rejeitadas | Confiança e clareza; não FPS | Baixo/médio; reversível em Git | 90 IDs rastreáveis, zero alegações de ganho sem ensaio. Não desbloquear ações |
| 1 / P0 | Executar Fase 5A em VM: BAT/UAC, ACL, diário, lock, conta diferente, painel, perfis e recuperação | Pré-requisito comercial | Médio; VM recuperável. Testa Undo antes de snapshot restore | Before/AfterApply/AfterReboot/AfterUndo/AfterUndoReboot, efeitos funcionais e zero mutações não explicadas |
| 2 / P1 | Estender `benchmarks/analyze.py` e manifesto: timestamp/cena, tipo semântico de coluna, bloco/par, reinício, contexto e CI por run | Permite medir diferença real | Médio; análise offline | Testes com efeito conhecido, nulo, regressão, autocorrelação e dados incompletos; sem inferência de input físico |
| 3 / P1 | Inventário e diagnóstico por sessão; importação PresentMon antes de captura automática | Alto potencial indireto, B para método | Médio/alto; leitura apenas | Unknown explícito, processo/swapchain correto e custo medido; sem recomendações causais automáticas |
| 4 / P1 | Contratos de 9/41/79; separar 48/71; excluir receita global de 88 do caminho gaming | Benefício B condicionado à carga; correção funcional | Médio; usar diário existente | Políticas consumidas por componente real, conta/edição corretas, funcionalidade e Undo aprovados |
| 5 / P1 | Novo debloat: inventário, catálogo de dependências, preview e poucos adapters de startup/background | B sob concorrência; alto valor funcional | Médio; R1 predominante | Recusa de dependências protegidas, ausência/erro distintos e nenhum wildcard destrutivo |
| 6 / P2 | AppX por conta; depois provisionamento separado e recuperação testada | D para FPS inativo; B se remove carga real | Alto; R2/R3 explícitos | Pacote/dados/provisionamento separados; reinstalação testada ou indisponibilidade declarada; testes multiutilizador |
| 7 / P2 | Ensaios por jogo: apresentação, Reflex/Anti-Lag suportados, cap/VRR e captura | B, potencial alto em contexto certo | Médio/alto; preferências restauráveis | Latência e fluidez avaliadas separadamente; sem regressão de captura/HDR/alt-tab |
| 8 / P2 | NIC explícita por rota/identidade, HAGS e energia apenas por hipótese | C; retorno variável | Alto; hardware/local recovery | Segurança, reboot, sleep/resume e métricas físicas; nenhuma promoção só por mocks |
| 9 / P3 | Distribuição: pacote assinado, versão de painel, atualização e recuperação compatível, licenças/SBOM | Prontidão comercial | Alto; migrações versionadas | Matriz suportada publicada, testes de atualização/downgrade e suporte de recuperação |

Dependências: 0 e preparação de 2/3 podem avançar offline; 1 bloqueia distribuição e promoção funcional. 4 depende de 1. 5 depende dos contratos e inventário. 6 não é requisito para começar benchmarks de 4/5. 7/8 exigem hardware físico; não substituir por GPU virtual. Não implementar fases 8/9 para compensar falta de resultados na 4.

## 6. Contratos e critérios de aceitação por tarefa

Cada tarefa entregue ao Codex deve indicar: problema observado; hipótese; fonte de mecanismo; recursos exatos; edições/versões; comportamento com dados desconhecidos; baseline/ownership; pós-verificação; recuperação parcial; testes offline e ensaio real exigido; critério de paragem. Não escrever “melhorar FPS” como único critério.

Primeiras tarefas concretas:

1. **Sem mutação:** produzir inventário de recursos das 28 ações e respetivo reader funcional. Acrescentar a lacuna AllowGameDVR/Win11 sem escrever flags alternativas.
2. **Integração:** ensaiar 79 isolada e 9/41 com e sem aplicações presentes, na conta correta e com políticas externas. Classificar Unknown em vez de inventar suporte.
3. **Análise offline:** distinguir intervalos entre frames de durações de trabalho. O campo `interval_kind=render` atual não impede alguém de escolher GPU busy e obter um FPS sem sentido. Exigir semântica de coluna e origem, não apenas unidade ms.
4. **Debloat:** substituir primeiro a apresentação/planeamento de 49; manter execução bloqueada até existir contrato de remoção/recuperação. Eliminar o contador de sucesso por padrão.
5. **Perfis:** seleção exata para laboratório e resultados por recurso; sem expansão silenciosa, exceto dependências explicitadas no preview.

## 7. Quando parar, conservar ou retirar

Conservar a ferramenta de diagnóstico se identifica problemas verificáveis com custo aceitável. Promover uma otimização apenas com recuperação funcional e benefício confirmado no seu domínio. Manter como opção funcional quando o cliente valoriza a função, mesmo sem FPS. Retirar receita quando não tem contrato suportado, quando o custo excede benefício ou quando ensaio com poder adequado exclui o benefício mínimo definido.

Parar investigação de uma hipótese quando o teste confirmatório contradiz o mecanismo, antes de acrescentar variantes de registo. Registar resultado negativo. Não retirar uma ação apenas por um ensaio pequeno inconclusivo, nem mantê-la indefinidamente com promessa vaga de “pode ajudar”.
