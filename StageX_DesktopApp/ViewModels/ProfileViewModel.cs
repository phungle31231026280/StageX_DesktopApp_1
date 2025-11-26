using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
using StageX_DesktopApp.Views; // Để gọi Window đổi pass
using System;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class ProfileViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        [ObservableProperty] private string _accountName = "Loading...";
        [ObservableProperty] private string _email = "...";
        [ObservableProperty] private string _initial = "U";

        // Form fields
        [ObservableProperty] private string _fullName;
        [ObservableProperty] private string _address;
        [ObservableProperty] private string _phone;
        [ObservableProperty] private DateTime _dateOfBirth = DateTime.Now;

        public ProfileViewModel()
        {
            _dbService = new DatabaseService();
            LoadProfileCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadProfile()
        {
            if (AuthSession.CurrentUser == null) return;

            var user = await _dbService.GetUserWithDetailAsync(AuthSession.CurrentUser.UserId);
            if (user == null) return;

            AccountName = user.AccountName;
            Email = user.Email;
            Initial = !string.IsNullOrEmpty(user.AccountName) ? user.AccountName[0].ToString().ToUpper() : "U";

            if (user.UserDetail != null)
            {
                FullName = user.UserDetail.FullName;
                Address = user.UserDetail.Address;
                Phone = user.UserDetail.Phone;
                DateOfBirth = user.UserDetail.DateOfBirth ?? DateTime.Now;
            }
        }

        [RelayCommand]
        private async Task SaveInfo()
        {
            if (AuthSession.CurrentUser == null) return;
            try
            {
                await _dbService.SaveUserDetailAsync(AuthSession.CurrentUser.UserId, FullName, Address, Phone, DateOfBirth);
                MessageBox.Show("Cập nhật hồ sơ thành công!");
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }

        [RelayCommand]
        private void ChangePassword()
        {
            {
                var win = new ChangePasswordView();
                win.ShowDialog();
            }
        }
    }
}