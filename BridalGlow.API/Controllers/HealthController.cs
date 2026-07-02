namespace BridalGlow.API.Controllers;

using BridalGlow.Data.Database;
using BridalGlow.Model.Responses;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(
        BridalGlowDbContext db,
        IRecommendationQueryService recommender,
        CancellationToken cancellationToken)
    {
        var databaseConnected = await db.Database.CanConnectAsync(cancellationToken);

        RecommenderStatusResponse? recommenderStatus = null;
        if (databaseConnected)
        {
            try
            {
                recommenderStatus = await recommender.GetStatusAsync(cancellationToken);
            }
            catch
            {
                // Recommender metadata is optional for health; DB connectivity is primary.
            }
        }

        return Ok(new
        {
            status = databaseConnected ? "ok" : "degraded",
            service = "BridalGlow.API",
            database = new { connected = databaseConnected },
            recommender = recommenderStatus
        });
    }
}
