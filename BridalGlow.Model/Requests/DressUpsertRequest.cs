using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Requests;

public class DressUpsertRequest
{
    [Required(ErrorMessage = "Šifra vjenčanice je obavezna.")]
    [MaxLength(50, ErrorMessage = "Šifra ne smije biti duža od 50 znakova.")]
    public string Code { get; set; } = string.Empty;

    [Required(ErrorMessage = "Naziv vjenčanice je obavezan.")]
    [MaxLength(200, ErrorMessage = "Naziv ne smije biti duži od 200 znakova.")]
    public string Name { get; set; } = string.Empty;

    [MaxLength(2000, ErrorMessage = "Opis ne smije biti duži od 2000 znakova.")]
    public string? Description { get; set; }

    [MaxLength(100, ErrorMessage = "Naziv brenda ne smije biti duži od 100 znakova.")]
    public string? Brand { get; set; }

    [Required(ErrorMessage = "Boja vjenčanice je obavezna.")]
    [MaxLength(50, ErrorMessage = "Boja ne smije biti duža od 50 znakova.")]
    public string Color { get; set; } = string.Empty;

    [MaxLength(100, ErrorMessage = "Materijal ne smije biti duži od 100 znakova.")]
    public string? Material { get; set; }

    [MaxLength(100, ErrorMessage = "Silueta ne smije biti duža od 100 znakova.")]
    public string? Silhouette { get; set; }

    [MaxLength(100, ErrorMessage = "Izrez ne smije biti duži od 100 znakova.")]
    public string? Neckline { get; set; }

    [MaxLength(100, ErrorMessage = "Tip rukava ne smije biti duži od 100 znakova.")]
    public string? SleeveType { get; set; }

    [MaxLength(100, ErrorMessage = "Dužina vlečka ne smije biti duža od 100 znakova.")]
    public string? TrainLength { get; set; }

    [Required(ErrorMessage = "Oznaka veličine je obavezna.")]
    [MaxLength(20, ErrorMessage = "Oznaka veličine ne smije biti duža od 20 znakova.")]
    public string SizeLabel { get; set; } = string.Empty;

    [Range(0, 500, ErrorMessage = "Obim grudi mora biti između 0 i 500 cm.")]
    public decimal? BustCm { get; set; }

    [Range(0, 500, ErrorMessage = "Obim struka mora biti između 0 i 500 cm.")]
    public decimal? WaistCm { get; set; }

    [Range(0, 500, ErrorMessage = "Obim bokova mora biti između 0 i 500 cm.")]
    public decimal? HipCm { get; set; }

    [Range(0, 300, ErrorMessage = "Dužina mora biti između 0 i 300 cm.")]
    public decimal? LengthCm { get; set; }

    [Required(ErrorMessage = "Stanje vjenčanice je obavezno.")]
    public DressCondition Condition { get; set; }

    [Range(0, (double)decimal.MaxValue, ErrorMessage = "Nabavna cijena mora biti veća ili jednaka 0.")]
    public decimal? AcquisitionCost { get; set; }

    [Range(0, (double)decimal.MaxValue, ErrorMessage = "Zamijenska vrijednost mora biti veća ili jednaka 0.")]
    public decimal? ReplacementValue { get; set; }

    [Required(ErrorMessage = "Osnovna cijena iznajmljivanja je obavezna.")]
    [Range(0.01, (double)decimal.MaxValue, ErrorMessage = "Osnovna cijena iznajmljivanja mora biti veća od 0.")]
    public decimal BaseRentalPrice { get; set; }

    [Range(0, (double)decimal.MaxValue, ErrorMessage = "Cijena probe mora biti veća ili jednaka 0.")]
    public decimal? TryOnPrice { get; set; }

    [Range(0, (double)decimal.MaxValue, ErrorMessage = "Depozit mora biti veći ili jednak 0.")]
    public decimal? DepositAmount { get; set; }

    [Required(ErrorMessage = "Status vjenčanice je obavezan.")]
    public DressStatus Status { get; set; }

    public bool IsFeatured { get; set; }

    [Required(ErrorMessage = "Primarna kategorija je obavezna.")]
    [Range(1, int.MaxValue, ErrorMessage = "Primarna kategorija je obavezna.")]
    public int PrimaryCategoryId { get; set; }

    public List<int>? TagIds { get; set; }
}
