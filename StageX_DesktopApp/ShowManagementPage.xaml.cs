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
            await LoadShowsAsync();
            await LoadGenresForListBoxAsync();
        }

        // Tải Thể loại cho ListBox
        private async Task LoadGenresForListBoxAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var genres = await context.Genres
                                           .OrderBy(g => g.GenreName)
                                           .ToListAsync();
                    GenresListBox.ItemsSource = genres;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải thể loại: {ex.Message}");
            }
        }

        // Tải Vở diễn cho Bảng
        private async Task LoadShowsAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var shows = await context.Shows
                                          .Include(s => s.Genres) // Tải kèm Thể loại
                                          .OrderBy(s => s.Title)
                                          .ToListAsync();

                    // Tạo chuỗi "GenresDisplay"
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

        // Nút "Làm mới"
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

        // Click vào Bảng
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

                // Cập nhật ListBox thể loại
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

        // Nút "Lưu Vở diễn" (Thêm + Sửa)
        private async void SaveShowButton_Click(object sender, RoutedEventArgs e)
        {
            string title = ShowTitleTextBox.Text.Trim();
            if (string.IsNullOrEmpty(title))
            {
                MessageBox.Show("Tiêu đề vở diễn không được để trống!");
                return;
            }
            if (!int.TryParse(ShowDurationTextBox.Text, out int duration) || duration <= 0)
            {
                MessageBox.Show("Thời lượng (phút) phải là một con số > 0!");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    Show showToSave;

                    // Logic SỬA (UPDATE)
                    if (int.TryParse(ShowIdTextBox.Text, out int showId) && showId > 0)
                    {
                        showToSave = await context.Shows
                                            .Include(s => s.Genres) // Phải Include()
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

                    // 3. Cập nhật Mối quan hệ Nhiều-Nhiều (Thể loại)
                    showToSave.Genres.Clear(); // Xóa hết thể loại cũ

                    // Lấy danh sách thể loại MỚI
                    foreach (var item in GenresListBox.SelectedItems)
                    {
                        if (item is Genre selectedGenre)
                        {
                            // "Attach" thể loại này (để EF Core biết nó đã tồn tại)
                            context.Genres.Attach(selectedGenre);
                            showToSave.Genres.Add(selectedGenre);
                        }
                    }

                    // 4. Lưu CSDL
                    await context.SaveChangesAsync();
                    MessageBox.Show("Lưu vở diễn thành công!");
                }

                // 5. Tải lại mọi thứ
                await LoadShowsAsync();
                ClearShowButton_Click(null, null);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi lưu vở diễn: {ex.Message}\n\nInner: {ex.InnerException?.Message}");
            }
        }

        // Nút "Xóa"
        private async void DeleteShowButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Show showToDelete)
            {
                var result = MessageBox.Show($"Bạn có chắc muốn xóa vở diễn '{showToDelete.Title}'?",
                                             "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Warning);

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
                        await LoadShowsAsync();
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