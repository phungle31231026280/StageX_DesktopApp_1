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

        [ObservableProperty] private ObservableCollection<Theater> _theaters;
        [ObservableProperty] private ObservableCollection<SeatCategory> _categories;

        public List<Seat> CurrentSeats { get; set; } = new List<Seat>();

        [ObservableProperty] private bool _isEditing = false;
        [ObservableProperty] private bool _isCreatingNew = false;
        [ObservableProperty] private bool _isReadOnlyMode = false;
        [ObservableProperty] private string _editPanelTitle = "Cấu hình Rạp";

        [ObservableProperty] private string _newTheaterName = "";
        [ObservableProperty] private string _newRows = "";
        [ObservableProperty] private string _newCols = "";

        [ObservableProperty] private string _editTheaterName;
        [ObservableProperty] private Theater _selectedTheater;
        [ObservableProperty] private string _saveBtnContent = "Lưu rạp mới";

        [ObservableProperty] private string _categoryName = "";
        [ObservableProperty] private string _categoryPrice = "";
        [ObservableProperty] private int _editingCategoryId =0;
        [ObservableProperty] private string _categoryBtnContent = "Thêm";

        public event Action<List<Seat>> RequestDrawSeats;

        public TheaterSeatViewModel()
        {
            _dbService = new DatabaseService();
            Application.Current.Dispatcher.InvokeAsync(async () => await LoadData());
        }

        private async Task LoadData()
        {
            var tList = await _dbService.GetTheatersWithStatusAsync();
            Theaters = new ObservableCollection<Theater>(tList);
            var cList = await _dbService.GetSeatCategoriesAsync();
            Categories = new ObservableCollection<SeatCategory>(cList);
        }

        [RelayCommand]
        private void PreviewNewTheater()
        {
            if (!int.TryParse(NewRows, out int r) || !int.TryParse(NewCols, out int c) || r <= 0 || c <= 0)
            {
                MessageBox.Show("Số hàng/cột không hợp lệ!"); return;
            }
            if (string.IsNullOrWhiteSpace(NewTheaterName)) { MessageBox.Show("Nhập tên rạp!"); return; }

            IsEditing = true; IsCreatingNew = true; IsReadOnlyMode = false; SaveBtnContent = "Lưu rạp mới";
            EditPanelTitle = "Tạo rạp mới (Chưa lưu)";
            SelectedTheater = null; EditTheaterName = NewTheaterName;

            CurrentSeats.Clear();
            for (int i = 1; i <= r; i++)
            {
                string rowChar = ((char)('A' + i - 1)).ToString();
                for (int j = 1; j <= c; j++)
                {
                    CurrentSeats.Add(new Seat { RowChar = rowChar, SeatNumber = j, RealSeatNumber = j });
                }
            }
            RequestDrawSeats?.Invoke(CurrentSeats);
            MessageBox.Show("Đã tạo sơ đồ mẫu. Hãy gán hạng ghế rồi bấm LƯU!");
        }

        [RelayCommand]
        private async Task SelectTheater(Theater t)
        {
            if (t == null) return;
            SelectedTheater = t;
            EditTheaterName = t.Name;

            // [CẬP NHẬT LOGIC QUAN TRỌNG TẠI ĐÂY]
            if (t.CanDelete)
            {
                // Trường hợp: Rạp CHƯA DÙNG -> Được phép Sửa
                IsEditing = true; // HIỆN bảng cấu hình để sửa
                IsCreatingNew = false;
                IsReadOnlyMode = false;
                EditPanelTitle = $"Chỉnh sửa rạp {t.Name}";
                SaveBtnContent = "Cập nhật";
            }
            else
            {
                // Trường hợp: Rạp ĐÃ DÙNG -> Chỉ Xem
                IsEditing = false; // ẨN luôn bảng cấu hình đi cho gọn
                IsCreatingNew = false;
                IsReadOnlyMode = true;
                // Không cần EditPanelTitle vì bảng đã ẩn
            }

            try
            {
                CurrentSeats = await _dbService.GetSeatsByTheaterAsync(t.TheaterId);
                await Task.Delay(50);
                RequestDrawSeats?.Invoke(CurrentSeats); // Vẫn vẽ sơ đồ bên phải bình thường
            }
            catch (Exception ex) { MessageBox.Show("Lỗi tải ghế: " + ex.Message); }
        }
        [RelayCommand]
        private async Task SaveOrUpdateTheater()
        {
            if (IsCreatingNew)
            {
                await SaveNewTheater();
            }
            else
            {
                await UpdateCurrentTheater();
            }
        }
        [RelayCommand]
        private async Task SaveTheaterName()
        {
            if (IsReadOnlyMode || SelectedTheater == null) return;
            await _dbService.UpdateTheaterNameAsync(SelectedTheater.TheaterId, EditTheaterName);
            MessageBox.Show("Đổi tên thành công!");
            await LoadData();
        }

        [RelayCommand]
        private async Task SaveNewTheater()
        {
            if (CurrentSeats.Any(s => s.CategoryId == null || s.CategoryId == 0)) { MessageBox.Show("Chưa gán hạng ghế hết!"); return; }
            try
            {
                var t = new Theater { Name = EditTheaterName, TotalSeats = CurrentSeats.Count, Status = "Đã hoạt động" };
                await _dbService.SaveNewTheaterAsync(t, CurrentSeats);
                MessageBox.Show("Lưu rạp thành công!");
                CancelEdit();
                await LoadData();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }
        private async Task UpdateCurrentTheater()
        {
            if (SelectedTheater == null) return;
            try
            {
                await _dbService.UpdateTheaterNameAsync(SelectedTheater.TheaterId, EditTheaterName);
                if (CurrentSeats != null && CurrentSeats.Count > 0)
                {
                    await _dbService.UpdateSeatsCategoryAsync(CurrentSeats);
                }

                MessageBox.Show("Cập nhật thành công!");
                CancelEdit();
                await LoadData();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi cập nhật: " + ex.Message); }
        }
        [RelayCommand]
        private async Task DeleteTheater(Theater t)
        {
            if (MessageBox.Show($"Xóa rạp '{t.Name}'?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
            {
                try { await _dbService.DeleteTheaterAsync(t.TheaterId); await LoadData(); }
                catch { MessageBox.Show("Không thể xóa rạp đang hoạt động!"); }
            }
        }

        [RelayCommand]
        private void CancelEdit()
        {
            IsEditing = false; IsCreatingNew = false; CurrentSeats.Clear();
            RequestDrawSeats?.Invoke(CurrentSeats); SelectedTheater = null;
        }

        public async Task ApplyCategoryToSeats(int catId, List<Seat> selectedSeats)
        {
            if (IsReadOnlyMode) return;

            // [FIX LỖI]: Tìm object Category từ list để gán vào ghế (để View hiện màu ngay)
            var categoryObj = Categories.FirstOrDefault(c => c.CategoryId == catId);

            foreach (var s in selectedSeats)
            {
                s.CategoryId = (catId == 0 ? null : catId);
                s.SeatCategory = categoryObj; // Cập nhật object tham chiếu để hiện màu
            }

            // ViewModel bắn event vẽ lại ghế -> View sẽ nhận được list mới có màu mới
            RequestDrawSeats?.Invoke(CurrentSeats);

            if (!IsCreatingNew && SelectedTheater != null)
            {
                await _dbService.UpdateSeatsCategoryAsync(selectedSeats);
                MessageBox.Show("Đã cập nhật hạng ghế!");
            }
        }

        public void RemoveSeats(List<Seat> selectedSeats)
        {
            if (IsReadOnlyMode) return;

            // Xóa khỏi danh sách bộ nhớ
            foreach (var s in selectedSeats) CurrentSeats.Remove(s);

            // Bắn sự kiện để vẽ lại (View sẽ lo việc tính toán lại số ghế)
            RequestDrawSeats?.Invoke(CurrentSeats);
        }

        [RelayCommand]
        private async Task SaveCategory()
        {
            string name = CategoryName.Trim();
            if (string.IsNullOrEmpty(name) || !decimal.TryParse(CategoryPrice, out decimal price)) return;
            var cat = new SeatCategory { CategoryId = EditingCategoryId, CategoryName = name, BasePrice = price };
            if (EditingCategoryId == 0) cat.ColorClass = "1ABC9C";
            await _dbService.SaveSeatCategoryAsync(cat);
            MessageBox.Show(EditingCategoryId > 0 ? "Cập nhật xong!" : "Thêm mới xong!");
            CategoryName = ""; CategoryPrice = ""; EditingCategoryId = 0; CategoryBtnContent = "Thêm";
            await LoadData();
        }

        [RelayCommand] private void EditCategory(SeatCategory c) { CategoryName = c.CategoryName; CategoryPrice = c.BasePrice.ToString("F0"); EditingCategoryId = c.CategoryId; CategoryBtnContent = "Lưu"; }
        [RelayCommand] private async Task DeleteCategory(SeatCategory c) { if (MessageBox.Show("Xóa hạng này?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes) { await _dbService.DeleteSeatCategoryAsync(c.CategoryId); await LoadData(); } }
    }
}