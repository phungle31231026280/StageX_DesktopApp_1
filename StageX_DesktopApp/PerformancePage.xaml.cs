using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore; // <-- Dùng EF Core

namespace StageX_DesktopApp
{
    public partial class PerformancePage : Page
    {
        public PerformancePage()
        {
            InitializeComponent();
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadPerformancesAsync(); // Tải Bảng (Tra cứu)
            await LoadComboBoxesAsync(); // Tải dữ liệu Vở diễn, Rạp
        }

        /// <summary>
        /// Ghi chú: Tải dữ liệu cho ComboBoxes (Form và Filter)
        /// </summary>
        private async Task LoadComboBoxesAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    // Tải Vở diễn (CHỈ DÙNG CHO FORM THÊM/SỬA)
                    var shows = await context.Shows
                                        .OrderBy(s => s.Title)
                                        .AsNoTracking()
                                        .ToListAsync();
                    ShowComboBox.ItemsSource = shows; // Gán cho Form

                    // Tải Rạp
                    var theaters = await context.Theaters
                                        .OrderBy(t => t.Name)
                                        .AsNoTracking()
                                        .ToListAsync();

                    // 1. Gán Rạp cho Form (Thêm/Sửa)
                    // (Tạo bản sao để tránh xung đột)
                    TheaterComboBox.ItemsSource = theaters.ToList();

                    // 2. Gán Rạp cho Filter (Tra cứu)
                    var filterTheaters = theaters.ToList();
                    filterTheaters.Insert(0, new Theater { TheaterId = 0, Name = "-- Tất cả Rạp --" });
                    FilterTheaterComboBox.ItemsSource = filterTheaters;
                    FilterTheaterComboBox.SelectedIndex = 0;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải dữ liệu cho Form: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Tải Bảng Suất diễn (VỚI BỘ LỌC)
        /// </summary>
        private async Task LoadPerformancesAsync(string showName = "", int theaterId = 0, DateTime? date = null)
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var query = context.Performances
                                        .Include(p => p.Show)
                                        .Include(p => p.Theater)
                                        .OrderByDescending(p => p.PerformanceDate)
                                        .AsNoTracking()
                                        .AsQueryable();

                    if (!string.IsNullOrWhiteSpace(showName))
                    {
                        query = query.Where(p => p.Show.Title.Contains(showName));
                    }
                    if (theaterId > 0)
                    {
                        query = query.Where(p => p.TheaterId == theaterId);
                    }

                    // GHI CHÚ: SỬA LỖI (CS0117)
                    // 'DbFunctions.TruncateTime' là của EF6.
                    // Cách của EF Core (.NET 8) là so sánh thuộc tính .Date
                    if (date.HasValue)
                    {
                        query = query.Where(p => p.PerformanceDate.Date == date.Value.Date);
                    }

                    var performances = await query.ToListAsync();

                    foreach (var p in performances)
                    {
                        p.ShowTitle = p.Show?.Title;
                        p.TheaterName = p.Theater?.Name;
                    }

                    PerformancesGrid.ItemsSource = performances;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải Suất diễn: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Thêm STT cho bảng
        /// </summary>
        private void PerformancesGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }

        // --- HÀM XỬ LÝ LỌC ---
        private async void SearchButton_Click(object sender, RoutedEventArgs e)
        {
            string showName = SearchShowNameTextBox.Text.Trim();
            int theaterId = (int)(FilterTheaterComboBox.SelectedValue ?? 0);
            DateTime? date = FilterDatePicker.SelectedDate;

            await LoadPerformancesAsync(showName, theaterId, date);
        }

        private async void ClearFilterButton_Click(object sender, RoutedEventArgs e)
        {
            SearchShowNameTextBox.Text = "";
            FilterTheaterComboBox.SelectedIndex = 0;
            FilterDatePicker.SelectedDate = null;

            await LoadPerformancesAsync(); // Tải lại (không lọc)
        }

        // --- CÁC HÀM CRUD (Thêm/Sửa/Xóa) ---
        // (Các hàm ClearButton_Click, EditButton_Click, SaveButton_Click,
        // và DeleteButton_Click giữ nguyên như cũ)

        private void ClearButton_Click(object sender, RoutedEventArgs e)
        {
            FormTitle.Text = "Thêm suất diễn";
            SaveButton.Content = "Thêm suất diễn";
            ClearButton.Visibility = Visibility.Collapsed;
            PerformanceIdTextBox.Text = "";
            ShowComboBox.SelectedIndex = -1;
            TheaterComboBox.SelectedIndex = -1;
            PerformanceDatePicker.SelectedDate = null;
            StartTimeTextBox.Text = "";
            PriceTextBox.Text = "";
            StatusComboBox.SelectedIndex = -1;
            PerformancesGrid.SelectedItem = null;
        }

        private void EditButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Performance perfToEdit)
            {
                FormTitle.Text = "Chỉnh sửa suất diễn";
                PerformanceIdTextBox.Text = perfToEdit.PerformanceId.ToString();
                ShowComboBox.SelectedValue = perfToEdit.ShowId;
                TheaterComboBox.SelectedValue = perfToEdit.TheaterId;
                PerformanceDatePicker.SelectedDate = perfToEdit.PerformanceDate;
                StartTimeTextBox.Text = perfToEdit.StartTime.ToString(@"hh\:mm");
                PriceTextBox.Text = perfToEdit.Price.ToString("F0");
                StatusComboBox.SelectedIndex = (perfToEdit.Status == "Đã hủy") ? 1 : 0;

                SaveButton.Content = "Lưu thay đổi";
                ClearButton.Visibility = Visibility.Visible;
            }
        }

        private async void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            if (ShowComboBox.SelectedValue == null ||
                TheaterComboBox.SelectedValue == null ||
                PerformanceDatePicker.SelectedDate == null ||
                !TimeSpan.TryParse(StartTimeTextBox.Text, out TimeSpan startTime) ||
                !decimal.TryParse(PriceTextBox.Text, out decimal price) ||
                StatusComboBox.SelectedValue == null)
            {
                MessageBox.Show("Vui lòng nhập đầy đủ và chính xác tất cả thông tin!");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    Performance performanceToSave;

                    if (int.TryParse(PerformanceIdTextBox.Text, out int perfId) && perfId > 0)
                    {
                        performanceToSave = await context.Performances.FindAsync(perfId);
                        if (performanceToSave == null) return;
                    }
                    else
                    {
                        performanceToSave = new Performance();
                        context.Performances.Add(performanceToSave);
                    }

                    performanceToSave.ShowId = (int)ShowComboBox.SelectedValue;
                    performanceToSave.TheaterId = (int)TheaterComboBox.SelectedValue;
                    performanceToSave.PerformanceDate = PerformanceDatePicker.SelectedDate.Value;
                    performanceToSave.StartTime = startTime;
                    performanceToSave.Price = price;
                    performanceToSave.Status = (StatusComboBox.SelectedItem as ComboBoxItem).Content.ToString();

                    var show = await context.Shows.FindAsync(performanceToSave.ShowId);
                    if (show != null)
                    {
                        performanceToSave.EndTime = startTime.Add(TimeSpan.FromMinutes(show.DurationMinutes));
                    }

                    await context.SaveChangesAsync();
                    MessageBox.Show("Lưu suất diễn thành công!");
                }

                await LoadPerformancesAsync(
                    SearchShowNameTextBox.Text.Trim(),
                    (int)(FilterTheaterComboBox.SelectedValue ?? 0),
                    FilterDatePicker.SelectedDate
                );
                ClearButton_Click(null, null);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi lưu suất diễn: {ex.Message}\n\nInner: {ex.InnerException?.Message}");
            }
        }

        private async void DeleteButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Performance perfToDelete)
            {
                var result = MessageBox.Show($"Bạn có chắc muốn xóa suất diễn này?", "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Warning);

                if (result == MessageBoxResult.Yes)
                {
                    try
                    {
                        using (var context = new AppDbContext())
                        {
                            var perfToRemove = new Performance { PerformanceId = perfToDelete.PerformanceId };
                            context.Performances.Remove(perfToRemove);
                            await context.SaveChangesAsync();
                        }

                        await LoadPerformancesAsync(
                            SearchShowNameTextBox.Text.Trim(),
                            (int)(FilterTheaterComboBox.SelectedValue ?? 0),
                            FilterDatePicker.SelectedDate
                        );
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Lỗi khi xóa: {ex.Message}.\nLưu ý: Bạn không thể xóa suất diễn nếu đã có người đặt vé.");
                    }
                }
            }
        }
    }
}