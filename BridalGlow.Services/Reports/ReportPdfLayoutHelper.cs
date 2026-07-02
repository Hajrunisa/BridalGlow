using System.Globalization;
using BridalGlow.Model.Responses;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace BridalGlow.Services.Reports;

internal static class ReportPdfLayoutHelper
{
    internal static readonly Color PrimaryColor = Colors.Pink.Medium;
    internal static readonly Color HeaderBackground = Colors.Grey.Lighten3;
    internal static readonly Color BorderColor = Colors.Grey.Lighten2;

    internal static void EnsureLicense()
    {
        QuestPDF.Settings.License = LicenseType.Community;
    }

    internal static void ComposeReportHeader(
        IContainer container,
        string title,
        DateTime? fromUtc,
        DateTime? toUtc,
        int? dressId,
        int? dressCategoryId)
    {
        container.Column(column =>
        {
            column.Item().Text("BridalGlow")
                .FontSize(22)
                .Bold()
                .FontColor(PrimaryColor);

            column.Item().PaddingTop(4).Text(title)
                .FontSize(16)
                .Bold();

            column.Item().PaddingTop(8).Text(text =>
            {
                text.Span("Period: ").SemiBold();
                text.Span(FormatPeriod(fromUtc, toUtc));
            });

            column.Item().Text(text =>
            {
                text.Span("Filters: ").SemiBold();
                text.Span(FormatFilters(dressId, dressCategoryId));
            });

            column.Item().Text(text =>
            {
                text.Span("Generated: ").SemiBold();
                text.Span(DateTime.UtcNow.ToString("dd MMM yyyy HH:mm", CultureInfo.InvariantCulture) + " UTC");
            });

            column.Item().PaddingTop(8).LineHorizontal(1).LineColor(BorderColor);
        });
    }

    internal static void ComposeSectionTitle(IContainer container, string title)
    {
        container.PaddingTop(12).PaddingBottom(6).Text(title)
            .FontSize(13)
            .Bold()
            .FontColor(PrimaryColor);
    }

    internal static void ComposeKeyValueTable(IContainer container, IEnumerable<(string Label, string Value)> rows)
    {
        container.Table(table =>
        {
            table.ColumnsDefinition(columns =>
            {
                columns.RelativeColumn(2);
                columns.RelativeColumn(3);
            });

            foreach (var (label, value) in rows)
            {
                table.Cell().Element(CellStyle).Text(label).SemiBold();
                table.Cell().Element(CellStyle).Text(value);
            }
        });
    }

    internal static void ComposeFooter(IContainer container)
    {
        container.AlignCenter().Text(text =>
        {
            text.Span("BridalGlow — Confidential business report | Page ");
            text.CurrentPageNumber();
            text.Span(" / ");
            text.TotalPages();
        });
    }

    internal static IContainer CellStyle(IContainer container)
    {
        return container
            .BorderBottom(1)
            .BorderColor(BorderColor)
            .PaddingVertical(4)
            .PaddingHorizontal(6);
    }

    internal static IContainer HeaderCellStyle(IContainer container)
    {
        return container
            .Background(HeaderBackground)
            .BorderBottom(1)
            .BorderColor(BorderColor)
            .PaddingVertical(4)
            .PaddingHorizontal(6)
            .DefaultTextStyle(x => x.SemiBold());
    }

    internal static string FormatMoney(decimal amount, string currency)
        => $"{amount:N2} {currency}";

    internal static string FormatPeriod(DateTime? fromUtc, DateTime? toUtc)
    {
        if (!fromUtc.HasValue && !toUtc.HasValue)
            return "All time";

        var from = fromUtc?.ToString("dd MMM yyyy", CultureInfo.InvariantCulture) ?? "—";
        var to = toUtc?.ToString("dd MMM yyyy", CultureInfo.InvariantCulture) ?? "—";
        return $"{from} to {to}";
    }

    internal static string FormatFilters(int? dressId, int? dressCategoryId)
    {
        var parts = new List<string>();
        if (dressId.HasValue)
            parts.Add($"Dress ID {dressId.Value}");
        if (dressCategoryId.HasValue)
            parts.Add($"Category ID {dressCategoryId.Value}");

        return parts.Count > 0 ? string.Join(", ", parts) : "None";
    }
}
