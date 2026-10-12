namespace ZstdDemo.Models.Responses;

public record  Product
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; }= string.Empty;
    public string Description { get; set; }= string.Empty;  // ← 説明文を長めにするのがポイント
    public decimal Price{ get; set; }
    public int Stock{ get; set; }
    public string[] Tags { get; set; }= [];
    public DateTime CreatedAt{ get; set; }
}