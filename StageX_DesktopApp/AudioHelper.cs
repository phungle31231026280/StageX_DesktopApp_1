using System;
using System.IO;
using System.Windows.Media;

namespace StageX_DesktopApp
{
    public static class AudioHelper
    {
        private static MediaPlayer _player = new MediaPlayer();

        public static void Play(string fileName)
        {
            try
            {
                // Đường dẫn đến thư mục chứa file nhạc (tùy bạn để ở đâu, ví dụ này là thư mục gốc/Sounds)
                string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Resources", fileName);

                if (File.Exists(path))
                {
                    _player.Open(new Uri(path));
                    _player.Play();
                }
            }
            catch
            {
                // Nếu lỗi file nhạc thì bỏ qua, không làm sập app
            }
        }
    }
}