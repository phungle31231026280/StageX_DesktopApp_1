using StageX_DesktopApp.Models;
using System;
using System.Threading.Tasks; // <-- Dùng Task
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore; // <-- Dùng EF Core

namespace StageX_DesktopApp
{
    public partial class ProfilePage : Page
    {
        // Ghi chú: KHÔNG dùng _context toàn cục nữa
        // để tránh lỗi "A second operation was started..."
        // private AppDbContext _context;

        private UserDetail _currentUserDetail;
        private User _currentUser;

        public ProfilePage()
        {
            InitializeComponent();
            // _context = new AppDbContext(); // Không khởi tạo ở đây
        }

        // Ghi chú: Tải thông tin khi trang được mở
        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            if (AuthSession.CurrentUser == null)
            {
                MessageBox.Show("Lỗi: Không tìm thấy phiên đăng nhập!");
                return;
            }
            int currentUserId = AuthSession.CurrentUser.UserId;

            // Ghi chú: Tạo 1 context mới CHỈ để Tải
            using (var context = new AppDbContext())
            {
                // Tải tài khoản
                _currentUser = await context.Users.FindAsync(currentUserId);

                // Tải chi tiết (dùng .Include() để tải User kèm theo)
                _currentUserDetail = await context.UserDetails
                                        .Include(ud => ud.User)
                                        .FirstOrDefaultAsync(ud => ud.UserId == currentUserId);
            }

            if (_currentUser == null)
            {
                MessageBox.Show("Lỗi: Không tìm thấy tài khoản trong CSDL!");
                return;
            }

            // Đổ dữ liệu lên Khối thông tin (Header)
            InfoAccountName.Text = _currentUser.AccountName;
            InfoEmail.Text = _currentUser.Email;
            // Lấy chữ cái đầu
            if (!string.IsNullOrEmpty(_currentUser.AccountName))
            {
                InfoInitial.Text = _currentUser.AccountName[0].ToString().ToUpper();
            }

            // Đổ dữ liệu lên Form
            if (_currentUserDetail != null)
            {
                FullNameTextBox.Text = _currentUserDetail.FullName;
                DobDatePicker.SelectedDate = _currentUserDetail.DateOfBirth;
                AddressTextBox.Text = _currentUserDetail.Address;
                PhoneTextBox.Text = _currentUserDetail.Phone;
            }
        }

        // Ghi chú: Xử lý nút "Cập nhật hồ sơ"
        private async void SaveInfoButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Ghi chú: Tạo 1 context mới CHỈ để Lưu
                using (var context = new AppDbContext())
                {
                    // Logic này giống file PHP

                    // Tìm xem user detail đã tồn tại chưa
                    var detail = await context.UserDetails.FindAsync(_currentUser.UserId);

                    // Nếu chưa có chi tiết, tạo mới
                    if (detail == null)
                    {
                        detail = new UserDetail
                        {
                            UserId = _currentUser.UserId // Gán khóa chính
                        };
                        context.UserDetails.Add(detail);
                    }

                    // Cập nhật thông tin từ TextBox vào Model
                    detail.FullName = FullNameTextBox.Text;
                    detail.DateOfBirth = DobDatePicker.SelectedDate ?? DateTime.Now;
                    detail.Address = AddressTextBox.Text;
                    detail.Phone = PhoneTextBox.Text;

                    await context.SaveChangesAsync();
                } // Context được tự động đóng ở đây

                MessageBox.Show("Cập nhật thông tin thành công!");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi lưu thông tin: {ex.Message}");
            }
        }

        // Ghi chú: Xử lý nút "Đặt lại mật khẩu"
        private void ChangePasswordButton_Click(object sender, RoutedEventArgs e)
        {
            // Mở cửa sổ (Window) mới như một Dialog (hộp thoại)
            ChangePasswordWindow changePassWindow = new ChangePasswordWindow();
            changePassWindow.ShowDialog(); // .ShowDialog() sẽ khóa cửa sổ chính
        }
    }
}