import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// كونترولر لخانة الكتابة يعرض الملصقات (إيموجي الصور) كصورة داخل الخانة نفسها
/// بدل ما يطلع الرمز الطويل [[lamma_emoji:...]].
///
/// الفكرة: كل ملصق يُمثَّل داخل الخانة بحرف واحد من منطقة Private Use،
/// وهذا الحرف يُرسم كصورة. عند الإرسال نحوّل الحروف إلى الرمز الأصلي
/// عن طريق [wireText]، وعند التعديل نحوّل الرمز إلى حرف عن طريق [setWireText].
class StickerTextController extends TextEditingController {
  StickerTextController({super.text});

  static const int _base = 0xE000;
  static const int _max = 0xF8FF;
  static final RegExp _token = RegExp(r'\[\[lamma_emoji:([^\]]+)\]\]');

  final List<String> _urls = <String>[];

  bool _isSticker(int unit) =>
      unit >= _base && unit <= _max && (unit - _base) < _urls.length;

  String? _urlOf(int unit) => _isSticker(unit) ? _urls[unit - _base] : null;

  String _charFor(String url) {
    var index = _urls.indexOf(url);
    if (index < 0) {
      if (_base + _urls.length >= _max) return '';
      _urls.add(url);
      index = _urls.length - 1;
    }
    return String.fromCharCode(_base + index);
  }

  /// يحوّل أي رمز [[lamma_emoji:..]] داخل النص إلى حرف ملصق واحد.
  String fromWire(String wire) {
    return wire.replaceAllMapped(_token, (match) {
      try {
        final url = Uri.decodeComponent(match.group(1) ?? '');
        final c = _charFor(url);
        return c.isEmpty ? match.group(0)! : c;
      } catch (_) {
        return match.group(0)!;
      }
    });
  }

  /// النص الحقيقي اللي ينرسل/ينحفظ (الملصق يرجع رمزاً).
  String get wireText {
    final buffer = StringBuffer();
    for (final unit in text.codeUnits) {
      final url = _urlOf(unit);
      if (url != null) {
        buffer.write('[[lamma_emoji:${Uri.encodeComponent(url)}]]');
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  /// يضبط محتوى الخانة من نص مخزّن (مثلاً عند تعديل رسالة).
  void setWireText(String wire) {
    final converted = fromWire(wire);
    value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }

  /// يدخل إيموجي أو ملصق (بصيغته المخزّنة) مكان المؤشر.
  void insertWire(String wire) {
    final insert = fromWire(wire);
    final oldText = text;
    final sel = selection;
    final start = sel.start < 0 ? oldText.length : sel.start;
    final end = sel.end < 0 ? oldText.length : sel.end;
    final next = oldText.replaceRange(start, end, insert);
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    if (!source.codeUnits.any(_isSticker)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final children = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      children.add(TextSpan(text: buffer.toString(), style: style));
      buffer.clear();
    }

    for (final unit in source.codeUnits) {
      final url = _urlOf(unit);
      if (url == null) {
        buffer.writeCharCode(unit);
        continue;
      }
      flush();
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(
          width: 26,
          height: 26,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
            errorWidget: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined, size: 20),
          ),
        ),
      ));
    }
    flush();
    return TextSpan(style: style, children: children);
  }
}

/// نص مختصر مفهوم للمعاينات (الرد، قائمة المحادثات) بدل رمز الملصق الطويل.
String stickerPreview(String text) =>
    text.replaceAll(RegExp(r'\[\[lamma_emoji:[^\]]+\]\]'), '🖼 ملصق');
