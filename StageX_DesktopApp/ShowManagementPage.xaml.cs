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
    public partial class ShowManagementPage : Page
    {
        public ShowManagementPage()
        {
            InitializeComponent();
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            // Tải dữ liệu lần đầu (không lọc)
            await LoadShowsAsync();
            await LoadGenresForListBoxAsync();
        }

        /// <summary>
        /// Ghi chú: Tải danh sách Thể loại (cho CẢ 2 bên)
        /// </summary>
        private async Task LoadGenresForListBoxAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var genres = await context.Genres
                                               .OrderBy(g => g.GenreName)
                                               .ToListAsync();

                    // 1. Tải cho Form (bên trái)
                    GenresListBox.ItemsSource = genres;

                    // 2. Tải cho Filter (bên phải)
                    var filterGenres = genres.ToList(); // Tạo bản sao
                    // Thêm 1 dòng "Tất cả"
                    filterGenres.Insert(0, new Genre { GenreId = 0, GenreName = "-- Tất cả thể loại --" });
                    FilterGenreComboBox.ItemsSource = filterGenres;
                    FilterGenreComboBox.SelectedIndex = 0; // Chọn dòng "Tất cả"
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải thể loại: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Tải Vở diễn (VỚI BỘ LỌC)
        /// </summary>
        private async Task LoadShowsAsync(string searchTerm = "", int genreId = 0)
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    // Bắt đầu truy vấn
                    var query = context.Shows
                                       .Include(s => s.Genres) // Tải kèm Thể loại
                                       .OrderBy(s => s.Title)
                                       .AsQueryable(); // Chuyển sang IQueryable

                    // 1. Lọc theo tên (Tra cứu)
                    if (!string.IsNullOrWhiteSpace(searchTerm))
                    {
                        query = query.Where(s => s.Title.Contains(searchTerm));
                    }

                    // 2. Lọc theo thể loại (Genre)
                    if (genreId > 0)
                    {
                        query = query.Where(s => s.Genres.Any(g => g.GenreId == genreId));
                    }

                    // Thực thi truy vấn
                    var shows = await query.ToListAsync();

                    // (Code tạo chuỗi GenresDisplay giữ nguyên)
                    foreach (var show in shows)
                    {
                        if (show.Genres != null && show.Genres.Any())
                        {
                            show.GenresDisplay = string.Join(", ", show.Genres.Select(g => g.GenreName));
                        }
                        else
                        {
                            show.GenresDisplay = "(Chưa có)";
                        }
                    }
                    ShowsGrid.ItemsSource = shows;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải vở diễn: {ex.Message}");
            }
        }

        /// <summary>
        /// GHI CHÚ: HÀM MỚI - Xử lý nút "Lọc"
        /// </summary>
        private async void SearchButton_Click(object sender, RoutedEventArgs e)
        {
            string searchTerm = SearchTitleTextBox.Text;
            int genreId = (int)(FilterGenreComboBox.SelectedValue ?? 0);

            // Gọi hàm LoadShowsAsync với các tham số lọc
            await LoadShowsAsync(searchTerm, genreId);
        }

        // --- CÁC HÀM CRUD (Thêm/Sửa/Xóa) ---

        private void ClearShowButton_Click(object sender, RoutedEventArgs e)
        {
            ShowIdTextBox.Text = "";
            ShowTitleTextBox.Text = "";
            ShowDirectorTextBox.Text = "";
            ShowDurationTextBox.Text = "";
            ShowPosterTextBox.Text = "";
            ShowDescriptionTextBox.Text = "";
            GenresListBox.SelectedItems.Clear();
            ShowsGrid.SelectedItem = null;
        }

        private void ShowsGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ShowsGrid.SelectedItem is Show selectedShow)
            {
                ShowIdTextBox.Text = selectedShow.ShowId.ToString();
                ShowTitleTextBox.Text = selectedShow.Title;
                ShowDirectorTextBox.Text = selectedShow.Director;
                ShowDurationTextBox.Text = selectedShow.DurationMinutes.ToString();
                ShowPosterTextBox.Text = selectedShow.PosterImageUrl;
                ShowDescriptionTextBox.Text = selectedShow.Description;

                GenresListBox.SelectedItems.Clear();
                if (selectedShow.Genres != null)
                {
                    foreach (var genreInShow in selectedShow.Genres)
                    {
                        foreach (var itemInList in GenresListBox.Items)
                        {
                            if (itemInList is Genre genreInList && genreInList.GenreId == genreInShow.GenreId)
                            {
                                GenresListBox.SelectedItems.Add(itemInList);
                                break;
                            }
                        }
                    }
                }
            }
        }

        private async void SaveShowButton_Click(object sender, RoutedEventArgs e)
        {
            // ... (Code kiểm tra validate Title và Duration giữ nguyên) ...
            string title = ShowTitleTextBox.Text.Trim();
            if (string.IsNullOrEmpty(title)) { /* ... */ return; }
            if (!int.TryParse(ShowDurationTextBox.Text, out int duration) || duration <= 0) { /* ... */ return; }

            try
            {
                using (var context = new AppDbContext())
                {
                    Show showToSave;

                    // Logic SỬA (UPDATE)
                    if (int.TryParse(ShowIdTextBox.Text, out int showId) && showId > 0)
                    {
                        showToSave = await context.Shows
                                            .Include(s => s.Genres)
                                            .FirstOrDefaultAsync(s => s.ShowId == showId);
                        if (showToSave == null) return;
                    }
                    // Logic THÊM MỚI (ADD)
                    else
                    {
                        showToSave = new Show
                        {
                            Status = "Sắp chiếu",
                            Genres = new List<Genre>()
                        };
                        context.Shows.Add(showToSave);
                    }

                    // 2. Cập nhật thông tin từ Form
                    showToSave.Title = title;
                    showToSave.Director = ShowDirectorTextBox.Text.Trim();
                    showToSave.DurationMinutes = duration;
                    showToSave.PosterImageUrl = ShowPosterTextBox.Text.Trim();
                    showToSave.Description = ShowDescriptionTextBox.Text.Trim();

                    // 3. Cập nhật Thể loại
                    showToSave.Genres.Clear();
                    foreach (var item in GenresListBox.SelectedItems)
                    {
                        if (item is Genre selectedGenre)
                        {
                            context.Genres.Attach(selectedGenre);
                            showToSave.Genres.Add(selectedGenre);
                        }
                    }

                    // 4. Lưu CSDL
                    await context.SaveChangesAsync();
                    MessageBox.Show("Lưu vở diễn thành công!");
                }

                // 5. GHI CHÚ: Tải lại Bảng (với filter cũ)
                await LoadShowsAsync(SearchTitleTextBox.Text, (int)(FilterGenreComboBox.SelectedValue ?? 0));
                ClearShowButton_Click(null, null);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi lưu vở diễn: {ex.Message}\n\nInner: {ex.InnerException?.Message}");
            }
        }

        private async void DeleteShowButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Show showToDelete)
            {
                var result = MessageBox.Show($"Bạn có chắc muốn xóa vở diễn '{showToDelete.Title}'?", "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Warning);

                if (result == MessageBoxResult.Yes)
                {
                    try
                    {
                        using (var context = new AppDbContext())
                        {
                            var showToRemove = new Show { ShowId = showToDelete.ShowId };
                            context.Shows.Remove(showToRemove);
                            await context.SaveChangesAsync();
                        }
                        // GHI CHÚ: Tải lại Bảng (với filter cũ)
                        await LoadShowsAsync(SearchTitleTextBox.Text, (int)(FilterGenreComboBox.SelectedValue ?? 0));
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Lỗi khi xóa: {ex.Message}.\nLưu ý: Bạn không thể xóa vở diễn nếu nó đang có Suất diễn.");
                    }
                }
            }
        }

        // Thêm STT cho Bảng
        private void ShowsGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }
    }
}