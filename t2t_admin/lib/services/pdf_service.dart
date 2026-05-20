import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../models/transaction_model.dart';
import '../models/reward_model.dart';

class PDFService {
  static Future<void> generateAndSaveTicketPDF(
    TransactionModel transaction,
    RewardModel? reward,
  ) async {
    final pdf = pw.Document();

    ByteData? font;
    try {
      font = await PlatformAssetBundle().load('fonts/Roboto-Regular.ttf');
    } catch (e) {
      font = null;
    }

    pw.Font? customFont;
    if (font != null && font.lengthInBytes > 0) {
      customFont = pw.Font.ttf(font);
    }

    final qrWidget = pw.BarcodeWidget(
      barcode: pw.Barcode.qrCode(),
      data: transaction.ticketCode ?? '',
      width: 100,
      height: 100,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    children: [
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'T2T REWARD TICKET',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          font: customFont,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Ticket Information
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TICKET DETAILS',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          font: customFont,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      _buildPDFDetailRow(
                        'Reward Name:',
                        transaction.rewardName ?? 'Unknown Reward',
                        customFont,
                      ),
                      pw.SizedBox(height: 10),
                      _buildPDFDetailRow(
                        'Ticket Code:',
                        transaction.ticketCode ?? 'N/A',
                        customFont,
                      ),
                      pw.SizedBox(height: 10),
                      _buildPDFDetailRow(
                        'Points Deducted:',
                        '-${transaction.points} pts',
                        customFont,
                      ),
                      pw.SizedBox(height: 10),
                      _buildPDFDetailRow(
                        'Status:',
                        _getPDFStatusText(transaction.status),
                        customFont,
                      ),
                      pw.SizedBox(height: 10),
                      _buildPDFDetailRow(
                        'Student Name:',
                        transaction.studentName,
                        customFont,
                      ),
                      pw.SizedBox(height: 10),
                      _buildPDFDetailRow(
                        'Department:',
                        transaction.department,
                        customFont,
                      ),
                      pw.SizedBox(height: 10),
                      _buildPDFDetailRow(
                        'Date:',
                        _formatPDFDate(transaction.timestamp.toDate()),
                        customFont,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // QR Code Section
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'QR CODE FOR VERIFICATION',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            font: customFont,
                          ),
                        ),
                        pw.SizedBox(height: 15),
                        qrWidget,
                        pw.SizedBox(height: 10),
                        pw.Text(
                          transaction.ticketCode ?? '',
                          style: pw.TextStyle(fontSize: 12, font: customFont),
                        ),
                      ],
                    ),
                  ),
                ),

                pw.Spacer(),

                // Authentic Seal
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(
                      'AUTHENTIC TICKET',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        font: customFont,
                      ),
                    ),
                  ),
                ),

                pw.SizedBox(height: 20),

                pw.Center(
                  child: pw.Text(
                    'Generated by T2T Rewards System',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                      font: customFont,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'T2T_Ticket_${transaction.ticketCode ?? 'Unknown'}.pdf',
    );
  }

  static pw.Widget _buildPDFDetailRow(
    String label,
    String value,
    pw.Font? font,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            font: font,
          ),
        ),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, font: font)),
      ],
    );
  }

  static String _getPDFStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Authentic - Pending Approval';
      case 'completed':
        return 'Authentic - Approved';
      default:
        return status;
    }
  }

  static String _formatPDFDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
