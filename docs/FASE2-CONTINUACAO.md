# Fase 2 ? continua??o em 21 de outubro de 2026

## Bloco 2: baseline por valor e Undo sem defaults

Preservados os quatro commits anteriores na branch `dev/phase2-execution-power-safety`.

O di?rio `mutation_state.json` guarda m?quina, utilizador, vista do registo, exist?ncia, tipo e conte?do original. Guarda inten??o antes da escrita; verifica estado ap?s escrita e revers?o. Um lock exclusivo protege opera??es simult?neas. Valores j? conformes n?o passam a pertencer ao programa. Apply repetido conserva a baseline. Valores com altera??es externas s?o preservados e comunicados como conflito. As chaves vazias ficam no registo: n?o existe remo??o recursiva de ?rvores potencialmente partilhadas.

O Undo principal e o painel utilizam a mesma implementa??o. Foram retiradas as importa??es autom?ticas de chaves inteiras, remo??es recursivas de chaves e reposi??es arbitr?rias de registo, servi?os, rede, BCD, armazenamento e tarefas. Backups legados ficam intactos; a informa??o dispon?vel n?o prova quais os valores efetivamente modificados. Uma nova execu??o Apply ? bloqueada quando existem esses backups. N?o existe migra??o autom?tica que invente informa??o ausente.

Primeira integra??o: a??es 9, 13, 17 e 79. As restantes a??es conservam as fun??es e os lugares no menu, mas o dispatcher impede a??es cuja revers?o ainda n?o foi migrada. Esta barreira tempor?ria evita que a remo??o do Undo inseguro deixe novas altera??es sem revers?o. Energia mant?m a implementa??o anterior.

Testes: 63 passaram (44 anteriores e 19 novos). Apenas fun??es carregadas por AST, registo simulado e ficheiros de teste. Nenhuma altera??o ao Windows de desenvolvimento. Cobertura: Apply repetido, Undo repetido, aus?ncia, tipos, strings expans?veis literais, bin?rios, multi-strings, QWORD, falhas antes/depois da escrita, backup falhado, conflitos externos, di?rio corrupto, m?quina/utilizador errados, concorr?ncia e integra??o Game DVR.

N?o foram medidos FPS nem lat?ncia. Ainda n?o ? uma vers?o validada para clientes.

Refer?ncias de implementa??o: [tipos de valores do registo](https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registrykey.getvaluekind), [implementa??o Microsoft de RegistryKey](https://source.dot.net/Microsoft.Win32.Registry/Microsoft/Win32/RegistryKey.cs.html).
