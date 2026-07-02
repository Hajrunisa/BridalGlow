namespace BridalGlow.Model.SignalR;

public static class NotificationHubGroups
{
    public static string User(int userId) => $"user_{userId}";

    public static string Role(string role) => $"role_{role}";
}
