using StageX_DesktopApp.Models;
using System;
using System.Threading.Tasks; // Dùng Task
using System.Windows;
using Microsoft.EntityFrameworkCore; // Dùng EF Core

namespace StageX_DesktopApp
{
    public partial class ChangePasswordWindow : Window
    {
        public ChangePasswordWindow()
        {
            InitializeComponent();
        }

        // Ghi chú: Xử lý nút "Xác nhận đổi"
        private async void SavePasswordButton_Click(object sender, RoutedEventArgs e)
        {
            string currentPass = CurrentPasswordBox.Password;
            string newPass = NewPasswordBox.Password;
            string confirmPass = ConfirmPasswordBox.Password;

            // 1. Kiểm tra (Validate)
            if (string.IsNullOrEmpty(currentPass) || string.IsNullOrEmpty(newPass) || string.IsNullOrEmpty(confirmPass))
            {
                MessageBox.Show("Vui lòng nhập đầy đủ 3 ô mật khẩu!");
                return;
            }
            if (newPass.Length < 3) // Đã sửa xuống 3 ký tự
            {
                MessageBox.Show("Mật khẩu mới phải có ít nhất 3 ký tự!");
                return;
            }
            if (newPass != confirmPass)
            {
                MessageBox.Show("Mật khẩu mới và Xác nhận không trùng khớp!");
                return;
            }

            try
            {
                // 2. Dùng BCrypt để kiểm tra mật khẩu HIỆN TẠI
                string currentHash = AuthSession.CurrentUser.PasswordHash;
                bool isCurrentPassCorrect = BCrypt.Net.BCrypt.Verify(currentPass, currentHash);

                if (!isCurrentPassCorrect)
                {
                    MessageBox.Show("Mật khẩu HIỆN TẠI không đúng!");
                    return;
                }

                // 3. Nếu đúng, tạo Hash mới cho mật khẩu MỚI
                string newHash = BCrypt.Net.BCrypt.HashPassword(newPass);

                // 4. Cập nhật hash mới vào CSDL
                // Ghi chú: Tạo 1 context MỚI chỉ để cập nhật
                using (var context = new AppDbContext())
                {
                    var userToUpdate = await context.Users.FindAsync(AuthSession.CurrentUser.UserId);
                    if (userToUpdate != null)
                    {
                        userToUpdate.PasswordHash = newHash;
                        await context.SaveChangesAsync();
                    }
                }

                // 5. Cập nhật lại AuthSession (quan trọng)
                AuthSession.CurrentUser.PasswordHash = newHash;

                MessageBox.Show("Đổi mật khẩu thành công!");

                // 6. Đóng cửa sổ này
                this.Close();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi đổi mật khẩu: {ex.Message}");
            }
        }
    }
}