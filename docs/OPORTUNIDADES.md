# Oportunidades adicionais — propostas, não ganhos comprovados

Estas propostas não foram aplicadas. Não dependem de novos tweaks genéricos; procuram identificar limitações concretas antes de mudar o sistema.

## 1. Diagnóstico de stutter correlacionado com drivers — prioridade alta

**Mecanismo:** correlacionar frametime spikes com DPC/ISR, CPU ready time e I/O, identificando o driver/processo presente no intervalo do problema. O WPA permite analisar duração de DPC/ISR por módulo/função. [Microsoft: CPU Analysis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/cpu-analysis).

**Âmbito:** máquinas de laboratório Windows 10/11 com versão compatível do Windows Performance Toolkit; resultados dependem de símbolos/providers disponíveis. Não implica suporte certificado a todos os drivers.

**Vantagem possível:** direcionar atualização/reversão de driver ou configuração específica, em vez de desligar dispositivos e serviços em massa. **Riscos:** overhead da captura, dados sensíveis nos traces e inferência de causalidade incorreta. **Medição:** mesma cena com spikes reproduzíveis, comparação por versão de driver e confirmação de que os picos desaparecem. Não alterar affinity/priority de interrupções automaticamente nesta etapa.

## 2. Tratar contenção de processos por sessão — prioridade média, após diagnóstico

**Mecanismo:** identificar processos concorrentes que consomem CPU/I/O durante o jogo; testar controlo pontual de QoS ou agendamento apenas nesses processos. Evitar a desativação global de Power Throttling da ação 81 como resposta universal. O Windows distingue QoS orientada a desempenho/eficiência; o suporte e a interpretação variam com versão e hardware. [Microsoft: Quality of Service](https://learn.microsoft.com/en-us/windows/win32/procthread/quality-of-service).

**Âmbito:** Windows com APIs suportadas, processos acessíveis e identificados. Perfis para CPUs híbridas ou X3D exigem laboratório próprio; não selecionar afinidades apenas pelo nome comercial.

**Vantagem possível:** reduzir competição real sem remover serviços permanentemente. **Riscos:** atrasar trabalho útil, prejudicar Discord/OBS/áudio e contrariar decisões do scheduler. **Medição:** CPU ready time, utilização por processo, FPS e percentis de frametime com e sem carga concorrente. Restaurar a política ao terminar a sessão. Não implementar serviço permanente ou launcher neste lote.

## 3. Perfis de apresentação por jogo — prioridade alta depois de HAGS/FSO corrigidos

**Mecanismo:** verificar API, modo de apresentação e fila de renderização; testar otimizações de jogos em janela e opções de baixa latência disponibilizadas pelo jogo/driver. Windows 11 disponibiliza otimizações para determinados jogos DX10/DX11 em janela. [Microsoft: otimizações em janela](https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11).

**Âmbito:** executável, versão do jogo, GPU/driver e API específicos; não inferir compatibilidade apenas por NVIDIA/AMD/Intel. **Vantagem possível:** menor espera de apresentação/filas em cenários suportados. **Riscos:** tearing, conflitos com captura/overlays, frame generation e preferências do utilizador. **Medição:** apresentação/frametimes e latência instrumentada, com FPS cap/VRR/V-Sync controlados. Preservar flags não geridas em `DirectXUserGlobalSettings` antes de qualquer implementação.

## 4. Validar energia sustentada por topologia — prioridade alta para o código deste lote

**Mecanismo:** usar a cópia isolada do plano como suporte de ensaios de core parking e, posteriormente, outras políticas de CPU justificadas. O plano original permanece disponível para recuperação.

**Âmbito:** os índices existem na plataforma e a API confirma leitura/escrita; isto não demonstra benefício para Intel híbrido, AMD ou X3D. **Vantagem possível:** reduzir transições que causem atraso num workload concreto. **Riscos:** maior consumo, temperatura e perda de boost sustentado. **Medição:** sequência A/B do protocolo, clocks/temperaturas e sessões longas. Não acrescentar CPU idle off, afinidade global ou políticas de boost agressivas sem esse ensaio.

## 5. Seleção de NIC e propriedades por driver — prioridade média, após rollback de rede

**Mecanismo:** selecionar a interface física utilizada pelo jogo, ler propriedades suportadas e testar interrupt moderation/EEE/offloads individualmente. Documentação de NIC descreve compromissos entre latência, CPU e throughput; não constitui benchmark de gaming. [Microsoft: tuning de NIC](https://learn.microsoft.com/en-us/windows-server/networking/technologies/network-subsystem/net-sub-performance-tuning-nics).

**Âmbito:** NIC, driver e tipo de ligação identificados; excluir VPN/adaptadores virtuais salvo finalidade explícita. **Vantagem possível:** menor espera local/jitter em casos específicos. **Riscos:** mais interrupções, perda de débito, perda de ligação e regressão sob carga. **Medição:** latência/perdas sob carga, CPU/DPC, throughput e estabilidade, com plano de recuperação local. Congestionamento no router ou no servidor exige diagnóstico separado.

## 6. Investigar cache/compilação antes de limpar — prioridade alta

**Mecanismo:** distinguir stutter por compilação de shaders de stutter por I/O, falta de memória ou driver. Preservar caches no percurso normal; limpeza apenas para corrupção/problema demonstrado. A cache de shaders evita trabalho de compilação repetido. [NVIDIA: Shader Cache](https://www.nvidia.com/content/Control-Panel-Help/vLatest/en-us/mergedProjects/3D%20Settings/Manage_3D_Settings_(reference).htm).

**Âmbito:** jogo e driver identificados; caminhos e regras variam por fabricante/API. **Vantagem possível:** evitar regressões introduzidas pelo próprio otimizador. **Riscos:** cache inválida pode precisar de reparação, e espaço em disco é finito. **Medição:** runs com caches aquecidas, eventos de compilação quando disponíveis e I/O correlacionado. Primeiro unificar a ação 24 e o botão do painel; não repetir a limpeza automaticamente após cada sessão.

## Critérios para evolução dos perfis

- **Balanced:** apenas ações migradas com rollback, pós-verificação e baixo impacto funcional demonstrado. Não usar este nome para o Apply legado atual.
- **Performance:** acrescentar mudanças condicionadas a hardware/carga e aos ensaios aprovados.
- **Extreme:** experiências explicitamente selecionadas, com risco, objetivo e reversão documentados. Rejeitar automaticamente ações cujos requisitos não possam ser determinados.

Segurança/anti-cheat é um requisito de compatibilidade, não um interruptor «mais FPS». A seleção precisa de estado efetivo e requisitos atuais do jogo; nenhum perfil aqui apresentado promete essa compatibilidade. Existem agora três perfis limitados de desenvolvimento, descritos em [PERFIS.md](PERFIS.md). As propostas acima continuam dependentes de integração e medições; não constituem ganhos demonstrados.
