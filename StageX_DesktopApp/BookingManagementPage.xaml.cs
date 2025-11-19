using PdfSharp.Drawing;
using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore;
using System.IO;
using System.Diagnostics;

// Thư viện PDF
using PdfSharp.Pdf;


namespace StageX_DesktopApp
{
    // Class phụ để hiển thị lên DataGrid (ViewModel)
    public class BookingViewModel
    {
        public int BookingId { get; set; }
        public string CustomerName { get; set; }
        public string CustomerPhone { get; set; }
        public string ShowTitle { get; set; }
        public string TheaterName { get; set; }
        public DateTime PerformanceTime { get; set; }
        public decimal TotalAmount { get; set; }
        public string Status { get; set; }
        public string SeatList { get; set; } // Danh sách ghế (vd: A1, A2)
    }

    public partial class BookingManagementPage : Page
    {
        public BookingManagementPage()
        {
            InitializeComponent();
        }

        private async void  Page_Loaded(object sender, RoutedEventArgs e)
        {
             LoadBookingsAsync();
        }

        // --- TẢI VÀ TRA CỨU ---
        private async void LoadBookingsAsync(string keyword = "", string statusFilter = "-- Tất cả --")
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    // 1. Query cơ bản
                    var query = context.Bookings
                        .Include(b => b.User).ThenInclude(u => u.UserDetail) // Lấy tên khách
                        .Include(b => b.Performance).ThenInclude(p => p.Show) // Lấy tên vở
                        .Include(b => b.Performance).ThenInclude(p => p.Theater) // Lấy tên rạp
                        .Include(b => b.Tickets).ThenInclude(t => t.Seat) // Lấy ghế
                        .OrderByDescending(b => b.CreatedAt)
                        .AsNoTracking()
                        .AsQueryable();

                    // 2. Lọc theo từ khóa (Mã, Tên, SĐT)
                    if (!string.IsNullOrWhiteSpace(keyword))
                    {
                        // Lưu ý: EF Core có thể không dịch được UserDetail.Phone trực tiếp nếu nó null
                        // Nên ta tải về RAM rồi lọc (với dữ liệu nhỏ/trung bình) hoặc viết query kỹ hơn.
                        // Ở đây ta dùng cách tải về RAM cho đơn giản (vì số lượng booking không quá lớn).
                    }

                    // 3. Thực thi query (Tải về RAM)
                    var rawList = await query.ToListAsync();

                    // 4. Chuyển sang ViewModel và Lọc tiếp trong RAM (để xử lý Null dễ hơn)
                    var viewList = rawList.Select(b => new BookingViewModel
                    {
                        BookingId = b.BookingId,
                        // Nếu có UserDetail thì lấy tên, không thì lấy Email
                        CustomerName = b.User?.UserDetail?.FullName ?? b.User?.Email ?? "Khách vãng lai",
                        CustomerPhone = b.User?.UserDetail?.Phone ?? "---",
                        ShowTitle = b.Performance?.Show?.Title ?? "Không rõ",
                        TheaterName = b.Performance?.Theater?.Name ?? "",
                        PerformanceTime = b.Performance?.PerformanceDate.Add(b.Performance.StartTime) ?? DateTime.MinValue,
                        TotalAmount = b.TotalAmount,
                        Status = b.Status,
                        // Nối danh sách ghế: A1, A2
                        SeatList = string.Join(", ", b.Tickets.Select(t => $"{t.Seat?.RowChar}{t.Seat?.SeatNumber}"))
                    });

                    // 5. Áp dụng bộ lọc Keyword (trong RAM)
                    if (!string.IsNullOrWhiteSpace(keyword))
                    {
                        string k = keyword.ToLower();
                        viewList = viewList.Where(x =>
                            x.BookingId.ToString().Contains(k) ||
                            x.CustomerName.ToLower().Contains(k) ||
                            x.CustomerPhone.Contains(k)
                        );
                    }

                    // 6. Áp dụng bộ lọc Trạng thái
                    if (statusFilter != "-- Tất cả --")
                    {
                        viewList = viewList.Where(x => x.Status == statusFilter);
                    }

                    BookingsGrid.ItemsSource = viewList.ToList();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi tải dữ liệu: {ex.Message}");
            }
        }

        private async void SearchButton_Click(object sender, RoutedEventArgs e)
        {
            string keyword = SearchBox.Text.Trim();
            string status = (StatusComboBox.SelectedItem as ComboBoxItem)?.Content.ToString() ?? "-- Tất cả --";
             LoadBookingsAsync(keyword, status);
        }

        private async void SearchBox_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)
        {
            if (e.Key == System.Windows.Input.Key.Enter)
            {
                 SearchButton_Click(null, null);
            }
        }

        // --- CHỨC NĂNG IN VÉ (PDF) ---
        private void PrintButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is BookingViewModel booking)
            {
                ExportTicketToPdf(booking);
            }
        }

        private void ExportTicketToPdf(BookingViewModel b)
        {
            try
            {
                // 1. Tạo tài liệu PDF
                PdfDocument document = new PdfDocument();
                document.Info.Title = $"Vé_{b.BookingId}";

                // Tạo trang khổ A6 (nhỏ gọn như vé) hoặc A5
                PdfPage page = document.AddPage();
                page.Width = XUnit.FromMillimeter(105); // A6 Width
                page.Height = XUnit.FromMillimeter(148); // A6 Height
                XGraphics gfx = XGraphics.FromPdfPage(page);

                // Font
                XFont fontTitle = new XFont("Arial", 16);
                XFont fontHeader = new XFont("Arial", 12);
                XFont fontNormal = new XFont("Arial", 10); 
                XFont fontItalic = new XFont("Arial", 9);

                // 2. Vẽ nội dung
                double y = 20;
                double margin = 10;
                double width = page.Width - 2 * margin;

                // Logo / Tên rạp
                gfx.DrawString("STAGEX THEATER", fontTitle, XBrushes.DarkRed, new XRect(0, y, page.Width, 20), XStringFormats.TopCenter);
                y += 25;
                gfx.DrawString("Vé Xem Kịch", fontHeader, XBrushes.Black, new XRect(0, y, page.Width, 15), XStringFormats.TopCenter);
                y += 20;

                // Kẻ đường
                gfx.DrawLine(XPens.Black, margin, y, page.Width - margin, y);
                y += 15;

                // Thông tin chính
                gfx.DrawString($"Mã đơn: #{b.BookingId}", fontNormal, XBrushes.Black, margin, y);
                y += 15;
                gfx.DrawString($"Khách hàng: {b.CustomerName}", fontNormal, XBrushes.Black, margin, y);
                y += 20;

                // Thông tin vở diễn (In đậm)
                gfx.DrawString("Vở diễn:", fontHeader, XBrushes.Black, margin, y);
                y += 15;
                // Tự động xuống dòng nếu tên vở quá dài (Logic đơn giản: cắt chuỗi)
                gfx.DrawString(b.ShowTitle, fontTitle, XBrushes.Black, new XRect(margin, y, width, 40), XStringFormats.TopLeft);
                y += 30;

                gfx.DrawString($"Rạp: {b.TheaterName}", fontNormal, XBrushes.Black, margin, y);
                y += 15;
                gfx.DrawString($"Thời gian: {b.PerformanceTime:dd/MM/yyyy HH:mm}", fontNormal, XBrushes.Black, margin, y);
                y += 25;

                // Ghế và Giá
                gfx.DrawString("Ghế ngồi:", fontHeader, XBrushes.Black, margin, y);
                gfx.DrawString(b.SeatList, fontTitle, XBrushes.DarkBlue, margin + 70, y);
                y += 25;

                gfx.DrawString("Tổng tiền:", fontHeader, XBrushes.Black, margin, y);
                gfx.DrawString($"{b.TotalAmount:N0} VNĐ", fontTitle, XBrushes.Red, margin + 70, y);
                y += 30;

                // Footer
                gfx.DrawLine(XPens.Black, margin, y, page.Width - margin, y);
                y += 10;
                gfx.DrawString("Cảm ơn quý khách đã ủng hộ StageX!", fontItalic, XBrushes.Gray, new XRect(0, y, page.Width, 10), XStringFormats.TopCenter);
                y += 12;
                gfx.DrawString("Vui lòng đến trước giờ diễn 15 phút.", fontItalic, XBrushes.Gray, new XRect(0, y, page.Width, 10), XStringFormats.TopCenter);

                // 3. Lưu và Mở
                string folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "StageX_Tickets");
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);

                string fileName = $"Ve_{b.BookingId}_{DateTime.Now:HHmmss}.pdf";
                string fullPath = Path.Combine(folder, fileName);

                document.Save(fullPath);

                // Tự động mở file PDF
                Process.Start(new ProcessStartInfo(fullPath) { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi in vé: {ex.Message}");
            }
        }
    }
}