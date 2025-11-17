using StageX_DesktopApp.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore; // <-- Dùng EF Core

namespace StageX_DesktopApp
{
    public partial class GenreManagementPage : Page
    {
        private int _selectedGenreId = 0;

        public GenreManagementPage()
        {
            InitializeComponent();
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadGenresAsync();
        }

        // Tải danh sách thể loại
        private async Task LoadGenresAsync()
        {
            try
            {
                // Dùng context "nhẹ"
                using (var context = new AppDbContext())
                {
                    var genres = await context.Genres
                                           .OrderBy(g => g.GenreId)
                                           .ToListAsync();
                    GenresGrid.ItemsSource = genres;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải thể loại: {ex.Message}");
            }
        }

        // Thêm STT cho bảng
        private void GenresGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }

        // Xử lý nút "Thêm"
        private async void AddGenreButton_Click(object sender, RoutedEventArgs e)
        {
            string genreName = AddGenreNameTextBox.Text.Trim();
            if (string.IsNullOrEmpty(genreName))
            {
                MessageBox.Show("Tên thể loại không được để trống!");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    var newGenre = new Genre { GenreName = genreName };
                    context.Genres.Add(newGenre);
                    await context.SaveChangesAsync();
                }

                MessageBox.Show("Thêm thể loại mới thành công!");
                AddGenreNameTextBox.Text = "";
                await LoadGenresAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi thêm thể loại: {ex.Message}");
            }
        }

        // Xử lý nút "Chỉnh sửa" (trong Bảng)
        private void EditButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Genre genreToEdit)
            {
                EditGenreIdTextBox.Text = genreToEdit.GenreId.ToString();
                EditGenreNameTextBox.Text = genreToEdit.GenreName;
                _selectedGenreId = genreToEdit.GenreId;
                EditGenrePanel.Visibility = Visibility.Visible;
            }
        }

        // Xử lý nút "Lưu" (trong form "Chỉnh sửa")
        private async void SaveGenreButton_Click(object sender, RoutedEventArgs e)
        {
            string newName = EditGenreNameTextBox.Text.Trim();
            if (_selectedGenreId == 0 || string.IsNullOrEmpty(newName))
            {
                MessageBox.Show("Vui lòng chọn thể loại và nhập tên mới.");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    var genreToUpdate = await context.Genres.FindAsync(_selectedGenreId);
                    if (genreToUpdate != null)
                    {
                        genreToUpdate.GenreName = newName;
                        await context.SaveChangesAsync();
                        MessageBox.Show("Cập nhật thể loại thành công!");

                        await LoadGenresAsync();
                        CancelEditButton_Click(null, null);
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi cập nhật: {ex.Message}");
            }
        }

        // Xử lý nút "Hủy"
        private void CancelEditButton_Click(object sender, RoutedEventArgs e)
        {
            EditGenreIdTextBox.Text = "";
            EditGenreNameTextBox.Text = "";
            _selectedGenreId = 0;
            EditGenrePanel.Visibility = Visibility.Collapsed;
        }

        // Xử lý nút "Xóa" (trong Bảng)
        private async void DeleteButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Genre genreToDelete)
            {
                var result = MessageBox.Show($"Bạn có chắc muốn xóa thể loại '{genreToDelete.GenreName}'?",
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
                            var genreToRemove = new Genre { GenreId = genreToDelete.GenreId };
                            context.Genres.Remove(genreToRemove);
                            await context.SaveChangesAsync();
                        }

                        await LoadGenresAsync();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Lỗi khi xóa: {ex.Message}.\nLưu ý: Bạn không thể xóa thể loại nếu nó đang được gán cho một vở diễn.");
                    }
                }
            }
        }
    }
}