import 'dart:convert';
import 'dart:math' as math;

const waveNames = <String, String>{
  'seno': 'Seno · macio',
  'triangulo': 'Triângulo · aveludado',
  'serra': 'Serra · brilhante',
  'quadrada': 'Quadrada · digital',
  'piano': 'Piano elétrico',
  'sino': 'Sino · metálico',
  'ruido': 'Ruído · textura',
};
const modeNames = <String, String>{
  'pad': 'Acordes sustentados',
  'baixo': 'Baixo',
  'arp': 'Arpejo',
  'pulso': 'Pulso percussivo',
  'melodia': 'Sequência de notas',
  'fx': 'Efeito sonoro',
};

class Section {
  final String name;
  final int bars;
  final double energy;
  const Section(this.name, this.bars, this.energy);
}

class Layer {
  final String name, mode, wave, notes;
  final double gain, pan, attack, release, cutoff, drive, reverb, echo;
  final int octave;
  final bool muted;
  const Layer({
    this.name = 'Nova camada',
    this.mode = 'pad',
    this.wave = 'seno',
    this.notes = 'C4:1 E4:1 G4:1 E4:1',
    this.gain = .45,
    this.pan = 0,
    this.attack = .04,
    this.release = .35,
    this.cutoff = 6000,
    this.drive = 0,
    this.reverb = .2,
    this.echo = 0,
    this.octave = 4,
    this.muted = false,
  });
  Layer copyWith({
    String? name,
    String? mode,
    String? wave,
    String? notes,
    double? gain,
    double? pan,
    double? attack,
    double? release,
    double? cutoff,
    double? drive,
    double? reverb,
    double? echo,
    int? octave,
    bool? muted,
  }) => Layer(
    name: name ?? this.name,
    mode: mode ?? this.mode,
    wave: wave ?? this.wave,
    notes: notes ?? this.notes,
    gain: gain ?? this.gain,
    pan: pan ?? this.pan,
    attack: attack ?? this.attack,
    release: release ?? this.release,
    cutoff: cutoff ?? this.cutoff,
    drive: drive ?? this.drive,
    reverb: reverb ?? this.reverb,
    echo: echo ?? this.echo,
    octave: octave ?? this.octave,
    muted: muted ?? this.muted,
  );
}

class NoonProject {
  final String name;
  final double bpm, volume;
  final List<String> chords;
  final List<Section> sections;
  final List<Layer> layers;
  NoonProject({
    required this.name,
    this.bpm = 96,
    this.volume = .75,
    required List<String> chords,
    required List<Section> sections,
    required List<Layer> layers,
  }) : chords = List.unmodifiable(chords),
       sections = List.unmodifiable(sections),
       layers = List.unmodifiable(layers);
  int get bars => sections.fold(0, (sum, s) => sum + s.bars);
  double get seconds => bars * 4 * 60 / bpm;
  NoonProject copyWith({
    String? name,
    double? bpm,
    double? volume,
    List<String>? chords,
    List<Section>? sections,
    List<Layer>? layers,
  }) => NoonProject(
    name: name ?? this.name,
    bpm: bpm ?? this.bpm,
    volume: volume ?? this.volume,
    chords: chords ?? this.chords,
    sections: sections ?? this.sections,
    layers: layers ?? this.layers,
  );

  String encode() {
    final s = StringBuffer(
      'noon 1\nprojeto ${jsonEncode(name)}\ntempo ${_n(bpm)}\nvolume ${_n(volume)}\nharmonia ${chords.join(' ')}\n\n',
    );
    for (final section in sections) {
      s.writeln(
        'secao ${jsonEncode(section.name)} ${section.bars} ${_n(section.energy)}',
      );
    }
    for (final l in layers) {
      s.writeln('\ncamada ${jsonEncode(l.name)} ${l.mode}');
      for (final e in <String, Object>{
        'onda': l.wave,
        'ganho': _n(l.gain),
        'pan': _n(l.pan),
        'oitava': l.octave,
        'ataque': _n(l.attack),
        'release': _n(l.release),
        'filtro': _n(l.cutoff),
        'drive': _n(l.drive),
        'reverb': _n(l.reverb),
        'eco': _n(l.echo),
        'mudo': l.muted ? 'sim' : 'nao',
        'notas': l.notes,
      }.entries) {
        s.writeln('  ${e.key} ${e.value}');
      }
      s.writeln('fim');
    }
    return s.toString();
  }

  static NoonProject demo() => NoonProject(
    name: 'Entre o sol e o silêncio',
    chords: ['Am', 'F', 'C', 'G'],
    sections: const [
      Section('Entrada', 2, .55),
      Section('Desenvolvimento', 4, .9),
      Section('Respiro', 2, .6),
    ],
    layers: const [
      Layer(
        name: 'Luz difusa',
        wave: 'triangulo',
        gain: .32,
        attack: .28,
        release: .8,
        reverb: .48,
        cutoff: 2800,
        pan: -.15,
      ),
      Layer(
        name: 'Gotas de vidro',
        mode: 'arp',
        wave: 'sino',
        gain: .24,
        octave: 5,
        reverb: .3,
        echo: .28,
        pan: .3,
      ),
      Layer(
        name: 'Chão quente',
        mode: 'baixo',
        gain: .42,
        octave: 2,
        reverb: .05,
        cutoff: 800,
      ),
      Layer(
        name: 'Batimento',
        mode: 'pulso',
        gain: .28,
        octave: 2,
        attack: .004,
        release: .12,
        reverb: .08,
      ),
    ],
  );
}

String _n(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();

class ScriptError implements Exception {
  final int line;
  final String message;
  const ScriptError(this.line, this.message);
  @override
  String toString() => line > 0 ? 'Linha $line: $message' : message;
}

/// A bounded declarative language. No eval, file access or executable expressions.
NoonProject parseNoon(String source) {
  if (utf8.encode(source).length > 65536) {
    throw const ScriptError(0, 'O script excede 64 KB.');
  }
  final lines = const LineSplitter().convert(source.replaceFirst('\uFEFF', ''));
  String name = 'Sem título';
  double bpm = 96, volume = .75;
  List<String> chords = ['Am', 'F', 'C', 'G'];
  final sections = <Section>[];
  final layers = <Layer>[];
  final globals = <String>{};
  final properties = <String>{};
  Layer? layer;
  bool header = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('//')) continue;
    Never fail(String message) => throw ScriptError(i + 1, message);
    if (!header) {
      if (line != 'noon 1') {
        fail('Comece com noon 1. Versões diferentes não são suportadas.');
      }
      header = true;
      continue;
    }
    final split = line.indexOf(' ');
    final key = split < 0 ? line : line.substring(0, split);
    final value = split < 0 ? '' : line.substring(split + 1).trim();
    double number(double min, double max) {
      final n = double.tryParse(value);
      if (n == null || !n.isFinite || n < min || n > max) {
        fail('$key deve estar entre $min e $max.');
      }
      return n;
    }

    if (layer != null) {
      if (!properties.add(key)) fail('Propriedade $key repetida.');
      switch (key) {
        case 'fim':
          if (value.isNotEmpty) fail('Use apenas fim.');
          layers.add(layer);
          layer = null;
        case 'onda':
          if (!waveNames.containsKey(value)) fail('Onda desconhecida: $value.');
          layer = layer.copyWith(wave: value);
        case 'ganho':
          layer = layer.copyWith(gain: number(0, 1));
        case 'pan':
          layer = layer.copyWith(pan: number(-1, 1));
        case 'oitava':
          final n = number(1, 6);
          if (n != n.roundToDouble()) fail('A oitava precisa ser inteira.');
          layer = layer.copyWith(octave: n.toInt());
        case 'ataque':
          layer = layer.copyWith(attack: number(.002, 2));
        case 'release':
          layer = layer.copyWith(release: number(.02, 3));
        case 'filtro':
          layer = layer.copyWith(cutoff: number(100, 16000));
        case 'drive':
          layer = layer.copyWith(drive: number(0, 1));
        case 'reverb':
          layer = layer.copyWith(reverb: number(0, 1));
        case 'eco':
          layer = layer.copyWith(echo: number(0, 1));
        case 'mudo':
          if (value != 'sim' && value != 'nao') {
            fail('Use mudo sim ou mudo nao.');
          }
          layer = layer.copyWith(muted: value == 'sim');
        case 'notas':
          try {
            parseNotes(value);
          } on FormatException catch (e) {
            fail(e.message);
          }
          layer = layer.copyWith(notes: value);
        default:
          fail('Propriedade desconhecida: $key.');
      }
      continue;
    }
    if (key != 'secao' && key != 'camada' && !globals.add(key)) {
      fail('Comando $key repetido.');
    }
    switch (key) {
      case 'projeto':
        try {
          name = jsonDecode(value) as String;
        } catch (_) {
          fail('Use projeto "Nome do projeto".');
        }
        if (name.trim().isEmpty || name.length > 80 || name.contains('\n')) {
          fail('Nome deve ter de 1 a 80 caracteres em uma linha.');
        }
      case 'tempo':
        bpm = number(60, 180);
      case 'volume':
        volume = number(0, 1);
      case 'harmonia':
        chords = value.split(RegExp(r'\s+'));
        if (chords.isEmpty || chords.length > 16) {
          fail('Use de 1 a 16 acordes.');
        }
        for (final chord in chords) {
          try {
            chordMidi(chord, 4);
          } on FormatException catch (e) {
            fail(e.message);
          }
        }
      case 'secao':
        final match = RegExp(
          r'^("(?:[^"\\]|\\.)*")\s+(\d+)\s+([+\-\d.eE]+)$',
        ).firstMatch(value);
        if (match == null) fail('Use secao "Nome" compassos energia.');
        final label = jsonDecode(match.group(1)!) as String;
        final bars = int.parse(match.group(2)!);
        final energy = double.tryParse(match.group(3)!);
        if (label.isEmpty ||
            label.length > 40 ||
            label.contains('\n') ||
            bars < 1 ||
            bars > 16 ||
            energy == null ||
            !energy.isFinite ||
            energy < 0 ||
            energy > 1) {
          fail('Seção: nome até 40 caracteres, 1–16 compassos, energia 0–1.');
        }
        sections.add(Section(label, bars, energy));
        if (sections.length > 8) fail('Limite de 8 seções.');
      case 'camada':
        final match = RegExp(
          r'^("(?:[^"\\]|\\.)*")\s+(\w+)$',
        ).firstMatch(value);
        if (match == null) {
          fail('Use camada "Nome" pad (ou baixo, arp, pulso, melodia, fx).');
        }
        final label = jsonDecode(match.group(1)!) as String;
        final mode = match.group(2)!;
        if (label.isEmpty || label.length > 40 || label.contains('\n')) {
          fail('Nome da camada deve ter de 1 a 40 caracteres.');
        }
        if (!modeNames.containsKey(mode)) fail('Modo desconhecido: $mode.');
        if (layers.length >= 8) fail('Limite de 8 camadas.');
        layer = Layer(name: label, mode: mode);
        properties.clear();
      default:
        fail('Comando desconhecido: $key.');
    }
  }
  if (!header) {
    throw const ScriptError(1, 'O script está vazio. Comece com noon 1.');
  }
  if (layer != null) throw ScriptError(lines.length, 'Feche a camada com fim.');
  if (sections.isEmpty) {
    throw const ScriptError(0, 'Adicione ao menos uma secao.');
  }
  if (layers.isEmpty) {
    throw const ScriptError(0, 'Adicione ao menos uma camada.');
  }
  final project = NoonProject(
    name: name,
    bpm: bpm,
    volume: volume,
    chords: chords,
    sections: sections,
    layers: layers,
  );
  if (project.bars > 16 || project.seconds > 60) {
    throw const ScriptError(
      0,
      'Limite desta versão: 16 compassos e 60 segundos.',
    );
  }
  return project;
}

int noteMidi(String note) {
  final m = RegExp(r'^([A-G])([#b]?)([1-7])$').firstMatch(note);
  if (m == null) {
    throw FormatException(
      'Nota inválida: $note. Use C4, F#3, Bb2 ou R para pausa.',
    );
  }
  const pitch = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  return 12 * (int.parse(m.group(3)!) + 1) +
      pitch[m.group(1)]! +
      (m.group(2) == '#'
          ? 1
          : m.group(2) == 'b'
          ? -1
          : 0);
}

List<int> chordMidi(String chord, int octave) {
  final m = RegExp(r'^([A-G])([#b]?)(m7|maj7|m|7)?$').firstMatch(chord);
  if (m == null) {
    throw FormatException(
      'Acorde inválido: $chord. Exemplos: C, Am, F# ou Bbmaj7.',
    );
  }
  final root = noteMidi('${m.group(1)}${m.group(2)}$octave');
  final suffix = m.group(3) ?? '';
  return [
    root,
    root + (suffix.startsWith('m') && suffix != 'maj7' ? 3 : 4),
    root + 7,
    if (suffix.endsWith('7')) root + (suffix == 'maj7' ? 11 : 10),
  ];
}

class NoteStep {
  final int? midi;
  final double beats;
  const NoteStep(this.midi, this.beats);
}

List<NoteStep> parseNotes(String text) {
  final tokens = text.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty || tokens.length > 64) {
    throw const FormatException('Use de 1 a 64 notas.');
  }
  return tokens.map((token) {
    final pair = token.split(':');
    if (pair.length != 2) {
      throw const FormatException('Use notas como C4:1 E4:0.5 R:0.5.');
    }
    final beats = double.tryParse(pair[1]);
    if (beats == null || !beats.isFinite || beats < .25 || beats > 16) {
      throw const FormatException(
        'A duração de cada nota deve ser de 0.25 a 16 tempos.',
      );
    }
    return NoteStep(pair[0] == 'R' ? null : noteMidi(pair[0]), beats);
  }).toList();
}

double midiHz(int midi) => 440.0 * math.pow(2, (midi - 69) / 12);

const harmonyGuides = <String, List<String>>{
  'Contemplativo · i–VI–III–VII': ['Am', 'F', 'C', 'G'],
  'Luminoso · I–V–vi–IV': ['C', 'G', 'Am', 'F'],
  'Íntimo · ii–V–I': ['Dm7', 'G7', 'Cmaj7', 'Cmaj7'],
  'Suspenso · i–VII–VI–VII': ['Dm', 'C', 'Bb', 'C'],
};
