using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
using System.Windows;
using System.Windows.Controls;

namespace StageX_DesktopApp.ViewModels
{
    public partial class ChangePasswordViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        public ChangePasswordViewModel()
        {
            _dbService = new DatabaseService();
        }

        // Command nhận vào mảng PasswordBox (hoặc 3 tham số riêng)
        // Cách đơn giản nhất là truyền cả Window để đóng khi xong
        [RelayCommand]
        private async void SavePassword(object parameter)
        {
            // Chúng ta cần lấy 3 PasswordBox từ View. 
            // Vì PasswordBox không bind được, ta dùng MultiBinding Converter hoặc truyền tham số Array.
            // Ở đây giả định parameter là một mảng object[] chứa 3 PasswordBox và Window

            if (parameter is object[] controls && controls.Length == 4)
            {
                var currentBox = controls[0] as PasswordBox;
                var newBox = controls[1] as PasswordBox;
                var confirmBox = controls[2] as PasswordBox;
                var window = controls[3] as Window;

                string currentPass = currentBox?.Password;
                string newPass = newBox?.Password;
                string confirmPass = confirmBox?.Password;

                // 1. Validate
                if (string.IsNullOrEmpty(currentPass) || string.IsNullOrEmpty(newPass) || string.IsNullOrEmpty(confirmPass))
                {
                    MessageBox.Show("Vui lòng nhập đủ thông tin!"); return;
                }
                if (newPass.Length < 3)
                {
                    MessageBox.Show("Mật khẩu mới quá ngắn!"); return;
                }
                if (newPass != confirmPass)
                {
                    MessageBox.Show("Mật khẩu xác nhận không khớp!"); return;
                }

                // 2. Check Pass cũ
                if (!BCrypt.Net.BCrypt.Verify(currentPass, AuthSession.CurrentUser.PasswordHash))
                {
                    MessageBox.Show("Mật khẩu hiện tại không đúng!"); return;
                }

                // 3. Lưu
                string newHash = BCrypt.Net.BCrypt.HashPassword(newPass);
                await _dbService.ChangePasswordAsync(AuthSession.CurrentUser.UserId, newHash);

                // Update Session
                AuthSession.CurrentUser.PasswordHash = newHash;

                MessageBox.Show("Đổi mật khẩu thành công!");
                window?.Close();
            }
        }
    }
}