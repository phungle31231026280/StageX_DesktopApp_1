using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.EntityFrameworkCore;

namespace StageX_DesktopApp
{
    public partial class TheaterSeatPage : Page
    {
        private Theater _selectedTheater;
        private bool _isCreatingNew = false;
        private string _newTheaterName = "";
        private List<Seat> _tempSeats = new List<Seat>();
        private List<Seat> _selectedSeats = new List<Seat>();
        private List<SeatCategory> _allCategories = new List<SeatCategory>();
        private int _editingCategoryId = 0;

        public TheaterSeatPage()
        {
            InitializeComponent();
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadCategoriesAsync();
            await LoadTheatersAsync();
        }

        // --- TẢI DỮ LIỆU ---
        private async Task LoadCategoriesAsync()
        {
            using (var context = new AppDbContext())
            {
                _allCategories = await context.SeatCategories.OrderBy(c => c.CategoryId).ToListAsync();
                CategoriesGrid.ItemsSource = _allCategories;

                var listForCombo = _allCategories.ToList();
                listForCombo.Insert(0, new SeatCategory { CategoryId = 0, CategoryName = "-- Chưa gán hạng --" });
                AssignCategoryComboBox.ItemsSource = listForCombo;
            }
        }

        private async Task LoadTheatersAsync()
        {
            using (var context = new AppDbContext())
            {
                var theaters = await context.Theaters
                                           .Include(t => t.Performances)
                                           .OrderBy(t => t.TheaterId)
                                           .ToListAsync();
                foreach (var t in theaters)
                {
                    t.CanDelete = (t.Performances == null || !t.Performances.Any());
                    bool hasPast = t.Performances != null && t.Performances.Any(p => p.PerformanceDate < DateTime.Now);
                    t.CanEdit = !hasPast;
                }
                TheatersGrid.ItemsSource = theaters;
            }
        }

        // --- SỰ KIỆN CHỌN HÀNG (HIỆN SƠ ĐỒ) ---
        private async void TheatersGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (TheatersGrid.SelectedItem is Theater theater)
            {
                _selectedTheater = theater;
                _isCreatingNew = false;

                // Tải sơ đồ ghế ngay khi chọn hàng
                await LoadSeatMapFromDB(theater.TheaterId);
                SeatMapTitle.Text = $"Sơ đồ rạp: {theater.Name}";

                // Nếu Form sửa đang mở, hãy cập nhật thông tin form theo rạp mới chọn
                if (EditTheaterPanel.Visibility == Visibility.Visible)
                {
                    PrepareEditForm(theater);
                }
            }
        }

        // Hàm phụ trợ: Tải ghế từ DB lên RAM
        private async Task LoadSeatMapFromDB(int theaterId)
        {
            using (var context = new AppDbContext())
            {
                _tempSeats = await context.Seats
                                    .Where(s => s.TheaterId == theaterId)
                                    .Include(s => s.SeatCategory)
                                    .OrderBy(s => s.RowChar).ThenBy(s => s.SeatNumber)
                                    .ToListAsync();
            }
            DrawSeatMap(_tempSeats);
            UpdateAssignComboBoxes(_tempSeats);
        }

        // --- SỰ KIỆN NÚT SỬA (MỞ FORM) ---
        private async void EditTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Theater theater)
            {
                _isCreatingNew = false;
                _selectedTheater = theater;

                // Tải sơ đồ ghế
                await LoadSeatMapFromDB(theater.TheaterId);
                SeatMapTitle.Text = $"Sơ đồ rạp: {theater.Name}";

                // Mở Form Sửa
                PrepareEditForm(theater);
            }
        }

        private void PrepareEditForm(Theater theater)
        {
            EditTheaterPanel.Visibility = Visibility.Visible;
            RenameTheaterPanel.Visibility = Visibility.Visible;
            EditTheaterNameTextBox.Text = theater.Name;
            SaveNewTheaterButton.Visibility = Visibility.Collapsed;

            SetEditMode(true);
        }

        // --- CHẾ ĐỘ TẠO MỚI ---
        private void PreviewTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            string name = AddTheaterNameTextBox.Text.Trim();
            if (!int.TryParse(AddTheaterRowsTextBox.Text, out int rows) || rows <= 0 ||
                !int.TryParse(AddTheaterColsTextBox.Text, out int cols) || cols <= 0 ||
                string.IsNullOrEmpty(name) || name.StartsWith("Tên rạp"))
            {
                MessageBox.Show("Thông tin không hợp lệ!");
                return;
            }

            _isCreatingNew = true;
            _newTheaterName = name;
            _selectedTheater = null;
            _tempSeats.Clear();
            TheatersGrid.SelectedItem = null; // Bỏ chọn bảng

            for (int r = 1; r <= rows; r++)
            {
                char rowChar = (char)('A' + r - 1);
                for (int c = 1; c <= cols; c++)
                {
                    _tempSeats.Add(new Seat { RowChar = rowChar.ToString(), SeatNumber = c, RealSeatNumber = c });
                }
            }

            SeatMapTitle.Text = $"[XEM TRƯỚC] {name} ({rows}x{cols}) - CHƯA LƯU";
            DrawSeatMap(_tempSeats);

            EditTheaterPanel.Visibility = Visibility.Visible;
            RenameTheaterPanel.Visibility = Visibility.Collapsed;
            SaveNewTheaterButton.Visibility = Visibility.Visible;

            SetEditMode(true); // Luôn cho phép sửa khi tạo mới
            UpdateAssignComboBoxes(_tempSeats);
            MessageBox.Show("Đang ở chế độ tạo mới. Hãy gán Hạng ghế và Lưu!");
        }

        // --- CÁC HÀM LOGIC KHÁC (GIỮ NGUYÊN) ---

        private void SetEditMode(bool isEditable)
        {
            EditPanelTitle.Text = isEditable ? (_isCreatingNew ? "Cấu hình Rạp Mới" : "Chỉnh sửa Rạp & Ghế") : "Chi tiết Rạp (Chỉ xem)";
            RenameTheaterPanel.IsEnabled = isEditable;
            AssignCategoryComboBox.IsEnabled = isEditable;
            AssignRowComboBox.IsEnabled = isEditable;
            AssignSeatStartComboBox.IsEnabled = isEditable;
            AssignSeatEndComboBox.IsEnabled = isEditable;
            AssignSeatButton.IsEnabled = isEditable;
            SelectRangeButton.IsEnabled = isEditable;
            RemoveSelectedSeatsButton.Visibility = (isEditable && _isCreatingNew) ? Visibility.Visible : Visibility.Collapsed;
        }

        // --- LOGIC VẼ SƠ ĐỒ
        private void DrawSeatMap(List<Seat> seats)
        {
            SeatMapWrapPanel.Children.Clear();
            _selectedSeats.Clear();

            var grid = new Grid();

            // 1. Lấy danh sách Hàng và Cột tối đa
            var rows = seats.Select(s => s.RowChar).Distinct().OrderBy(r => r).ToList();
            int maxSeatNum = seats.Any() ? seats.Max(s => s.SeatNumber) : 0;

            // 2. Tạo Cột cho Grid (Dựa trên số ghế lớn nhất để giữ khung)
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(30) }); // Cột tên hàng
            for (int c = 1; c <= maxSeatNum; c++)
            {
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            }

            // 3. Tạo Hàng
            foreach (var r in rows) grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Hàng số cột

            // 4. Vẽ Tên Hàng (A, B...)
            for (int i = 0; i < rows.Count; i++)
            {
                var txt = new TextBlock
                {
                    Text = rows[i],
                    FontWeight = FontWeights.Bold,
                    VerticalAlignment = VerticalAlignment.Center,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Foreground = Brushes.Gray,
                    FontSize = 14
                };
                Grid.SetRow(txt, i); Grid.SetColumn(txt, 0); grid.Children.Add(txt);
            }

            // ==========================================================
            // LOGIC MỚI: TÍNH LẠI "SỐ THỰC TẾ" (RealSeatNumber)
            // ==========================================================
            foreach (var row in rows)
            {
                // Lấy tất cả ghế trong hàng này, sắp xếp theo vị trí
                var seatsInRow = seats.Where(s => s.RowChar == row).OrderBy(s => s.SeatNumber).ToList();

                // Đếm lại từ 1 (bỏ qua các ghế đã bị xóa/lỗ hổng)
                int currentCount = 1;
                foreach (var seat in seatsInRow)
                {
                    // Cập nhật số thực tế cho ghế (để hiển thị A1, A2...)
                    seat.RealSeatNumber = currentCount;
                    currentCount++;
                }
            }

            // 5. Vẽ Ghế
            foreach (var seat in seats)
            {
                Brush bg = Brushes.Gray;
                if (seat.CategoryId != null && seat.CategoryId > 0)
                {
                    var cat = _allCategories.FirstOrDefault(c => c.CategoryId == seat.CategoryId);
                    if (cat != null) bg = cat.DisplayColor;
                }

                // Hiển thị tên: Hàng + Số thực tế (đã dồn)
                // Ví dụ: Ghế ở cột 3 nhưng là ghế thứ 2 trong hàng -> Hiện "A2"
                string content = $"{seat.RowChar}{seat.RealSeatNumber}";

                var btn = new Button
                {
                    Content = content,
                    Width = 35,  // GHI CHÚ: Đã chỉnh nhỏ lại (vừa đủ chữ A10)
                    Height = 30,
                    Margin = new Thickness(2),
                    Background = bg,
                    Foreground = Brushes.Black,
                    FontWeight = FontWeights.Bold,
                    FontSize = 11,
                    Tag = seat
                };

                btn.Click += SeatButton_Click;

                int rIdx = rows.IndexOf(seat.RowChar);
                int cIdx = seat.SeatNumber; // Vị trí cột vẫn giữ nguyên theo số gốc

                Grid.SetRow(btn, rIdx);
                Grid.SetColumn(btn, cIdx);
                grid.Children.Add(btn);
            }

            // 6. Vẽ Số Cột (1, 2, 3...) ở dưới
            int lastRowIndex = rows.Count;
            for (int i = 1; i <= maxSeatNum; i++)
            {
                var colNumTxt = new TextBlock
                {
                    Text = i.ToString(),
                    Foreground = Brushes.Gray,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Margin = new Thickness(0, 5, 0, 0),
                    FontSize = 10
                };
                Grid.SetRow(colNumTxt, lastRowIndex); Grid.SetColumn(colNumTxt, i); grid.Children.Add(colNumTxt);
            }

            SeatMapWrapPanel.Children.Add(grid);
        }

        private void SeatButton_Click(object sender, RoutedEventArgs e)
        {
            var btn = sender as Button; var seat = btn.Tag as Seat; if (seat == null) return;
            if (_selectedSeats.Contains(seat)) _selectedSeats.Remove(seat); else _selectedSeats.Add(seat);
            UpdateVisualSelection();
        }

        private void UpdateVisualSelection()
        {
            if (SeatMapWrapPanel.Children.Count > 0 && SeatMapWrapPanel.Children[0] is Grid g)
            {
                foreach (var c in g.Children) if (c is Button b && b.Tag is Seat s)
                    {
                        b.BorderThickness = _selectedSeats.Contains(s) ? new Thickness(3) : new Thickness(0);
                        b.BorderBrush = Brushes.Red;
                    }
            }
        }

        private void UpdateAssignComboBoxes(List<Seat> seats)
        {
            var rows = seats.Select(s => s.RowChar).Distinct().OrderBy(r => r).ToList();
            var nums = seats.Select(s => s.SeatNumber).Distinct().OrderBy(n => n).ToList();
            AssignRowComboBox.ItemsSource = rows;
            AssignSeatStartComboBox.ItemsSource = nums;
            AssignSeatEndComboBox.ItemsSource = nums;
        }

        private void SelectRangeButton_Click(object sender, RoutedEventArgs e)
        {
            if (AssignRowComboBox.SelectedValue == null) return;
            string row = (string)AssignRowComboBox.SelectedValue;
            int start = (int)(AssignSeatStartComboBox.SelectedValue ?? 0);
            int end = (int)(AssignSeatEndComboBox.SelectedValue ?? 100);
            foreach (var s in _tempSeats.Where(x => x.RowChar == row && x.SeatNumber >= start && x.SeatNumber <= end))
                if (!_selectedSeats.Contains(s)) _selectedSeats.Add(s);
            UpdateVisualSelection();
        }

        private async void AssignSeatButton_Click(object sender, RoutedEventArgs e)
        {
            if (AssignCategoryComboBox.SelectedValue == null || _selectedSeats.Count == 0) { MessageBox.Show("Chọn hạng & ghế!"); return; }
            int catId = (int)AssignCategoryComboBox.SelectedValue;
            foreach (var s in _selectedSeats) s.CategoryId = (catId == 0) ? null : catId;
            DrawSeatMap(_tempSeats);
            _selectedSeats.Clear();

            if (!_isCreatingNew && _selectedTheater != null)
            {
                using (var ctx = new AppDbContext())
                {
                    foreach (var s in _tempSeats)
                    { // Lưu ý: Có thể tối ưu bằng SP
                        if (s.SeatId > 0)
                        {
                            var dbSeat = new Seat { SeatId = s.SeatId, CategoryId = s.CategoryId };
                            ctx.Seats.Attach(dbSeat);
                            ctx.Entry(dbSeat).Property(x => x.CategoryId).IsModified = true;
                        }
                    }
                    await ctx.SaveChangesAsync();
                }
                MessageBox.Show("Đã cập nhật!");
            }
        }

        private void RemoveSelectedSeats_Click(object sender, RoutedEventArgs e)
        {
            if (!_isCreatingNew) { MessageBox.Show("Không thể xóa ghế của rạp đang hoạt động!"); return; }
            foreach (var s in _selectedSeats.ToList()) _tempSeats.Remove(s);
            DrawSeatMap(_tempSeats);
            _selectedSeats.Clear();
        }

        private async void SaveNewTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if (_tempSeats.Any(s => s.CategoryId == null || s.CategoryId == 0)) { MessageBox.Show("Vẫn còn ghế chưa gán hạng!"); return; }
            try
            {
                using (var ctx = new AppDbContext())
                {
                    var t = new Theater { Name = _newTheaterName, TotalSeats = _tempSeats.Count, Status = "Đã hoạt động" };
                    ctx.Theaters.Add(t); await ctx.SaveChangesAsync();
                    foreach (var s in _tempSeats) { s.TheaterId = t.TheaterId; s.SeatCategory = null; ctx.Seats.Add(s); }
                    await ctx.SaveChangesAsync();
                }
                MessageBox.Show("Thành công!"); CancelEditButton_Click(null, null); await LoadTheatersAsync();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }

        private async void SaveTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedTheater != null)
            {
                using (var ctx = new AppDbContext())
                {
                    var t = await ctx.Theaters.FindAsync(_selectedTheater.TheaterId);
                    if (t != null) { t.Name = EditTheaterNameTextBox.Text; await ctx.SaveChangesAsync(); }
                }
                await LoadTheatersAsync(); MessageBox.Show("Đã đổi tên!");
            }
        }

        private async void DeleteTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Theater t)
            {
                // Kiểm tra điều kiện xóa
                using (var ctx = new AppDbContext())
                {
                    if (await ctx.Performances.AnyAsync(p => p.TheaterId == t.TheaterId))
                    {
                        MessageBox.Show("Không thể xóa rạp đã có lịch sử suất diễn!", "Lỗi", MessageBoxButton.OK, MessageBoxImage.Error); return;
                    }
                }
                if (MessageBox.Show($"Xóa rạp '{t.Name}'?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
                {
                    try
                    {
                        using (var ctx = new AppDbContext())
                        {
                            await ctx.Database.ExecuteSqlRawAsync("DELETE FROM seats WHERE theater_id={0}", t.TheaterId);
                            ctx.Theaters.Remove(new Theater { TheaterId = t.TheaterId });
                            await ctx.SaveChangesAsync();
                        }
                        await LoadTheatersAsync();
                        CancelEditButton_Click(null, null);
                    }
                    catch (Exception ex) { MessageBox.Show("Lỗi xóa: " + ex.Message); }
                }
            }
        }

        private void CancelEditButton_Click(object sender, RoutedEventArgs e)
        {
            EditTheaterPanel.Visibility = Visibility.Collapsed;
            SeatMapWrapPanel.Children.Clear();
            SeatMapTitle.Text = "Sơ đồ ghế...";
            _isCreatingNew = false;
            _tempSeats.Clear();
            TheatersGrid.SelectedItem = null; // Bỏ chọn
        }

        // CRUD Hạng ghế & Placeholder...
        private async void AddCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            string name = AddCategoryNameTextBox.Text.Trim();
            string priceStr = AddCategoryPriceTextBox.Text.Trim();
            if (string.IsNullOrEmpty(name) || name == "Tên hạng ghế" || !decimal.TryParse(priceStr, out decimal price)) { MessageBox.Show("Lỗi nhập liệu"); return; }
            try
            {
                using (var ctx = new AppDbContext())
                {
                    if (_editingCategoryId > 0)
                    {
                        var c = await ctx.SeatCategories.FindAsync(_editingCategoryId);
                        if (c != null) { c.CategoryName = name; c.BasePrice = price; }
                        _editingCategoryId = 0; AddCategoryButton.Content = "Thêm";
                    }
                    else
                    {
                        string color = GetRandomVibrantColor();
                        ctx.SeatCategories.Add(new SeatCategory { CategoryName = name, BasePrice = price, ColorClass = color });
                    }
                    await ctx.SaveChangesAsync();
                }
                AddCategoryNameTextBox_LostFocus(AddCategoryNameTextBox, null);
                AddCategoryPriceTextBox_LostFocus(AddCategoryPriceTextBox, null);
                await LoadCategoriesAsync();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }
        private string GetRandomVibrantColor()
        {
            string[] safeColors = { "E74C3C", "8E44AD", "3498DB", "1ABC9C", "27AE60", "F1C40F", "E67E22", "D35400", "C0392B", "9B59B6", "2980B9", "16A085", "F39C12", "7F8C8D", "2C3E50" };
            return safeColors[new Random().Next(safeColors.Length)];
        }
        private void EditCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is SeatCategory c)
            {
                AddCategoryNameTextBox.Text = c.CategoryName; AddCategoryNameTextBox.Foreground = Brushes.White;
                AddCategoryPriceTextBox.Text = c.BasePrice.ToString("F0"); AddCategoryPriceTextBox.Foreground = Brushes.White;
                _editingCategoryId = c.CategoryId; AddCategoryButton.Content = "Lưu";
            }
        }
        private async void DeleteCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is SeatCategory c)
            {
                if (MessageBox.Show("Xóa?", "Confirm", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
                {
                    using (var ctx = new AppDbContext())
                    {
                        if (await ctx.Seats.AnyAsync(s => s.CategoryId == c.CategoryId)) { MessageBox.Show("Đang dùng!"); return; }
                        ctx.SeatCategories.Remove(new SeatCategory { CategoryId = c.CategoryId }); await ctx.SaveChangesAsync();
                    }
                    await LoadCategoriesAsync();
                }
            }
        }
        private void TheatersGrid_LoadingRow(object sender, DataGridRowEventArgs e) { e.Row.Header = (e.Row.GetIndex() + 1).ToString(); }
        private void CategoriesGrid_LoadingRow(object sender, DataGridRowEventArgs e) { e.Row.Header = (e.Row.GetIndex() + 1).ToString(); }
        private void Placeholder_GotFocus(object sender, RoutedEventArgs e) { if (sender is TextBox tb && (tb.Text.Contains("Tên") || tb.Text.Contains("Giá") || tb.Text.Contains("Số"))) { tb.Text = ""; tb.Foreground = Brushes.White; } }
        private void AddCategoryNameTextBox_LostFocus(object sender, RoutedEventArgs e) { if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Tên hạng ghế"; ((TextBox)sender).Foreground = Brushes.Gray; } }
        private void AddCategoryPriceTextBox_LostFocus(object sender, RoutedEventArgs e) { if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Giá cơ bản"; ((TextBox)sender).Foreground = Brushes.Gray; } }
        private void AddTheaterNameTextBox_LostFocus(object sender, RoutedEventArgs e) { if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Tên rạp (ví dụ: Rạp 1)"; ((TextBox)sender).Foreground = Brushes.Gray; } }
        private void AddTheaterRowsTextBox_LostFocus(object sender, RoutedEventArgs e) { if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Số hàng"; ((TextBox)sender).Foreground = Brushes.Gray; } }
        private void AddTheaterColsTextBox_LostFocus(object sender, RoutedEventArgs e) { if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Số cột"; ((TextBox)sender).Foreground = Brushes.Gray; } }
    }
}