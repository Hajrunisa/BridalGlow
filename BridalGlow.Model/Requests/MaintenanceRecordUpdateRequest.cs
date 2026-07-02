using System;
using System.ComponentModel.DataAnnotations;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Requests;

public class MaintenanceRecordUpdateRequest
{
    public MaintenanceType? MaintenanceType { get; set; }

    [MaxLength(1000, ErrorMessage = "Opis ne smije biti duži od 1000 znakova.")]
    public string? Description { get; set; }

    [Range(0, double.MaxValue, ErrorMessage = "Iznos troška ne može biti negativan.")]
    public decimal? CostAmount { get; set; }

    [MaxLength(200, ErrorMessage = "Naziv dobavljača ne smije biti duži od 200 znakova.")]
    public string? VendorName { get; set; }

    [MaxLength(100, ErrorMessage = "Broj fakture ne smije biti duži od 100 znakova.")]
    public string? InvoiceNumber { get; set; }

    public DressCondition? BeforeCondition { get; set; }
    public DressCondition? AfterCondition { get; set; }

    public DateTime? OutOfServiceFromUtc { get; set; }
    public DateTime? OutOfServiceToUtc { get; set; }

    public DateTime? PerformedAtUtc { get; set; }
    public DateTime? NextCheckAtUtc { get; set; }
}
