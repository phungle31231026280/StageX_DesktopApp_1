using Microsoft.EntityFrameworkCore;
using PdfSharp.Drawing;
using PdfSharp.Drawing.Layout;
// Thư viện PDF
using PdfSharp.Pdf;
using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;


namespace StageX_DesktopApp
{
    // Class phụ để hiển thị lên DataGrid (ViewModel)
    public class BookingViewModel
    {
        public int BookingId { get; set; }
        public string CustomerName { get; set; } = string.Empty;
        public string ShowTitle { get; set; } = string.Empty;
        public string TheaterName { get; set; }
        public DateTime PerformanceTime { get; set; }
        public decimal TotalAmount { get; set; }
        public string Status { get; set; }
        public string SeatList { get; set; } // Danh sách ghế (vd: A1, A2)
        public string CreatorName { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
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
        private async Task LoadBookingsAsync(string keyword = "", string statusFilter = "-- Tất cả --")
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
                        .Include(b => b.CreatedByUser).ThenInclude(u=>u.UserDetail)
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
                        CustomerName = b.User != null ? (b.User.UserDetail?.FullName ?? b.User.Email) : string.Empty,
                        CreatorName = b.User != null ? "Online" :
                          (b.CreatedByUser != null ? (b.CreatedByUser.UserDetail?.FullName ?? b.CreatedByUser.AccountName) : "—"),
                        ShowTitle = b.Performance?.Show?.Title ?? "Không rõ",
                        TheaterName = b.Performance?.Theater?.Name ?? "",
                        PerformanceTime = b.Performance?.PerformanceDate.Add(b.Performance.StartTime) ?? DateTime.MinValue,
                        TotalAmount = b.TotalAmount,
                        Status = b.Status,
                        CreatedAt = b.CreatedAt,
                        // Nối danh sách ghế: A1, A2
                        SeatList = string.Join(", ", b.Tickets.Select(t => $"{t.Seat?.RowChar}{t.Seat?.SeatNumber}"))
                    });

                    // 5. Áp dụng bộ lọc Keyword (trong RAM)
                    if (!string.IsNullOrWhiteSpace(keyword))
                    {
                        string k = keyword.ToLower();
                        viewList = viewList.Where(x =>
                            x.BookingId.ToString().Contains(k) ||
                            x.CustomerName.ToLower().Contains(k)
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
                 
                
                ;
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
                // --- TÁCH GHẾ: mỗi ghế = 1 vé ---
                var seats = (b.SeatList ?? string.Empty)
                    .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                    .Select(s => s.Trim())
                    .ToList();

                if (seats.Count == 0)
                    seats.Add("—");

                PdfDocument document = new PdfDocument();
                document.Info.Title = $"Ve_{b.BookingId}";

                // --- Cấu hình font & brush ---
                XBrush bgBrush = new XSolidBrush(XColor.FromArgb(26, 26, 26));
                XBrush textWhite = XBrushes.White;
                XBrush textGold = new XSolidBrush(XColor.FromArgb(255, 193, 7));
                XBrush textGray = XBrushes.LightGray;
                XPen linePen = new XPen(XColor.FromArgb(60, 60, 60), 1);

                XFont fontTitle = new XFont("Arial", 18);
                XFont fontHeader = new XFont("Arial", 12);
                XFont fontNormal = new XFont("Arial", 10);
                XFont fontSmall = new XFont("Arial", 8);


                foreach (var seatCode in seats)
                {
                    PdfPage page = document.AddPage();
                    page.Width = XUnit.FromMillimeter(105);
                    page.Height = XUnit.FromMillimeter(148);

                    XGraphics gfx = XGraphics.FromPdfPage(page);
                    double margin = 12;
                    double y = 18;
                    double pageWidth = page.Width;
                    double contentWidth = pageWidth - margin * 2;

                    // --- NỀN ---
                    gfx.DrawRectangle(bgBrush, 0, 0, page.Width, page.Height);
                    gfx.DrawRectangle(new XPen(XColor.FromArgb(255, 193, 7), 2),
                                      margin, margin, contentWidth, page.Height - margin * 2);

                    // --- LOGO ---
                    try
                    {
                        string logoPath = "logo.png";  // tự chỉnh
                        if (File.Exists(logoPath))
                        {
                            XImage logo = XImage.FromFile(logoPath);
                            gfx.DrawImage(logo, (pageWidth - 50) / 2, y, 50, 50);
                            y += 55;
                        }
                    }
                    catch { y += 10; }

                    // --- TIÊU ĐỀ ---
                    gfx.DrawString("STAGEX THEATER", fontTitle, textGold,
                        new XRect(0, y, pageWidth, 20), XStringFormats.TopCenter);
                    y += 27;

                    gfx.DrawString("VÉ XEM KỊCH", fontHeader, textWhite,
                        new XRect(0, y, pageWidth, 20), XStringFormats.TopCenter);
                    y += 25;

                    gfx.DrawLine(linePen, margin + 5, y, pageWidth - margin - 5, y);
                    y += 15;


                    double leftX = margin + 8;

                    // --------- HÀM VẼ 1 DÒNG LABEL: VALUE ----------
                    void DrawRow(string label, string value, bool boldValue = false)
                    {
                        gfx.DrawString(label, fontNormal, textGray, leftX, y);

                        var fontVal = boldValue ? fontHeader : fontNormal;

                        gfx.DrawString(value ?? "—", fontVal, textWhite, leftX + 80, y);
                        y += 18;
                    }

                    // --- THÔNG TIN CHUNG ---
                    DrawRow("Mã đơn:", $"#{b.BookingId}");

                    DrawRow("Khách:", string.IsNullOrWhiteSpace(b.CustomerName) ? "Offline" : b.CustomerName);

                    DrawRow("Người lập:", b.CreatorName);

                    DrawRow("Ngày tạo:", b.CreatedAt.ToString("dd/MM/yyyy HH:mm"));

                    y += 8;

                    // --- VỞ DIỄN ---
                    gfx.DrawString("Vở diễn:", fontHeader, textGray, leftX, y);
                    y += 17;

                    gfx.DrawString(b.ShowTitle, fontTitle, textGold,
                        new XRect(leftX, y, contentWidth - 20, 50),
                        XStringFormats.TopLeft);

                    y += 35;

                    DrawRow("Rạp:", b.TheaterName);
                    DrawRow("Suất:", b.PerformanceTime.ToString("HH:mm - dd/MM/yyyy"));

                    // --- GHẾ ---
                    y += 5;
                    gfx.DrawString("Ghế:", fontHeader, textGray, leftX, y);
                    gfx.DrawString(seatCode, fontTitle, textGold, leftX + 60, y);
                    y += 35;

                    // --- TỔNG TIỀN ---
                    gfx.DrawLine(linePen, leftX, y, pageWidth - leftX, y);
                    y += 12;

                    gfx.DrawString("TỔNG CỘNG:", fontHeader, textWhite, leftX, y + 5);
                    gfx.DrawString($"{b.TotalAmount:N0} đ", fontTitle, textGold,
                        pageWidth - leftX - 100, y + 0);

                    y += 40;

                    // --- BARCODE GIẢ ---
                    Random rnd = new Random();
                    double barcodeX = (pageWidth - 100) / 2;

                    for (int i = 0; i < 50; i++)
                    {
                        double w = rnd.Next(1, 4);
                        gfx.DrawRectangle(XBrushes.White, barcodeX, y, w, 20);
                        barcodeX += w + rnd.Next(1, 3);
                    }

                    y += 30;

                    gfx.DrawString("Cảm ơn quý khách!", fontSmall, textGray,
                        new XRect(0, y, pageWidth, 10), XStringFormats.TopCenter);
                }

                // --- LƯU FILE ---
                string folder = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                    "StageX_Tickets");

                if (!Directory.Exists(folder))
                    Directory.CreateDirectory(folder);

                string fileName = $"Ve_{b.BookingId}_{DateTime.Now:HHmmss}.pdf";
                string fullPath = Path.Combine(folder, fileName);

                document.Save(fullPath);
                Process.Start(new ProcessStartInfo(fullPath) { UseShellExecute = true });

                AudioHelper.Play("success.mp3");

            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi in vé: {ex.Message}");
            }
        }
    }
}