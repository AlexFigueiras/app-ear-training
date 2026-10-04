// Verifica se as bibliotecas nativas 64-bit (.so) têm segmentos ELF LOAD alinhados a 16 KB —
// exigência da Google Play para apps com código nativo (aparelhos Android 15+ com páginas de
// 16 KB). Bibliotecas 32-bit ficam de fora: esses aparelhos não usam páginas de 16 KB.
// Dart puro, zero dependência nova (AGENTS.md seção 2, item 4). Usado pelo CI (job
// release-check) sobre o lib/ extraído do APK de release.
//
// Uso: dart tool/check_elf_alignment.dart <diretório com os .so>
import 'dart:io';
import 'dart:typed_data';

const int requiredAlignment = 16 * 1024;
const int _ptLoad = 1;

void main(List<String> args) {
  if (args.length != 1) {
    stderr
        .writeln('uso: dart tool/check_elf_alignment.dart <diretório com .so>');
    exit(64);
  }

  final libs = Directory(args.first)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.so'))
      .toList();
  if (libs.isEmpty) {
    stderr.writeln('❌ Nenhum .so encontrado em ${args.first}.');
    exit(1);
  }

  var checked = 0;
  var failures = 0;
  for (final lib in libs) {
    final info = readLoadAlignment(lib.readAsBytesSync());
    final path = lib.path.replaceAll('\\', '/');
    if (info == null) {
      stderr.writeln('❌ $path: não é um ELF válido.');
      failures++;
    } else if (!info.is64Bit) {
      stdout.writeln('·  $path: 32-bit, fora da exigência de 16 KB.');
    } else if (info.minAlignment < requiredAlignment) {
      stderr.writeln(
          '❌ $path: LOAD alinhado a ${info.minAlignment} bytes (exigido $requiredAlignment).');
      checked++;
      failures++;
    } else {
      stdout.writeln('✅ $path: LOAD alinhado a ${info.minAlignment} bytes.');
      checked++;
    }
  }

  if (failures > 0) {
    stderr.writeln(
        '\n$failures biblioteca(s) fora do alinhamento de 16 KB exigido pela Play.');
    exit(1);
  }
  if (checked == 0) {
    stderr.writeln(
        '❌ Nenhuma biblioteca 64-bit verificada — o APK deveria ter arm64-v8a/x86_64.');
    exit(1);
  }
  stdout.writeln(
      '\nTodas as $checked bibliotecas 64-bit estão alinhadas a 16 KB.');
}

class ElfLoadAlignment {
  final bool is64Bit;

  /// Menor `p_align` entre os segmentos PT_LOAD.
  final int minAlignment;

  const ElfLoadAlignment({required this.is64Bit, required this.minAlignment});
}

/// Lê o menor alinhamento dos segmentos PT_LOAD de um ELF little-endian (32 ou 64 bits).
/// Devolve null se os bytes não forem um ELF little-endian com segmento LOAD.
ElfLoadAlignment? readLoadAlignment(Uint8List bytes) {
  const elfMagic = [0x7f, 0x45, 0x4c, 0x46];
  if (bytes.length < 0x34) return null;
  for (var i = 0; i < elfMagic.length; i++) {
    if (bytes[i] != elfMagic[i]) return null;
  }
  final is64Bit = bytes[4] == 2;
  if (bytes[5] != 1) return null; // só little-endian (todas as ABIs Android)
  if (is64Bit && bytes.length < 0x40) return null;

  final data = ByteData.sublistView(bytes);
  const le = Endian.little;
  final phoff = is64Bit ? data.getUint64(0x20, le) : data.getUint32(0x1C, le);
  final phentsize = data.getUint16(is64Bit ? 0x36 : 0x2A, le);
  final phnum = data.getUint16(is64Bit ? 0x38 : 0x2C, le);

  int? minAlignment;
  for (var i = 0; i < phnum; i++) {
    final offset = phoff + i * phentsize;
    if (offset + phentsize > bytes.length) return null;
    if (data.getUint32(offset, le) != _ptLoad) continue;
    final align = is64Bit
        ? data.getUint64(offset + 0x30, le)
        : data.getUint32(offset + 0x1C, le);
    if (minAlignment == null || align < minAlignment) minAlignment = align;
  }

  if (minAlignment == null) return null;
  return ElfLoadAlignment(is64Bit: is64Bit, minAlignment: minAlignment);
}
