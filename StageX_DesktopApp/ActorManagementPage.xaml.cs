using StageX_DesktopApp.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using Microsoft.EntityFrameworkCore;

namespace StageX_DesktopApp
{
    public partial class ActorManagementPage : Page
    {
        public ActorManagementPage()
        {
            InitializeComponent();
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadActorsAsync();
        }

        private async Task LoadActorsAsync(string keyword = "")
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    var query = context.Actors.AsQueryable();

                    if (!string.IsNullOrEmpty(keyword))
                    {
                        query = query.Where(a => a.FullName.Contains(keyword) || a.NickName.Contains(keyword));
                    }

                    var actors = await query.OrderByDescending(a => a.ActorId).ToListAsync();
                    ActorsGrid.ItemsSource = actors;
                }
            }
            catch (Exception ex) { MessageBox.Show("Lỗi tải dữ liệu: " + ex.Message); }
        }

        private async void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            string name = FullNameBox.Text.Trim();
            if (string.IsNullOrEmpty(name)) { MessageBox.Show("Vui lòng nhập tên!"); return; }

            try
            {
                using (var context = new AppDbContext())
                {
                    Actor actor;
                    bool isNew = false;

                    if (int.TryParse(ActorIdBox.Text, out int id) && id > 0)
                    {
                        actor = await context.Actors.FindAsync(id);
                        if (actor == null) return;
                    }
                    else
                    {
                        actor = new Actor();
                        context.Actors.Add(actor);
                        isNew = true;
                    }

                    actor.FullName = name;
                    actor.NickName = NickNameBox.Text.Trim();
                    actor.AvatarUrl = AvatarUrlBox.Text.Trim();
                    actor.Status = (StatusComboBox.SelectedItem as ComboBoxItem).Content.ToString();

                    await context.SaveChangesAsync();
                    MessageBox.Show(isNew ? "Thêm thành công!" : "Cập nhật thành công!");

                    ClearButton_Click(null, null);
                    await LoadActorsAsync();
                }
            }
            catch (Exception ex) { MessageBox.Show("Lỗi lưu: " + ex.Message); }
        }

        private void EditButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Actor actor)
            {
                ActorIdBox.Text = actor.ActorId.ToString();
                FullNameBox.Text = actor.FullName;
                NickNameBox.Text = actor.NickName;
                AvatarUrlBox.Text = actor.AvatarUrl;

                // Load ảnh preview
                try { if (!string.IsNullOrEmpty(actor.AvatarUrl)) PreviewImage.Source = new BitmapImage(new Uri(actor.AvatarUrl)); } catch { }

                StatusComboBox.SelectedIndex = (actor.Status == "Ngừng hoạt động") ? 1 : 0;
                SaveButton.Content = "Cập nhật";
            }
        }

        private async void DeleteButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is Actor actor)
            {
                if (MessageBox.Show($"Xóa diễn viên '{actor.FullName}'?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
                {
                    try
                    {
                        using (var context = new AppDbContext())
                        {
                            // Kiểm tra xem diễn viên có đang đóng vở nào không
                            // (Cần Include Shows trong query nếu muốn check kỹ)
                            context.Actors.Remove(new Actor { ActorId = actor.ActorId });
                            await context.SaveChangesAsync();
                        }
                        await LoadActorsAsync();
                    }
                    catch { MessageBox.Show("Không thể xóa (Diễn viên đang tham gia vở diễn)!"); }
                }
            }
        }

        private void ClearButton_Click(object sender, RoutedEventArgs e)
        {
            ActorIdBox.Text = "";
            FullNameBox.Text = "";
            NickNameBox.Text = "";
            AvatarUrlBox.Text = "";
            PreviewImage.Source = null;
            StatusComboBox.SelectedIndex = 0;
            SaveButton.Content = "Lưu Diễn viên";
        }

        private async void SearchButton_Click(object sender, RoutedEventArgs e)
        {
            await LoadActorsAsync(SearchBox.Text.Trim());
        }

        private async void SearchBox_KeyUp(object sender, System.Windows.Input.KeyEventArgs e)
        {
            if (e.Key == System.Windows.Input.Key.Enter)
            {
                await LoadActorsAsync(SearchBox.Text.Trim());
            }
        }
    }
}