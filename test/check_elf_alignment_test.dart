import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_elf_alignment.dart'
    show readLoadAlignment, requiredAlignment;

/// ELF mínimo: cabeçalho + um PT_PHDR (ignorado) + um PT_LOAD por alinhamento informado.
Uint8List _fakeElf({required bool is64Bit, required List<int> loadAlignments}) {
  final phentsize = is64Bit ? 56 : 32;
  final phoff = is64Bit ? 64 : 52;
  final phnum = loadAlignments.length + 1;
  final bytes = Uint8List(phoff + phentsize * phnum);
  final data = ByteData.sublistView(bytes);
  const le = Endian.little;

  bytes.setAll(0, [0x7f, 0x45, 0x4c, 0x46, is64Bit ? 2 : 1, 1]);
  if (is64Bit) {
    data.setUint64(0x20, phoff, le);
    data.setUint16(0x36, phentsize, le);
    data.setUint16(0x38, phnum, le);
  } else {
    data.setUint32(0x1C, phoff, le);
    data.setUint16(0x2A, phentsize, le);
    data.setUint16(0x2C, phnum, le);
  }

  data.setUint32(phoff, 6, le); // PT_PHDR
  for (var i = 0; i < loadAlignments.length; i++) {
    final offset = phoff + (i + 1) * phentsize;
    data.setUint32(offset, 1, le); // PT_LOAD
    if (is64Bit) {
      data.setUint64(offset + 0x30, loadAlignments[i], le);
    } else {
      data.setUint32(offset + 0x1C, loadAlignments[i], le);
    }
  }
  return bytes;
}

void main() {
  test('64-bit alinhado a 16 KB passa', () {
    final info = readLoadAlignment(
        _fakeElf(is64Bit: true, loadAlignments: [16384, 65536]))!;
    expect(info.is64Bit, isTrue);
    expect(info.minAlignment, greaterThanOrEqualTo(requiredAlignment));
  });

  test('64-bit com um segmento de 4 KB é detectado', () {
    final info = readLoadAlignment(
        _fakeElf(is64Bit: true, loadAlignments: [16384, 4096]))!;
    expect(info.minAlignment, 4096);
  });

  test('32-bit é reconhecido (fora da exigência)', () {
    final info =
        readLoadAlignment(_fakeElf(is64Bit: false, loadAlignments: [4096]))!;
    expect(info.is64Bit, isFalse);
  });

  test('arquivo que não é ELF, ou ELF sem LOAD, é recusado', () {
    expect(readLoadAlignment(Uint8List(128)), isNull);
    expect(
        readLoadAlignment(_fakeElf(is64Bit: true, loadAlignments: [])), isNull);
  });
}
