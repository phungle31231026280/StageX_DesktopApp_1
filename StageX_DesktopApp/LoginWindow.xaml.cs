using Microsoft.EntityFrameworkCore;
using StageX_DesktopApp.Models;
using System;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp
{
    public partial class LoginWindow : Window
    {
        public LoginWindow()
        {
            InitializeComponent();
            IdentifierTextBox.Text = "admin@example.com";
            PasswordBox.Password = "12345678";
        }

        private async void LoginButton_Click(object sender, RoutedEventArgs e)
        {
            LoginButton.IsEnabled = false;

            // GHI CHÚ: ĐÂY LÀ TIN NHẮN "ĐANG KIỂM TRA"
            ErrorTextBlock.Text = "Đang kiểm tra...";

            try
            {
                using (var context = new AppDbContext())
                {
                    string identifier = IdentifierTextBox.Text;
                    string password = PasswordBox.Password;

                    var user = await context.Users
                        .FirstOrDefaultAsync(u => u.Email == identifier || u.AccountName == identifier);

                    if (user == null)
                    {
                        // GHI CHÚ: ĐÂY LÀ TIN NHẮN LỖI "NHẬP SAI"
                        ErrorTextBlock.Text = "Tài khoản không tồn tại.";
                        LoginButton.IsEnabled = true;
                        return;
                    }
                    if (user.Status != null && user.Status.Equals("khóa", StringComparison.OrdinalIgnoreCase))
                    {
                        ErrorTextBlock.Text = "Tài khoản đã bị khóa";
                        LoginButton.IsEnabled = true;
                        return;
                    }

                    bool isPasswordCorrect = BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);
                    if (!isPasswordCorrect)
                    {
                        // GHI CHÚ: PHÁT TIẾNG LỖI
                        AudioHelper.Play("error.mp3");
                        ErrorTextBlock.Text = "Mật khẩu không đúng.";
                        LoginButton.IsEnabled = true;
                        return;
                    }

                    if (user.Role != "Nhân viên" && user.Role != "Admin")
                    {
                        // GHI CHÚ: ĐÂY LÀ TIN NHẮN LỖI "NHẬP SAI"
                        ErrorTextBlock.Text = "Bạn không có quyền truy cập.";
                        LoginButton.IsEnabled = true;
                        return;
                    }

                    // Đăng nhập thành công
                    
                    AuthSession.Login(user);
                    MainWindow mainWindow = new MainWindow();
                    mainWindow.Show();
                    AudioHelper.Play("success.mp3");
                    this.Close();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi kết nối CSDL (Hãy chắc chắn XAMPP đang chạy): {ex.Message}");
                LoginButton.IsEnabled = true;
                // GHI CHÚ: ĐÂY LÀ TIN NHẮN LỖI KẾT NỐI
                ErrorTextBlock.Text = "Lỗi kết nối CSDL.";
            }
        }
    }
}