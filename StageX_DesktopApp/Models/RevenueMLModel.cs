using Microsoft.ML.Data;
using System;

namespace StageX_DesktopApp.Models
{
    // 1. Dữ liệu đầu vào (lấy từ Database)
    public class RevenueInput
    {
        public DateTime Date { get; set; } // Ngày thu tiền
        public float TotalRevenue { get; set; } // Tổng tiền (ML.NET dùng float)
    }

    // 2. Kết quả dự báo (ML.NET trả về)
    public class RevenueForecast
    {
        // Mảng chứa các giá trị dự báo cho n ngày tiếp theo
        public float[] ForecastedRevenue { get; set; }

        // Khoảng tin cậy dưới (tối thiểu)
        public float[] LowerBound { get; set; }

        // Khoảng tin cậy trên (tối đa)
        public float[] UpperBound { get; set; }
    }
}