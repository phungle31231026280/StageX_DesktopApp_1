using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class SeatCategoryViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // Danh sách hiển thị
        [ObservableProperty] private List<SeatCategory> _categories;

        // Các trường nhập liệu
        [ObservableProperty] private int _categoryId;
        [ObservableProperty] private string _categoryName;
        [ObservableProperty] private string _basePriceStr; // Binding string để dễ xử lý input
        [ObservableProperty] private string _saveBtnContent = "Thêm";
        [ObservableProperty] private bool _isEditing = false;

        public SeatCategoryViewModel()
        {
            _dbService = new DatabaseService();
            LoadCategoriesCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadCategories()
        {
            Categories = await _dbService.GetSeatCategoriesAsync();
        }

        [RelayCommand]
        private void Edit(SeatCategory cat)
        {
            if (cat == null) return;
            CategoryId = cat.CategoryId;
            CategoryName = cat.CategoryName;
            BasePriceStr = cat.BasePrice.ToString("F0"); // Hiển thị không số thập phân

            SaveBtnContent = "Lưu";
            IsEditing = true;
        }

        [RelayCommand]
        private void Cancel()
        {
            CategoryId = 0;
            CategoryName = "";
            BasePriceStr = "";
            SaveBtnContent = "Thêm";
            IsEditing = false;
        }

        [RelayCommand]
        private async Task Save()
        {
            // Validate
            if (string.IsNullOrWhiteSpace(CategoryName) || CategoryName.Contains("Tên hạng"))
            {
                MessageBox.Show("Vui lòng nhập tên hạng ghế hợp lệ!");
                return;
            }

            if (!decimal.TryParse(BasePriceStr, out decimal price))
            {
                MessageBox.Show("Giá phụ thu phải là số!");
                return;
            }

            try
            {
                var cat = new SeatCategory
                {
                    CategoryId = CategoryId,
                    CategoryName = CategoryName,
                    BasePrice = price
                };

                // Nếu là thêm mới -> Random màu (Logic từ code cũ)
                if (CategoryId == 0)
                {
                    cat.ColorClass = GetRandomVibrantColor();
                }

                await _dbService.SaveSeatCategoryAsync(cat);

                MessageBox.Show(CategoryId > 0 ? "Cập nhật thành công!" : "Thêm mới thành công!");
                Cancel(); // Reset form
                await LoadCategories(); // Tải lại bảng
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }

        [RelayCommand]
        private async Task Delete(SeatCategory cat)
        {
            if (cat == null) return;

            if (MessageBox.Show($"Xóa hạng ghế '{cat.CategoryName}'?", "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes)
            {
                try
                {
                    await _dbService.DeleteSeatCategoryAsync(cat.CategoryId);
                    await LoadCategories();
                }
                catch
                {
                    MessageBox.Show("Không thể xóa hạng ghế này (Đang được sử dụng cho ghế).");
                }
            }
        }

        // Hàm random màu từ code cũ
        private string GetRandomVibrantColor()
        {
            string[] safeColors = { "E74C3C", "8E44AD", "3498DB", "1ABC9C", "27AE60", "F1C40F", "E67E22", "D35400", "C0392B", "9B59B6", "2980B9", "16A085", "F39C12", "7F8C8D", "2C3E50" };
            return safeColors[new Random().Next(safeColors.Length)];
        }
    }
}