# SkyOptimizer — desempenho e manutenção

Branch `dev/performance-rebuild`. Preserva os 57 commits anteriores e mantém main intacta.

## Utilização

Abrir `Executar-SkyOptimizer.bat` apresenta o menu: desempenho, painel, Undo, limpeza, reparação e auditoria.

```powershell
.\SkyOptimizer.ps1 -DryRun
.\SkyOptimizer.ps1 -Apply
.\SkyOptimizer.ps1 -DeployPanel
.\SkyOptimizer.ps1 -Clean
.\SkyOptimizer.ps1 -CleanShaders
.\SkyOptimizer.ps1 -Undo
```

`-Apply` usa Performance e cria automaticamente a pasta do cliente com relatório e atalhos funcionais. A aplicação de manutenção fica no armazenamento protegido para continuar disponível depois de apagar a pasta inicial. `-Clean` limpa temporários antigos; `-CleanShaders` é um diagnóstico separado, com confirmação e possibilidade de recompilação/stuttering.

## Desempenho

Performance acrescenta energia, background UWP, Delivery Optimization e ajustes NIC à seleção MAX anterior. Num contexto Windows 11 Pro, Edge, AC e sem indicadores de gestão são selecionados 15 candidatos (16 com Wi-Fi físico confirmado). O driver e cada recurso são verificados antes da escrita; numa VM vários podem ser incompatíveis.

O plano apresenta custos antes da confirmação: consumo/temperatura, notificações/sincronização e possíveis regressões CPU/rede. Configuração verificada não demonstra ganho de FPS. Não foram executados benchmarks físicos nesta entrega.

Os 90 IDs históricos e três novos IDs continuam visíveis no plano, com decisões individuais. São agora 29 elegíveis; o código legado bloqueado não é executado por um bypass. `-Apply -Profile MAX` conserva a seleção restrita anterior. Laboratory continua a permitir experiências por ID e Undo:

```powershell
.\SkyOptimizer.ps1 -Apply -Profile Laboratory -ExperimentalActions "3,74"
```

## Recuperação e resultados

Baselines por recurso, verificação, conflitos externos, locks e relatórios por RunId foram conservados. O relatório também fica no run se o painel falhar. Undo não inventa valores de fábrica nem apaga backups em conflito. `latest_run.json` identifica a tentativa atual. Exit codes: 0 configuração verificada; 1 falha; 2 execução/reversão incompleta. Nenhum certifica desempenho.

O painel abre as Definições de Segurança e Localização com nomes claros; não apresenta esses atalhos como alternâncias automáticas. Impressora/Bluetooth mantêm a recuperação por baseline. Não existe remoção automática de backups nem promessa de desinstalação total.

## Documentação

- [Novos ajustes de CPU e Wi-Fi](docs/POWER-PERFORMANCE.md).
- [Mudanças, limites e estudo breve de evolução](docs/PERFORMANCE-REBUILD.md).
- [Estado histórico das 90 ações e seleção contextual acrescentada](docs/ACOES-ESTADO.json).
- [Benchmarking](docs/BENCHMARKS.md).
- [README anterior preservado](docs/README-FASE5G-HISTORICO.md).

Os documentos Fase 2–5G e `TESTES-RESULTADO.json` descrevem versões anteriores. As contagens e hashes históricos não certificam esta versão. O escopo `integration/evidence-performance.json` cobre o alias antigo, não todos os recursos do novo perfil: ampliar a captura independente antes de ensaios Apply/Undo em VM.
