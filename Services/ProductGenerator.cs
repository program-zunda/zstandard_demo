using ZstdDemo.Models.Responses;

namespace ZstdDemo.Services;

public class ProductGenerator
{
    private static readonly string[] Categories =
        ["電化製品", "書籍", "衣類", "食品", "スポーツ用品", "家具"];

    private static readonly string[] TagPool =
        ["新商品", "セール中", "人気", "限定", "送料無料", "レビュー高評価"];

    public static List<Product> Generate(int count)
    {
        var rnd = new Random(42);  // ← シード固定で毎回同じデータに
        var list = new List<Product>(count);

        for (int i = 1; i <= count; i++)
        {
            // タグを1〜3個ランダムに選ぶ
            int tagCount = rnd.Next(1, 4);
            var tags = new string[tagCount];
            for (int t = 0; t < tagCount; t++)
            {
                tags[t] = TagPool[rnd.Next(TagPool.Length)];
            }
            
            list.Add(new Product
            {
                Id = i,
                Name = $"商品 {i:D5}",
                Category = Categories[rnd.Next(Categories.Length)],
                Description = $"これは商品番号 {i} の説明文です。" +
                "高品質な素材を使用しており、多くのお客様にご満足いただいております。" +
                "耐久性に優れ、日常使いに最適な一品です。" +
                "ギフトにもおすすめで、幅広い年代の方にお使いいただけます。",
                Price = Math.Round((decimal)(rnd.NextDouble() * 50000 + 500), 0),
                Stock = rnd.Next(0, 200),
                Tags = tags,
                CreatedAt = DateTime.UtcNow.AddDays(-rnd.Next(0, 365))
            });
        }
        return list;
    }
}