using Microsoft.ML;
using Microsoft.ML.Transforms.TimeSeries;
using StageX_DesktopApp.Models;
using System.Collections.Generic;
using System.Linq;

namespace StageX_DesktopApp.Services
{
    public class RevenueForecastingService
    {
        private MLContext _mlContext;

        public RevenueForecastingService()
        {
            _mlContext = new MLContext(seed: 0);
        }

        /// <summary>
        /// Dự báo doanh thu theo THÁNG
        /// </summary>
        /// <param name="historyData">Dữ liệu lịch sử (đã được lấp đầy các tháng trống)</param>
        /// <param name="horizon">Số tháng muốn dự báo (mặc định 3 tháng)</param>
        public RevenueForecast Predict(List<RevenueInput> historyData, int horizon = 3)
        {
            var dataView = _mlContext.Data.LoadFromEnumerable(historyData);

            // Cấu hình lại tham số cho phù hợp với dữ liệu Tháng (ít điểm hơn Ngày)
            var forecastingPipeline = _mlContext.Forecasting.ForecastBySsa(
                outputColumnName: nameof(RevenueForecast.ForecastedRevenue),
                inputColumnName: nameof(RevenueInput.TotalRevenue),

                // Quan trọng: Giảm windowSize vì chuỗi tháng ngắn hơn
                windowSize: 3,       // Dựa trên 3 tháng gần nhất để đoán
                seriesLength: 6,     // Cần ít nhất 6 tháng dữ liệu để học (nếu ít hơn sẽ lỗi)
                trainSize: historyData.Count,
                horizon: horizon,    // Dự báo n tháng tiếp theo
                confidenceLevel: 0.95f,
                confidenceLowerBoundColumn: nameof(RevenueForecast.LowerBound),
                confidenceUpperBoundColumn: nameof(RevenueForecast.UpperBound));

            var model = forecastingPipeline.Fit(dataView);
            var forecastingEngine = model.CreateTimeSeriesEngine<RevenueInput, RevenueForecast>(_mlContext);

            return forecastingEngine.Predict();
        }
    }
}