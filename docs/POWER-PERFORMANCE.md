# CPU e Wi-Fi: três ações novas

Estas ações entram no perfil Performance e podem ser pedidas por ID em Laboratory. Reutilizam a cópia isolada do plano, a baseline persistida antes das alterações e o Undo que reativa o plano original. Não alteram BIOS, tensão, limite térmico ou a política DC/bateria.

| ID | Alteração AC | Efeito procurado | Limite |
|---|---|---|---|
| 91 | CPU Energy Performance Preference (`PERFEPP`) = 0 | Favorecer desempenho sobre poupança em sistemas autónomos CPPC/HWP | Depende de firmware e controlo autónomo; configurar não prova aumento dos clocks |
| 92 | Máximo do processador = 100%; `PERFBOOSTMODE` = 2 | Retirar um teto de frequência configurado abaixo de 100% e permitir boost agressivo quando suportado | Não é overclock nem supera limites de potência/temperatura; maior calor pode piorar desempenho sustentado |
| 93 | Wi-Fi Power Saving Mode = Maximum Performance | Evitar a política de poupança do rádio quando ligado à corrente | Exige adaptador físico NDIS wireless/native 802.11 e setting disponível; driver/OEM pode condicionar o efeito |

O motor lê todos os settings de cada ação antes de escrever, recusa AC desconhecida, confirma os índices depois e verifica que DC não mudou. Uma ação já configurada é `AlreadyCompliant`. Uma definição ausente é `Incompatible`, sem inventar um valor de registo alternativo. Ação 92 não escreve o teto de CPU se o contrato de boost não puder ser lido.

Windows 11 Pro + Edge + AC e sem indicadores de gestão passa de 13 para **15 candidatos**, ou **16 com Wi-Fi físico confirmado**. A aplicação ainda pode recusar settings que o Windows não disponibilize. Home também admite os novos ajustes de energia. Sistemas geridos e bateria conservam as exclusões anteriores. Laboratory resolve automaticamente a dependência 1:

```powershell
.\SkyOptimizer.ps1 -DryRun
.\SkyOptimizer.ps1 -Apply
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "91,92"
.\SkyOptimizer.ps1 -Undo
```

O catálogo passa a **93 ações / 29 elegíveis**. Os 58 IDs antigos continuam bloqueados: adicionar estas ações não valida os corpos legados. Esses bloqueios misturam três situações: migração de baseline/recuperação por concluir; suporte/efeito dependente de hardware ou workload; e preferências de interface/privacidade sem benefício de desempenho demonstrado. Não representam 58 otimizações comprovadas que foram simplesmente desligadas.

## Fontes primárias

- [Microsoft: PerfEnergyPreference](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-perfenergypreference).
- [Microsoft: PERFBOOSTMODE e diferenças P-state/CPPC](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-perfboostmode).
- [Microsoft: Maximum processor performance state](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-maxperformance).
- [Intel: política de energia wireless](https://www.intel.com/content/www/us/en/support/articles/000046272.html). A caixa de suspensão/hibernação do Gestor de Dispositivos não controla essa política e fica preservada.
- [Microsoft: desempenho máximo wireless em resolução de problemas de ligação](https://support.microsoft.com/en-gb/windows/experience/connectivity-networking/fix-wi-fi-connection-issues-in-windows).

## Verificação e interpretação

Testes cobrem settings exatos, aplicação repetida, leitura prévia das duas propriedades de boost, preservação de DC e do plano original, Undo, deteção de Wi-Fi e recusa sem AC. São modelos do Windows em memória, não benchmarks de hardware. Não se anuncia ganho de FPS medido. Comparar antes/depois com os mesmos jogos e verificar clocks, temperatura e frametimes; validar separadamente em portátil e desktop.

O escopo histórico `integration/evidence-performance.json` não cobre estes índices. Capturar o plano original/ativo e os valores AC/DC dos quatro settings antes de aplicar em VM/hardware. Comparar os valores e o funcionamento após Apply, repetição, reinício e Undo. O plano original deve permanecer igual e ser reativado no Undo; a cópia pode ser conservada com estado incompleto por proteção contra edições externas.
