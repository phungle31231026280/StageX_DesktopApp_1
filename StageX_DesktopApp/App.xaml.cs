using System.Windows;
namespace StageX_DesktopApp
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // TRẢ LẠI: Mở cửa sổ Đăng nhập
            var loginWindow = new LoginWindow();
            loginWindow.Show();

            // Xóa/Comment cửa sổ TestHash
            // var testWindow = new TestHashWindow();
            // testWindow.Show();
        }
    }
}