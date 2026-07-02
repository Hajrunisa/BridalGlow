using BridalGlow.API.Filters;
using BridalGlow.Model;
using BridalGlow.Model.Constants;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = RoleNames.Customer)]
public class InteractionsController : ControllerBase
{
    private readonly IUserDressInteractionService _interactionService;

    public InteractionsController(IUserDressInteractionService interactionService)
    {
        _interactionService = interactionService;
    }

    /// <summary>
    /// Records a customer dress interaction (View or Favorite) from the mobile client.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Record([FromBody] InteractionIngestRequest request)
    {
        if (request.InteractionType != InteractionType.View &&
            request.InteractionType != InteractionType.Favorite)
        {
            throw new UserException("Putem ovog endpointa dozvoljeni su samo tipovi View i Favorite.");
        }

        await _interactionService.RecordInteractionAsync(
            User.GetUserId(),
            request.DressId,
            request.InteractionType,
            InteractionSource.Mobile,
            sessionId: request.SessionId,
            metadataJson: request.MetadataJson);

        return NoContent();
    }

    /// <summary>
    /// Returns dress IDs marked as Favorite by the authenticated customer.
    /// </summary>
    [HttpGet("favorites")]
    public async Task<ActionResult<IReadOnlyList<int>>> GetFavorites()
    {
        return Ok(await _interactionService.GetFavoriteDressIdsAsync(User.GetUserId()));
    }

    /// <summary>
    /// Removes a previously recorded Favorite interaction for the authenticated customer.
    /// </summary>
    [HttpDelete("favorites/{dressId:int}")]
    public async Task<IActionResult> RemoveFavorite(int dressId)
    {
        await _interactionService.RemoveFavoriteAsync(User.GetUserId(), dressId);
        return NoContent();
    }
}
