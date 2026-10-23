# Noon · produto e decisões

Projeto iniciado em 23/10/2026. Arquivos de texto em UTF-8.

## Intenção e primeira entrega

Um estúdio para descobrir timbres, criar efeitos e compor pequenas trilhas sem precisar começar por teoria musical ou programação. O documento musical é um script declarativo próprio; a interface é uma maneira de editar esse documento. A primeira versão implementa uma fatia utilizável dessa proposta. Não equivale a uma DAW completa.

A jornada é abrir o exemplo → ouvir → selecionar camada → alterar timbre/efeitos → escolher harmonia/seções → exportar WAV ou .noon. Código e controles compartilham NoonProject. O rascunho textual só altera o projeto quando passa na validação. Importação também é transacional. Alterações visuais podem ser desfeitas; rascunhos ainda não aplicados são preservados separadamente.

## Família visual

Lake fornece a referência local: grafite, superfícies discretas, Lato nos controles e Bitcount na marca. Noon adota âmbar e cores suaves por camada. A marca original combina um arco de sol, horizonte e barras de som. A interface usa a mesma linguagem visual em janelas pequenas e grandes. No desktop há navegação e camadas laterais; acima de 1320 pixels lógicos há também o inspetor à direita. Tablet e celular usam navegação inferior e painéis roláveis. Os tamanhos seguem a janela, não a identificação do dispositivo.

## Stack e fronteiras

Flutter 3.44.1 / Dart 3.12.1 são a toolchain já instalada e usada pelo Lake e Folk. Compartilhar UI, linguagem e renderização entre Android e Windows reduz o número de implementações a manter. Kotlin/Compose exigiria uma segunda UI Windows; React Native acrescentaria outra base sem oferecer uma integração de áudio já existente neste workspace. Isso é uma decisão de manutenção, sem alegação de superioridade em latência.

O motor é Dart puro e produz PCM estéreo em isolate. O player nativo audioplayers apenas reproduz WAV temporário; não sintetiza nem mistura em tempo real. Prévia em 22050 Hz e exportação em 44100 Hz, ambas PCM 16 bits. As caudas têm quatro segundos adicionais. Limitador por atenuação global evita estouro da soma; o volume master é aplicado depois dessa atenuação.

O player usa ReleaseMode.release. Uma reprodução seguida de outra, substituindo o WAV no mesmo caminho, revelou que ReleaseMode.stop no backend Windows mantém a fonte decodificada e o arquivo aberto. O teste nativo reproduziu o erro de arquivo em uso; a liberação é necessária antes da nova gravação. A integração testa duas durações diferentes e compara a segunda duração informada pelo backend, além de aguardar o fim das duas reproduções.

Filtro passa-baixas de um polo, saturação atan, eco com realimentação limitada e ambiente curto de seis reflexões. Os osciladores serra/quadrada usam somas harmônicas finitas. Piano elétrico e sino são aproximações por síntese; não são instrumentos amostrados. Sem medição de latência nem pretensão de áudio profissional em tempo real.

Persistência: uma área de trabalho local com schema 1, fonte canônica e rascunho. Escritas serializadas e debounce; Windows usa temporário e backup durante substituição; Android usa AtomicFile. Falhas são exibidas. Arquivo local corrompido suspende gravações na sessão para preservar o original. .noon é a forma portátil de backup e de alternar entre projetos. Não há nuvem nem envio de conteúdo para LLMs.

Android usa ACTION_OPEN_DOCUMENT/ACTION_CREATE_DOCUMENT e UTF-8 no bridge Kotlin; Windows usa file_selector. A documentação de file_selector informa que escolher destino de salvamento não é suportado no Android, razão para usar um bridge nativo nessa plataforma. O app não solicita armazenamento amplo, microfone ou rede no manifesto principal.

## Fontes consultadas

Observações feitas em documentação oficial, sem uso prático ou benchmark dos concorrentes:

- [Sonic Pi](https://sonic-pi.net/) e [sintetizadores no tutorial](https://sonic-pi.net/tutorial-02.html): síntese musical acessível por código já existe. Não apresentar linguagem musical como invenção inédita; explorar a edição visual sincronizada.
- [Strudel: primeiros passos](https://strudel.cc/workshop/getting-started/): padrões, síntese e efeitos com código em uma experiência orientada à experimentação. Inspirou o ciclo curto editar → ouvir, sem copiar sintaxe ou exemplos musicais.
- [audioplayers 6.8.1](https://pub.dev/packages/audioplayers) e [DeviceFileSource](https://pub.dev/documentation/audioplayers/latest/audioplayers/DeviceFileSource-class.html): Android e Windows suportados; reprodução por arquivo local. Não presumir que o player seja um motor de síntese de baixa latência.
- [file_selector 1.1.0](https://pub.dev/packages/file_selector): seleção nativa e diferenças de capacidade entre plataformas.
- [Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files): arquivos selecionados pelo usuário, sem permissão ampla de armazenamento.
- [Flutter compute](https://api.flutter.dev/flutter/foundation/compute.html): processamento de áudio fora da thread de interface nos alvos nativos.
- [Distribuição Windows no Flutter](https://docs.flutter.dev/platform-integration/windows/building#building-your-own-zip-file-for-windows): ZIP com executável, DLLs, dados e runtime Visual C++ junto do app; o empacotador inclui os três DLLs de runtime recomendados a partir do redist x64 do Visual Studio instalado.

## Limites e próximos passos

Limites explícitos da versão: 8 camadas, 8 seções, 16 compassos, 60 segundos de arranjo mais cauda, 64 notas por sequência, 16 acordes e script de 64 KB. Compasso 4/4. Os padrões e melodias reiniciam em cada compasso; as progressões avançam a cada compasso. Energia de seção controla intensidade, sem mudança automática de instrumentação.

Referências de músicas são descritas manualmente por acordes e seções. Não há reconhecimento harmônico, catálogo de canções, reprodução de arranjos protegidos ou promessa de transcrição. Guias são progressões genéricas.

Evolução planejada: clips com início/duração editáveis; gravação de notas e MIDI; importação de samples; envelopes/automação; motor nativo em tempo real; roteamento por grafo; guias de referência mais ricos; ponte de LLM com prévia de alterações e autorização explícita. Não há botões simulando essas integrações nesta versão.

## Critérios de aceitação

- Um mesmo .noon recompila os mesmos valores e PCM determinístico.
- Erros têm linha quando possível e não alteram o projeto aplicado.
- Mutar uma camada gera silêncio; panorama e master alteram os canais/amplitude.
- A4 produz 440 Hz; exportação usa cabeçalho RIFF/PCM válido.
- Efeitos produzem diferenças em amostras reais.
- Rascunho inválido sobrevive a salvar/reabrir; importação inválida preserva o projeto.
- Layouts celular, paisagem, tablet e desktop são verificados, incluindo texto 200%.
- Compilação e integração são reportadas separadamente de testes com fakes.
