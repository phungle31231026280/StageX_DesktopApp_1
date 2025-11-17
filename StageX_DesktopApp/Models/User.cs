using System.ComponentModel.DataAnnotations.Schema;
namespace StageX_DesktopApp.Models
{
    [Table("users")]
    public class User
    {
        [Column("user_id")]
        public int UserId { get; set; }
        [Column("email")]
        public string Email { get; set; }
        [Column("password")]
        public string PasswordHash { get; set; }
        [Column("account_name")]
        public string AccountName { get; set; }
        [Column("user_type")]
        public string Role { get; set; }
        [Column("status")]
        public string Status { get; set; }

        // Mối quan hệ 1-1
        public virtual UserDetail UserDetail { get; set; }
    }
}