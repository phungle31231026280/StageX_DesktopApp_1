using System.Collections.Generic; // Thêm thư viện này
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("theaters")]
    public class Theater
    {
        [Key]
        [Column("theater_id")]
        public int TheaterId { get; set; }

        [Column("name")]
        public string Name { get; set; }

        [Column("total_seats")]
        public int TotalSeats { get; set; }

        [Column("status")]
        public string Status { get; set; }

        // 1. Thêm danh sách Suất diễn (để kiểm tra điều kiện)
        public virtual ICollection<Performance> Performances { get; set; }

        // 2. Thuộc tính "ảo" (NotMapped) để điều khiển hiển thị nút
        [NotMapped]
        public bool CanDelete { get; set; } // True = Hiện nút Xóa

        [NotMapped]
        public bool CanEdit { get; set; }   // True = Hiện nút Sơ đồ/Sửa
    }
}