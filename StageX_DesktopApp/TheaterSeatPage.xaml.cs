using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.EntityFrameworkCore; // <-- Dùng EF Core

namespace StageX_DesktopApp
{
    public partial class TheaterSeatPage : Page
    {
        private Theater _selectedTheater; // Biến lưu rạp đang chọn
        private int _selectedCategoryId = 0; // Biến lưu hạng ghế đang sửa

        public TheaterSeatPage()
        {
            InitializeComponent();
        }

        /// <summary>
        /// Ghi chú: Hàm chạy KHI TRANG ĐƯỢC TẢI LÊN
        /// </summary>
        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadCategoriesAsync(); // Tải Bảng Hạng ghế (bên trái)
            await LoadTheatersAsync();   // Tải Bảng Rạp (bên phải)
        }

        // ==========================================================
        // KHU VỰC 1: QUẢN LÝ RẠP (THÊM, SỬA, XÓA RẠP)
        // ==========================================================

        /// <summary>
        /// Ghi chú: Tải Bảng Rạp (bên phải-dưới)
        /// </summary>
        private async Task LoadTheatersAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var theaters = await context.Theaters
                                               .OrderBy(t => t.TheaterId)
                                               .ToListAsync();
                    TheatersGrid.ItemsSource = theaters;
                }
            }
            catch (Exception ex) { MessageBox.Show($"Lỗi tải Rạp: {ex.Message}"); }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Tạo" (Form Tạo rạp)
        /// </summary>
        private async void AddTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            string theaterName = AddTheaterNameTextBox.Text.Trim();
            if (!int.TryParse(AddTheaterRowsTextBox.Text, out int rows) || rows <= 0 ||
                !int.TryParse(AddTheaterColsTextBox.Text, out int cols) || cols <= 0 ||
                string.IsNullOrEmpty(theaterName))
            {
                MessageBox.Show("Tên rạp, Số hàng và Số cột (phải là số > 0) không hợp lệ!");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    // Ghi chú: Gọi Stored Procedure 'proc_create_theater' từ CSDL
                    //
                    // Nó sẽ tự động tạo rạp VÀ tạo các ghế (seats) cho rạp đó
                    await context.Database.ExecuteSqlRawAsync(
                        "CALL proc_create_theater({0}, {1}, {2})",
                        theaterName, rows, cols);

                    // GHI CHÚ: THỰC HIỆN YÊU CẦU CỦA BẠN (Bỏ qua Phê duyệt)
                    // Tìm rạp vừa tạo (đang 'Chờ xử lý') và set thành 'Đã hoạt động'
                    var newTheater = await context.Theaters.FirstOrDefaultAsync(
                        t => t.Name == theaterName && t.Status == "Chờ xử lý");

                    if (newTheater != null)
                    {
                        newTheater.Status = "Đã hoạt động";
                        await context.SaveChangesAsync();
                    }
                }

                MessageBox.Show("Thêm rạp mới thành công!");
                AddTheaterNameTextBox.Text = "";
                AddTheaterRowsTextBox.Text = "";
                AddTheaterColsTextBox.Text = "";
                await LoadTheatersAsync();
            }
            catch (Exception ex) { MessageBox.Show($"Lỗi khi thêm rạp: {ex.Message}"); }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Xóa" (trong Bảng Rạp)
        /// </summary>
        private async void DeleteTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Theater theaterToDelete)
            {
                var result = MessageBox.Show($"Bạn có chắc muốn xóa rạp '{theaterToDelete.Name}'?", "Xác nhận xóa", MessageBoxButton.YesNo);
                if (result != MessageBoxResult.Yes) return;

                try
                {
                    using (var context = new AppDbContext())
                    {
                        // Ghi chú: Chúng ta phải xóa ghế (seats) trước,
                        // sau đó mới xóa rạp (theaters)
                        await context.Database.ExecuteSqlRawAsync(
                            "DELETE FROM seats WHERE theater_id = {0}",
                            theaterToDelete.TheaterId);

                        var theaterToRemove = new Theater { TheaterId = theaterToDelete.TheaterId };
                        context.Theaters.Remove(theaterToRemove);
                        await context.SaveChangesAsync();
                    }
                    await LoadTheatersAsync();
                    CancelEditButton_Click(null, null); // Ẩn form sửa (nếu đang mở)
                }
                catch (Exception ex) { MessageBox.Show($"Lỗi khi xóa rạp: {ex.Message}"); }
            }
        }

        // ==========================================================
        // KHU VỰC 2: QUẢN LÝ HẠNG GHẾ (CRUD)
        // ==========================================================

        /// <summary>
        /// Ghi chú: Tải Bảng Hạng ghế (bên trái-trên)
        /// </summary>
        private async Task LoadCategoriesAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var categories = await context.SeatCategories.OrderBy(c => c.CategoryId).ToListAsync();
                    CategoriesGrid.ItemsSource = categories;

                    // Ghi chú: Đổ dữ liệu vào ComboBox "Quản lý ghế"
                    var categoriesForAssign = categories.ToList();
                    categoriesForAssign.Insert(0, new SeatCategory { CategoryId = 0, CategoryName = "-- Không áp dụng --" });
                    AssignCategoryComboBox.ItemsSource = categoriesForAssign;
                }
            }
            catch (Exception ex) { MessageBox.Show($"Lỗi tải Hạng ghế: {ex.Message}"); }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Thêm hạng ghế"
        /// </summary>
        private async void AddCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            string categoryName = AddCategoryNameTextBox.Text.Trim();
            string categoryPriceStr = AddCategoryPriceTextBox.Text.Trim();

            // Ghi chú: Kiểm tra xem người dùng đã nhập chưa (không phải chữ placeholder)
            if (string.IsNullOrEmpty(categoryName) || categoryName == "Tên hạng ghế" ||
                string.IsNullOrEmpty(categoryPriceStr) || categoryPriceStr == "Giá cơ bản" ||
                !decimal.TryParse(categoryPriceStr, out decimal basePrice))
            {
                MessageBox.Show("Tên hạng ghế và giá cơ bản không hợp lệ!");
                return;
            }

            try
            {
                // GHI CHÚ: Tự động tạo 1 màu Hex 6 chữ số ngẫu nhiên
                string randomColorHex = string.Format("{0:X6}", new Random().Next(0x1000000));

                var newCategory = new SeatCategory
                {
                    CategoryName = categoryName,
                    BasePrice = basePrice,
                    ColorClass = randomColorHex // <-- Gán màu random vào đây
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

                await LoadCategoriesAsync(); // Tải lại Bảng Hạng ghế
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi thêm hạng ghế: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Chỉnh sửa" (Hạng ghế)
        /// </summary>
        private void EditCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            // (Hàm này chúng ta sẽ viết sau, khi làm form Sửa Hạng ghế)
            MessageBox.Show("Chức năng sửa hạng ghế sẽ được thêm sau.");
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Xóa" (Hạng ghế)
        /// </summary>
        private async void DeleteCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is SeatCategory categoryToDelete)
            {
                var result = MessageBox.Show($"Bạn có chắc muốn xóa hạng ghế '{categoryToDelete.CategoryName}'?", "Xác nhận xóa", MessageBoxButton.YesNo);
                if (result != MessageBoxResult.Yes) return;

                try
                {
                    using (var context = new AppDbContext())
                    {
                        // Kiểm tra xem hạng ghế này có đang được dùng không
                        bool isUsed = await context.Seats.AnyAsync(s => s.CategoryId == categoryToDelete.CategoryId);
                        if (isUsed)
                        {
                            MessageBox.Show("Không thể xóa. Hạng ghế này đang được gán cho một số ghế trong rạp.");
                            return;
                        }

                        var categoryToRemove = new SeatCategory { CategoryId = categoryToDelete.CategoryId };
                        context.SeatCategories.Remove(categoryToRemove);
                        await context.SaveChangesAsync();
                    }
                    await LoadCategoriesAsync();
                }
                catch (Exception ex) { MessageBox.Show($"Lỗi khi xóa hạng ghế: {ex.Message}"); }
            }
        }

        // ==========================================================
        // KHU VỰC 3 & 4: SƠ ĐỒ GHẾ & SỬA RẠP
        // ==========================================================

        /// <summary>
        /// Ghi chú: Xử lý nút "Sơ đồ" (trong Bảng Rạp)
        /// </summary>
        private async void EditTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Theater theaterToEdit)
            {
                _selectedTheater = theaterToEdit; // Lưu rạp đang chọn

                // 1. Hiển thị Form Sửa Rạp (bên trái-dưới)
                EditTheaterPanel.Visibility = Visibility.Visible;
                EditTheaterIdTextBox.Text = _selectedTheater.TheaterId.ToString();
                EditTheaterNameTextBox.Text = _selectedTheater.Name;
                ModifyRowsTextBox.Text = "0";
                ModifyColsTextBox.Text = "0";

                // 2. Tải sơ đồ ghế
                await LoadSeatMapAsync(_selectedTheater.TheaterId);
            }
        }

        /// <summary>
        /// Ghi chú: Hàm vẽ Sơ đồ ghế (bên phải-trên)
        /// </summary>
        private async Task LoadSeatMapAsync(int theaterId)
        {
            SeatMapWrapPanel.Children.Clear(); // Xóa sơ đồ cũ
            SeatMapTitle.Text = $"Sơ đồ ghế cho rạp: {_selectedTheater.Name}";

            List<Seat> seats;
            List<string> rowChars;
            List<int> seatNumbers;

            using (var context = new AppDbContext())
            {
                // Tải tất cả ghế của rạp này, sắp xếp theo Hàng (A,B,C) rồi đến Số (1,2,3)
                //
                seats = await context.Seats
                    .Where(s => s.TheaterId == theaterId)
                    .Include(s => s.SeatCategory) // Tải kèm thông tin Hạng ghế (để lấy màu)
                    .OrderBy(s => s.RowChar)
                    .ThenBy(s => s.SeatNumber)
                    .ToListAsync();
            }

            if (!seats.Any())
            {
                SeatMapWrapPanel.Children.Add(new TextBlock { Text = "Rạp này chưa có ghế.", Foreground = Brushes.Gray });
                // Xóa sạch ComboBox nếu rạp rỗng
                AssignRowComboBox.ItemsSource = null;
                AssignSeatStartComboBox.ItemsSource = null;
                AssignSeatEndComboBox.ItemsSource = null;
                return;
            }

            // Lấy danh sách Hàng (A, B, C) và Cột (1, 2, 3)
            rowChars = seats.Select(s => s.RowChar).Distinct().ToList();
            seatNumbers = seats.Select(s => s.SeatNumber).Distinct().OrderBy(n => n).ToList();
            int maxCols = seatNumbers.Any() ? seatNumbers.Max() : 0;

            // Dùng Grid (lưới) để vẽ cho chính xác
            var seatGrid = new Grid();

            // Tạo Cột
            seatGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(30) }); // Cột 0: Tên hàng (A, B)
            for (int i = 0; i < maxCols; i++)
            {
                seatGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto }); // Cột cho ghế
            }

            // Tạo Hàng
            for (int i = 0; i < rowChars.Count; i++)
            {
                seatGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Hàng cho ghế
            }

            // Đổ Ghế (Button) vào Grid
            foreach (var seat in seats)
            {
                var seatButton = new Button
                {
                    Content = seat.RealSeatNumber > 0 ? seat.RealSeatNumber.ToString() : "x",
                    ToolTip = $"Ghế: {seat.RowChar}{seat.SeatNumber} | Hạng: {seat.SeatCategory?.CategoryName ?? "Chưa gán"}",
                    MinWidth = 30,
                    MinHeight = 30,
                    Margin = new Thickness(2),
                    FontWeight = FontWeights.Bold,
                    Foreground = Brushes.Black, // Chữ màu đen

                    // GHI CHÚ: Lấy màu trực tiếp từ Model (DisplayColor)
                    Background = seat.SeatCategory?.DisplayColor ?? Brushes.LightGray
                };

                int rowIndex = rowChars.IndexOf(seat.RowChar);
                int colIndex = seatNumbers.IndexOf(seat.SeatNumber) + 1; // +1 vì cột 0 là tên hàng

                Grid.SetRow(seatButton, rowIndex);
                Grid.SetColumn(seatButton, colIndex);
                seatGrid.Children.Add(seatButton);
            }

            // Thêm Tên Hàng (A, B, C...)
            for (int i = 0; i < rowChars.Count; i++)
            {
                var rowLabel = new TextBlock
                {
                    Text = rowChars[i],
                    FontWeight = FontWeights.Bold,
                    Foreground = Brushes.Gray,
                    VerticalAlignment = VerticalAlignment.Center,
                    HorizontalAlignment = HorizontalAlignment.Center
                };
                Grid.SetRow(rowLabel, i);
                Grid.SetColumn(rowLabel, 0);
                seatGrid.Children.Add(rowLabel);
            }

            SeatMapWrapPanel.Children.Add(seatGrid); // Thêm Grid (sơ đồ) vào WrapPanel

            // Cập nhật ComboBox "Quản lý ghế"
            AssignRowComboBox.ItemsSource = rowChars;
            AssignSeatStartComboBox.ItemsSource = seatNumbers;
            AssignSeatEndComboBox.ItemsSource = seatNumbers;
        }

        // Hàm helper để đổi màu HEX (ví dụ c0d6efd) thành màu WPF
        private SolidColorBrush TryParseHtmlColor(string htmlColor)
        {
            if (string.IsNullOrEmpty(htmlColor)) return null;
            // Xóa chữ 'c' ở đầu nếu có (từ CSDL PHP)
            if (htmlColor.StartsWith("c"))
            {
                htmlColor = htmlColor.Substring(1);
            }
            try
            {
                return (SolidColorBrush)new BrushConverter().ConvertFrom("#" + htmlColor);
            }
            catch { return Brushes.LightGray; }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Lưu thay đổi" (Sửa Rạp)
        /// </summary>
        private async void SaveTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            // Logic này gọi Stored Procedure 'proc_modify_theater_size'
            string newName = EditTheaterNameTextBox.Text.Trim();
            if (!int.TryParse(ModifyRowsTextBox.Text, out int addRows) ||
                !int.TryParse(ModifyColsTextBox.Text, out int addCols) ||
                string.IsNullOrEmpty(newName))
            {
                MessageBox.Show("Tên rạp và số lượng thêm/bớt phải hợp lệ!");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    // 1. Sửa tên (dùng EF Core)
                    var theater = await context.Theaters.FindAsync(_selectedTheater.TheaterId);
                    if (theater != null && theater.Name != newName)
                    {
                        theater.Name = newName;
                        await context.SaveChangesAsync();
                    }

                    // 2. Sửa kích thước (dùng Stored Procedure)
                    if (addRows != 0 || addCols != 0)
                    {
                        await context.Database.ExecuteSqlRawAsync(
                            "CALL proc_modify_theater_size({0}, {1}, {2})",
                            _selectedTheater.TheaterId, addRows, addCols);
                    }
                }

                MessageBox.Show("Cập nhật rạp thành công!");
                await LoadTheatersAsync(); // Tải lại bảng Rạp
                await LoadSeatMapAsync(_selectedTheater.TheaterId); // Tải lại sơ đồ ghế
            }
            catch (Exception ex) { MessageBox.Show($"Lỗi khi sửa rạp: {ex.Message}"); }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Đổi" (Gán Hạng ghế cho Ghế)
        /// </summary>
        private async void AssignSeatButton_Click(object sender, RoutedEventArgs e)
        {
            // Logic này gọi Stored Procedure 'proc_update_seat_category_range'
            if (AssignCategoryComboBox.SelectedValue == null ||
                AssignRowComboBox.SelectedValue == null ||
                AssignSeatStartComboBox.SelectedValue == null ||
                AssignSeatEndComboBox.SelectedValue == null)
            {
                MessageBox.Show("Vui lòng chọn đầy đủ thông tin (Hạng, Hàng, Ghế BĐ, Ghế KT).");
                return;
            }

            try
            {
                int categoryId = (int)AssignCategoryComboBox.SelectedValue;
                string rowChar = (string)AssignRowComboBox.SelectedValue;
                int startSeat = (int)AssignSeatStartComboBox.SelectedValue;
                int endSeat = (int)AssignSeatEndComboBox.SelectedValue;

                using (var context = new AppDbContext())
                {
                    await context.Database.ExecuteSqlRawAsync(
                        "CALL proc_update_seat_category_range({0}, {1}, {2}, {3}, {4})",
                        _selectedTheater.TheaterId, rowChar, startSeat, endSeat, categoryId);
                }

                MessageBox.Show("Gán hạng ghế thành công!");
                await LoadSeatMapAsync(_selectedTheater.TheaterId); // Tải lại sơ đồ
            }
            catch (Exception ex) { MessageBox.Show($"Lỗi khi gán hạng ghế: {ex.Message}"); }
        }

        /// <summary>
        /// Ghi chú: Xử lý nút "Hủy" (Form Sửa Rạp)
        /// </summary>
        private void CancelEditButton_Click(object sender, RoutedEventArgs e)
        {
            EditTheaterPanel.Visibility = Visibility.Collapsed;
            _selectedTheater = null;
            SeatMapWrapPanel.Children.Clear();
            SeatMapTitle.Text = "Sơ đồ ghế...";
        }

        // --- Logic cho Placeholder (Chữ mờ) ---
        private void Placeholder_GotFocus(object sender, RoutedEventArgs e)
        {
            TextBox tb = sender as TextBox;
            if (tb.Text == "Tên hạng ghế" || tb.Text == "Giá cơ bản")
            {
                tb.Text = "";
                tb.Foreground = Brushes.White;
            }
        }
        private void AddCategoryNameTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            TextBox tb = sender as TextBox;
            if (string.IsNullOrWhiteSpace(tb.Text))
            {
                tb.Text = "Tên hạng ghế";
                tb.Foreground = Brushes.Gray;
            }
        }
        private void AddCategoryPriceTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            TextBox tb = sender as TextBox;
            if (string.IsNullOrWhiteSpace(tb.Text))
            {
                tb.Text = "Giá cơ bản";
                tb.Foreground = Brushes.Gray;
            }
        }

        // (Placeholder cho Form Thêm Rạp)
        private void AddTheaterNameTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            TextBox tb = sender as TextBox;
            if (string.IsNullOrWhiteSpace(tb.Text))
            {
                tb.Text = "Tên rạp (ví dụ: Rạp 1)";
                tb.Foreground = Brushes.Gray;
            }
        }
        private void AddTheaterSeatsTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            TextBox tb = sender as TextBox;
            if (string.IsNullOrWhiteSpace(tb.Text))
            {
                tb.Text = "Tổng số ghế (ví dụ: 100)";
                tb.Foreground = Brushes.Gray;
            }
        }

        // --- Logic cho Bảng (STT) ---
        private void CategoriesGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }
        private void TheatersGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }

        // (Hàm này không dùng nữa, chúng ta dùng nút "Sơ đồ")
        private void TheatersGrid_SelectionChanged(object sender, SelectionChangedEventArgs e) { }
    }
}