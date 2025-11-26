using MimeKit;
using MailKit.Net.Smtp;
using MailKit.Security;
using System.Threading.Tasks;
using System;

namespace StageX_DesktopApp.Services
{
    public class MailService
    {
        // Cấu hình giữ nguyên như code cũ
        private const string Host = "smtp.gmail.com";
        private const int Port = 587;
        private const string Username = "dtngoc.video@gmail.com";
        private const string Password = "yfdcojadkfblargt";
        private const string FromEmail = "no-reply@stagex.local";
        private const string FromName = "StageX";

        public async Task<bool> SendNewAccountEmailAsync(string toEmail, string accountName, string plainPassword)
        {
            try
            {
                var message = new MimeMessage();
                message.From.Add(new MailboxAddress(FromName, FromEmail));
                message.To.Add(new MailboxAddress(string.Empty, toEmail));
                message.Subject = "Thông báo tài khoản mới";
                message.Body = new TextPart("plain")
                {
                    Text = $"Bạn đã được StageX cung cấp tài khoản mới,\nTên tài khoản là: {accountName}\nMật khẩu là: {plainPassword}"
                };

                using var client = new SmtpClient();
                await client.ConnectAsync(Host, Port, SecureSocketOptions.StartTls);
                await client.AuthenticateAsync(Username, Password);
                await client.SendAsync(message);
                await client.DisconnectAsync(true);
                return true;
            }
            catch (Exception)
            {
                return false;
            }
        }
    }
}