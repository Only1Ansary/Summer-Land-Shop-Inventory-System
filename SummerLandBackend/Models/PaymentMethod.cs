namespace SummerLandBackend.Models
{
    /// <summary>
    /// How money for a sale, purchase invoice, or supplier debt payment was
    /// handed over. Stored as an int so the API contract stays stable and
    /// works with older clients.
    /// </summary>
    public enum PaymentMethod
    {
        Cash = 0,
        Visa = 1,
        InstaPay = 2,
        VCash = 3
    }
}
