using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("performances")] // Ánh xạ tới bảng 'performances'
    public class Performance
    {
        [Key]
        [Column("performance_id")]
        public int PerformanceId { get; set; }

        [Column("show_id")]
        public int ShowId { get; set; }

        [Column("theater_id")]
        public int TheaterId { get; set; }

        [Column("performance_date")]
        public DateTime PerformanceDate { get; set; }

        [Column("start_time")]
        public TimeSpan StartTime { get; set; } // Dùng TimeSpan cho kiểu TIME

        [Column("end_time")]
        public TimeSpan? EndTime { get; set; } // Dùng ? vì nó có thể NULL

        [Column("status")]
        public string Status { get; set; } // 'Đang mở bán', 'Đã hủy', ...

        [Column("price")]
        public decimal Price { get; set; } // Giá vé gốc

        // Ghi chú: Mối quan hệ (để tải tên)
        public virtual Show Show { get; set; }
        public virtual Theater Theater { get; set; }

        // Ghi chú: Thuộc tính "ảo" (không có trong CSDL)
        // Dùng để hiển thị tên Vở diễn và Rạp trong Bảng (DataGrid)
        [NotMapped]
        public string ShowTitle { get; set; }
        [NotMapped]
        public string TheaterName { get; set; }
    }
}