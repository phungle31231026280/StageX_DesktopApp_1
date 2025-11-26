using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class TestHashViewModel : ObservableObject
    {
        // Input: Mật khẩu cần mã hóa
        [ObservableProperty]
        private string _passwordToHash;

        // Output: Kết quả mã hóa
        [ObservableProperty]
        private string _resultHash;

        [RelayCommand]
        private void GenerateHash()
        {
            if (string.IsNullOrEmpty(PasswordToHash))
            {
                ResultHash = "Vui lòng nhập mật khẩu!";
                return;
            }

            // Sử dụng thư viện BCrypt.Net-Next để mã hóa
            ResultHash = BCrypt.Net.BCrypt.HashPassword(PasswordToHash);
        }

        [RelayCommand]
        private void CopyToClipboard()
        {
            if (!string.IsNullOrEmpty(ResultHash))
            {
                Clipboard.SetText(ResultHash);
                MessageBox.Show("Đã copy Hash vào clipboard!");
            }
        }
    }
}