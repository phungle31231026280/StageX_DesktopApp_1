using StageX_DesktopApp.Models;

namespace StageX_DesktopApp.Utilities
{
    public static class AuthSession
    {
        // Lưu thông tin người dùng đang đăng nhập
        public static User? CurrentUser { get; private set; }

        public static void Login(User user)
        {
            CurrentUser = user;
        }

        public static void Logout()
        {
            CurrentUser = null;
        }

        public static bool IsLoggedIn => CurrentUser != null;
    }
}