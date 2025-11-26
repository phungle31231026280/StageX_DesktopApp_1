using System.Windows.Controls;

namespace StageX_DesktopApp.Views
{
    /// <summary>
    /// Interaction logic for AccountView.xaml
    /// </summary>
    public partial class AccountView : UserControl
    {
        public AccountView()
        {
            InitializeComponent();
            // Mọi logic gửi mail, lưu DB đã nằm bên AccountViewModel
        }
    }
}