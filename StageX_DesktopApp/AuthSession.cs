using StageX_DesktopApp.Models;

namespace StageX_DesktopApp
{
    public static class AuthSession
    {
        public static User CurrentUser { get; private set; }
        public static void Login(User user) { CurrentUser = user; }
        public static void Logout() { CurrentUser = null; }
    }
}