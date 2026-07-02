using System;

namespace BridalGlow.Model;

public class UserException : Exception
{
    public UserException(string message) : base(message)
    {
    }
}
