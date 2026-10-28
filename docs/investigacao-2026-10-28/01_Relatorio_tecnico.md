# SkyOptimizer — investigação técnica e estratégia de evolução

**Data:** 28 de outubro de 2026. **Natureza:** investigação documental e inspeção estática; não é certificação de desempenho. **Conclusão:** investir primeiro em diagnóstico durante jogos, validação funcional e redução seletiva de concorrência. Não promover mais receitas globais por estarem implementadas ou serem reversíveis.

## Entregáveis e leitura

Este relatório reúne conclusões, evidência, ranking e questões em aberto. Os documentos complementares são:

- [Matriz dos 90 IDs e oportunidades adicionais](02_Matriz_90_acoes.md).
- [Plano de debloat avançado](03_Debloat_avancado.md).
- [Arquitetura adaptativa e plano faseado para o Codex](04_Arquitetura_e_plano_Codex.md).
- [Protocolo de benchmarks e critérios de promoção/retirada](05_Protocolo_benchmarks.md).

A matriz inclui propostas rejeitadas. Todos são planos; nenhuma recomendação foi aplicada. As fontes externas foram consultadas em 28/10/2026; documentação antiga é usada apenas para o mecanismo/contexto indicado, sem presumir validade universal nas builds atuais.

## 1. Base examinada e confirmação do estado

Repositório local: `C:\Users\gfcco\OneDrive\Documentos\SkyOptimizer`. Branch identificada no HEAD: `dev/phase2-execution-power-safety`; referência local lida: `ab5573644325314697b904c1fb8cc2b27e4e0d5b`. O comando Git não conseguiu aceder ao diretório neste ambiente; a referência foi lida diretamente. Não se certifica ausência de alterações locais a partir dessa referência.

O SHA-256 observado de `SkyOptimizer.ps1` é `5E49346EDA68074E33F5C2FD5F220F87DCADEC18982B4C059B8A6C76EEFCB88D`, coincidente com `docs/TESTES-RESULTADO.json` e `docs/FASE5A-TESTES.json`. Estes registam o commit de teste `0878bd97f72a78c6549b2edab66a5f1f1889b2cf`.

Recontagem de `ACOES-ESTADO.json`: **90 IDs = 28 elegíveis + 56 bloqueados + 5 retirados + manutenção 24**. Os resultados guardados confirmam **225 Pester e 11 Python aprovados**, sem falhas. Não voltei a executar as suites. Os próprios resultados declaram ausência de integração em VM e de benchmarks físicos.

Foram consultados README, Fases 2/2-continuação/3A/3B/3C/4/5A, catálogo, auditorias 3B e 4, perfis, oportunidades, protocolo de benchmarks e procedimentos de integração/hardware/tarefas. A inspeção do código concentrou-se nos percursos que sustentam as decisões: perfis/dispatcher, ações de captura, serviços e AppX, relatórios e analisador Python. Isto não repete uma auditoria de segurança integral nem verifica cada linha do produto.

**O que preservar:** baseline tipada, intenção antes da mutação, idempotência, conflitos externos preservados, identidade de recurso, isolamento do plano de energia, bloqueio das receitas legadas e coletor independente. As retiradas 12/14/30/39/54 são coerentes com o objetivo comercial.

**O que permanece aberto:** F4-11, contratos funcionais; F4-12, integração real; F4-13, histórico/diagnóstico ainda parcial. A proteção de armazenamento/ACL/UAC precisa de execução real. HKCU continua a ser a conta elevada. O Undo de energia conserva cópias e devolve estado incompleto; isso é contenção de risco, não reversão integral. Só 58/70/84 têm ownership explícito novo. Não transformar a contagem de testes em percentagem de cobertura ou fiabilidade comercial.

## 2. Como classificar evidência

| Classe | Significado e alcance |
|---|---|
| A | Benefício experimental demonstrado nas condições publicadas ou posteriormente reproduzidas. Não transfere automaticamente para outro jogo ou PC. |
| B | Mecanismo sólido e benefício condicional; ainda exige confirmação no cliente. |
| C | Hipótese plausível, sem validação suficiente para recomendação automática. |
| D | Benefício de gaming não demonstrado, evidência inconsistente ou objetivo apenas funcional/cosmético. |
| E | Receita com risco desproporcionado ou regressão relevante; rejeitar como predefinição. |

Acrescentar sempre a **natureza da prova**: documentação de mecanismo, experiência externa, ensaio SkyOptimizer ou inferência. Uma técnica pode ter benefício A numa experiência e continuar E como política comercial: desativar proteções é o exemplo central. Aqui, nenhuma ação tem benefício A medido pelo SkyOptimizer. D não significa demonstração matemática de efeito zero; significa que não há base suficiente para vender o benefício.

## 3. Ranking de investimento

| Ordem | Melhoria | Razão, classe e demonstração necessária |
|---:|---|---|
| 1 | Fechar integração e contratos das ações ativas | Pré-requisito comercial, não ganho de FPS. Validar Apply/reboot/Undo e função real, começando por 9/41/79. |
| 2 | Captura por jogo e diagnóstico temporal | Diferencial central: distinguir espera de CPU, GPU, memória, I/O e concorrência. B como método de investigação; exige intervenção confirmatória. |
| 3 | Gestão seletiva de captura, browsers, launchers e sincronização | B quando há carga concorrente observada. Comparar com a mesma carga ativa e inativa; preservar funcionalidades utilizadas. |
| 4 | Perfis de apresentação e latência por jogo | B para caminhos suportados; maior proximidade ao mecanismo que produz latência. Medir frametimes e latência separadamente. |
| 5 | Novo debloat com inventário, escopos e recuperação honesta | Alto valor funcional; efeito de gaming B apenas quando remove trabalho concorrente. AppX inativo é D para FPS. |
| 6 | Diagnóstico térmico, energia sustentada, RAM e GPU correta | B quando resolve configuração inadequada. Evitar que um perfil agressivo piore boost, ruído ou autonomia. |
| 7 | Ensaios de NIC e drivers dirigidos a sintomas | C até reproduzir problema local. Custo e variabilidade maiores; não confundir Internet/servidor com Windows. |
| 8 | Experiências de scheduling/HAGS/energia | C por combinação de jogo/driver/topologia. Manter fora de automatismos até haver provas. |

O ranking considera utilidade esperada, risco e capacidade de provar resultados; não estima percentagens de ganho. O menor número de processos não deve ser um objetivo de otimização.

## 4. CPU, scheduler, energia e interrupções

O Windows agenda threads, não nomes de aplicações. Uso total de CPU baixo não exclui uma thread crítica saturada. O diagnóstico deve separar Running, Ready e Waiting, com correlação temporal de I/O e DPC/ISR. Um máximo isolado num driver não prova a causa de stutter. A amostragem de CPU pode perder eventos breves; usar os eventos adequados no WPA. **B para diagnóstico; C para alterar scheduling.** [Microsoft, CPU Analysis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/cpu-analysis).

Não impor prioridade Realtime, afinidade fixa, desativação de SMT/E-cores ou quantum global. Essas medidas restringem recursos ou mudam prioridades de trabalho útil. Um teste que beneficia um jogo pouco paralelo pode prejudicar compilação de shaders, streaming, Discord e OBS. CPU Sets por jogo é hipótese C para casos reproduzidos; afinidade não deve resultar de uma correspondência textual com “Intel” ou “X3D”.

Intel documenta a integração preferencial de Thread Director da 12.ª geração com Windows 11. Isto justifica distinguir plataforma/SO, não inventar uma regra universal para todas as gerações. Para Ryzen, distinguir CPU simétrica, múltiplos CCD e configurações com cache assimétrica; manter drivers de chipset e políticas do fabricante como baseline. O contrato atual completo entre Game Bar, Game Mode e todos os Ryzen X3D não ficou verificado nesta investigação: bloquear automatismos dependentes dessa suposição. [Intel, Thread Director e Windows](https://www.intel.com/content/www/us/en/support/articles/000091284/processors.html).

Core parking, P-states, C-states e boost têm compromissos de latência, energia e temperatura. A ação 1 é infraestrutura: copiar o plano não produz por si melhoria. A ação 3 continua C. Desativar economia globalmente pode aumentar consumo e reduzir desempenho sustentado num portátil. Testar AC e bateria separadamente; medir uma sessão longa, não apenas o primeiro minuto. “Ligado à tomada” não significa ausência de limites térmicos ou de potência.

MMCSS aplica-se a threads inscritas no serviço. `GPU Priority` e `SFIO Priority` são documentados como não utilizados; a garantia antiga de `Clock Rate` deixou de existir. A alteração genérica 36 não deve regressar. `SystemResponsiveness=0` também não significa “zero reserva”: valores inferiores a 10 são normalizados para 20 segundo a documentação. **D/E para receitas genéricas**, sem negar o valor do MMCSS usado corretamente pelas aplicações. [Microsoft, MMCSS](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service).

EcoQoS é uma oportunidade C para tarefas secundárias identificadas, nunca para áudio, jogo ou captura indiscriminadamente. A Microsoft documenta influência na seleção de cores e energia. Primeiro reduzir o overhead do próprio SkyOptimizer; depois testar terceiros acessíveis e explicitamente escolhidos. Há ainda um confundidor pouco óbvio: inatividade do utilizador pode baixar QoS em bateria nas versões abrangidas. Benchmarks automatizados devem registar e controlar esse comportamento; não transformar o controlo de laboratório em tweak universal. [Microsoft, Quality of Service](https://learn.microsoft.com/en-us/windows/win32/procthread/quality-of-service).

## 5. GPU, apresentação e latência

**Apresentação por jogo é prioridade superior a flags globais.** Windows 11 oferece otimizações para jogos DX10/DX11 em janela/borderless, com passagem para flip model em casos compatíveis. Não generalizar para todos os jogos, nem assumir que fullscreen exclusivo é sempre superior. A ação 42 usa armazenamento interno; o suporte da funcionalidade não documenta automaticamente essa escrita. Preferir orientação pela interface suportada enquanto não existir contrato estável. Medir PresentMode e efeito real após reiniciar o jogo. [Microsoft, otimizações em janela](https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11).

HAGS transfere trabalho de scheduling para hardware suportado. A Microsoft apresentou-o como mudança que poderia ser transparente, não promessa de ganho visível. Suporte depende de GPU e driver; não de VRAM ou marca. Manter 37 bloqueada e avaliar HAGS com overlays, captura, múltiplos monitores e frame generation. **C para benefício num PC desconhecido.** [Microsoft, HAGS](https://devblogs.microsoft.com/directx/hardware-accelerated-gpu-scheduling/).

Reflex e Anti-Lag 2 atuam perto da fila CPU/GPU; são candidatos B em jogos suportados, especialmente limitados por GPU. Anti-Lag 2 depende de integração no jogo: o SkyOptimizer não o pode acrescentar por uma chave de registo. Usar opções suportadas, sem injeção. O guia NVIDIA de 2020 contém recomendações históricas de fullscreen que não devem sobrepor-se à documentação atual de apresentação. [NVIDIA, latência](https://www.nvidia.com/en-gb/geforce/guides/system-latency-optimization-guide/); [AMD GPUOpen, Anti-Lag 2](https://gpuopen.com/anti-lag-2/).

VRR/G-Sync/FreeSync, V-Sync e caps resolvem objetivos diferentes. VRR sincroniza apresentação dentro do intervalo suportado; não cria FPS. V-Sync pode reduzir tearing e aumentar espera. Um cap pode estabilizar tempos e evitar saturação, mas baixar throughput. Testar limiter do jogo e alternativas suportadas separadamente; não empilhar limiters. Não existe margem fixa abaixo do refresh ideal para todos os motores. Oferecer objetivos “latência mínima com tearing aceite” e “fluidez sem tearing”, com preferências explícitas.

Upscaling pode reduzir carga GPU com custo de qualidade; em limitação de CPU o benefício pode ser pequeno. Frame generation aumenta frames apresentados sem necessariamente acelerar simulação ou resposta à entrada. Registar resolução interna, modo de qualidade, frames renderizados/gerados e artefactos. Não contabilizar frames gerados como ganho equivalente de desempenho nativo.

Overlays e gravação consomem recursos quando ativos, mas presença de um processo não demonstra impacto. Medir encoder, composição, GPU, CPU e I/O. **B para desligar gravação não utilizada sob carga; C/D para remover todos os overlays por princípio.** A ação 9 não desinstala Game Bar; deve ser descrita com precisão. `AllowGameDVR` tem nota explícita de imposição apenas em Windows 10 desktop. Windows 11 requer verificação funcional dos outros controlos, não sucesso pelo registo. [Microsoft, AllowGameDVR](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement#allowgamedvr).

## 6. Memória, armazenamento e caches

RAM livre não equivale a RAM útil. Medir commit/limite, memória disponível, working sets privados/partilhados, compressão, hard faults e I/O de paginação. Hard faults podem carregar ficheiros mapeados e não apenas pagefile; atribuição exige contexto. Não somar working sets partilhados para anunciar “RAM libertada”. Não esvaziar standby lists periodicamente nem desativar compressão/pagefile como rotina. A política recomendada é conservar a gestão do Windows até haver diagnóstico específico. O pagefile sustenta commit e dumps; removê-lo pode provocar falhas mesmo com RAM aparentemente disponível. [Microsoft, pagefile](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/introduction-to-the-page-file).

SysMain (6) permanece C: procurar I/O concorrente reproduzível antes de ensaiar. Uma regressão em HDD ou numa instalação particular não autoriza desativação por detetar SSD. Medir arranque de aplicações e cargas frias/quentes, além de FPS. Memória comprimida ou cache ocupada também não demonstra problema por si só.

Preservar caches de shaders por omissão. A NVIDIA documenta recompilação/stutter após invalidação e recomenda tamanho compatível com jogos e espaço disponível. Limpeza 24 continua reparação manual; o próprio fabricante admite limpeza quando há corrupção. Não converter a exceção em manutenção periódica. **B para preservar cache útil; E para limpeza sistemática.** [NVIDIA, cache](https://www.nvidia.com/content/Control-Panel-Help/vLatest/en-us/mergedProjects/3D%20Settings/Manage_3D_Settings_%28reference%29.htm); [NVIDIA, reparação de cache](https://nvidia.custhelp.com/app/answers/detail/a_id/5735).

Armazenamento: identificar o volume do jogo, dispositivo físico, espaço, latência e fila durante o problema. Não usar “primeiro disco” ou C: como substituto. SSD/NVMe pode melhorar carregamento e streaming quando I/O limita; não garante FPS maior numa cena residente. DirectStorage exige implementação no jogo; não é ativado universalmente por debloat. O anúncio técnico distingue compatibilidade Windows 10 de otimizações Windows 11. [Microsoft, DirectStorage](https://devblogs.microsoft.com/directx/directstorage-api-available-on-pc/).

Indexação merece ajuste de escopo, não desativação cega. A Microsoft descreve backoff por atividade e exclusões de pastas. Bibliotecas com muitos ficheiros/mods e índice em reconstrução são cenários de investigação. Excluir uma pasta também reduz pesquisa; reconstruir o índice cria trabalho adicional e não pertence a uma sessão de medição. [Microsoft, Windows Search](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/windows-search-performance-issues).

## 7. Input e rede

Pipeline de entrada: dispositivo/sensor/debounce → transporte USB/rádio → processamento do SO/jogo → simulação → fila/renderização → apresentação/scanout → resposta do painel. FPS, timer resolution e DPC são apenas partes ou indicadores indiretos. Sem instrumento físico, apresentar métricas de software com os seus pontos inicial/final; não anunciar click-to-photon completo.

Raw Input não recebe as mesmas ballistics do ponteiro Windows. Alterar aceleração de rato não configura automaticamente Raw Input nem reduz latência em todos os jogos. Repetição do teclado não altera necessariamente o primeiro keydown; 73 não é otimização de strafe. Preservar acessibilidade. [Microsoft, entrada de rato](https://learn.microsoft.com/en-us/windows/win32/dxtecharts/taking-advantage-of-high-dpi-mouse-movement).

Polling de 1.000/4.000/8.000 Hz corresponde a intervalos nominais de 1/0,25/0,125 ms, não a latência total. Mais eventos exigem processamento: testar movimento real contínuo, e não benchmark com rato parado. A MSI documenta custo adicional de 8.000 Hz para um modelo específico; não extrapolar os seus requisitos mínimos para todos os periféricos. [MSI, polling](https://www.msi.com/faq/faq-8795).

A Microsoft recomenda não desativar USB selective suspend globalmente. A ação 8 só se justifica como ensaio de idle/retoma de um problema observado, nunca como receita para baixar latência do rato em atividade. Testar hubs/docks, áudio, comando, suspensão e consumo. [Microsoft, USB selective suspend](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-selective-suspend).

Rede: separar RTT ao gateway, destino local controlado e remoto; observar perdas e jitter sob upload/download. Congestionamento no router/ISP ou servidor não se resolve com portas efémeras ou TTL. Nagle é TCP; não serve como receita universal para tráfego UDP. EEE, DMA coalescing e interrupt moderation são experiências por NIC/driver. Desativar moderação pode diminuir espera e aumentar CPU/interrupções; desligar offloads pode reduzir throughput e piorar carga. [Microsoft, NIC](https://learn.microsoft.com/en-us/windows-hardware/drivers/network/performance-in-network-adapters); [Intel, tuning Windows 700/800](https://cdrdv2-public.intel.com/784543/784543_Intel%20Ethernet%20700-800%20Series%20Windows%20Performance%20Tuning%20Guide_rev1_2.pdf).

A ação 20 retira peering, não downloads. Para contenção observada, limites de tráfego e horários são hipóteses mais diretas. Verificar capacidade, versão e precedência GPO/MDM antes de usar interfaces de monitorização/configuração. Gestão de filas no router pode ser uma recomendação externa após prova de bufferbloat, sem alegar que o SkyOptimizer controla o ISP. [Microsoft, Delivery Optimization](https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/delivery-optimization-in-windows); [monitorização DO](https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-monitor).

## 8. Segurança, firmware e diferenças entre plataformas

Não sacrificar Defender, Windows Update, Secure Boot, TPM ou integridade de memória para atingir uma meta comercial de FPS. VBS/HVCI pode ter custo real; ensaios antigos não autorizam percentagens universais. Para Defender, investigar ficheiros/processos com o analisador disponível e os requisitos da plataforma; não criar exclusões globais de jogos, Downloads ou discos. [Microsoft, análise de desempenho Defender](https://learn.microsoft.com/defender-endpoint/tune-performance-defender-antivirus); [riscos de exclusões](https://support.microsoft.com/en-us/windows/security/threat-malware-protection/virus-and-threat-protection-in-the-windows-security-app).

XMP/EXPO, ReBAR, GPU selecionada, PCIe e throttling podem revelar problemas mais relevantes que debloat. São diagnóstico/recomendação antes de serem automação. Não inferir canais de memória ou EXPO ativo apenas pelo número de módulos ou clock anunciado. EXPO é overclocking; requer estabilidade e compatibilidade, sem promessa de suporte universal. ReBAR depende de firmware/GPU/driver; não mudar CSM/UEFI numa máquina desconhecida, pois o arranque pode depender do modo existente. [AMD, EXPO](https://www.amd.com/en/products/processors/technologies/expo.html); [Intel, ReBAR](https://www.intel.com/content/www/us/en/support/articles/000090831/graphics.html).

Atualizar BIOS/driver só perante problema, suporte ou melhoria relevante documentada. Registar versão e notas, preservar possibilidade de recuperação e considerar que firmware pode não aceitar downgrade. Não automatizar flashing, voltagens, undervolt, PBO ou desativação de proteções térmicas nesta evolução. Reinstalar drivers indiscriminadamente pode invalidar caches e prejudicar a comparação.

| Plataforma | Decisão de produto |
|---|---|
| Windows 10 | Identificar edição/build e situação de suporte/ESU/LTSC. Não recomendar downgrade por reputação de desempenho. |
| Windows 11 | Verificar versão concreta, políticas suportadas, apresentação e comportamento de energia. “11” não é uma única configuração. |
| Home versus Pro/Enterprise | Não escrever políticas só porque a chave aceita valores. Não extrapolar os gates conservadores atuais. |
| Desktop recente | Menos pressão de RAM/CPU pode reduzir retorno do debloat; priorizar apresentação, jogo e processos realmente ativos. |
| PC antigo/pouca RAM/HDD | Maior probabilidade de contenção; preservar caches/pagefile e distinguir falta de capacidade de configuração defeituosa. |
| Portátil/iGPU | Memória e orçamento térmico partilhados; respeitar OEM, AC/DC, MUX/híbrido, ruído e autonomia. |
| Híbrido/múltiplos CCD | Validar placement em workload real; não desligar núcleos ou parking por marca. |

O suporte geral Windows 10 22H2 terminou em 14/10/2025; ESU e LTSC têm condições próprias. O produto deve consultar a edição/canal, sem tratar todos os Windows 10 como equivalentes. [Microsoft, release information](https://learn.microsoft.com/en-us/windows/release-health/release-information).

## 9. Evidência experimental externa e resultados negativos

**Experiência externa A, âmbito estreito:** TechSpot, 27/01/2026, comparou Windows 11 25H2 e Windows 10 22H2 em 14 jogos, principalmente Ryzen 9800X3D/RTX 5090, driver 591.74. Encontrou cerca de 4% de vantagem média geométrica a 1080p e 5% nas outras resoluções. Há jogos próximos da igualdade e resultados invertidos por resolução. As instalações tinham antivírus/VBS desativados; portanto não representam a baseline de segurança proposta para clientes. Três runs e uma configuração principal não estabelecem universalidade, nem isolam o efeito de debloat. [Estudo original TechSpot](https://www.techspot.com/article/3081-windows-11-vs-windows-10-gaming/).

**Experiência externa A para custo, não recomendação de desativação:** Tom’s Hardware, 2021, mediu perdas de alguns pontos percentuais com VBS/HVCI em quatro CPUs Intel/AMD. A antiguidade de Windows, drivers, jogos e hardware limita a transferência para 2026. Sustenta que segurança pode ter custo; não sustenta que o SkyOptimizer deva removê-la. [Ensaio original](https://www.tomshardware.com/news/windows-11-gaming-benchmarks-performance-vbs-hvci-security).

Não encontrei, nas fontes examinadas, ensaio controlado suficiente para atribuir ganho universal de gaming a remoção de AppX inativos, “telemetria zero”, agrupamento de svchost, limpeza de standby, MSI forçado, temporizador global ou desligar todos os serviços opcionais. Estes permanecem C/D/E conforme mecanismo e risco. A ausência de tal ensaio nesta pesquisa não prova que não exista qualquer estudo.

**Experiência externa com resultados mistos:** BabelTechReviews, 03/05/2022, ensaiou HAGS em 26 jogos, i9-12900K/RTX 3080 e driver 512.15 no Windows 11 21H2. Reportou melhorias de consistência nalguns títulos, regressões noutros e crashes em Horizon Zero Dawn. O método agregava três runs após excluir outliers, usava limiar editorial de 3% e uma baseline alterada, incluindo CFG desligado por jogo e limpeza de standby. Isso limita causalidade, representatividade e a interpretação de “significativo”; não equivale a um teste estatístico com CI. Serve como evidência histórica contra universalidade, não como recomendação HAGS off em 2026. [Ensaio original e metodologia](https://babeltechreviews.com/hardware-accelerated-gpu-scheduling-performance/).

As regressões mais plausíveis/documentadas são: recompilação após limpar caches; falhas por limite de commit; consumo maior ao desativar economia USB; aumento de CPU ao desligar interrupt moderation; perda de sincronização com OneSyncSvc; remoções AppX sem recuperação de dados. São suficientes para rejeitar a aplicação indiscriminada, mesmo antes de medir FPS.

## 10. Ferramentas e integração comercial

PresentMon deve ser o primeiro candidato para captura ETW/CSV. Fixar versão, campos, relógio, filtros e licença; uma coluna de duração GPU não é necessariamente intervalo de frames. Campos de input/latência dependem de instrumentação e não incluem automaticamente toda a eletrónica do periférico/painel. CapFrameX é útil como ferramenta independente de laboratório. WPR/WPA fornece investigação detalhada, com custo de captura e privacidade. [PresentMon, documentação](https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md).

PresentMon e o código principal de CapFrameX apresentam licenças MIT, com conservação dos avisos; dependências têm termos próprios. LibreHardwareMonitor usa MPL 2.0; avaliar os ficheiros e binários realmente distribuídos, em especial drivers e componentes de terceiros. Começar por importação de capturas e ferramentas externas evita acoplar sensores privilegiados ao produto antes da revisão. Isto é triagem técnica de dependências, não parecer jurídico. [PresentMon LICENSE](https://raw.githubusercontent.com/GameTechDev/PresentMon/main/LICENSE.txt); [CapFrameX LICENSE](https://github.com/CXWorld/CapFrameX/blob/master/LICENSE); [LibreHardwareMonitor LICENSE](https://raw.githubusercontent.com/LibreHardwareMonitor/LibreHardwareMonitor/master/LICENSE).

## 11. Questões em aberto e limites da investigação

1. Sem hardware, não existe ganho SkyOptimizer demonstrado, margem de erro medida ou compatibilidade aprovada.
2. Falta uma matriz atual completa de drivers NVIDIA/AMD/Intel, OEMs, anti-cheats, HDR/VR e múltiplos monitores. Validar por versão; não certificar a partir do fabricante.
3. O contrato específico Ryzen X3D/Game Bar/parking exige fonte primária atual e ensaio por topologia. A página AMD tentada não ficou acessível; não foi usada como prova.
4. Memória comprimida, SysMain e standby precisam de traces e estudos atuais por build. Não há fundamento suficiente aqui para desativação universal.
5. Faltam ensaios independentes comparáveis de debloat moderno em máquinas de poucos recursos, com segurança preservada e dados brutos.
6. Recuperação AppX depende de pacotes, licenças, disponibilidade e dados. Nenhuma promessa de restauração integral está pronta.
7. Sensor APIs e WDDM podem expor campos diferentes; definir Unknown e Unsupported antes de automatizar decisões.
8. Os estudos externos citados não fornecem, nesta entrega, um conjunto de dados brutos reanalisado independentemente.
9. Firmware, tuning específico de memória e latência física de periféricos exigem campanhas próprias; não foram esgotados todos os modelos.
10. Catálogos e políticas podem mudar. Revalidar fontes e capacidade antes de cada lançamento; não usar uma build mínima como garantia para todas as posteriores.

Esta investigação cobre as áreas pedidas e produz um plano executável, mas **não se declara exaustiva**. O critério de sucesso da próxima fase será fechar dúvidas com evidência, inclusive quando o resultado correto for “não alterar nada”.
