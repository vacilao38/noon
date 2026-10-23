# Noon

Estúdio pessoal para sintetizar timbres, efeitos e pequenas trilhas sonoras. Primeira versão funcional da proposta, 0.1.0, para Windows e Android em celular/tablet. Código e documentos em UTF-8.

## Abrir

Pacotes em `dist/`: extraia o ZIP Windows inteiro e abra `noon.exe`. No Android, use o APK correspondente ao aparelho; ARM64 atende à maioria dos aparelhos atuais. Os APKs são de uso pessoal, assinados com a chave de desenvolvimento, sem publicação na Play Store. Android mínimo 7 / API 24. Windows 10/11 x64.

## Experimentar

1. Toque em **Ouvir** para renderizar o projeto de exemplo.
2. Selecione uma camada e abra **Timbre**. Escolha um instrumento, ajuste entrada/cauda, brilho, panorama e efeitos.
3. Em **Compor**, escolha acordes e edite a duração/intensidade das seções.
4. Em **Script**, edite a mesma composição como texto. **Copiar para LLM** inclui instruções e projeto; cole o resultado da sua LLM e use **Aplicar script**.
5. Exporte **WAV** para ouvir em outros programas ou **.noon** para continuar editando, transportar ou fazer backup.

O projeto atual e o rascunho são salvos localmente. Para alternar entre projetos, exporte e abra arquivos .noon. Não existe sincronização entre aparelhos. Desinstalar o Android remove os dados privados; mantenha backups exportados.

## O que funciona

- Até 8 camadas, 7 fontes sintetizadas e 6 modos de execução: acordes, baixo, arpejo, pulso, melodia e efeito.
- Piano elétrico e sino por síntese, osciladores seno/triângulo/serra/quadrada e ruído determinístico.
- Filtro passa-baixas, saturação, eco e ambiente curto; efeitos são calculados em amostras reais.
- Progressões genéricas e acordes personalizados, seções com duração e energia.
- Teclas para ouvir uma nota da camada selecionada; não gravam no arranjo e não oferecem polifonia ao vivo.
- Script e controles sincronizados, validação com linha de erro, importação transacional e até 40 estados para desfazer/refazer.
- Salvamento com recuperação de escrita interrompida. Rascunho inválido não substitui o último projeto aplicado.
- Exportação WAV estéreo PCM 16 bits / 44,1 kHz. Prévia a 22,05 kHz. Quatro segundos adicionais preservam caudas de efeitos.

## Limites desta versão

Até 16 compassos, 60 segundos de arranjo, 8 seções, 16 acordes e 64 notas por sequência. Compasso 4/4. Os padrões reiniciam a cada compasso; as seções alteram intensidade. Referências de músicas são descritas manualmente por acordes e seções.

Ainda não inclui importação de áudio/samples, gravação, clips livres na timeline, MIDI, VST, automação, reconhecimento de músicas, motor em tempo real ou LLM conectada. O teclado usa renderização e reprodução de uma nota por vez; não é um instrumento de baixa latência.

## Exemplos e documentação

[Projeto de trilha](artifacts/Entre-o-sol-e-o-silencio.noon) · [Trilha WAV](artifacts/Entre-o-sol-e-o-silencio.wav) · [Efeito .noon](artifacts/Sinal.noon) · [Efeito WAV](artifacts/Sinal.wav)

[Linguagem Noon Script](docs/NOON-SCRIPT.md) · [Decisões, pesquisa e evolução](docs/DECISIONS.md) · [Validação](artifacts/VALIDATION.md)

Identidade Clustter cores: grafite e âmbar, Lato nos controles e Bitcount na marca. Fontes OFL e seus avisos em `assets/fonts/`. O código dos aplicativos existentes e o catálogo público foram preservados.

## Desenvolvimento

Flutter 3.44.1, Dart 3.12.1, Java 21 e toolchains Android/Windows. Dependências fixadas em `pubspec.lock`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release --split-per-abi
flutter test integration_test/native_audio_test.dart -d windows
dart run tool/render_examples.dart
```

Para capturas em Windows: configure `FLUTTER_ROOT`, defina `NOON_CAPTURE=1` e execute `flutter test test/layout_test.dart`. As capturas são renderizações do Flutter, não de um Android físico.

Estrutura: `model.dart` documento e parser; `synth.dart` motor DSP/WAV; `controller.dart` histórico, transações e estado; `platform_services.dart` arquivos e player; `workspace.dart` interface adaptativa; `design.dart` tokens e marca; bridge Kotlin para arquivos Android.

## Distribuição pública

[Noon na Clustter cores](https://vacilao38.github.io/clustter-cores-downloads/#noon) · [Instaladores e hashes](https://github.com/vacilao38/clustter-cores-downloads/releases/tag/noon-v0.1.0). Publicados em 23/10/2026 para Windows e Android.
