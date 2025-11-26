using System;
using System.IO;
using System.Windows.Media; // Quan trọng để chơi MP3

namespace StageX_DesktopApp.Services
{
    public static class SoundManager
    {
        private static MediaPlayer _player = new MediaPlayer();
        private static string _basePath = AppDomain.CurrentDomain.BaseDirectory;

        // Các hàm tiện ích gọi nhanh
        public static void PlaySuccess() => PlaySound("success.mp3"); // Hoặc "success.wav"
        public static void PlayError() => PlaySound("error.mp3");
        public static void PlayLogout() => PlaySound("log out.mp3");
        public static void PlayClick() => PlaySound("click.mp3");

        private static void PlaySound(string fileName)
        {
            try
            {
                // Tìm file trong thư mục 'Sounds'
                string fullPath = Path.Combine(_basePath, "Sounds", fileName);

                if (File.Exists(fullPath))
                {
                    _player.Open(new Uri(fullPath));
                    _player.Volume = 1.0;
                    _player.Play();
                }
                else
                {
                    // Fallback nếu không tìm thấy file (chỉ để debug)
                    // System.Diagnostics.Debug.WriteLine($"Sound not found: {fullPath}");
                }
            }
            catch
            {
                // Bỏ qua lỗi âm thanh để không crash app
            }
        }
    }
}