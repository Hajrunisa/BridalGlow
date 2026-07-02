using System.Globalization;
using BridalGlow.Model.Responses;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace BridalGlow.Services.Reports;

internal static class BusinessPerformancePdfDocument
{
    public static byte[] Generate(BusinessPerformanceReportResponse data)
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
                        "Salon Business Performance Report",
                        data.FromUtc,
                        data.ToUtc,
                        data.DressId,
                        data.DressCategoryId));

                page.Content().Element(c => ComposeContent(c, data));
                page.Footer().Element(ReportPdfLayoutHelper.ComposeFooter);
            });
        }).GeneratePdf();
    }

    private static void ComposeContent(IContainer container, BusinessPerformanceReportResponse data)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ComposeFinanceSection(c, data.Finance));
            column.Item().Element(c => ComposeRentalsSection(c, data.Rentals));
            column.Item().Element(c => ComposeReviewsSection(c, data.Reviews));
            column.Item().Element(c => ComposeMaintenanceSection(c, data.Maintenance));
            column.Item().Element(c => ComposeDressPortfolioSection(c, data.DressPortfolio));
            column.Item().Element(c => ComposeMonthlyTrendsSection(c, data.MonthlyTrends, data.Finance.Currency));
        });
    }

    private static void ComposeFinanceSection(IContainer container, FinanceKpiSection finance)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Finance Summary"));
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeKeyValueTable(c, new[]
            {
                ("Total Captured", ReportPdfLayoutHelper.FormatMoney(finance.TotalCapturedAmount, finance.Currency)),
                ("Total Refunds", ReportPdfLayoutHelper.FormatMoney(finance.TotalRefundAmount, finance.Currency)),
                ("Net Revenue", ReportPdfLayoutHelper.FormatMoney(finance.NetRevenue, finance.Currency)),
                ("Transactions", finance.TransactionCount.ToString(CultureInfo.InvariantCulture))
            }));
        });
    }

    private static void ComposeRentalsSection(IContainer container, RentalKpiSection rentals)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Rental Operations"));
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeKeyValueTable(c, new[]
            {
                ("Total Reservations", rentals.TotalCount.ToString(CultureInfo.InvariantCulture)),
                ("Completion Rate", $"{rentals.CompletionRate:N2}%"),
                ("Cancellation Rate", $"{rentals.CancellationRate:N2}%")
            }));

            if (rentals.StatusBreakdown.Count == 0)
                return;

            column.Item().PaddingTop(6).Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn(2);
                    columns.RelativeColumn();
                });

                table.Header(header =>
                {
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Status");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Count");
                });

                foreach (var item in rentals.StatusBreakdown)
                {
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle).Text(item.StatusLabel);
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(item.Count.ToString(CultureInfo.InvariantCulture));
                }
            });
        });
    }

    private static void ComposeReviewsSection(IContainer container, BusinessReviewReportSection reviews)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Reviews"));
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeKeyValueTable(c, new[]
            {
                ("Average Rating", $"{reviews.Summary.AverageRating:N2} / 5"),
                ("Total Reviews", reviews.Summary.TotalCount.ToString(CultureInfo.InvariantCulture)),
                ("Published", reviews.Summary.PublishedCount.ToString(CultureInfo.InvariantCulture)),
                ("Pending Moderation", reviews.Summary.PendingModerationCount.ToString(CultureInfo.InvariantCulture)),
                ("Hidden", reviews.Summary.HiddenCount.ToString(CultureInfo.InvariantCulture)),
                ("Rejected", reviews.Summary.RejectedCount.ToString(CultureInfo.InvariantCulture))
            }));

            if (reviews.RatingDistribution.Count == 0)
                return;

            column.Item().PaddingTop(6).Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn();
                    columns.RelativeColumn();
                });

                table.Header(header =>
                {
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Rating");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Count");
                });

                foreach (var item in reviews.RatingDistribution)
                {
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(item.Rating.ToString(CultureInfo.InvariantCulture));
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(item.Count.ToString(CultureInfo.InvariantCulture));
                }
            });
        });
    }

    private static void ComposeMaintenanceSection(IContainer container, BusinessMaintenanceReportSection maintenance)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Maintenance"));
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeKeyValueTable(c, new[]
            {
                ("Total Records", maintenance.Summary.TotalRecordCount.ToString(CultureInfo.InvariantCulture)),
                ("Total Cost", maintenance.Summary.TotalCostAmount.ToString("N2", CultureInfo.InvariantCulture))
            }));

            if (maintenance.ByType.Count == 0)
                return;

            column.Item().PaddingTop(6).Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn(2);
                    columns.RelativeColumn();
                    columns.RelativeColumn();
                });

                table.Header(header =>
                {
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Type");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Records");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Cost");
                });

                foreach (var item in maintenance.ByType)
                {
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle).Text(item.MaintenanceTypeLabel);
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(item.RecordCount.ToString(CultureInfo.InvariantCulture));
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(item.TotalCostAmount.ToString("N2", CultureInfo.InvariantCulture));
                }
            });
        });
    }

    private static void ComposeDressPortfolioSection(IContainer container, DressPortfolioKpiSection portfolio)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Dress Portfolio"));
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeKeyValueTable(c, new[]
            {
                ("Active Dresses", portfolio.ActiveDressCount.ToString(CultureInfo.InvariantCulture)),
                ("Out of Service", portfolio.OutOfServiceDressCount.ToString(CultureInfo.InvariantCulture))
            }));

            if (portfolio.TopRentedDresses.Count == 0)
                return;

            column.Item().PaddingTop(6).Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn();
                    columns.RelativeColumn(2);
                    columns.RelativeColumn();
                });

                table.Header(header =>
                {
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Code");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Dress");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Rentals");
                });

                foreach (var item in portfolio.TopRentedDresses)
                {
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle).Text(item.DressCode);
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle).Text(item.DressName);
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(item.RentalCount.ToString(CultureInfo.InvariantCulture));
                }
            });
        });
    }

    private static void ComposeMonthlyTrendsSection(
        IContainer container,
        List<MonthlyTrendItem> trends,
        string currency)
    {
        container.Column(column =>
        {
            column.Item().Element(c => ReportPdfLayoutHelper.ComposeSectionTitle(c, "Monthly Trends"));

            if (trends.Count == 0)
            {
                column.Item().Text("No trend data for the selected period.");
                return;
            }

            column.Item().Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn();
                    columns.RelativeColumn();
                    columns.RelativeColumn();
                });

                table.Header(header =>
                {
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Month");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Revenue");
                    header.Cell().Element(ReportPdfLayoutHelper.HeaderCellStyle).Text("Rentals");
                });

                foreach (var item in trends)
                {
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle).Text(item.Month);
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(ReportPdfLayoutHelper.FormatMoney(item.Revenue, currency));
                    table.Cell().Element(ReportPdfLayoutHelper.CellStyle)
                        .Text(item.RentalCount.ToString(CultureInfo.InvariantCulture));
                }
            });
        });
    }
}
