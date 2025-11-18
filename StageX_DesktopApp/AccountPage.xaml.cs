using StageX_DesktopApp.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore; // <-- Dùng EF Core

namespace StageX_DesktopApp
{
    public partial class AccountPage : Page
    {
        public AccountPage()
        {
            InitializeComponent();
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadAccountsAsync();
        }

        /// <summary>
        /// Ghi chú: Tải danh sách Tài khoản (Chỉ Admin/Nhân viên)
        /// </summary>
        private async Task LoadAccountsAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    // Logic giống proc_get_staff_users()
                    var accounts = await context.Users
                                               .Where(u => u.Role == "Admin" || u.Role == "Nhân viên")
                                               .OrderBy(u => u.UserId)
                                               .ToListAsync();
                    AccountsGrid.ItemsSource = accounts;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải tài khoản: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Thêm STT cho bảng
        /// </summary>
        private void AccountsGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }

        /// <summary>
        /// Ghi chú: Nút "Hủy" hoặc "Làm mới"
        /// </summary>
        private void ClearButton_Click(object sender, RoutedEventArgs e)
        {
            FormTitle.Text = "Thêm tài khoản mới";
            SaveButton.Content = "Thêm tài khoản";
            ClearButton.Visibility = Visibility.Collapsed;

            UserIdTextBox.Text = "";
            AccountNameTextBox.Text = "";
            EmailTextBox.Text = "";
            PasswordBox.Password = "";
            RoleComboBox.SelectedIndex = -1;
            StatusComboBox.SelectedIndex = -1;

            AccountsGrid.SelectedItem = null;
        }

        /// <summary>
        /// Ghi chú: Nút "Cập nhật" (trong Bảng)
        /// </summary>
        private void EditButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is User userToEdit)
            {
                // 1. Đổ dữ liệu lên Form
                FormTitle.Text = "Chỉnh sửa tài khoản";
                UserIdTextBox.Text = userToEdit.UserId.ToString();
                AccountNameTextBox.Text = userToEdit.AccountName;
                EmailTextBox.Text = userToEdit.Email;

                PasswordBox.Password = ""; // Luôn xóa trống mật khẩu

                // 2. Chọn đúng ComboBox
                RoleComboBox.SelectedIndex = (userToEdit.Role == "Admin") ? 1 : 0;
                StatusComboBox.SelectedIndex = (userToEdit.Status == "khóa") ? 1 : 0;

                // 3. Đổi nút
                SaveButton.Content = "Lưu thay đổi";
                ClearButton.Visibility = Visibility.Visible;
            }
        }

        /// <summary>
        /// Ghi chú: (Dùng tạm) Click vào Bảng cũng là Sửa
        /// </summary>
        private void AccountsGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (AccountsGrid.SelectedItem is User userToEdit)
            {
                // 1. Đổ dữ liệu lên Form
                FormTitle.Text = "Chỉnh sửa tài khoản";
                UserIdTextBox.Text = userToEdit.UserId.ToString();
                AccountNameTextBox.Text = userToEdit.AccountName;
                EmailTextBox.Text = userToEdit.Email;

                PasswordBox.Password = ""; // Luôn xóa trống mật khẩu

                // 2. Chọn đúng ComboBox
                RoleComboBox.SelectedIndex = (userToEdit.Role == "Admin") ? 1 : 0;
                StatusComboBox.SelectedIndex = (userToEdit.Status == "khóa") ? 1 : 0;

                // 3. Đổi nút
                SaveButton.Content = "Lưu thay đổi";
                ClearButton.Visibility = Visibility.Visible;
            }
        }


        /// <summary>
        /// Ghi chú: Nút "Lưu" (Xử lý cả Thêm + Sửa)
        /// </summary>
        private async void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            // 1. Lấy dữ liệu
            string accountName = AccountNameTextBox.Text.Trim();
            string email = EmailTextBox.Text.Trim();
            string password = PasswordBox.Password;
            string role = (RoleComboBox.SelectedItem as ComboBoxItem)?.Content.ToString();
            string status = (StatusComboBox.SelectedItem as ComboBoxItem)?.Content.ToString();

            // 2. Kiểm tra (Validate)
            if (string.IsNullOrEmpty(accountName) || string.IsNullOrEmpty(email) ||
                string.IsNullOrEmpty(role) || string.IsNullOrEmpty(status))
            {
                MessageBox.Show("Vui lòng nhập Tên tài khoản, Email, Vai trò và Trạng thái!");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    // Logic SỬA (UPDATE)
                    if (int.TryParse(UserIdTextBox.Text, out int userId) && userId > 0)
                    {
                        var userToUpdate = await context.Users.FindAsync(userId);
                        if (userToUpdate == null) return;

                        // Cập nhật thông tin
                        userToUpdate.AccountName = accountName;
                        userToUpdate.Email = email;
                        userToUpdate.Role = role;
                        userToUpdate.Status = status;

                        // Chỉ cập nhật mật khẩu NẾU người dùng nhập
                        if (!string.IsNullOrEmpty(password))
                        {
                            userToUpdate.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
                        }
                    }
                    // Logic THÊM MỚI (ADD)
                    else
                    {
                        if (string.IsNullOrEmpty(password))
                        {
                            MessageBox.Show("Mật khẩu là bắt buộc khi thêm tài khoản mới!");
                            return;
                        }

                        // Hash mật khẩu mới
                        string newHash = BCrypt.Net.BCrypt.HashPassword(password);

                        var newUser = new User
                        {
                            AccountName = accountName,
                            Email = email,
                            PasswordHash = newHash,
                            Role = role,
                            Status = status,
                            IsVerified = true // Dòng này sẽ hết lỗi
                        };
                        context.Users.Add(newUser);
                    }

                    await context.SaveChangesAsync();
                    MessageBox.Show("Lưu tài khoản thành công!");
                }

                // 5. Tải lại Bảng và Làm mới Form
                await LoadAccountsAsync();
                ClearButton_Click(null, null);
            }
            catch (DbUpdateException ex) // Bắt lỗi (ví dụ: Trùng Email)
            {
                MessageBox.Show($"Lỗi khi lưu tài khoản: {ex.InnerException?.Message ?? ex.Message}");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi không xác định: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Nút "Xóa"
        /// </summary>
        private async void DeleteButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is User userToDelete)
            {
                // Ngăn người dùng tự xóa chính mình
                if (userToDelete.UserId == AuthSession.CurrentUser.UserId)
                {
                    MessageBox.Show("Bạn không thể tự xóa chính mình!");
                    return;
                }

                var result = MessageBox.Show($"Bạn có chắc muốn xóa tài khoản '{userToDelete.AccountName}'?",
                                             "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Warning);

                if (result == MessageBoxResult.Yes)
                {
                    try
                    {
                        using (var context = new AppDbContext())
                        {
                            var userToRemove = new User { UserId = userToDelete.UserId };
                            context.Users.Remove(userToRemove);
                            await context.SaveChangesAsync();
                        }
                        await LoadAccountsAsync();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Lỗi khi xóa: {ex.Message}");
                    }
                }
            }
        }
    }
}