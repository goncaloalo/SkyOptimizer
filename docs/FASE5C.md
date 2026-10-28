# Fase 5C — implementação orientada pela investigação

Base: `ab55736`, branch `dev/phase2-execution-power-safety`. Os cinco documentos de `investigacao-2026-10-28` foram lidos integralmente antes de editar ficheiros. Eram os únicos ficheiros não versionados; ficam preservados sem alterações. Consultadas as entregas 2–5A. Aplicam-se as skills lean-build e surgical-patch já usadas na fase anterior.

## Plano priorizado e dependências

1. **P1 — diagnóstico e medições offline:** impedir conversão de GPU busy/duração de trabalho em FPS; explicitar semântica do campo; contar incidentes consecutivos e tempo excedente. Importar amostras temporais de processos/memória/I/O e produzir observações com dados ausentes explícitos. Não recolher no host, não inferir causalidade nem latência física.
2. **P1 — contratos e debloat:** conter captura sem contrato funcional Win11; impedir execução dos grupos 48/71; substituir corpo destrutivo de 49 por recusa e oferecer inventário/preview da conta atual. Dependências e componentes desconhecidos nunca autorizam remoção. Undo de alterações anteriores continua disponível.
3. **P1 — perfis:** seleção exata Laboratory, com dependências visíveis e sem herdar Performance. Conservar aliases e menus existentes. Recomendações por diagnóstico são hipóteses para escolha do operador, não mutações automáticas.
4. **P1 — entrega:** regressões, catálogo e protocolos atualizados; commits incrementais; distinguir observação, implementação e validação real.

VM, recuperação AppX/dados, leitores funcionais de captura, drivers, sensores e testes físicos continuam gates posteriores. Não serão criados adapters de remoção ou perfis por fabricante sem esse suporte. CI por pares/blocos será posterior à validação do formato de captura; não se apresentará estatística descritiva como significância.

## Decisões sobre a investigação

As categorias A–E são avaliações da investigação, não benchmarks SkyOptimizer. A presença de um processo/AppX não demonstra carga dispensável. A ausência de carga observada também não autoriza removê-lo. GPU busy não mede cadência. AllowGameDVR não é contrato funcional Win11; não será substituído por outra flag interna adivinhada. Não é possível separar 48/71 em novas ações automaticamente aprovadas apenas reutilizando o writer de serviços.
