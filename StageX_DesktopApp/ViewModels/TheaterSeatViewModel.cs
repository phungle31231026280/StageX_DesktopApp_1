using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class TheaterSeatViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // --- DỮ LIỆU HIỂN THỊ ---
        [ObservableProperty] private ObservableCollection<Theater> _theaters;
        [ObservableProperty] private ObservableCollection<SeatCategory> _categories;

        // Danh sách ghế hiện tại (để vẽ lên màn hình)
        // Dùng List thường vì ta sẽ vẽ lại toàn bộ khi thay đổi
        public List<Seat> CurrentSeats { get; set; } = new List<Seat>();

        // --- TRẠNG THÁI GIAO DIỆN ---
        [ObservableProperty] private bool _isEditing = false;       // Hiện panel chỉnh sửa/tạo mới
        [ObservableProperty] private bool _isCreatingNew = false;   // True = Đang tạo rạp mới, False = Đang sửa rạp cũ
        [ObservableProperty] private string _editPanelTitle = "2. Cấu hình Rạp";

        // --- FORM TẠO MỚI (RẠP) ---
        [ObservableProperty] private string _newTheaterName = "Rạp mới";
        [ObservableProperty] private string _newRows = "10";
        [ObservableProperty] private string _newCols = "12";

        // --- FORM CHỈNH SỬA (RẠP) ---
        [ObservableProperty] private string _editTheaterName;
        [ObservableProperty] private Theater _selectedTheater;

        // --- FORM HẠNG GHẾ ---
        [ObservableProperty] private string _categoryName = "Tên hạng (ví dụ: VIP)";
        [ObservableProperty] private string _categoryPrice = "Giá phụ thu";
        [ObservableProperty] private int _editingCategoryId = 0;
        [ObservableProperty] private string _categoryBtnContent = "Thêm";

        // --- SỰ KIỆN BÁO VIEW VẼ LẠI ---
        public event Action<List<Seat>> RequestDrawSeats;

        public TheaterSeatViewModel()
        {
            _dbService = new DatabaseService();
            // Khởi tạo dữ liệu trên UI Thread
            Application.Current.Dispatcher.Invoke(async () => await LoadData());
        }

        private async Task LoadData()
        {
            var tList = await _dbService.GetTheatersWithStatusAsync();
            Theaters = new ObservableCollection<Theater>(tList);

            var cList = await _dbService.GetSeatCategoriesAsync();
            Categories = new ObservableCollection<SeatCategory>(cList);
        }

        // 1. XEM TRƯỚC RẠP MỚI (Tạo ghế giả lập)
        [RelayCommand]
        private void PreviewNewTheater()
        {
            if (!int.TryParse(NewRows, out int r) || !int.TryParse(NewCols, out int c) || r <= 0 || c <= 0)
            {
                MessageBox.Show("Số hàng/cột không hợp lệ!"); return;
            }
            if (string.IsNullOrWhiteSpace(NewTheaterName) || NewTheaterName.Contains("Tên rạp"))
            {
                MessageBox.Show("Vui lòng nhập tên rạp!"); return;
            }

            IsEditing = true;
            IsCreatingNew = true;
            EditPanelTitle = "1. Tạo rạp mới (Chưa lưu)";
            SelectedTheater = null;
            EditTheaterName = NewTheaterName;

            // Tạo ghế trong RAM (SeatId = 0)
            CurrentSeats.Clear();
            for (int i = 1; i <= r; i++)
            {
                string rowChar = ((char)('A' + i - 1)).ToString();
                for (int j = 1; j <= c; j++)
                {
                    CurrentSeats.Add(new Seat { RowChar = rowChar, SeatNumber = j, RealSeatNumber = j });
                }
            }

            // Bắn sự kiện vẽ
            RequestDrawSeats?.Invoke(CurrentSeats);
            MessageBox.Show("Đã tạo sơ đồ mẫu. Hãy chọn vùng ghế để gán hạng, sau đó bấm LƯU RẠP MỚI!");
        }

        // 2. CHỌN RẠP CŨ ĐỂ SỬA
        [RelayCommand]
        private async Task SelectTheater(Theater t)
        {
            if (t == null) return;
            IsEditing = true;
            IsCreatingNew = false;
            EditPanelTitle = $"2. Cấu hình: {t.Name}";
            SelectedTheater = t;
            EditTheaterName = t.Name;

            try
            {
                // Tải ghế thật từ DB
                CurrentSeats = await _dbService.GetSeatsByTheaterAsync(t.TheaterId);

                // Thêm delay nhỏ để UI ổn định
                await Task.Delay(50);
                RequestDrawSeats?.Invoke(CurrentSeats);
            }
            catch (Exception ex) { MessageBox.Show("Lỗi tải ghế: " + ex.Message); }
        }

        // 3. LƯU TÊN RẠP (Khi sửa)
        [RelayCommand]
        private async Task SaveTheaterName()
        {
            if (SelectedTheater != null && !string.IsNullOrWhiteSpace(EditTheaterName))
            {
                await _dbService.UpdateTheaterNameAsync(SelectedTheater.TheaterId, EditTheaterName);
                MessageBox.Show("Đổi tên thành công!");
                await LoadData();
            }
        }

        // 4. LƯU RẠP MỚI (Insert vào DB)
        [RelayCommand]
        private async Task SaveNewTheater()
        {
            // Kiểm tra
            if (CurrentSeats.Any(s => s.CategoryId == null || s.CategoryId == 0))
            {
                MessageBox.Show("Vui lòng gán hạng cho TẤT CẢ các ghế trước khi lưu!"); return;
            }

            try
            {
                var t = new Theater { Name = EditTheaterName, TotalSeats = CurrentSeats.Count, Status = "Đã hoạt động" };
                await _dbService.SaveNewTheaterAsync(t, CurrentSeats);

                MessageBox.Show("Lưu rạp mới thành công!");
                CancelEdit(); // Reset giao diện
                await LoadData();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi lưu rạp: " + ex.Message); }
        }

        // 5. XÓA RẠP
        [RelayCommand]
        private async Task DeleteTheater(Theater t)
        {
            if (t == null) return;
            if (!t.CanDelete) { MessageBox.Show("Rạp này đã có lịch sử hoạt động, không thể xóa!"); return; }

            if (MessageBox.Show($"Xóa rạp '{t.Name}'?", "Xác nhận", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes)
            {
                try { await _dbService.DeleteTheaterAsync(t.TheaterId); await LoadData(); }
                catch { MessageBox.Show("Lỗi xóa!"); }
            }
        }

        [RelayCommand]
        private void CancelEdit()
        {
            IsEditing = false;
            IsCreatingNew = false;
            CurrentSeats.Clear();
            RequestDrawSeats?.Invoke(CurrentSeats); // Xóa trắng màn hình
            SelectedTheater = null;
        }

        // 6. GÁN HẠNG GHẾ (Logic gọi từ View)
        public async Task ApplyCategoryToSeats(int catId, List<Seat> selectedSeats)
        {
            // Cập nhật trong RAM để vẽ lại
            foreach (var s in selectedSeats) s.CategoryId = (catId == 0 ? null : catId);

            RequestDrawSeats?.Invoke(CurrentSeats); // Vẽ lại màu mới

            // Nếu đang sửa trực tiếp rạp cũ (không phải tạo mới) -> Lưu ngay xuống DB
            if (!IsCreatingNew && SelectedTheater != null)
            {
                await _dbService.UpdateSeatsCategoryAsync(selectedSeats);
                MessageBox.Show("Đã cập nhật hạng ghế!");
            }
        }

        public void RemoveSeats(List<Seat> selectedSeats)
        {
            foreach (var s in selectedSeats) CurrentSeats.Remove(s);
            RequestDrawSeats?.Invoke(CurrentSeats);
        }

        // --- QUẢN LÝ HẠNG GHẾ ---
        [RelayCommand]
        private async Task SaveCategory()
        {
            string name = CategoryName.Trim();
            string priceStr = CategoryPrice.Trim();

            if (string.IsNullOrEmpty(name) || name.Contains("Tên hạng") ||
                !decimal.TryParse(priceStr, out decimal price))
            {
                MessageBox.Show("Thông tin hạng ghế không hợp lệ!"); return;
            }

            try
            {
                var cat = new SeatCategory { CategoryId = EditingCategoryId, CategoryName = name, BasePrice = price };
                if (EditingCategoryId == 0) cat.ColorClass = GetRandomColor(); // Random màu nếu tạo mới

                await _dbService.SaveSeatCategoryAsync(cat);

                MessageBox.Show(EditingCategoryId > 0 ? "Cập nhật thành công!" : "Thêm mới thành công!");

                // Reset form
                CategoryName = "Tên hạng (ví dụ: VIP)";
                CategoryPrice = "Giá phụ thu";
                EditingCategoryId = 0;
                CategoryBtnContent = "Thêm";

                await LoadData();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }

        [RelayCommand]
        private void EditCategory(SeatCategory c)
        {
            CategoryName = c.CategoryName;
            CategoryPrice = c.BasePrice.ToString("F0");
            EditingCategoryId = c.CategoryId;
            CategoryBtnContent = "Lưu";
        }

        [RelayCommand]
        private async Task DeleteCategory(SeatCategory c)
        {
            if (MessageBox.Show("Xóa hạng ghế này?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
            {
                try { await _dbService.DeleteSeatCategoryAsync(c.CategoryId); await LoadData(); }
                catch { MessageBox.Show("Hạng ghế đang được sử dụng, không thể xóa!"); }
            }
        }

        private string GetRandomColor()
        {
            string[] colors = { "E74C3C", "8E44AD", "3498DB", "1ABC9C", "27AE60", "F1C40F", "E67E22" };
            return colors[new Random().Next(colors.Length)];
        }
    }
}