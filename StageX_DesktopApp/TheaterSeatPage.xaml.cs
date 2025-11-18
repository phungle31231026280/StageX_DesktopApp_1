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
                TheatersGrid.ItemsSource = await context.Theaters.OrderBy(t => t.TheaterId).ToListAsync();
            }
        }

        // --- QUẢN LÝ HẠNG GHẾ ---
        private async void AddCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            string name = AddCategoryNameTextBox.Text.Trim();
            string priceStr = AddCategoryPriceTextBox.Text.Trim();

            if (string.IsNullOrEmpty(name) || name == "Tên hạng ghế" ||
                !decimal.TryParse(priceStr, out decimal price))
            {
                MessageBox.Show("Thông tin không hợp lệ!");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    if (_editingCategoryId > 0) // Sửa
                    {
                        var cat = await context.SeatCategories.FindAsync(_editingCategoryId);
                        if (cat != null) { cat.CategoryName = name; cat.BasePrice = price; }
                        _editingCategoryId = 0;
                        AddCategoryButton.Content = "Thêm";
                    }
                    else // Thêm
                    {
                        string randomColor = string.Format("{0:X6}", new Random().Next(0x1000000));
                        context.SeatCategories.Add(new SeatCategory { CategoryName = name, BasePrice = price, ColorClass = randomColor });
                    }
                    await context.SaveChangesAsync();
                }

                // Reset
                AddCategoryNameTextBox_LostFocus(AddCategoryNameTextBox, null);
                AddCategoryPriceTextBox_LostFocus(AddCategoryPriceTextBox, null);
                await LoadCategoriesAsync();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }

        private void EditCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is SeatCategory cat)
            {
                AddCategoryNameTextBox.Text = cat.CategoryName; AddCategoryNameTextBox.Foreground = Brushes.White;
                AddCategoryPriceTextBox.Text = cat.BasePrice.ToString("F0"); AddCategoryPriceTextBox.Foreground = Brushes.White;
                _editingCategoryId = cat.CategoryId;
                AddCategoryButton.Content = "Lưu";
            }
        }

        private async void DeleteCategoryButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is SeatCategory cat)
            {
                if (MessageBox.Show($"Xóa '{cat.CategoryName}'?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
                {
                    try
                    {
                        using (var ctx = new AppDbContext())
                        {
                            ctx.SeatCategories.Remove(new SeatCategory { CategoryId = cat.CategoryId });
                            await ctx.SaveChangesAsync();
                        }
                        await LoadCategoriesAsync();
                    }
                    catch { MessageBox.Show("Không thể xóa hạng ghế đang được sử dụng!"); }
                }
            }
        }

        // --- QUẢN LÝ RẠP ---
        private void PreviewTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            string name = AddTheaterNameTextBox.Text.Trim();
            if (!int.TryParse(AddTheaterRowsTextBox.Text, out int rows) || rows <= 0 ||
                !int.TryParse(AddTheaterColsTextBox.Text, out int cols) || cols <= 0 ||
                string.IsNullOrEmpty(name) || name.StartsWith("Tên rạp"))
            {
                MessageBox.Show("Thông tin rạp không hợp lệ!");
                return;
            }

            _isCreatingNew = true;
            _newTheaterName = name;
            _selectedTheater = null;
            _tempSeats.Clear();

            for (int r = 1; r <= rows; r++)
            {
                char rowChar = (char)('A' + r - 1);
                for (int c = 1; c <= cols; c++)
                {
                    _tempSeats.Add(new Seat { RowChar = rowChar.ToString(), SeatNumber = c, RealSeatNumber = c });
                }
            }

            SeatMapTitle.Text = $"[XEM TRƯỚC] {name} ({rows}x{cols})";
            DrawSeatMap(_tempSeats);
            EditTheaterPanel.Visibility = Visibility.Visible;
            EditPanelTitle.Text = "Cấu hình Rạp Mới";
            RenameTheaterPanel.Visibility = Visibility.Collapsed;
            SaveNewTheaterButton.Visibility = Visibility.Visible;
            UpdateAssignComboBoxes(_tempSeats);
            MessageBox.Show("Vui lòng gán Hạng ghế trước khi Lưu!");
        }

        private async void SaveNewTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if (_tempSeats.Any(s => s.CategoryId == null || s.CategoryId == 0))
            {
                MessageBox.Show("Vẫn còn ghế chưa gán hạng!", "Lỗi", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    var theater = new Theater { Name = _newTheaterName, TotalSeats = _tempSeats.Count, Status = "Đã hoạt động" };
                    context.Theaters.Add(theater);
                    await context.SaveChangesAsync();

                    foreach (var seat in _tempSeats)
                    {
                        seat.TheaterId = theater.TheaterId;
                        seat.SeatCategory = null;
                        context.Seats.Add(seat);
                    }
                    await context.SaveChangesAsync();
                }
                MessageBox.Show("Lưu thành công!");
                CancelEditButton_Click(null, null);
                await LoadTheatersAsync();

                AddTheaterNameTextBox_LostFocus(AddTheaterNameTextBox, null);
                AddTheaterRowsTextBox_LostFocus(AddTheaterRowsTextBox, null);
                AddTheaterColsTextBox_LostFocus(AddTheaterColsTextBox, null);
            }
            catch (Exception ex) { MessageBox.Show("Lỗi lưu: " + ex.Message); }
        }

        private async void EditTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Theater theater)
            {
                _isCreatingNew = false;
                _selectedTheater = theater;
                using (var ctx = new AppDbContext())
                {
                    _tempSeats = await ctx.Seats.Where(s => s.TheaterId == theater.TheaterId)
                                        .Include(s => s.SeatCategory).OrderBy(s => s.RowChar).ThenBy(s => s.SeatNumber)
                                        .ToListAsync();
                }
                SeatMapTitle.Text = $"Sơ đồ: {theater.Name}";
                DrawSeatMap(_tempSeats);
                EditTheaterPanel.Visibility = Visibility.Visible;
                EditPanelTitle.Text = "Sửa Rạp & Ghế";
                RenameTheaterPanel.Visibility = Visibility.Visible;
                EditTheaterNameTextBox.Text = theater.Name;
                SaveNewTheaterButton.Visibility = Visibility.Collapsed;
                UpdateAssignComboBoxes(_tempSeats);
            }
        }

        private async void DeleteTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Theater t)
            {
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
        }

        private async void SaveTheaterButton_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedTheater != null)
            {
                string newName = EditTheaterNameTextBox.Text;
                using (var ctx = new AppDbContext())
                {
                    var t = await ctx.Theaters.FindAsync(_selectedTheater.TheaterId);
                    if (t != null) { t.Name = newName; await ctx.SaveChangesAsync(); }
                }
                await LoadTheatersAsync();
                MessageBox.Show("Đã đổi tên!");
            }
        }

        // --- LOGIC CHUNG ---
        private void DrawSeatMap(List<Seat> seats)
        {
            SeatMapWrapPanel.Children.Clear();
            var grid = new Grid();
            var rows = seats.Select(s => s.RowChar).Distinct().OrderBy(r => r).ToList();
            var cols = seats.Select(s => s.SeatNumber).Distinct().OrderBy(n => n).ToList();

            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(30) });
            foreach (var c in cols) grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            foreach (var r in rows) grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            for (int i = 0; i < rows.Count; i++)
            {
                var txt = new TextBlock { Text = rows[i], FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center, Foreground = Brushes.Gray };
                Grid.SetRow(txt, i); Grid.SetColumn(txt, 0);
                grid.Children.Add(txt);
            }

            foreach (var seat in seats)
            {
                Brush bg = Brushes.Gray;
                if (seat.CategoryId != null && seat.CategoryId > 0)
                {
                    var cat = _allCategories.FirstOrDefault(c => c.CategoryId == seat.CategoryId);
                    if (cat != null) bg = cat.DisplayColor;
                }
                var btn = new Button { Content = seat.SeatNumber.ToString(), Width = 30, Height = 30, Margin = new Thickness(2), Background = bg, Foreground = Brushes.Black, FontWeight = FontWeights.Bold };
                int rIdx = rows.IndexOf(seat.RowChar);
                int cIdx = cols.IndexOf(seat.SeatNumber) + 1;
                Grid.SetRow(btn, rIdx); Grid.SetColumn(btn, cIdx);
                grid.Children.Add(btn);
            }
            SeatMapWrapPanel.Children.Add(grid);
        }

        private void UpdateAssignComboBoxes(List<Seat> seats)
        {
            var rows = seats.Select(s => s.RowChar).Distinct().OrderBy(r => r).ToList();
            var nums = seats.Select(s => s.SeatNumber).Distinct().OrderBy(n => n).ToList();
            AssignRowComboBox.ItemsSource = rows;
            AssignSeatStartComboBox.ItemsSource = nums;
            AssignSeatEndComboBox.ItemsSource = nums;
        }

        private async void AssignSeatButton_Click(object sender, RoutedEventArgs e)
        {
            if (AssignCategoryComboBox.SelectedValue == null || AssignRowComboBox.SelectedValue == null) return;
            int catId = (int)AssignCategoryComboBox.SelectedValue;
            string row = (string)AssignRowComboBox.SelectedValue;
            int start = (int)(AssignSeatStartComboBox.SelectedValue ?? 0);
            int end = (int)(AssignSeatEndComboBox.SelectedValue ?? 100);

            foreach (var seat in _tempSeats.Where(s => s.RowChar == row && s.SeatNumber >= start && s.SeatNumber <= end))
                seat.CategoryId = (catId == 0) ? null : catId;

            DrawSeatMap(_tempSeats);

            if (!_isCreatingNew && _selectedTheater != null)
            {
                using (var ctx = new AppDbContext())
                {
                    await ctx.Database.ExecuteSqlRawAsync("CALL proc_update_seat_category_range({0},{1},{2},{3},{4})",
                        _selectedTheater.TheaterId, row, start, end, catId == 0 ? 0 : catId);
                }
                MessageBox.Show("Đã cập nhật!");
            }
        }

        private void CategoriesGrid_LoadingRow(object sender, DataGridRowEventArgs e) { e.Row.Header = (e.Row.GetIndex() + 1).ToString(); }
        private void TheatersGrid_LoadingRow(object sender, DataGridRowEventArgs e) { e.Row.Header = (e.Row.GetIndex() + 1).ToString(); }
        private void TheatersGrid_SelectionChanged(object sender, SelectionChangedEventArgs e) { }

        // --- PLACEHOLDERS ---
        private void Placeholder_GotFocus(object sender, RoutedEventArgs e)
        {
            if (sender is TextBox tb && (tb.Text.Contains("Tên hạng") || tb.Text.Contains("Giá") || tb.Text.Contains("Tên rạp") || tb.Text.Contains("Số")))
            {
                tb.Text = ""; tb.Foreground = Brushes.White;
            }
        }
        private void AddCategoryNameTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Tên hạng ghế"; ((TextBox)sender).Foreground = Brushes.Gray; }
        }
        private void AddCategoryPriceTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Giá cơ bản"; ((TextBox)sender).Foreground = Brushes.Gray; }
        }
        private void AddTheaterNameTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Tên rạp (ví dụ: Rạp 1)"; ((TextBox)sender).Foreground = Brushes.Gray; }
        }
        private void AddTheaterRowsTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Số hàng"; ((TextBox)sender).Foreground = Brushes.Gray; }
        }
        private void AddTheaterColsTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(((TextBox)sender).Text)) { ((TextBox)sender).Text = "Số cột"; ((TextBox)sender).Foreground = Brushes.Gray; }
        }
        // Sửa lỗi hàm cũ AddTheaterSeatsTextBox_LostFocus (đổi tên thành Cols)
        private void AddTheaterSeatsTextBox_LostFocus(object sender, RoutedEventArgs e) { AddTheaterColsTextBox_LostFocus(sender, e); }
    }
}