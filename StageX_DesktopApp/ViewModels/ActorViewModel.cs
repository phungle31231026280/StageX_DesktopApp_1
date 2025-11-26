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
    public partial class ActorViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        [ObservableProperty] private List<Actor> _actors;
        [ObservableProperty] private string _searchKeyword;

        // Các trường nhập liệu
        [ObservableProperty] private int _id;
        [ObservableProperty] private string _fullName;
        [ObservableProperty] private string _nickName;
        [ObservableProperty] private string _avatarUrl;
        [ObservableProperty] private int _statusIndex = 0; // 0: Hoạt động, 1: Ngừng
        [ObservableProperty] private string _saveButtonContent = "Lưu Diễn viên";

        public ActorViewModel()
        {
            _dbService = new DatabaseService();
            LoadActorsCommand.Execute(null); // Tải dữ liệu khi khởi tạo
        }

        [RelayCommand]
        private async Task LoadActors()
        {
            Actors = await _dbService.GetActorsAsync(SearchKeyword);
        }

        [RelayCommand]
        private void Edit(Actor actor)
        {
            if (actor == null) return;
            Id = actor.ActorId;
            FullName = actor.FullName;
            NickName = actor.NickName;
            AvatarUrl = actor.AvatarUrl;
            StatusIndex = (actor.Status == "Ngừng hoạt động") ? 1 : 0;
            SaveButtonContent = "Cập nhật";
        }

        [RelayCommand]
        private void Clear()
        {
            Id = 0;
            FullName = "";
            NickName = "";
            AvatarUrl = "";
            StatusIndex = 0;
            SaveButtonContent = "Lưu Diễn viên";
        }

        [RelayCommand]
        private async Task Save()
        {
            if (string.IsNullOrWhiteSpace(FullName))
            {
                MessageBox.Show("Vui lòng nhập tên!");
                return;
            }

            var actor = new Actor
            {
                ActorId = Id,
                FullName = FullName,
                NickName = NickName,
                AvatarUrl = AvatarUrl,
                Status = StatusIndex == 1 ? "Ngừng hoạt động" : "Hoạt động"
            };

            try
            {
                await _dbService.SaveActorAsync(actor);
                MessageBox.Show(Id > 0 ? "Cập nhật thành công!" : "Thêm thành công!");
                Clear();
                await LoadActors(); // Tải lại danh sách
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi lưu: " + ex.Message);
            }
        }

        [RelayCommand]
        private async Task Delete(Actor actor)
        {
            if (actor == null) return;
            if (MessageBox.Show($"Xóa diễn viên '{actor.FullName}'?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
            {
                try
                {
                    await _dbService.DeleteActorAsync(actor.ActorId);
                    await LoadActors();
                }
                catch
                {
                    MessageBox.Show("Không thể xóa (Diễn viên đang tham gia vở diễn)!");
                }
            }
        }
    }
}