using System.Windows;
using BCrypt.Net;

namespace StageX_DesktopApp
{
    public partial class TestHashWindow : Window
    {
        public TestHashWindow() { InitializeComponent(); }
        private void HashButton_Click(object sender, RoutedEventArgs e)
        {
            ResultHash.Text = BCrypt.Net.BCrypt.HashPassword(PasswordToHash.Text);
        }
    }
}