using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("users")]
    public class User
    {
        [Key]
        [Column("user_id")]
        public int UserId { get; set; }

        [Column("email")]
        public string Email { get; set; }

        [Column("account_name")]
        public string? AccountName { get; set; }

        [Column("password")]
        public string PasswordHash { get; set; }

        // GHI CHÚ: Đổi tên từ 'UserType' thành 'Role' để khớp với code của bạn
        [Column("user_type")]
        public string Role { get; set; }

        [Column("status")]
        public string? Status { get; set; }

        // GHI CHÚ: Thêm thuộc tính này để sửa lỗi 'IsVerified'
        [Column("is_verified")]
        public bool? IsVerified { get; set; }

        // Mối quan hệ 1-1 (cho trang Hồ sơ)
        public virtual UserDetail UserDetail { get; set; }
    }
}