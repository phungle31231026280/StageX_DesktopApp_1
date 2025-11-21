using StageX_DesktopApp.Models;
using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore;

namespace StageX_DesktopApp
{
    public partial class ProfilePage : Page
    {
        private UserDetail _currentUserDetail;
        private User _currentUser;

        public ProfilePage()
        {
            InitializeComponent();
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            if (AuthSession.CurrentUser == null)
            {
                MessageBox.Show("Vui lòng đăng nhập lại!");
                return;
            }
            int currentUserId = AuthSession.CurrentUser.UserId;

            try
            {
                using (var context = new AppDbContext())
                {
                    // Tải thông tin từ CSDL
                    _currentUser = await context.Users.FindAsync(currentUserId);

                    // GHI CHÚ: Dùng SingleOrDefault hoặc FirstOrDefault để an toàn
                    _currentUserDetail = await context.UserDetails
                                            .FirstOrDefaultAsync(ud => ud.UserId == currentUserId);
                }

                if (_currentUser == null) return;

                // Đổ dữ liệu lên Header
                InfoAccountName.Text = _currentUser.AccountName ?? "Chưa đặt tên";
                InfoEmail.Text = _currentUser.Email;

                // GHI CHÚ: Kiểm tra kỹ để tránh lỗi khi AccountName bị null
                if (!string.IsNullOrEmpty(_currentUser.AccountName))
                {
                    InfoInitial.Text = _currentUser.AccountName[0].ToString().ToUpper();
                }
                else
                {
                    InfoInitial.Text = "U";
                }

                // Đổ dữ liệu lên Form
                if (_currentUserDetail != null)
                {
                    FullNameTextBox.Text = _currentUserDetail.FullName;
                    DobDatePicker.SelectedDate = _currentUserDetail.DateOfBirth;
                    AddressTextBox.Text = _currentUserDetail.Address;
                    PhoneTextBox.Text = _currentUserDetail.Phone;
                }
                else
                {
                    // Nếu chưa có chi tiết, reset form
                    FullNameTextBox.Text = "";
                    DobDatePicker.SelectedDate = DateTime.Now;
                    AddressTextBox.Text = "";
                    PhoneTextBox.Text = "";
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi tải hồ sơ: {ex.Message}\n\n(Hãy chắc chắn bạn đã cập nhật AppDbContext.cs)");
            }
        }

        // ... (Các hàm SaveInfoButton_Click và ChangePasswordButton_Click giữ nguyên như cũ) ...

        private async void SaveInfoButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var detail = await context.UserDetails.FindAsync(_currentUser.UserId);
                    if (detail == null)
                    {
                        detail = new UserDetail { UserId = _currentUser.UserId };
                        context.UserDetails.Add(detail);
                    }
                    detail.FullName = FullNameTextBox.Text;
                    detail.DateOfBirth = DobDatePicker.SelectedDate ?? DateTime.Now;
                    detail.Address = AddressTextBox.Text;
                    detail.Phone = PhoneTextBox.Text;
                    await context.SaveChangesAsync();
                }
                MessageBox.Show("Cập nhật thành công!");
            }
            catch (Exception ex) { MessageBox.Show("Lỗi lưu: " + ex.Message); }
        }

        private void ChangePasswordButton_Click(object sender, RoutedEventArgs e)
        {
            ChangePasswordWindow win = new ChangePasswordWindow();
            win.ShowDialog();
        }
    }
}