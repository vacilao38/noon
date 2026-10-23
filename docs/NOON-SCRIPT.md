# Noon Script v1

Linguagem declarativa em UTF-8. Cada comando ocupa uma linha. Linhas vazias e comentários iniciados com `//` são ignorados. A interface reescreve o script canônico ao aplicar alterações; comentários e espaçamento não fazem parte do documento musical.

```text
noon 1
projeto "Meu primeiro som"
tempo 96
volume 0.75
harmonia Am F C G

secao "Entrada" 2 0.55
secao "Corpo" 4 0.9
secao "Saída" 2 0.6

camada "Vidro" arp
  onda sino
  ganho 0.35
  pan 0.2
  oitava 5
  ataque 0.01
  release 0.4
  filtro 6000
  drive 0
  reverb 0.3
  eco 0.2
  mudo nao
  notas C4:1 E4:1 G4:1 E4:1
fim
```

O cabeçalho `noon 1`, ao menos uma seção e uma camada são obrigatórios. Comandos e propriedades desconhecidos, duplicados ou fora dos limites são rejeitados. O parser nunca executa código arbitrário e não lê arquivos ou rede.

| Comando | Valores |
| --- | --- |
| `projeto` | Nome JSON entre aspas, 1–80 caracteres |
| `tempo` | 60–180 BPM |
| `volume` | 0–1 |
| `harmonia` | 1–16 acordes, separados por espaço |
| `secao` | Nome entre aspas, compassos inteiros, energia 0–1 |
| `camada` | Nome entre aspas e modo |
| `fim` | Encerra a camada |

Acordes usam notas A–G, com `#` ou `b` opcionais. Sufixos aceitos: nenhum (maior), `m`, `7`, `m7`, `maj7`. Exemplos: `C`, `Am`, `Bbmaj7`, `F#7`. Um acorde por compasso, repetindo a lista. Não há transposição implícita.

| Modo | Comportamento por compasso |
| --- | --- |
| `pad` | Notas simultâneas do acorde, sustentadas por 3,6 tempos |
| `baixo` | Fundamental nos tempos 1 e 3 |
| `arp` | Oito notas do acorde, a cada meio tempo |
| `pulso` | Quatro ataques com queda de frequência e amplitude |
| `melodia` | Sequência de `notas` repete/reinicia em cada compasso |
| `fx` | Nota com subida de duas oitavas, ou textura de ruído |

| Propriedade da camada | Valores e unidade |
| --- | --- |
| `onda` | `seno`, `triangulo`, `serra`, `quadrada`, `piano`, `sino`, `ruido` |
| `ganho` | 0–1 |
| `pan` | -1 esquerda, 0 centro, 1 direita |
| `oitava` | Inteiro 1–6; usado por modos harmônicos |
| `ataque` | 0.002–2 segundos |
| `release` | 0.02–3 segundos |
| `filtro` | 100–16000 Hz; limitado à banda disponível na prévia |
| `drive`, `reverb`, `eco` | 0–1 |
| `mudo` | `sim` ou `nao` |
| `notas` | Até 64 eventos `nota:tempos`, exemplo `C4:1 E4:0.5 R:0.5 G4:2` |

Notas explícitas vão de C1 a B7 e permitem acidentes. `R` é pausa. Duração entre 0.25 e 16 tempos. Eventos que ultrapassam o compasso são cortados; a sequência recomeça no compasso seguinte. `oitava` não transpõe notas explícitas. `notas` é usada no modo `melodia`; permanece preservada nos outros modos.

Somente propriedades globais precisam vir fora de um bloco; seções e camadas podem ser intercaladas. Propriedades omitidas recebem os padrões de `Layer` em `lib/model.dart`. Use exportação/cópia canônica como referência completa.

Até 8 camadas e 8 seções, soma de até 16 compassos e duração de até 60 segundos, mais quatro segundos de cauda. Energia da seção multiplica a intensidade das notas daquela seção. Todas as camadas acompanham as mesmas seções. O arquivo não contém samples externos.

## Usar com uma LLM

Em Script, **Copiar para LLM** copia o projeto e um resumo do contrato. Cole na LLM de sua escolha, peça uma alteração concreta e depois cole o resultado no Noon. **Aplicar script** valida tudo antes de substituir o documento. Não há integração de rede ou chave de API no app. Erros devem ser corrigidos no texto; você pode descartar o rascunho explicitamente ou desfazer uma aplicação válida.
