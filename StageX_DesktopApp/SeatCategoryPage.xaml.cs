using StageX_DesktopApp.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore; 

namespace StageX_DesktopApp
{
    public partial class SeatCategoryPage : Page
    {
        private int _selectedCategoryId = 0;

        public SeatCategoryPage()
        {
            InitializeComponent();
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadCategoriesAsync();
        }

        /// <summary>
        /// Ghi chú: Tải danh sách Hạng ghế từ CSDL
        /// </summary>
        private async Task LoadCategoriesAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var categories = await context.SeatCategories
                                                   .OrderBy(c => c.CategoryId)
                                                   .ToListAsync();
                    CategoriesGrid.ItemsSource = categories;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải hạng ghế: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Thêm STT cho bảng
        /// </summary>
        private void CategoriesGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Thêm"
        /// </summary>
        

        /// <summary>
        /// Ghi chú: Xử lý nút "Chỉnh sửa" (trong Bảng)
        /// </summary>
        private void EditButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is SeatCategory categoryToEdit)
            {
                EditCategoryIdTextBox.Text = categoryToEdit.CategoryId.ToString();
                EditCategoryNameTextBox.Text = categoryToEdit.CategoryName;
                EditCategoryPriceTextBox.Text = categoryToEdit.BasePrice.ToString("F0"); // F0 để không có ".00"

                _selectedCategoryId = categoryToEdit.CategoryId;
                EditCategoryPanel.Visibility = Visibility.Visible;
            }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Lưu" (trong form "Chỉnh sửa")
        /// </summary>
        private async void SaveCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            string newName = EditCategoryNameTextBox.Text.Trim();
            if (_selectedCategoryId == 0 || string.IsNullOrEmpty(newName) || !decimal.TryParse(EditCategoryPriceTextBox.Text, out decimal newPrice))
            {
                MessageBox.Show("Vui lòng nhập tên và giá hợp lệ.");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    var categoryToUpdate = await context.SeatCategories.FindAsync(_selectedCategoryId);
                    if (categoryToUpdate != null)
                    {
                        categoryToUpdate.CategoryName = newName;
                        categoryToUpdate.BasePrice = newPrice;

                        await context.SaveChangesAsync();
                        MessageBox.Show("Cập nhật hạng ghế thành công!");

                        await LoadCategoriesAsync();
                        CancelEditButton_Click(null, null);
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi cập nhật: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Hủy"
        /// </summary>
        private void CancelEditButton_Click(object sender, RoutedEventArgs e)
        {
            EditCategoryIdTextBox.Text = "";
            EditCategoryNameTextBox.Text = "";
            EditCategoryPriceTextBox.Text = "";
            _selectedCategoryId = 0;
            EditCategoryPanel.Visibility = Visibility.Collapsed;
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Xóa" (trong Bảng)
        /// </summary>
        private async void DeleteButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is SeatCategory categoryToDelete)
            {
                var result = MessageBox.Show($"Bạn có chắc muốn xóa hạng ghế '{categoryToDelete.CategoryName}'?",
                                             "Xác nhận xóa",
                                             MessageBoxButton.YesNo,
                                             MessageBoxImage.Warning);

                if (result == MessageBoxResult.Yes)
                {
                    try
                    {
                        using (var context = new AppDbContext())
                        {
                            // Ghi chú: Với EF Core, chúng ta tạo 1 đối tượng rỗng
                            // chỉ với ID, rồi Remove nó
                            var categoryToRemove = new SeatCategory { CategoryId = categoryToDelete.CategoryId };
                            context.SeatCategories.Remove(categoryToRemove);
                            await context.SaveChangesAsync();
                        }
                        await LoadCategoriesAsync();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Lỗi khi xóa: {ex.Message}.\nLưu ý: Bạn không thể xóa hạng ghế nếu nó đang được gán cho một ghế.");
                    }
                }
            }
        }

        private void TextBox_GotFocus(object sender, RoutedEventArgs e)
        {
            TextBox textBox = sender as TextBox;
            if (textBox == null) return;

            // Nếu nội dung là chữ placeholder, thì xóa nó đi
            if (textBox.Text == "Tên hạng (ví dụ: VIP 2)" || textBox.Text == "Giá phụ thu (ví dụ: 50000)")
            {
                textBox.Text = "";
                textBox.Foreground = System.Windows.Media.Brushes.White; // Đổi chữ thành màu trắng
            }
        }

        // Ghi chú: Hàm này gọi khi click ra khỏi ô "Tên hạng"
        private void AddCategoryNameTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            TextBox textBox = sender as TextBox;
            // Nếu ô bị bỏ trống, hiện lại chữ placeholder
            if (string.IsNullOrWhiteSpace(textBox.Text))
            {
                textBox.Text = "Tên hạng (ví dụ: VIP 2)";
                textBox.Foreground = System.Windows.Media.Brushes.Gray;
            }
        }

        // Ghi chú: Hàm này gọi khi click ra khỏi ô "Giá phụ thu"
        private void AddCategoryPriceTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            TextBox textBox = sender as TextBox;
            // Nếu ô bị bỏ trống, hiện lại chữ placeholder
            if (string.IsNullOrWhiteSpace(textBox.Text))
            {
                textBox.Text = "Giá phụ thu (ví dụ: 50000)";
                textBox.Foreground = System.Windows.Media.Brushes.Gray;
            }
        }

        // Ghi chú: Sửa lại hàm "Thêm" để kiểm tra placeholder
        private async void AddCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            string categoryName = AddCategoryNameTextBox.Text.Trim();
            string categoryPriceStr = AddCategoryPriceTextBox.Text.Trim();

            // GHI CHÚ: Kiểm tra xem người dùng đã nhập chưa (không phải chữ placeholder)
            if (string.IsNullOrEmpty(categoryName) || categoryName == "Tên hạng (ví dụ: VIP 2)" ||
                string.IsNullOrEmpty(categoryPriceStr) || categoryPriceStr == "Giá phụ thu (ví dụ: 50000)" ||
                !decimal.TryParse(categoryPriceStr, out decimal basePrice))
            {
                MessageBox.Show("Tên hạng ghế và giá phụ thu không hợp lệ!");
                return;
            }

            try
            {
                // Logic này giống file PHP
                var newCategory = new SeatCategory
                {
                    CategoryName = categoryName,
                    BasePrice = basePrice,
                    ColorClass = "temp_color" // (Màu sắc sẽ được gán ngẫu nhiên sau)
                };

                using (var context = new AppDbContext())
                {
                    context.SeatCategories.Add(newCategory);
                    await context.SaveChangesAsync();
                }

                MessageBox.Show("Thêm hạng ghế mới thành công!");
                AddCategoryNameTextBox.Text = "Tên hạng (ví dụ: VIP 2)";
                AddCategoryPriceTextBox.Text = "Giá phụ thu (ví dụ: 50000)";
                await LoadCategoriesAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi thêm hạng ghế: {ex.Message}");
            }
            try
            {
                var newCategory = new SeatCategory
                {
                    CategoryName = categoryName,
                    BasePrice = basePrice,
                    ColorClass = "temp_color"
                };

                using (var context = new AppDbContext())
                {
                    context.SeatCategories.Add(newCategory);
                    await context.SaveChangesAsync();
                }

                MessageBox.Show("Thêm hạng ghế mới thành công!");

                // GHI CHÚ: Reset 2 ô về trạng thái placeholder
                AddCategoryNameTextBox_LostFocus(AddCategoryNameTextBox, null);
                AddCategoryPriceTextBox_LostFocus(AddCategoryPriceTextBox, null);

                await LoadCategoriesAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi thêm hạng ghế: {ex.Message}");
            }
        }
    }
}