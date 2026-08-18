import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../features/diary/domain/entities/diary_entry.dart';

enum ExportFormat { pdf, text, image }

class ExportService {
  static final ExportService instance = ExportService._();
  ExportService._();

  Future<void> exportAsPdf(
    List<DiaryEntry> entries,
    BuildContext context,
  ) async {
    final pdf = pw.Document(
      title: 'Diary Export',
      author: 'Diary App',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => _buildPdfPages(ctx, entries),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text('My Diary',
              style: pw.TextStyle(
                  fontSize: 24, color: PdfColors.indigo, fontWeight: pw.FontWeight.bold)),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Diary Export',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/diary_export_$ts.pdf');
    await file.writeAsBytes(await pdf.save());
    await _share(file, 'diary_export_$ts.pdf');
  }

  Future<void> exportAsText(
    List<DiaryEntry> entries,
    BuildContext context,
  ) async {
    final buf = StringBuffer();
    buf.writeln('========================================');
    buf.writeln('           MY DIARY — EXPORT');
    buf.writeln('========================================\n');
    buf.writeln(
        'Exported: ${DateFormat('MMM d, yyyy – h:mm a').format(DateTime.now())}');
    buf.writeln('Total entries: ${entries.length}\n');

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      buf.writeln('Entry #${i + 1}');
      buf.writeln('──────────────────────────────────────────');
      buf.writeln('Title: ${e.title}');
      buf.writeln(
          'Date:  ${DateFormat('EEEE, MMMM d, yyyy').format(e.createdAt)}');
      buf.writeln('Time:  ${DateFormat('h:mm a').format(e.createdAt)}');
      buf.writeln('Mood:  ${_moodLabel(e.mood)}');
      if (e.tags.isNotEmpty) buf.writeln('Tags:  ${e.tags.join(', ')}');
      if (e.isFavorite) buf.writeln('★ Favorite');
      buf.writeln();
      buf.writeln(e.content);
      buf.writeln('\n');
    }

    final dir = await getTemporaryDirectory();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/diary_export_$ts.txt');
    await file.writeAsString(buf.toString());
    await _share(file, 'diary_export_$ts.txt');
  }

  Future<void> exportAsImage(
    GlobalKey previewKey,
    BuildContext context,
  ) async {
    final boundary = previewKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final dir = await getTemporaryDirectory();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/diary_card_$ts.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    await _share(file, 'diary_card_$ts.png');
  }

  List<pw.Widget> _buildPdfPages(pw.Context ctx, List<DiaryEntry> entries) {
    final widgets = <pw.Widget>[];
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final dateStr =
          DateFormat('EEEE, MMMM d, yyyy – h:mm a').format(e.createdAt);

      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Row(children: [
        pw.Container(width: 4, height: 24, color: _moodColor(e.mood)),
        pw.SizedBox(width: 8),
        pw.Expanded(
            child: pw.Header(
                level: 1,
                child: pw.Text(e.title,
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold)))),
      ]));
      widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12),
          child: pw.Text('$dateStr  •  ${_moodLabel(e.mood)}',
              style:
                  pw.TextStyle(fontSize: 10, color: PdfColors.grey600))));
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12),
          child: pw.Paragraph(
              text: e.content,
              style: pw.TextStyle(fontSize: 11, lineSpacing: 1.5))));

      if (e.imagePaths.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        widgets.add(pw.Wrap(
            spacing: 4,
            runSpacing: 4,
            children: e.imagePaths
                .where((p) => File(p).existsSync())
                .take(4)
                .map((p) => pw.Container(
                    width: 80,
                    height: 80,
                    child: pw.Image(
                        pw.MemoryImage(File(p).readAsBytesSync()),
                        fit: pw.BoxFit.cover)))
                .toList()));
      }
      if (e.tags.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12),
            child: pw.Text(e.tags.map((t) => '#$t').join('  '),
                style: pw.TextStyle(fontSize: 9, color: PdfColors.indigo))));
      }
      if (i < entries.length - 1) {
        widgets.add(pw.SizedBox(height: 16));
      }
    }
    return widgets;
  }

  Future<void> _share(File file, String filename) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: filename,
    );
  }

  PdfColor _moodColor(Mood m) => switch (m) {
        Mood.happy => PdfColors.green,
        Mood.sad => PdfColors.indigo,
        Mood.angry => PdfColors.red,
        Mood.calm => PdfColors.teal,
        Mood.anxious => PdfColors.amber,
        Mood.neutral => PdfColors.grey,
      };

  String _moodLabel(Mood m) => switch (m) {
        Mood.happy => 'Happy 😊',
        Mood.sad => 'Sad 😢',
        Mood.angry => 'Angry 😤',
        Mood.calm => 'Calm 😌',
        Mood.anxious => 'Anxious 😰',
        Mood.neutral => 'Neutral 😐',
      };
}
