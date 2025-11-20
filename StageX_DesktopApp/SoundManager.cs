using System;
using System.Media; // Thư viện phát nhạc
using System.IO;

namespace StageX_DesktopApp.Services
{
    public static class SoundManager
    {
        private static string _basePath = AppDomain.CurrentDomain.BaseDirectory;

        public static void PlaySuccess()
        {
            PlaySound("Sounds/success.wav");
            // Hoặc dùng âm thanh hệ thống nếu lười tải file:
            // SystemSounds.Asterisk.Play();
        }

        public static void PlayError()
        {
            PlaySound("Sounds/error.wav");
            // Hoặc dùng âm thanh hệ thống:
            // SystemSounds.Hand.Play();
        }

        private static void PlaySound(string fileName)
        {
            try
            {
                string path = Path.Combine(_basePath, fileName);
                if (File.Exists(path))
                {
                    using (SoundPlayer player = new SoundPlayer(path))
                    {
                        player.Play(); // Phát 1 lần (không lặp)
                    }
                }
                else
                {
                    // Nếu không tìm thấy file, dùng tiếng bíp mặc định
                    SystemSounds.Beep.Play();
                }
            }
            catch
            {
                // Bỏ qua lỗi âm thanh (không để app bị crash vì cái loa hỏng)
            }
        }
    }
}