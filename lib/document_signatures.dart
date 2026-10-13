import 'dart:typed_data';

/// Validate document headers, not only user-supplied extensions or MIME types.
/// This is a format sanity check, not a malware scanner or a PDF sanitizer.
class DocumentSignatures {
  static const maxBytes = 20 * 1024 * 1024;

  static String mimeTypeForName(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const FormatException('Unsupported document extension'),
    };
  }

  static void validate({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    if (name.isEmpty || name.length > 255 ||
        name.contains('/') || name.contains('\\') ||
        name.codeUnits.any((unit) => unit < 32 || unit == 127)) {
      throw const FormatException('Invalid document name');
    }
    if (mimeTypeForName(name) != mimeType) {
      throw const FormatException('Document name and MIME type disagree');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Document must be between 1 byte and 20 MB');
    }
    bool matches(int offset, List<int> signature) =>
        bytes.length >= offset + signature.length &&
        List.generate(signature.length, (i) => i)
            .every((i) => bytes[offset + i] == signature[i]);

    final valid = switch (mimeType) {
      'application/pdf' => matches(0, [0x25, 0x50, 0x44, 0x46, 0x2d]),
      'image/jpeg' => matches(0, [0xff, 0xd8, 0xff]),
      'image/png' => matches(0, [137, 80, 78, 71, 13, 10, 26, 10]),
      'image/webp' =>
        matches(0, [82, 73, 70, 70]) &&
        matches(8, [87, 69, 66, 80]),
      _ => false,
    };
    if (!valid) {
      throw const FormatException('Document contents do not match its file type');
    }
  }
}
