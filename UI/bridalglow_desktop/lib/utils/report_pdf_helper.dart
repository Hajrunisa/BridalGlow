import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Server-generated PDF payload returned by [ReportsProvider] download methods.
class ReportPdfDocument {
  final Uint8List bytes;
  final String fileName;

  const ReportPdfDocument({
    required this.bytes,
    required this.fileName,
  });
}

/// Desktop helper for previewing, saving and printing server-side PDF reports.
class ReportPdfHelper {
  ReportPdfHelper._();

  static Future<void> preview(
    BuildContext context, {
    required ReportPdfDocument document,
    String? title,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ReportPdfPreviewScreen(
          document: document,
          title: title ?? document.fileName,
        ),
      ),
    );
  }

  /// Opens the Windows save dialog and writes the PDF bytes to disk.
  /// Returns the saved path, or `null` when the user cancels.
  static Future<String?> download(ReportPdfDocument document) async {
    final pickedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF report',
      fileName: document.fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (pickedPath == null) return null;

    final path = pickedPath.toLowerCase().endsWith('.pdf')
        ? pickedPath
        : '$pickedPath.pdf';
    await File(path).writeAsBytes(document.bytes, flush: true);
    return path;
  }

  /// Opens the system print dialog for the given PDF document.
  static Future<void> print(ReportPdfDocument document) async {
    await Printing.layoutPdf(
      onLayout: (_) async => document.bytes,
      name: document.fileName,
    );
  }
}

class _ReportPdfPreviewScreen extends StatelessWidget {
  final ReportPdfDocument document;
  final String title;

  const _ReportPdfPreviewScreen({
    required this.document,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFC2778A),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (_) async => document.bytes,
        pdfFileName: document.fileName,
        allowPrinting: true,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
