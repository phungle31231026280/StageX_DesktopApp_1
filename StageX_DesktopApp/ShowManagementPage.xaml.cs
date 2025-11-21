using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore; // Dùng EF Core

namespace StageX_DesktopApp
{
    public partial class ShowManagementPage : Page
    {
        public ShowManagementPage()
        {
            InitializeComponent();
        }

        // Sự kiện Loaded: Được phép dùng 'async void'
        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            // Gọi các hàm logic (trả về Task) và chờ (await) chúng
            await LoadFormDataAsync();
            await LoadShowsAsync();
        }

        // --- CÁC HÀM LOGIC (SỬA TỪ 'VOID' THÀNH 'TASK') ---
        // Để có thể 'await' được ở chỗ khác

        private async Task LoadFormDataAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    // 1. Tải Thể loại
                    var genres = await context.Genres.OrderBy(g => g.GenreName).AsNoTracking().ToListAsync();
                    GenresListBox.ItemsSource = genres;

                    // 2. Gán cho Filter
                    var filterGenres = genres.ToList();
                    filterGenres.Insert(0, new Genre { GenreId = 0, GenreName = "-- Tất cả --" });
                    FilterGenreComboBox.ItemsSource = filterGenres;
                    FilterGenreComboBox.SelectedIndex = 0;

                    // 3. Tải Diễn viên
                    var actors = await context.Actors
                                            .Where(a => a.Status == "Hoạt động")
                                            .OrderBy(a => a.FullName)
                                            .AsNoTracking()
                                            .ToListAsync();
                    ActorsListBox.ItemsSource = actors;
                }
            }
            catch (Exception ex) { MessageBox.Show($"Lỗi tải dữ liệu form: {ex.Message}"); }
        }

        // Hàm này cũng sửa thành Task
        private async Task LoadShowsAsync(string keyword = "", int genreId = 0)
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var query = context.Shows
                                   .Include(s => s.Genres) // Load kèm Thể loại
                                   .Include(s => s.Actors) // Load kèm Diễn viên
                                   .OrderByDescending(s => s.ShowId)
                                   .AsQueryable();

                    if (!string.IsNullOrEmpty(keyword))
                        query = query.Where(s => s.Title.Contains(keyword));

                    if (genreId > 0)
                        query = query.Where(s => s.Genres.Any(g => g.GenreId == genreId));

                    var shows = await query.ToListAsync();

                    // Xử lý hiển thị
                    foreach (var s in shows)
                    {
                        s.GenresDisplay = (s.Genres != null && s.Genres.Any())
                            ? string.Join(", ", s.Genres.Select(g => g.GenreName))
                            : "";

                        s.ActorsDisplay = (s.Actors != null && s.Actors.Any())
                            ? string.Join(", ", s.Actors.Select(a => a.FullName))
                            : "(Chưa có)";
                    }
                    ShowsGrid.ItemsSource = shows;
                }
            }
            catch (Exception ex) { MessageBox.Show($"Lỗi tải vở diễn: {ex.Message}"); }
        }

        // --- CÁC HÀM SỰ KIỆN (BUTTON CLICK) ---
        // Các hàm này BẮT BUỘC phải là 'async void'

        private async void SearchButton_Click(object sender, RoutedEventArgs e)
        {
            string keyword = SearchTitleTextBox.Text.Trim();
            int genreId = (int)(FilterGenreComboBox.SelectedValue ?? 0);

            // Gọi hàm Task và await nó
            await LoadShowsAsync(keyword, genreId);
        }

        private void ClearShowButton_Click(object sender, RoutedEventArgs e)
        {
            ShowIdTextBox.Text = "";
            ShowTitleTextBox.Text = "";
            ShowDurationTextBox.Text = "";
            ShowDirectorTextBox.Text = "";
            ShowPosterTextBox.Text = "";
            ShowDescriptionTextBox.Text = "";

            GenresListBox.SelectedItems.Clear();
            ActorsListBox.SelectedItems.Clear();

            ShowsGrid.SelectedItem = null;
        }

        private void ShowsGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ShowsGrid.SelectedItem is Show show)
            {
                ShowIdTextBox.Text = show.ShowId.ToString();
                ShowTitleTextBox.Text = show.Title;
                ShowDurationTextBox.Text = show.DurationMinutes.ToString();
                ShowDirectorTextBox.Text = show.Director;
                ShowPosterTextBox.Text = show.PosterImageUrl;
                ShowDescriptionTextBox.Text = show.Description;

                // 1. Chọn lại Thể loại
                GenresListBox.SelectedItems.Clear();
                if (show.Genres != null)
                {
                    foreach (var g in show.Genres)
                    {
                        foreach (var item in GenresListBox.Items)
                        {
                            if (item is Genre listGenre && listGenre.GenreId == g.GenreId)
                            {
                                GenresListBox.SelectedItems.Add(item);
                                break;
                            }
                        }
                    }
                }

                // 2. Chọn lại Diễn viên
                ActorsListBox.SelectedItems.Clear();
                if (show.Actors != null)
                {
                    foreach (var a in show.Actors)
                    {
                        foreach (var item in ActorsListBox.Items)
                        {
                            if (item is Actor listActor && listActor.ActorId == a.ActorId)
                            {
                                ActorsListBox.SelectedItems.Add(item);
                                break;
                            }
                        }
                    }
                }
            }
        }

        private async void SaveShowButton_Click(object sender, RoutedEventArgs e)
        {
            string title = ShowTitleTextBox.Text.Trim();
            if (string.IsNullOrEmpty(title)) { MessageBox.Show("Nhập tiêu đề!"); return; }
            if (!int.TryParse(ShowDurationTextBox.Text, out int duration)) { MessageBox.Show("Thời lượng phải là số!"); return; }

            try
            {
                using (var context = new AppDbContext())
                {
                    Show show;
                    bool isNew = false;

                    if (int.TryParse(ShowIdTextBox.Text, out int id) && id > 0)
                    {
                        show = await context.Shows
                                            .Include(s => s.Genres)
                                            .Include(s => s.Actors)
                                            .FirstOrDefaultAsync(s => s.ShowId == id);
                        if (show == null) return;
                    }
                    else
                    {
                        show = new Show { Status = "Sắp chiếu" };
                        context.Shows.Add(show);
                        isNew = true;
                    }

                    // Cập nhật thông tin cơ bản
                    show.Title = title;
                    show.DurationMinutes = duration;
                    show.Director = ShowDirectorTextBox.Text;
                    show.PosterImageUrl = ShowPosterTextBox.Text;
                    show.Description = ShowDescriptionTextBox.Text;

                    // ==================== PHẦN QUAN TRỌNG NHẤT – SỬA Ở ĐÂY ====================
                    // Cách 2 chuẩn nhất: chỉ lấy ID → query lại → add → không bao giờ bị lỗi tracking nữa
                    var selectedGenreIds = GenresListBox.SelectedItems.OfType<Genre>().Select(g => g.GenreId).ToList();
                    var selectedActorIds = ActorsListBox.SelectedItems.OfType<Actor>().Select(a => a.ActorId).ToList();

                    // Xóa hết quan hệ cũ
                    show.Genres.Clear();
                    show.Actors.Clear();

                    // Thêm lại từ database (EF tự track, không cần Attach)
                    if (selectedGenreIds.Any())
                    {
                        var genres = await context.Genres
                                                  .Where(g => selectedGenreIds.Contains(g.GenreId))
                                                  .ToListAsync();
                        foreach (var g in genres) show.Genres.Add(g);
                    }

                    if (selectedActorIds.Any())
                    {
                        var actors = await context.Actors
                                                  .Where(a => selectedActorIds.Contains(a.ActorId))
                                                  .ToListAsync();
                        foreach (var a in actors) show.Actors.Add(a);
                    }
                    // ==================== HẾT PHẦN SỬA ====================

                    await context.SaveChangesAsync();
                    MessageBox.Show(isNew ? "Thêm mới thành công!" : "Cập nhật thành công!");

                    ClearShowButton_Click(null, null);
                    await LoadShowsAsync(SearchTitleTextBox.Text.Trim(),
                                        (int)(FilterGenreComboBox.SelectedValue ?? 0));
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi: {ex.Message}\nInner: {ex.InnerException?.Message}");
            }
        }

        private void EditButton_Click(object sender, RoutedEventArgs e)
        {
            var btn = sender as Button;
            var show = btn?.DataContext as Show;
            if (show != null)
            {
                ShowsGrid.SelectedItem = show;
                ShowTitleTextBox.Focus();
            }
        }
        private void ShowsGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }
    }
}