using System.Globalization;
using BridalGlow.Model.Responses;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace BridalGlow.Services.Reports;

internal static class FinancialReportPdfDocument
{
    public static byte[] Generate(FinancialReportResponse data)
    {
        ReportPdfLayoutHelper.EnsureLicense();

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(36);
                page.DefaultTextStyle(x => x.FontSize(10));

                page.Header().Element(c =>
                    ReportPdfLayoutHelper.ComposeReportHeader(
                        c,
                        "Financial Activity Report",
                        data.FromUtc,
                        data.ToUtc,
                        data.DressId,
                        data.DressCategoryId));

                page.Content().Element(c => ComposeContent(c, data));
                page.Footer().Element(ReportPdfLayoutHelper.ComposeFooter);
            });
        }).GeneratePdf();
    }

    private static void ComposeContent(IContainer container, FinancialReportResponse data)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ComposePeriodSummarySection(c, data.PeriodSummary));
            column.Item().Element(c => ComposeRefundSection(c, data.Refunds));
            column.Item().Element(c => ComposeLedgerSection(c, data.Ledger));
        });
    }

    private static void ComposePeriodSummarySection(IContainer container, FinanceKpiSection summary)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Period Summary"));
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeKeyValueTable(c, new[]
            {
                ("Total Captured", ReportPdfLayoutHelper.FormatMoney(summary.TotalCapturedAmount, summary.Currency)),
                ("Total Refunds", ReportPdfLayoutHelper.FormatMoney(summary.TotalRefundAmount, summary.Currency)),
                ("Net Revenue", ReportPdfLayoutHelper.FormatMoney(summary.NetRevenue, summary.Currency)),
                ("Capture Transactions", summary.TransactionCount.ToString(CultureInfo.InvariantCulture))
            }));
        });
    }

    private static void ComposeRefundSection(IContainer container, RefundSummarySection refunds)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Refund Summary"));
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeKeyValueTable(c, new[]
            {
                ("Total Refund Requests", refunds.TotalCount.ToString(CultureInfo.InvariantCulture)),
                ("Succeeded Amount", ReportPdfLayoutHelper.FormatMoney(refunds.TotalSucceededAmount, refunds.Currency)),
                ("Succeeded Count", refunds.SucceededCount.ToString(CultureInfo.InvariantCulture)),
                ("Pending Count", refunds.PendingCount.ToString(CultureInfo.InvariantCulture)),
                ("Rejected Count", refunds.RejectedCount.ToString(CultureInfo.InvariantCulture))
            }));
        });
    }

    private static void ComposeLedgerSection(IContainer container, LedgerReportResponse ledger)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Ledger Entries"));
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeKeyValueTable(c, new[]
            {
                ("Ledger Received Total", ReportPdfLayoutHelper.FormatMoney(
                    ledger.Summary.TotalReceivedAmount,
                    ledger.Summary.Currency)),
                ("Ledger Transaction Count", ledger.Summary.TransactionCount.ToString(CultureInfo.InvariantCulture)),
                ("Entry Count", ledger.Entries.Count.ToString(CultureInfo.InvariantCulture))
            }));

            if (ledger.Entries.Count == 0)
            {
                column.Item().PaddingTop(6).Text("No ledger entries for the selected period.");
                return;
            }

            column.Item().PaddingTop(6).Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn(1.2f);
                    columns.RelativeColumn();
                    columns.RelativeColumn();
                    columns.RelativeColumn(1.4f);
                    columns.RelativeColumn(1.6f);
                });

                table.Header(header =>
                {
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Date");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Type");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Direction");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Amount");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Reservation");
                });

                foreach (var entry in ledger.Entries)
                {
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle).Text(
                        entry.OccurredAtUtc.ToString("dd MMM yyyy", CultureInfo.InvariantCulture));
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle).Text(entry.EntryTypeLabel);
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle).Text(entry.DirectionLabel);
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(ReportPdfLayoutHelper.FormatMoney(entry.Amount, entry.Currency));
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(entry.ReservationNumber ?? "—");
                }
            });
        });
    }
}
