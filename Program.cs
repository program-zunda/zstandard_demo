using Microsoft.AspNetCore.ResponseCompression;
using ZstdDemo.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;  // HTTPSでも圧縮する
    options.MimeTypes = ResponseCompressionDefaults.MimeTypes
        .Concat(new[] { "application/json" });
});

var app = builder.Build();

app.UseResponseCompression();

// 小さいJSON（10件）
app.MapGet("/api/products/small", () =>
    Results.Json(ProductGenerator.Generate(10)));

// 中サイズ（500件）
app.MapGet("/api/products/medium", () =>
    Results.Json(ProductGenerator.Generate(500)));

// 大きいJSON（5000件）
app.MapGet("/api/products/large", () =>
    Results.Json(ProductGenerator.Generate(5000)));

app.Run();
